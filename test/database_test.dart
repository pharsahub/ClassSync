import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:classsync/core/storage/app_database.dart';
import 'package:classsync/core/crypto/deterministic_ids.dart';
import 'package:classsync/models/teacher.dart';
import 'package:classsync/models/student.dart';
import 'package:classsync/models/device.dart';
import 'package:classsync/models/quiz.dart';
import 'package:classsync/models/question.dart';
import 'package:classsync/models/session.dart';
import 'package:classsync/models/attendance.dart';
import 'package:classsync/models/submission.dart';
import 'package:classsync/models/answer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late AppDatabase appDb;

  setUp(() async {
    appDb = AppDatabase();
    await appDb.initialize(
      inMemory: true,
      customFactory: databaseFactoryFfi,
    );
  });

  tearDown(() async {
    await appDb.close();
  });

  group('SQLite Schema & Core DAOs', () {
    test('Teacher DAO: can upsert and retrieve teacher', () async {
      const teacher = Teacher(
        teacherId: 'teacher_smith',
        name: 'Dr. Jane Smith',
        publicKey: '00112233445566778899aabbccddeeff',
        privateKeyHash: 'hash_priv_123',
      );

      await appDb.upsertTeacher(teacher);
      final retrieved = await appDb.getTeacher('teacher_smith');

      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Dr. Jane Smith'));
      expect(retrieved.publicKey, equals('00112233445566778899aabbccddeeff'));
    });

    test('Student & Device DAO: can upsert, link device, and import roster', () async {
      final s1 = Student(
        studentId: 'std_amina',
        name: 'Amina Al-Mansoor',
        publicKey: 'pub_amina_key_123',
        classId: 'CS301',
      );
      final s2 = Student(
        studentId: 'std_devon',
        name: 'Devon Vance',
        publicKey: 'pub_devon_key_456',
        classId: 'CS301',
      );

      await appDb.importRoster([s1, s2]);
      final allStudents = await appDb.getAllStudents();
      expect(allStudents.length, equals(2));

      const device = Device(
        deviceId: 'dev_amina_phone',
        studentId: 'std_amina',
        platform: 'android',
      );
      await appDb.upsertDevice(device);
      final retrievedDevice = await appDb.getDevice('dev_amina_phone');
      expect(retrievedDevice, isNotNull);
      expect(retrievedDevice!.studentId, equals('std_amina'));
    });

    test('Quiz & Question DAO: can insert quiz with questions and retrieve', () async {
      const teacher = Teacher(
        teacherId: 't1',
        name: 'Prof. Davis',
        publicKey: 'pub_t1',
      );
      await appDb.upsertTeacher(teacher);

      final quiz = Quiz(
        quizId: 'quiz_os_1',
        teacherId: 't1',
        title: 'Operating Systems: Deadlocks',
        description: 'Test on Banker algorithm and semaphore synchronization.',
        timeLimitMinutes: 15,
        signature: 'sig_teacher_ed25519',
        questions: [
          Question(
            questionId: 'q1',
            quizId: 'quiz_os_1',
            type: QuestionType.mcq,
            body: 'What are the 4 Coffman conditions for deadlocks?',
            options: ['Mutual Exclusion, Hold & Wait, No Preemption, Circular Wait', 'Other'],
            correctAnswer: '0',
            marks: 2,
          ),
          Question(
            questionId: 'q2',
            quizId: 'quiz_os_1',
            type: QuestionType.trueFalse,
            body: 'Deadlock prevention eliminates at least one Coffman condition.',
            options: ['True', 'False'],
            correctAnswer: '0',
            marks: 1,
          ),
        ],
      );

      await appDb.insertQuiz(quiz);
      final retrievedQuiz = await appDb.getQuiz('quiz_os_1');

      expect(retrievedQuiz, isNotNull);
      expect(retrievedQuiz!.title, equals('Operating Systems: Deadlocks'));
      expect(retrievedQuiz.questions.length, equals(2));
      expect(retrievedQuiz.signature, equals('sig_teacher_ed25519'));
    });

    test('Attendance & Session DAO: tracks active session and student check-in', () async {
      // 1. Seed Teacher & Student
      const teacher = Teacher(teacherId: 't1', name: 'Prof. Davis', publicKey: 'pub_t1');
      await appDb.upsertTeacher(teacher);

      final student = Student(studentId: 'std_amina', name: 'Amina', publicKey: 'pub_a', classId: 'CS1');
      await appDb.upsertStudent(student);

      // 2. Seed Quiz
      final quiz = Quiz(
        quizId: 'quiz_os_1',
        teacherId: 't1',
        title: 'OS Quiz',
        timeLimitMinutes: 10,
        questions: [],
      );
      await appDb.insertQuiz(quiz);

      // 3. Create Session
      final session = Session(
        sessionId: 'session_live_89',
        quizId: 'quiz_os_1',
        teacherId: 't1',
        qrToken: 'qr_secret_token_123',
        status: SessionStatus.waiting,
      );
      await appDb.insertSession(session);
      await appDb.updateSessionStatus('session_live_89', SessionStatus.inProgress);

      final retrieved = await appDb.getSession('session_live_89');
      expect(retrieved, isNotNull);
      expect(retrieved!.status, equals(SessionStatus.inProgress));

      final att = Attendance(
        attendanceId: 'att_01',
        sessionId: 'session_live_89',
        studentId: 'std_amina',
      );
      await appDb.markAttendance(att);

      final sessionAttendance = await appDb.getAttendanceForSession('session_live_89');
      expect(sessionAttendance.length, equals(1));
      expect(sessionAttendance.first.studentId, equals('std_amina'));
    });

    test('Submission DAO: Deterministic ID deduplication collapses duplicate incoming syncs', () async {
      // 1. Seed Teacher, Student, Device, Quiz, Question, Session
      const teacher = Teacher(teacherId: 't1', name: 'Prof. Davis', publicKey: 'pub_t1');
      await appDb.upsertTeacher(teacher);

      final student = Student(studentId: 'std_amina', name: 'Amina', publicKey: 'pub_a', classId: 'CS1');
      await appDb.upsertStudent(student);

      const device = Device(deviceId: 'dev_amina_phone', studentId: 'std_amina', platform: 'android');
      await appDb.upsertDevice(device);

      final quiz = Quiz(
        quizId: 'quiz_os_1',
        teacherId: 't1',
        title: 'OS Quiz',
        timeLimitMinutes: 10,
        questions: [
          Question(
            questionId: 'q1',
            quizId: 'quiz_os_1',
            type: QuestionType.mcq,
            body: 'Q1 body',
            options: ['A', 'B'],
            correctAnswer: '0',
            marks: 2,
          ),
          Question(
            questionId: 'q2',
            quizId: 'quiz_os_1',
            type: QuestionType.trueFalse,
            body: 'Q2 body',
            options: ['True', 'False'],
            correctAnswer: '0',
            marks: 1,
          ),
        ],
      );
      await appDb.insertQuiz(quiz);

      final session = Session(
        sessionId: 'session_live_89',
        quizId: 'quiz_os_1',
        teacherId: 't1',
        qrToken: 'qr_token_89',
      );
      await appDb.insertSession(session);

      const studentId = 'std_amina';
      const sessionId = 'session_live_89';
      const deviceId = 'dev_amina_phone';

      final deterministicSubId = DeterministicIds.generateSubmissionId(
        studentId: studentId,
        sessionId: sessionId,
        deviceId: deviceId,
      );

      final submission1 = Submission(
        submissionId: deterministicSubId,
        sessionId: sessionId,
        studentId: studentId,
        deviceId: deviceId,
        studentSignature: 'sig_submission_amina_ed25519',
        score: 3,
        totalPossibleMarks: 3,
        answers: {
          'q1': Answer(
            answerId: 'ans_1',
            submissionId: deterministicSubId,
            questionId: 'q1',
            response: '0',
            hashChainLink: 'hash_link_1',
            isCorrect: true,
            marksAwarded: 2,
          ),
          'q2': Answer(
            answerId: 'ans_2',
            submissionId: deterministicSubId,
            questionId: 'q2',
            response: '0',
            hashChainLink: 'hash_link_2',
            isCorrect: true,
            marksAwarded: 1,
          ),
        },
      );

      // First sync arrives
      await appDb.upsertSubmission(submission1);

      final subsAfterFirst = await appDb.getSubmissionsForSession(sessionId);
      expect(subsAfterFirst.length, equals(1));
      expect(subsAfterFirst.first.answers.length, equals(2));

      // Network dropped and reconnected later -> Student device resends same submission
      final duplicateSubmission = submission1.copyWith(
        syncStatus: SyncStatus.synced,
      );
      await appDb.upsertSubmission(duplicateSubmission);

      // Verify that NO duplicate record was created
      final subsAfterSecond = await appDb.getSubmissionsForSession(sessionId);
      expect(subsAfterSecond.length, equals(1), reason: 'Duplicate submissions must collapse to 1 row');
      expect(subsAfterSecond.first.submissionId, equals(deterministicSubId));
    });
  });
}
