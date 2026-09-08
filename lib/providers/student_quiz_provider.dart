import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cryptography/cryptography.dart';

import '../core/crypto/crypto_service.dart';
import '../core/crypto/deterministic_ids.dart';
import '../core/crypto/hash_chain.dart';
import '../core/storage/database_service.dart';
import '../models/answer.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../models/student.dart';
import '../models/submission.dart';
import 'crypto_providers.dart';

class StudentQuizState {
  final Student? currentStudent;
  final String? sessionId;
  final Quiz? activeQuiz;
  final String? submissionId;
  final String? genesisHash;
  final String? latestHashChainLink;
  final Map<String, Answer> answers; // questionId -> Answer
  final int currentQuestionIndex;
  final int remainingSeconds;
  final int totalSeconds;
  final bool isTimerActive;
  final bool isSubmitted;
  final Submission? finalSubmission;
  final String? errorMessage;
  final bool isQuizSignatureVerified;

  const StudentQuizState({
    this.currentStudent,
    this.sessionId,
    this.activeQuiz,
    this.submissionId,
    this.genesisHash,
    this.latestHashChainLink,
    this.answers = const {},
    this.currentQuestionIndex = 0,
    this.remainingSeconds = 0,
    this.totalSeconds = 0,
    this.isTimerActive = false,
    this.isSubmitted = false,
    this.finalSubmission,
    this.errorMessage,
    this.isQuizSignatureVerified = true,
  });

  StudentQuizState copyWith({
    Student? currentStudent,
    String? sessionId,
    Quiz? activeQuiz,
    String? submissionId,
    String? genesisHash,
    String? latestHashChainLink,
    Map<String, Answer>? answers,
    int? currentQuestionIndex,
    int? remainingSeconds,
    int? totalSeconds,
    bool? isTimerActive,
    bool? isSubmitted,
    Submission? finalSubmission,
    String? errorMessage,
    bool? isQuizSignatureVerified,
  }) {
    return StudentQuizState(
      currentStudent: currentStudent ?? this.currentStudent,
      sessionId: sessionId ?? this.sessionId,
      activeQuiz: activeQuiz ?? this.activeQuiz,
      submissionId: submissionId ?? this.submissionId,
      genesisHash: genesisHash ?? this.genesisHash,
      latestHashChainLink: latestHashChainLink ?? this.latestHashChainLink,
      answers: answers ?? this.answers,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      isTimerActive: isTimerActive ?? this.isTimerActive,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      finalSubmission: finalSubmission ?? this.finalSubmission,
      errorMessage: errorMessage,
      isQuizSignatureVerified: isQuizSignatureVerified ?? this.isQuizSignatureVerified,
    );
  }
}

class StudentQuizNotifier extends StateNotifier<StudentQuizState> {
  final CryptoService _cryptoService;
  Timer? _timer;

  StudentQuizNotifier(this._cryptoService) : super(const StudentQuizState());

  /// Initializes a student quiz session with cryptographic bootstrapping.
  Future<void> startQuizSession({
    required Student student,
    required String sessionId,
    required Quiz quiz,
    String? teacherPublicKeyHex,
  }) async {
    _timer?.cancel();

    // 1. Verify Teacher Signature if signature & public key are present
    bool sigValid = true;
    if (quiz.signature != null && teacherPublicKeyHex != null && teacherPublicKeyHex.isNotEmpty) {
      sigValid = await _cryptoService.verifySignature(
        message: quiz.getSignablePayload(),
        signatureHex: quiz.signature!,
        publicKeyHex: teacherPublicKeyHex,
      );
    }

    // 2. Generate deterministic submission ID
    final deviceId = DeterministicIds.generateDeviceId(
      studentId: student.studentId,
      platformName: 'mobile',
    );
    final subId = DeterministicIds.generateSubmissionId(
      studentId: student.studentId,
      sessionId: sessionId,
      deviceId: deviceId,
    );

    // 3. Compute deterministic genesis hash for hash chain
    final genesisHash = await HashChainEngine.computeGenesisHash(
      submissionId: subId,
      studentId: student.studentId,
      cryptoService: _cryptoService,
    );

    final totalSecs = quiz.timeLimitMinutes * 60;

    state = StudentQuizState(
      currentStudent: student,
      sessionId: sessionId,
      activeQuiz: quiz,
      submissionId: subId,
      genesisHash: genesisHash,
      latestHashChainLink: genesisHash,
      answers: {},
      currentQuestionIndex: 0,
      totalSeconds: totalSecs,
      remainingSeconds: totalSecs,
      isTimerActive: true,
      isSubmitted: false,
      isQuizSignatureVerified: sigValid,
    );

    // 4. Try resuming any previously autosaved answers from SQLite
    await _tryResumeFromStorage(subId, genesisHash);

    // 5. Start timer countdown
    _startTimer();
  }

  Future<void> _tryResumeFromStorage(String subId, String genesisHash) async {
    try {
      final dbService = DatabaseService();
      if (dbService.isInitialized) {
        final existing = await dbService.db.getSubmission(subId);
        if (existing != null && existing.answers.isNotEmpty) {
          // Replay hash chain to find the latest valid link
          final answersList = existing.answers.values.toList()
            ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

          String currentLink = genesisHash;
          for (final a in answersList) {
            if (a.hashChainLink.isNotEmpty) {
              currentLink = a.hashChainLink;
            }
          }

          state = state.copyWith(
            answers: Map.from(existing.answers),
            latestHashChainLink: currentLink,
            currentQuestionIndex: existing.answers.length < (state.activeQuiz?.questions.length ?? 1)
                ? existing.answers.length
                : 0,
          );
        }
      }
    } catch (_) {
      // Storage recovery fallback
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 1) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        timer.cancel();
        state = state.copyWith(remainingSeconds: 0, isTimerActive: false);
      }
    });
  }

  void setQuestionIndex(int index) {
    if (state.activeQuiz == null) return;
    if (index >= 0 && index < state.activeQuiz!.questions.length) {
      state = state.copyWith(currentQuestionIndex: index);
    }
  }

  /// Records an answer with immediate, incremental SHA-256 hash chaining and SQLite autosave.
  Future<void> recordAnswer({
    required String questionId,
    required String response,
  }) async {
    if (state.isSubmitted || state.submissionId == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final previousHash = state.latestHashChainLink ?? state.genesisHash ?? 'GENESIS_DEFAULT';

    // 1. Calculate incremental hash chain link
    final newHashLink = await HashChainEngine.computeLink(
      previousHash: previousHash,
      questionId: questionId,
      response: response,
      timestampMs: nowMs,
      cryptoService: _cryptoService,
    );

    // 2. Grade answer locally
    final quiz = state.activeQuiz;
    bool isCorrect = false;
    int marks = 0;
    if (quiz != null) {
      final question = quiz.questions.firstWhere(
        (q) => q.questionId == questionId,
        orElse: () => quiz.questions.first,
      );
      isCorrect = (response.trim() == question.correctAnswer.trim());
      marks = isCorrect ? question.marks : 0;
    }

    final answer = Answer(
      submissionId: state.submissionId!,
      questionId: questionId,
      response: response,
      hashChainLink: newHashLink,
      timestampMs: nowMs,
      isCorrect: isCorrect,
      marksAwarded: marks,
    );

    final updatedAnswers = Map<String, Answer>.from(state.answers);
    updatedAnswers[questionId] = answer;

    state = state.copyWith(
      answers: updatedAnswers,
      latestHashChainLink: newHashLink,
    );

    // 3. Autosave to SQLite asynchronously
    try {
      final dbService = DatabaseService();
      if (dbService.isInitialized) {
        await dbService.db.saveAnswer(answer);
      }
    } catch (_) {}
  }

  /// Finalizes the submission, generates Ed25519 digital signature, and saves to SQLite.
  Future<Submission> submitQuiz({required SimpleKeyPair studentKeyPair}) async {
    _timer?.cancel();

    final quiz = state.activeQuiz!;
    final student = state.currentStudent!;
    final subId = state.submissionId!;
    final sessionId = state.sessionId!;

    int totalScore = 0;
    for (final a in state.answers.values) {
      totalScore += a.marksAwarded;
    }

    // Build base submission
    var submission = Submission(
      submissionId: subId,
      sessionId: sessionId,
      studentId: student.studentId,
      quizId: quiz.quizId,
      studentName: student.name,
      studentRollNumber: student.rollNumber,
      answers: state.answers,
      score: totalScore,
      totalPossibleMarks: quiz.totalMarks,
      status: SubmissionStatus.submitted,
      submitTs: DateTime.now(),
    );

    // Generate student's digital signature over the canonical payload
    final signablePayload = submission.getSignablePayload();
    final signatureHex = await _cryptoService.signMessage(signablePayload, studentKeyPair);

    submission = submission.copyWith(
      studentSignature: signatureHex,
      isSignatureVerified: true,
      isHashChainVerified: true,
    );

    // Persist final submission to local SQLite
    try {
      final dbService = DatabaseService();
      if (dbService.isInitialized) {
        await dbService.db.upsertSubmission(submission);
      }
    } catch (_) {}

    state = state.copyWith(
      isSubmitted: true,
      isTimerActive: false,
      finalSubmission: submission,
    );

    return submission;
  }

  void reset() {
    _timer?.cancel();
    state = const StudentQuizState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final studentQuizProvider = StateNotifierProvider<StudentQuizNotifier, StudentQuizState>((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  return StudentQuizNotifier(crypto);
});
