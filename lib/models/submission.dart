import 'answer.dart';

enum SubmissionStatus {
  inProgress,
  submitted,
  graded,
}

class Submission {
  final String id;
  final String sessionId;
  final String quizId;
  final String studentId;
  final String studentName;
  final String studentRollNumber;
  final Map<String, Answer> answers; // key: questionId
  final int score;
  final int totalPossibleMarks;
  final DateTime submittedAt;
  final SubmissionStatus status;

  // TODO(crypto): In the next phase, embed an ECDSA digital signature here.
  // The signature will be generated on the student device using the student's private key
  // to guarantee non-repudiation and tamper resistance when transmitting over DTN/Bluetooth.
  final String? digitalSignature;
  final bool isSignatureVerified;

  Submission({
    required this.id,
    required this.sessionId,
    required this.quizId,
    required this.studentId,
    required this.studentName,
    required this.studentRollNumber,
    required this.answers,
    required this.score,
    required this.totalPossibleMarks,
    DateTime? submittedAt,
    this.status = SubmissionStatus.submitted,
    this.digitalSignature,
    this.isSignatureVerified = false,
  }) : submittedAt = submittedAt ?? DateTime.now();

  double get percentage =>
      totalPossibleMarks > 0 ? (score / totalPossibleMarks) * 100 : 0.0;

  Submission copyWith({
    String? id,
    String? sessionId,
    String? quizId,
    String? studentId,
    String? studentName,
    String? studentRollNumber,
    Map<String, Answer>? answers,
    int? score,
    int? totalPossibleMarks,
    DateTime? submittedAt,
    SubmissionStatus? status,
    String? digitalSignature,
    bool? isSignatureVerified,
  }) {
    return Submission(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      quizId: quizId ?? this.quizId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentRollNumber: studentRollNumber ?? this.studentRollNumber,
      answers: answers ?? Map.from(this.answers),
      score: score ?? this.score,
      totalPossibleMarks: totalPossibleMarks ?? this.totalPossibleMarks,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      digitalSignature: digitalSignature ?? this.digitalSignature,
      isSignatureVerified: isSignatureVerified ?? this.isSignatureVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'quizId': quizId,
      'studentId': studentId,
      'studentName': studentName,
      'studentRollNumber': studentRollNumber,
      'answers': answers.map((k, v) => MapEntry(k, v.toJson())),
      'score': score,
      'totalPossibleMarks': totalPossibleMarks,
      'submittedAt': submittedAt.toIso8601String(),
      'status': status.name,
      'digitalSignature': digitalSignature,
      'isSignatureVerified': isSignatureVerified,
    };
  }

  factory Submission.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as Map<String, dynamic>? ?? {};
    final answersMap = rawAnswers.map(
      (k, v) => MapEntry(k, Answer.fromJson(v as Map<String, dynamic>)),
    );

    return Submission(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      quizId: json['quizId'] as String,
      studentId: json['studentId'] as String,
      studentName: json['studentName'] as String,
      studentRollNumber: json['studentRollNumber'] as String? ?? '',
      answers: answersMap,
      score: json['score'] as int? ?? 0,
      totalPossibleMarks: json['totalPossibleMarks'] as int? ?? 0,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : DateTime.now(),
      status: SubmissionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SubmissionStatus.submitted,
      ),
      digitalSignature: json['digitalSignature'] as String?,
      isSignatureVerified: json['isSignatureVerified'] as bool? ?? false,
    );
  }
}
