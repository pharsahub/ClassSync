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

  String get code {
    switch (this) {
      case SessionStatus.waiting:
        return 'waiting';
      case SessionStatus.inProgress:
        return 'in_progress';
      case SessionStatus.completed:
        return 'completed';
    }
  }

  static SessionStatus fromString(String val) {
    final lower = val.toLowerCase().replaceAll('_', '');
    if (lower.contains('progress')) return SessionStatus.inProgress;
    if (lower.contains('comp')) return SessionStatus.completed;
    return SessionStatus.waiting;
  }
}

class Session {
  final String sessionId;
  final String quizId;
  final String teacherId;
  final String qrToken;
  final DateTime startedAt;
  final SessionStatus status;

  // Transient / linked objects
  final Quiz? quiz;
  final String sessionCode;
  final String teacherName;
  final List<Student> connectedStudents;
  final List<Submission> submissions;

  // Backward compatibility alias for UI
  String get id => sessionId;
  int get studentCount => connectedStudents.length;
  int get submittedCount =>
      connectedStudents.where((s) => s.status == StudentStatus.submitted).length;
  int get inProgressCount =>
      connectedStudents.where((s) => s.status == StudentStatus.inProgress).length;

  Session({
    required String sessionId,
    required this.quizId,
    required this.teacherId,
    String? qrToken,
    DateTime? startedAt,
    this.status = SessionStatus.waiting,
    this.quiz,
    String? sessionCode,
    this.teacherName = 'Prof. Anderson',
    List<Student>? connectedStudents,
    List<Submission>? submissions,
  })  : sessionId = sessionId,
        qrToken = qrToken ?? sessionId,
        sessionCode = sessionCode ?? (sessionId.length >= 6 ? sessionId.substring(0, 6).toUpperCase() : sessionId),
        startedAt = startedAt ?? DateTime.now(),
        connectedStudents = connectedStudents ?? [],
        submissions = submissions ?? [];

  Session copyWith({
    String? sessionId,
    String? quizId,
    String? teacherId,
    String? qrToken,
    DateTime? startedAt,
    SessionStatus? status,
    Quiz? quiz,
    String? sessionCode,
    String? teacherName,
    List<Student>? connectedStudents,
    List<Submission>? submissions,
    String? id, // legacy
  }) {
    return Session(
      sessionId: sessionId ?? id ?? this.sessionId,
      quizId: quizId ?? this.quizId,
      teacherId: teacherId ?? this.teacherId,
      qrToken: qrToken ?? this.qrToken,
      startedAt: startedAt ?? this.startedAt,
      status: status ?? this.status,
      quiz: quiz ?? this.quiz,
      sessionCode: sessionCode ?? this.sessionCode,
      teacherName: teacherName ?? this.teacherName,
      connectedStudents: connectedStudents ?? List.from(this.connectedStudents),
      submissions: submissions ?? List.from(this.submissions),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'quiz_id': quizId,
      'teacher_id': teacherId,
      'qr_token': qrToken,
      'started_at': startedAt.toIso8601String(),
      'status': status.code,
    };
  }

  factory Session.fromMap(
    Map<String, dynamic> map, {
    Quiz? quiz,
    List<Student>? connectedStudents,
    List<Submission>? submissions,
  }) {
    final sId = (map['session_id'] ?? map['id'] ?? '') as String;
    final rawStatus = (map['status'] ?? 'waiting') as String;

    return Session(
      sessionId: sId,
      quizId: map['quiz_id'] as String? ?? map['quizId'] as String? ?? '',
      teacherId: map['teacher_id'] as String? ?? map['teacherId'] as String? ?? 'teacher_1',
      qrToken: map['qr_token'] as String? ?? map['qrToken'] as String? ?? sId,
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : (map['startedAt'] != null
              ? DateTime.parse(map['startedAt'] as String)
              : DateTime.now()),
      status: SessionStatusExtension.fromString(rawStatus),
      quiz: quiz,
      sessionCode: map['session_code'] as String? ?? map['sessionCode'] as String?,
      teacherName: map['teacher_name'] as String? ?? map['teacherName'] as String? ?? 'Prof. Anderson',
      connectedStudents: connectedStudents ?? [],
      submissions: submissions ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'id': sessionId,
      'quiz_id': quizId,
      'quizId': quizId,
      'teacher_id': teacherId,
      'teacherId': teacherId,
      'qr_token': qrToken,
      'qrToken': qrToken,
      'started_at': startedAt.toIso8601String(),
      'startedAt': startedAt.toIso8601String(),
      'status': status.name,
      'sessionCode': sessionCode,
      'teacherName': teacherName,
      'quiz': quiz?.toJson(),
      'connectedStudents': connectedStudents.map((s) => s.toJson()).toList(),
      'submissions': submissions.map((s) => s.toJson()).toList(),
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    final quiz = json['quiz'] != null ? Quiz.fromJson(json['quiz'] as Map<String, dynamic>) : null;
    final students = (json['connectedStudents'] as List? ?? [])
        .map((s) => Student.fromJson(s as Map<String, dynamic>))
        .toList();
    final submissions = (json['submissions'] as List? ?? [])
        .map((s) => Submission.fromJson(s as Map<String, dynamic>))
        .toList();

    return Session.fromMap(
      json,
      quiz: quiz,
      connectedStudents: students,
      submissions: submissions,
    );
  }
}
