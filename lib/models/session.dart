import 'quiz.dart';
import 'student.dart';
import 'submission.dart';

enum SessionStatus {
  waiting,
  inProgress,
  completed,
}

extension SessionStatusExtension on SessionStatus {
  String get label {
    switch (this) {
      case SessionStatus.waiting:
        return 'Lobby (Waiting)';
      case SessionStatus.inProgress:
        return 'In Progress';
      case SessionStatus.completed:
        return 'Completed';
    }
  }
}

class Session {
  final String id;
  final String quizId;
  final Quiz? quiz;
  final String sessionCode; // 6-char alphanumeric code (e.g. CS-8492)
  final String teacherId;
  final String teacherName;
  final DateTime startedAt;
  final SessionStatus status;
  final List<Student> connectedStudents;
  final List<Submission> submissions;

  // TODO(dtn): When real DTN sync is integrated, this session object will contain:
  // - Bluetooth Low Energy (BLE) Service UUIDs for service advertisement
  // - Wi-Fi Direct / Nearby Connections Service IDs
  // - Bundle routing TTL and hop count metadata

  Session({
    required this.id,
    required this.quizId,
    this.quiz,
    required this.sessionCode,
    required this.teacherId,
    this.teacherName = 'Prof. Anderson',
    DateTime? startedAt,
    this.status = SessionStatus.waiting,
    List<Student>? connectedStudents,
    List<Submission>? submissions,
  })  : startedAt = startedAt ?? DateTime.now(),
        connectedStudents = connectedStudents ?? [],
        submissions = submissions ?? [];

  int get studentCount => connectedStudents.length;
  int get submittedCount =>
      connectedStudents.where((s) => s.status == StudentStatus.submitted).length;
  int get inProgressCount =>
      connectedStudents.where((s) => s.status == StudentStatus.inProgress).length;

  Session copyWith({
    String? id,
    String? quizId,
    Quiz? quiz,
    String? sessionCode,
    String? teacherId,
    String? teacherName,
    DateTime? startedAt,
    SessionStatus? status,
    List<Student>? connectedStudents,
    List<Submission>? submissions,
  }) {
    return Session(
      id: id ?? this.id,
      quizId: quizId ?? this.quizId,
      quiz: quiz ?? this.quiz,
      sessionCode: sessionCode ?? this.sessionCode,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      startedAt: startedAt ?? this.startedAt,
      status: status ?? this.status,
      connectedStudents: connectedStudents ?? List.from(this.connectedStudents),
      submissions: submissions ?? List.from(this.submissions),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quizId': quizId,
      'quiz': quiz?.toJson(),
      'sessionCode': sessionCode,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'startedAt': startedAt.toIso8601String(),
      'status': status.name,
      'connectedStudents': connectedStudents.map((s) => s.toJson()).toList(),
      'submissions': submissions.map((s) => s.toJson()).toList(),
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      quizId: json['quizId'] as String,
      quiz: json['quiz'] != null
          ? Quiz.fromJson(json['quiz'] as Map<String, dynamic>)
          : null,
      sessionCode: json['sessionCode'] as String,
      teacherId: json['teacherId'] as String? ?? 'teacher_default',
      teacherName: json['teacherName'] as String? ?? 'Prof. Anderson',
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : DateTime.now(),
      status: SessionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SessionStatus.waiting,
      ),
      connectedStudents: (json['connectedStudents'] as List? ?? [])
          .map((s) => Student.fromJson(s as Map<String, dynamic>))
          .toList(),
      submissions: (json['submissions'] as List? ?? [])
          .map((s) => Submission.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
