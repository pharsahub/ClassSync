import 'dart:convert';
import '../core/crypto/deterministic_ids.dart';
import 'answer.dart';

enum SubmissionStatus {
  inProgress,
  submitted,
  graded,
  rejected,
}

enum SyncStatus {
  pending,
  synced,
  failed,
}

class Submission {
  final String submissionId;
  final String sessionId;
  final String studentId;
  final String deviceId;
  final DateTime startTs;
  final DateTime submitTs;
  final String studentSignature;
  final SyncStatus syncStatus;

  // Additional metadata & linked answers
  final String quizId;
  final String studentName;
  final String studentRollNumber;
  final Map<String, Answer> answers; // key: questionId
  final int score;
  final int totalPossibleMarks;
  final SubmissionStatus status;
  final bool isSignatureVerified;
  final bool isHashChainVerified;
  final String? verificationError;

  // Backward compatibility alias for UI
  String get id => submissionId;
  DateTime get submittedAt => submitTs;
  String? get digitalSignature => studentSignature.isNotEmpty ? studentSignature : null;
  double get percentage =>
      totalPossibleMarks > 0 ? (score / totalPossibleMarks) * 100 : 0.0;

  Submission({
    String? submissionId,
    required this.sessionId,
    required this.studentId,
    String? deviceId,
    DateTime? startTs,
    DateTime? submitTs,
    this.studentSignature = '',
    this.syncStatus = SyncStatus.pending,
    this.quizId = '',
    this.studentName = '',
    this.studentRollNumber = '',
    Map<String, Answer>? answers,
    this.score = 0,
    this.totalPossibleMarks = 0,
    this.status = SubmissionStatus.submitted,
    this.isSignatureVerified = false,
    this.isHashChainVerified = false,
    this.verificationError,
  })  : deviceId = deviceId ?? DeterministicIds.generateDeviceId(studentId: studentId, platformName: 'mobile'),
        submissionId = submissionId ??
            DeterministicIds.generateSubmissionId(
              studentId: studentId,
              sessionId: sessionId,
              deviceId: deviceId ?? DeterministicIds.generateDeviceId(studentId: studentId, platformName: 'mobile'),
            ),
        startTs = startTs ?? DateTime.now(),
        submitTs = submitTs ?? DateTime.now(),
        answers = answers ?? {};

  Submission copyWith({
    String? submissionId,
    String? sessionId,
    String? studentId,
    String? deviceId,
    DateTime? startTs,
    DateTime? submitTs,
    String? studentSignature,
    SyncStatus? syncStatus,
    String? quizId,
    String? studentName,
    String? studentRollNumber,
    Map<String, Answer>? answers,
    int? score,
    int? totalPossibleMarks,
    SubmissionStatus? status,
    bool? isSignatureVerified,
    bool? isHashChainVerified,
    String? verificationError,
    // legacy
    String? id,
    DateTime? submittedAt,
    String? digitalSignature,
  }) {
    return Submission(
      submissionId: submissionId ?? id ?? this.submissionId,
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      deviceId: deviceId ?? this.deviceId,
      startTs: startTs ?? this.startTs,
      submitTs: submitTs ?? submittedAt ?? this.submitTs,
      studentSignature: studentSignature ?? digitalSignature ?? this.studentSignature,
      syncStatus: syncStatus ?? this.syncStatus,
      quizId: quizId ?? this.quizId,
      studentName: studentName ?? this.studentName,
      studentRollNumber: studentRollNumber ?? this.studentRollNumber,
      answers: answers ?? Map.from(this.answers),
      score: score ?? this.score,
      totalPossibleMarks: totalPossibleMarks ?? this.totalPossibleMarks,
      status: status ?? this.status,
      isSignatureVerified: isSignatureVerified ?? this.isSignatureVerified,
      isHashChainVerified: isHashChainVerified ?? this.isHashChainVerified,
      verificationError: verificationError ?? this.verificationError,
    );
  }

  /// Generates the canonical payload string to be signed by the student's Ed25519 private key.
  String getSignablePayload() {
    final sortedAnswers = answers.values.toList()
      ..sort((a, b) => a.questionId.compareTo(b.questionId));

    final answersList = sortedAnswers.map((a) => {
      'question_id': a.questionId,
      'response': a.response,
      'hash_chain_link': a.hashChainLink,
      'timestamp_ms': a.timestampMs,
    }).toList();

    return jsonEncode({
      'submission_id': submissionId,
      'session_id': sessionId,
      'student_id': studentId,
      'device_id': deviceId,
      'start_ts': startTs.toIso8601String(),
      'submit_ts': submitTs.toIso8601String(),
      'answers': answersList,
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'submission_id': submissionId,
      'session_id': sessionId,
      'student_id': studentId,
      'device_id': deviceId,
      'start_ts': startTs.toIso8601String(),
      'submit_ts': submitTs.toIso8601String(),
      'student_signature': studentSignature,
      'sync_status': syncStatus.name,
      'score': score,
      'total_possible_marks': totalPossibleMarks,
      'status': status.name,
      'is_signature_verified': isSignatureVerified ? 1 : 0,
      'is_hash_chain_verified': isHashChainVerified ? 1 : 0,
      'verification_error': verificationError,
    };
  }

  factory Submission.fromMap(Map<String, dynamic> map, {Map<String, Answer>? answers}) {
    final sId = (map['submission_id'] ?? map['id'] ?? '') as String;
    final stId = (map['student_id'] ?? map['studentId'] ?? '') as String;
    final sesId = (map['session_id'] ?? map['sessionId'] ?? '') as String;
    final devId = (map['device_id'] ?? map['deviceId'] ?? DeterministicIds.generateDeviceId(studentId: stId, platformName: 'mobile')) as String;

    final rawSig = (map['student_signature'] ?? map['digitalSignature'] ?? '') as String;
    final rawSync = (map['sync_status'] ?? 'pending') as String;
    final rawStatus = (map['status'] ?? 'submitted') as String;

    return Submission(
      submissionId: sId.isNotEmpty
          ? sId
          : DeterministicIds.generateSubmissionId(
              studentId: stId,
              sessionId: sesId,
              deviceId: devId,
            ),
      sessionId: sesId,
      studentId: stId,
      deviceId: devId,
      startTs: map['start_ts'] != null
          ? DateTime.parse(map['start_ts'] as String)
          : DateTime.now(),
      submitTs: map['submit_ts'] != null
          ? DateTime.parse(map['submit_ts'] as String)
          : (map['submittedAt'] != null
              ? DateTime.parse(map['submittedAt'] as String)
              : DateTime.now()),
      studentSignature: rawSig,
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == rawSync,
        orElse: () => SyncStatus.pending,
      ),
      quizId: map['quizId'] as String? ?? map['quiz_id'] as String? ?? '',
      studentName: map['studentName'] as String? ?? map['student_name'] as String? ?? '',
      studentRollNumber: map['studentRollNumber'] as String? ?? map['student_roll_number'] as String? ?? stId,
      answers: answers ?? {},
      score: map['score'] as int? ?? 0,
      totalPossibleMarks: (map['total_possible_marks'] ?? map['totalPossibleMarks'] ?? 0) as int,
      status: SubmissionStatus.values.firstWhere(
        (s) => s.name == rawStatus,
        orElse: () => SubmissionStatus.submitted,
      ),
      isSignatureVerified: (map['is_signature_verified'] == 1 || map['isSignatureVerified'] == true),
      isHashChainVerified: (map['is_hash_chain_verified'] == 1 || map['isHashChainVerified'] == true),
      verificationError: map['verification_error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'submission_id': submissionId,
      'id': submissionId,
      'session_id': sessionId,
      'sessionId': sessionId,
      'student_id': studentId,
      'studentId': studentId,
      'device_id': deviceId,
      'deviceId': deviceId,
      'quiz_id': quizId,
      'quizId': quizId,
      'student_name': studentName,
      'studentName': studentName,
      'student_roll_number': studentRollNumber,
      'studentRollNumber': studentRollNumber,
      'start_ts': startTs.toIso8601String(),
      'submit_ts': submitTs.toIso8601String(),
      'submittedAt': submitTs.toIso8601String(),
      'student_signature': studentSignature,
      'digitalSignature': studentSignature,
      'sync_status': syncStatus.name,
      'status': status.name,
      'score': score,
      'total_possible_marks': totalPossibleMarks,
      'totalPossibleMarks': totalPossibleMarks,
      'is_signature_verified': isSignatureVerified,
      'isSignatureVerified': isSignatureVerified,
      'is_hash_chain_verified': isHashChainVerified,
      'isHashChainVerified': isHashChainVerified,
      'verification_error': verificationError,
      'answers': answers.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  factory Submission.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as Map<String, dynamic>? ?? {};
    final answersMap = rawAnswers.map(
      (k, v) => MapEntry(k, Answer.fromJson(v as Map<String, dynamic>)),
    );

    return Submission.fromMap(json, answers: answersMap);
  }
}
