import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cryptography/cryptography.dart';
import 'package:csv/csv.dart';

import '../core/constants/app_constants.dart';
import '../core/crypto/crypto_service.dart';
import '../core/crypto/hash_chain.dart';
import '../core/storage/database_service.dart';
import '../core/utils/id_generator.dart';
import '../models/quiz.dart';
import '../models/session.dart';
import '../models/student.dart';
import '../models/submission.dart';
import '../models/teacher.dart';
import 'crypto_providers.dart';

class TeacherState {
  final Teacher? currentTeacher;
  final SimpleKeyPair? teacherKeyPair;
  final String teacherPublicKeyHex;
  final List<Quiz> quizzes;
  final List<Student> registeredRoster;
  final Session? activeSession;
  final List<Session> completedSessions;
  final String? ephemeralAesKeyHex;
  final String? qrPayload;

  const TeacherState({
    this.currentTeacher,
    this.teacherKeyPair,
    this.teacherPublicKeyHex = '',
    this.quizzes = const [],
    this.registeredRoster = const [],
    this.activeSession,
    this.completedSessions = const [],
    this.ephemeralAesKeyHex,
    this.qrPayload,
  });

  TeacherState copyWith({
    Teacher? currentTeacher,
    SimpleKeyPair? teacherKeyPair,
    String? teacherPublicKeyHex,
    List<Quiz>? quizzes,
    List<Student>? registeredRoster,
    Session? activeSession,
    List<Session>? completedSessions,
    String? ephemeralAesKeyHex,
    String? qrPayload,
    bool clearActiveSession = false,
  }) {
    return TeacherState(
      currentTeacher: currentTeacher ?? this.currentTeacher,
      teacherKeyPair: teacherKeyPair ?? this.teacherKeyPair,
      teacherPublicKeyHex: teacherPublicKeyHex ?? this.teacherPublicKeyHex,
      quizzes: quizzes ?? this.quizzes,
      registeredRoster: registeredRoster ?? this.registeredRoster,
      activeSession: clearActiveSession ? null : (activeSession ?? this.activeSession),
      completedSessions: completedSessions ?? this.completedSessions,
      ephemeralAesKeyHex: ephemeralAesKeyHex ?? this.ephemeralAesKeyHex,
      qrPayload: qrPayload ?? this.qrPayload,
    );
  }
}

class TeacherSessionNotifier extends StateNotifier<TeacherState> {
  final CryptoService _cryptoService;

  TeacherSessionNotifier(this._cryptoService)
      : super(const TeacherState(
          currentTeacher: Teacher(
            teacherId: 'teacher_prof_anderson',
            name: AppConstants.defaultTeacherName,
            publicKey: '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff',
          ),
          teacherPublicKeyHex: '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff',
        ));

  Future<void> initializeTeacherKeys() async {
    if (state.teacherKeyPair != null) return;
    final keyPair = await _cryptoService.generateEd25519KeyPair();
    final pubKeyHex = await _cryptoService.exportPublicKeyHex(keyPair);

    final defaultTeacher = Teacher(
      teacherId: 'teacher_prof_anderson',
      name: AppConstants.defaultTeacherName,
      publicKey: pubKeyHex,
    );

    state = state.copyWith(
      currentTeacher: defaultTeacher,
      teacherKeyPair: keyPair,
      teacherPublicKeyHex: pubKeyHex,
    );

    await loadInitialData();
  }

  Future<void> loadInitialData() async {
    final dbService = DatabaseService();
    if (dbService.isInitialized) {
      final dbQuizzes = await dbService.db.getAllQuizzes();
      final dbRoster = await dbService.db.getAllStudents();
      final dbSessions = await dbService.db.getAllSessions();

      state = state.copyWith(
        quizzes: dbQuizzes,
        registeredRoster: dbRoster,
        completedSessions: dbSessions.where((s) => s.status == SessionStatus.completed).toList(),
      );
    }
  }

  // -------------------------------------------------------------
  // ROSTER / TRUST BOOTSTRAPPING
  // -------------------------------------------------------------

  Future<void> importStudentRoster(List<Student> students) async {
    final dbService = DatabaseService();
    if (dbService.isInitialized) {
      await dbService.db.importRoster(students);
    }

    final updated = List<Student>.from(state.registeredRoster);
    for (final s in students) {
      updated.removeWhere((item) => item.studentId == s.studentId);
      updated.add(s);
    }

    state = state.copyWith(registeredRoster: updated);
  }

  // -------------------------------------------------------------
  // QUIZ REPOSITORY
  // -------------------------------------------------------------

  Future<void> saveQuiz(Quiz quiz) async {
    // If not signed yet and keys available, sign with teacher's private key
    Quiz signedQuiz = quiz;
    if (quiz.signature == null) {
      if (state.teacherKeyPair == null) {
        await initializeTeacherKeys();
      }
      if (state.teacherKeyPair != null) {
        final payload = quiz.getSignablePayload();
        final sigHex = await _cryptoService.signMessage(payload, state.teacherKeyPair!);
        signedQuiz = quiz.copyWith(signature: sigHex);
      }
    }

    final dbService = DatabaseService();
    if (dbService.isInitialized) {
      await dbService.db.insertQuiz(signedQuiz);
    }

    final updatedQuizzes = List<Quiz>.from(state.quizzes)
      ..removeWhere((q) => q.quizId == signedQuiz.quizId)
      ..insert(0, signedQuiz);

    state = state.copyWith(quizzes: updatedQuizzes);
  }

  Future<void> deleteQuiz(String quizId) async {
    final dbService = DatabaseService();
    if (dbService.isInitialized) {
      await dbService.db.deleteQuiz(quizId);
    }

    final updatedQuizzes = List<Quiz>.from(state.quizzes)
      ..removeWhere((q) => q.quizId == quizId);

    state = state.copyWith(
      quizzes: updatedQuizzes,
      clearActiveSession: state.activeSession?.quizId == quizId,
    );
  }

  // -------------------------------------------------------------
  // SESSION CREATION & QR ENCODING
  // -------------------------------------------------------------

  Future<Session> startSession(String quizId) async {
    if (state.teacherKeyPair == null) {
      await initializeTeacherKeys();
    }

    final quiz = state.quizzes.firstWhere(
      (q) => q.quizId == quizId,
      orElse: () => state.quizzes.first,
    );

    // 1. Ensure Quiz is digitally signed
    Quiz signedQuiz = quiz;
    if (quiz.signature == null && state.teacherKeyPair != null) {
      final payload = quiz.getSignablePayload();
      final sigHex = await _cryptoService.signMessage(payload, state.teacherKeyPair!);
      signedQuiz = quiz.copyWith(signature: sigHex);
    }

    // 2. Generate Ephemeral AES-256 Session Key
    final aesKey = await _cryptoService.generateAesKey();
    final aesKeyHex = await _cryptoService.exportAesKeyHex(aesKey);

    // 3. Create Session with QR Token
    final sessionId = IdGenerator.generate('ses');
    final sessionCode = IdGenerator.generateSessionCode();
    final qrToken = await _cryptoService.hashString('qr_seed:$sessionId:$aesKeyHex');

    // 4. QR Code encodes ONLY session_id + ephemeral_key + session_code + teacher_pubkey
    final qrData = jsonEncode({
      'type': 'classsync_session',
      'session_id': sessionId,
      'session_code': sessionCode,
      'ephemeral_key': aesKeyHex,
      'teacher_pubkey': state.teacherPublicKeyHex,
    });

    final newSession = Session(
      sessionId: sessionId,
      quizId: signedQuiz.quizId,
      quiz: signedQuiz,
      teacherId: state.currentTeacher?.teacherId ?? 'teacher_1',
      teacherName: state.currentTeacher?.name ?? AppConstants.defaultTeacherName,
      sessionCode: sessionCode,
      qrToken: qrToken,
      status: SessionStatus.waiting,
      connectedStudents: [],
      submissions: [],
    );

    final dbService = DatabaseService();
    if (dbService.isInitialized) {
      await dbService.db.insertSession(newSession);
    }

    state = state.copyWith(
      activeSession: newSession,
      ephemeralAesKeyHex: aesKeyHex,
      qrPayload: qrData,
    );

    return newSession;
  }

  Future<void> startQuizForSession() async {
    if (state.activeSession == null) return;
    final updated = state.activeSession!.copyWith(
      status: SessionStatus.inProgress,
      connectedStudents: state.activeSession!.connectedStudents.map((s) {
        return s.copyWith(status: StudentStatus.inProgress);
      }).toList(),
    );

    final dbService = DatabaseService();
    if (dbService.isInitialized) {
      await dbService.db.updateSessionStatus(updated.sessionId, SessionStatus.inProgress);
    }

    state = state.copyWith(activeSession: updated);
  }

  Future<void> endSession() async {
    if (state.activeSession == null) return;
    final finalized = state.activeSession!.copyWith(status: SessionStatus.completed);

    final dbService = DatabaseService();
    if (dbService.isInitialized) {
      await dbService.db.updateSessionStatus(finalized.sessionId, SessionStatus.completed);
    }

    final updatedCompleted = List<Session>.from(state.completedSessions)..insert(0, finalized);
    state = state.copyWith(
      completedSessions: updatedCompleted,
      clearActiveSession: true,
      qrPayload: null,
      ephemeralAesKeyHex: null,
    );
  }

  // -------------------------------------------------------------
  // INCOMING SUBMISSION VERIFICATION GATE
  // -------------------------------------------------------------

  Future<bool> processIncomingSubmission(Submission submission) async {
    final active = state.activeSession;
    if (active == null) return false;

    // 1. Resolve student public key from roster or submission
    final student = state.registeredRoster.cast<Student?>().firstWhere(
          (s) => s?.studentId == submission.studentId,
          orElse: () => null,
        );

    final pubKeyHex = student?.publicKey.isNotEmpty == true
        ? student!.publicKey
        : '';

    bool sigValid = false;
    String? verificationError;

    if (pubKeyHex.isEmpty) {
      verificationError = 'Unknown student: Public key not registered in teacher roster';
    } else {
      // 2. Verify Ed25519 signature
      final signablePayload = submission.getSignablePayload();
      sigValid = await _cryptoService.verifySignature(
        message: signablePayload,
        signatureHex: submission.studentSignature,
        publicKeyHex: pubKeyHex,
      );

      if (!sigValid) {
        verificationError = 'Digital signature verification FAILED — submission was modified or invalid key';
      }
    }

    // 3. Verify Answer Hash Chain
    bool chainValid = false;
    if (sigValid) {
      final genesis = await HashChainEngine.computeGenesisHash(
        submissionId: submission.submissionId,
        studentId: submission.studentId,
        cryptoService: _cryptoService,
      );

      final answersList = submission.answers.values.toList()
        ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

      final chainItems = answersList.map((a) {
        return AnswerChainItem(
          questionId: a.questionId,
          response: a.response,
          timestampMs: a.timestampMs,
          hashChainLink: a.hashChainLink,
        );
      }).toList();

      chainValid = await HashChainEngine.verifyChain(
        answers: chainItems,
        genesisHash: genesis,
        cryptoService: _cryptoService,
      );

      if (!chainValid) {
        verificationError = 'Tamper detected: Hash chain broken between answers';
      }
    }

    final isFullyVerified = sigValid && chainValid;

    final processedSubmission = submission.copyWith(
      status: isFullyVerified ? SubmissionStatus.graded : SubmissionStatus.rejected,
      isSignatureVerified: sigValid,
      isHashChainVerified: chainValid,
      verificationError: verificationError,
    );

    // Save to SQLite
    final dbService = DatabaseService();
    if (dbService.isInitialized) {
      await dbService.db.upsertSubmission(processedSubmission);
    }

    // Update session state
    final updatedSubs = List<Submission>.from(active.submissions)
      ..removeWhere((s) => s.submissionId == submission.submissionId)
      ..add(processedSubmission);

    final updatedStudents = List<Student>.from(active.connectedStudents);
    final existingIdx = updatedStudents.indexWhere((s) => s.studentId == submission.studentId);
    if (existingIdx >= 0) {
      updatedStudents[existingIdx] = updatedStudents[existingIdx].copyWith(
        status: StudentStatus.submitted,
        score: processedSubmission.score,
        submittedAt: DateTime.now(),
      );
    }

    state = state.copyWith(
      activeSession: active.copyWith(
        submissions: updatedSubs,
        connectedStudents: updatedStudents,
      ),
    );

    return isFullyVerified;
  }

  // -------------------------------------------------------------
  // CSV EXPORT OF MARKS & ATTENDANCE
  // -------------------------------------------------------------

  String exportSessionToCsv(Session session) {
    final List<List<dynamic>> rows = [];

    rows.add([
      'Session Code',
      'Quiz Title',
      'Student ID',
      'Student Name',
      'Score',
      'Total Marks',
      'Percentage (%)',
      'Signature Verified',
      'Hash Chain Intact',
      'Status',
      'Submitted At',
    ]);

    final quizTitle = session.quiz?.title ?? 'Class Assessment';

    for (final sub in session.submissions) {
      rows.add([
        session.sessionCode,
        quizTitle,
        sub.studentId,
        sub.studentName.isNotEmpty ? sub.studentName : sub.studentId,
        sub.score,
        sub.totalPossibleMarks,
        sub.percentage.toStringAsFixed(1),
        sub.isSignatureVerified ? 'YES' : 'NO',
        sub.isHashChainVerified ? 'YES' : 'NO',
        sub.status.name.toUpperCase(),
        sub.submittedAt.toIso8601String(),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}

final teacherSessionProvider = StateNotifierProvider<TeacherSessionNotifier, TeacherState>((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  return TeacherSessionNotifier(crypto);
});
