import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:classsync/core/crypto/crypto_service.dart';
import 'package:classsync/core/storage/database_service.dart';
import 'package:classsync/models/quiz.dart';
import 'package:classsync/models/question.dart';
import 'package:classsync/models/student.dart';
import 'package:classsync/models/submission.dart';
import 'package:classsync/providers/student_quiz_provider.dart';
import 'package:classsync/providers/teacher_session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late CryptoService cryptoService;

  setUp(() async {
    cryptoService = CryptoService();
    final dbService = DatabaseService();
    await dbService.init(inMemory: true);
  });

  tearDown(() async {
    final dbService = DatabaseService();
    await dbService.close();
  });

  group('Phase 2 & 3: Quiz Taking, Autosave, Signatures & Teacher Verification', () {
    test('End-to-End Quiz Flow: Autosave -> Ed25519 Signing -> Teacher Verification Gate', () async {
      // 1. Teacher setup
      final teacherNotifier = TeacherSessionNotifier(cryptoService);
      final studentKeyPair = await cryptoService.generateEd25519KeyPair();
      final studentPubKeyHex = await cryptoService.exportPublicKeyHex(studentKeyPair);

      final student = Student(
        studentId: 'std_zahra_18',
        name: 'Fatima Zahra',
        publicKey: studentPubKeyHex,
        classId: 'CS401',
      );

      // Bootstrap student in teacher's roster
      await teacherNotifier.importStudentRoster([student]);

      // Teacher creates and signs a quiz
      final quiz = Quiz(
        quizId: 'quiz_dtn_101',
        teacherId: 'teacher_1',
        title: 'Delay Tolerant Networking Basics',
        timeLimitMinutes: 10,
        questions: [
          Question(
            questionId: 'q1',
            quizId: 'quiz_dtn_101',
            type: QuestionType.mcq,
            body: 'What is the primary routing mechanism in DTN?',
            options: ['Store and Forward', 'Direct Circuit', 'Flooding Only', 'BGP'],
            correctAnswer: '0',
            marks: 2,
          ),
          Question(
            questionId: 'q2',
            quizId: 'quiz_dtn_101',
            type: QuestionType.trueFalse,
            body: 'DTN assumes continuous end-to-end internet connectivity.',
            options: ['True', 'False'],
            correctAnswer: '1',
            marks: 1,
          ),
        ],
      );

      await teacherNotifier.saveQuiz(quiz);
      final session = await teacherNotifier.startSession(quiz.quizId);

      // 2. Student takes the quiz locally
      final studentNotifier = StudentQuizNotifier(cryptoService);
      await studentNotifier.startQuizSession(
        student: student,
        sessionId: session.sessionId,
        quiz: quiz,
        teacherPublicKeyHex: teacherNotifier.state.teacherPublicKeyHex,
      );

      expect(studentNotifier.state.isQuizSignatureVerified, isTrue);

      // Student answers Question 1
      await studentNotifier.recordAnswer(questionId: 'q1', response: '0');
      expect(studentNotifier.state.answers['q1']?.hashChainLink, isNotEmpty);

      // Student answers Question 2
      await studentNotifier.recordAnswer(questionId: 'q2', response: '1');
      expect(studentNotifier.state.answers['q2']?.hashChainLink, isNotEmpty);

      // Student finalizes and submits with Ed25519 signature
      final submission = await studentNotifier.submitQuiz(studentKeyPair: studentKeyPair);
      expect(submission.studentSignature, isNotEmpty);
      expect(submission.score, equals(3));

      // 3. Teacher receives submission and runs cryptographic verification
      final verified = await teacherNotifier.processIncomingSubmission(submission);
      expect(verified, isTrue, reason: 'Valid submission must pass signature and hash chain verification');

      final activeSession = teacherNotifier.state.activeSession!;
      expect(activeSession.submissions.length, equals(1));
      expect(activeSession.submissions.first.status, equals(SubmissionStatus.graded));
      expect(activeSession.submissions.first.isSignatureVerified, isTrue);
      expect(activeSession.submissions.first.isHashChainVerified, isTrue);
    });

    test('Teacher Verification Gate REJECTS submission with tampered answers or invalid signature', () async {
      final teacherNotifier = TeacherSessionNotifier(cryptoService);
      final studentKeyPair = await cryptoService.generateEd25519KeyPair();
      final studentPubKeyHex = await cryptoService.exportPublicKeyHex(studentKeyPair);

      final student = Student(
        studentId: 'std_hacker_99',
        name: 'Malicious Node',
        publicKey: studentPubKeyHex,
        classId: 'CS401',
      );
      await teacherNotifier.importStudentRoster([student]);

      final quiz = Quiz(
        quizId: 'quiz_sec_1',
        teacherId: 'teacher_1',
        title: 'Security Quiz',
        timeLimitMinutes: 5,
        questions: [
          Question(
            questionId: 'q1',
            quizId: 'quiz_sec_1',
            type: QuestionType.mcq,
            body: 'Q1',
            options: ['A', 'B'],
            correctAnswer: '0',
            marks: 2,
          ),
        ],
      );
      await teacherNotifier.saveQuiz(quiz);
      final session = await teacherNotifier.startSession(quiz.quizId);

      // Legitimate submission creation
      final studentNotifier = StudentQuizNotifier(cryptoService);
      await studentNotifier.startQuizSession(
        student: student,
        sessionId: session.sessionId,
        quiz: quiz,
      );
      await studentNotifier.recordAnswer(questionId: 'q1', response: '0');
      final legitimateSub = await studentNotifier.submitQuiz(studentKeyPair: studentKeyPair);

      // Malicious tamper: modify score or modify answers without updating signature
      final tamperedSub = legitimateSub.copyWith(
        score: 100, // inflated
        answers: {
          'q1': legitimateSub.answers['q1']!.copyWith(response: '1'),
        },
      );

      final isAccepted = await teacherNotifier.processIncomingSubmission(tamperedSub);
      expect(isAccepted, isFalse, reason: 'Tampered submission must be rejected');

      final activeSession = teacherNotifier.state.activeSession!;
      expect(activeSession.submissions.first.status, equals(SubmissionStatus.rejected));
      expect(activeSession.submissions.first.verificationError, isNotNull);
    });
  });
}
