import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/answer.dart';
import '../../models/attendance.dart';
import '../../models/device.dart';
import '../../models/question.dart';
import '../../models/quiz.dart';
import '../../models/session.dart';
import '../../models/student.dart';
import '../../models/submission.dart';
import '../../models/teacher.dart';

/// SQLite Database Manager and DAO layer for ClassSync.
class AppDatabase {
  static const String dbFileName = 'classsync.db';
  static const int dbVersion = 1;

  Database? _db;

  Database get db {
    if (_db == null) {
      throw StateError('Database has not been initialized. Call initialize() first.');
    }
    return _db!;
  }

  /// Initializes the SQLite database (supporting Mobile, Desktop FFI, and In-Memory tests).
  Future<void> initialize({bool inMemory = false, DatabaseFactory? customFactory}) async {
    if (_db != null && _db!.isOpen) return;

    DatabaseFactory factory;
    if (customFactory != null) {
      factory = customFactory;
    } else if (kIsWeb) {
      throw UnsupportedError('SQLite FFI is not supported on Flutter Web.');
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = databaseFactory;
    }

    String path;
    if (inMemory) {
      path = inMemoryDatabasePath;
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      path = p.join(docDir.path, dbFileName);
    }

    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: dbVersion,
        onCreate: _onCreate,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE teachers (
        teacher_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        public_key TEXT NOT NULL,
        private_key_hash TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE students (
        student_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        public_key TEXT NOT NULL,
        class_id TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE devices (
        device_id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        platform TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE quizzes (
        quiz_id TEXT PRIMARY KEY,
        teacher_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        time_limit INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        signature TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE questions (
        question_id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        type TEXT NOT NULL,
        body TEXT NOT NULL,
        options TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        marks INTEGER NOT NULL,
        explanation TEXT,
        FOREIGN KEY (quiz_id) REFERENCES quizzes(quiz_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        session_id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        teacher_id TEXT NOT NULL,
        qr_token TEXT NOT NULL,
        started_at TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (quiz_id) REFERENCES quizzes(quiz_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        attendance_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        marked_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE submissions (
        submission_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        start_ts TEXT NOT NULL,
        submit_ts TEXT NOT NULL,
        student_signature TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        score INTEGER DEFAULT 0,
        total_possible_marks INTEGER DEFAULT 0,
        status TEXT DEFAULT 'submitted',
        is_signature_verified INTEGER DEFAULT 0,
        is_hash_chain_verified INTEGER DEFAULT 0,
        verification_error TEXT,
        FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE answers (
        answer_id TEXT PRIMARY KEY,
        submission_id TEXT NOT NULL,
        question_id TEXT NOT NULL,
        response TEXT NOT NULL,
        hash_chain_link TEXT NOT NULL,
        FOREIGN KEY (submission_id) REFERENCES submissions(submission_id) ON DELETE CASCADE,
        FOREIGN KEY (question_id) REFERENCES questions(question_id) ON DELETE CASCADE
      )
    ''');

    // Indexing for high-performance DTN queries
    await db.execute('CREATE INDEX idx_answers_submission ON answers(submission_id)');
    await db.execute('CREATE INDEX idx_submissions_session ON submissions(session_id)');
    await db.execute('CREATE INDEX idx_questions_quiz ON questions(quiz_id)');
  }

  // -------------------------------------------------------------
  // TEACHER DAO
  // -------------------------------------------------------------

  Future<void> upsertTeacher(Teacher teacher) async {
    await db.insert('teachers', teacher.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Teacher?> getTeacher(String teacherId) async {
    final maps = await db.query('teachers', where: 'teacher_id = ?', whereArgs: [teacherId], limit: 1);
    if (maps.isEmpty) return null;
    return Teacher.fromMap(maps.first);
  }

  // -------------------------------------------------------------
  // STUDENT DAO
  // -------------------------------------------------------------

  Future<void> upsertStudent(Student student) async {
    await db.insert('students', student.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Student?> getStudent(String studentId) async {
    final maps = await db.query('students', where: 'student_id = ?', whereArgs: [studentId], limit: 1);
    if (maps.isEmpty) return null;
    return Student.fromMap(maps.first);
  }

  Future<List<Student>> getAllStudents() async {
    final maps = await db.query('students', orderBy: 'name ASC');
    return maps.map((m) => Student.fromMap(m)).toList();
  }

  Future<void> importRoster(List<Student> students) async {
    final batch = db.batch();
    for (final s in students) {
      batch.insert('students', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // -------------------------------------------------------------
  // DEVICE DAO
  // -------------------------------------------------------------

  Future<void> upsertDevice(Device device) async {
    await db.insert('devices', device.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Device?> getDevice(String deviceId) async {
    final maps = await db.query('devices', where: 'device_id = ?', whereArgs: [deviceId], limit: 1);
    if (maps.isEmpty) return null;
    return Device.fromMap(maps.first);
  }

  // -------------------------------------------------------------
  // QUIZ & QUESTION DAO
  // -------------------------------------------------------------

  Future<void> insertQuiz(Quiz quiz) async {
    await db.transaction((txn) async {
      await txn.insert('quizzes', quiz.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (final q in quiz.questions) {
        await txn.insert('questions', q.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<Quiz?> getQuiz(String quizId) async {
    final quizMaps = await db.query('quizzes', where: 'quiz_id = ?', whereArgs: [quizId], limit: 1);
    if (quizMaps.isEmpty) return null;

    final questionMaps = await db.query(
      'questions',
      where: 'quiz_id = ?',
      whereArgs: [quizId],
      orderBy: 'question_id ASC',
    );
    final questions = questionMaps.map((m) => Question.fromMap(m)).toList();

    return Quiz.fromMap(quizMaps.first, questions: questions);
  }

  Future<List<Quiz>> getAllQuizzes() async {
    final quizMaps = await db.query('quizzes', orderBy: 'created_at DESC');
    if (quizMaps.isEmpty) return [];

    final allQuestionMaps = await db.query('questions');
    final Map<String, List<Question>> questionsByQuiz = {};
    for (final qMap in allQuestionMaps) {
      final quizId = qMap['quiz_id'] as String;
      questionsByQuiz.putIfAbsent(quizId, () => []).add(Question.fromMap(qMap));
    }

    return quizMaps.map((qMap) {
      final quizId = qMap['quiz_id'] as String;
      return Quiz.fromMap(qMap, questions: questionsByQuiz[quizId] ?? []);
    }).toList();
  }

  Future<void> deleteQuiz(String quizId) async {
    await db.delete('quizzes', where: 'quiz_id = ?', whereArgs: [quizId]);
  }

  // -------------------------------------------------------------
  // SESSION DAO
  // -------------------------------------------------------------

  Future<void> insertSession(Session session) async {
    await db.insert('sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSessionStatus(String sessionId, SessionStatus status) async {
    await db.update(
      'sessions',
      {'status': status.code},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<Session?> getSession(String sessionId) async {
    final sessionMaps = await db.query('sessions', where: 'session_id = ?', whereArgs: [sessionId], limit: 1);
    if (sessionMaps.isEmpty) return null;

    final quizId = sessionMaps.first['quiz_id'] as String;
    final quiz = await getQuiz(quizId);
    final submissions = await getSubmissionsForSession(sessionId);

    return Session.fromMap(sessionMaps.first, quiz: quiz, submissions: submissions);
  }

  Future<List<Session>> getAllSessions() async {
    final sessionMaps = await db.query('sessions', orderBy: 'started_at DESC');
    if (sessionMaps.isEmpty) return [];

    final quizzes = await getAllQuizzes();
    final Map<String, Quiz> quizMap = {for (final q in quizzes) q.quizId: q};

    final List<Session> result = [];
    for (final sMap in sessionMaps) {
      final quizId = sMap['quiz_id'] as String;
      final sessionId = sMap['session_id'] as String;
      final quiz = quizMap[quizId];
      final submissions = await getSubmissionsForSession(sessionId);
      result.add(Session.fromMap(sMap, quiz: quiz, submissions: submissions));
    }

    return result;
  }

  // -------------------------------------------------------------
  // ATTENDANCE DAO
  // -------------------------------------------------------------

  Future<void> markAttendance(Attendance attendance) async {
    await db.insert('attendance', attendance.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Attendance>> getAttendanceForSession(String sessionId) async {
    final maps = await db.query('attendance', where: 'session_id = ?', whereArgs: [sessionId]);
    return maps.map((m) => Attendance.fromMap(m)).toList();
  }

  // -------------------------------------------------------------
  // SUBMISSION & ANSWER DAO (Deterministic deduplication)
  // -------------------------------------------------------------

  /// Upserts a submission and its associated answers in a single transaction.
  /// Because `submission_id` is deterministic, arriving duplicates collapse cleanly.
  Future<void> upsertSubmission(Submission submission) async {
    await db.transaction((txn) async {
      await txn.insert(
        'submissions',
        submission.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final answer in submission.answers.values) {
        final answerWithSubId = answer.copyWith(submissionId: submission.submissionId);
        await txn.insert(
          'answers',
          answerWithSubId.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Saves or updates an individual answer with its computed hash chain link.
  Future<void> saveAnswer(Answer answer) async {
    await db.insert('answers', answer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Submission>> getSubmissionsForSession(String sessionId) async {
    final subMaps = await db.query('submissions', where: 'session_id = ?', whereArgs: [sessionId]);
    if (subMaps.isEmpty) return [];

    final List<Submission> result = [];
    for (final sMap in subMaps) {
      final subId = sMap['submission_id'] as String;
      final answerMaps = await db.query('answers', where: 'submission_id = ?', whereArgs: [subId]);
      final answers = {
        for (final aMap in answerMaps)
          aMap['question_id'] as String: Answer.fromMap(aMap)
      };

      final student = await getStudent(sMap['student_id'] as String);

      result.add(Submission.fromMap(
        sMap,
        answers: answers,
      ).copyWith(
        studentName: student?.name,
      ));
    }

    return result;
  }

  Future<Submission?> getSubmission(String submissionId) async {
    final subMaps = await db.query('submissions', where: 'submission_id = ?', whereArgs: [submissionId], limit: 1);
    if (subMaps.isEmpty) return null;

    final answerMaps = await db.query('answers', where: 'submission_id = ?', whereArgs: [submissionId]);
    final answers = {
      for (final aMap in answerMaps)
        aMap['question_id'] as String: Answer.fromMap(aMap)
    };

    final student = await getStudent(subMaps.first['student_id'] as String);

    return Submission.fromMap(
      subMaps.first,
      answers: answers,
    ).copyWith(
      studentName: student?.name,
    );
  }

  /// Closes database connection.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
