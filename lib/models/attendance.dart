class Attendance {
  final String attendanceId;
  final String sessionId;
  final String studentId;
  final DateTime markedAt;

  Attendance({
    required this.attendanceId,
    required this.sessionId,
    required this.studentId,
    DateTime? markedAt,
  }) : markedAt = markedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'attendance_id': attendanceId,
      'session_id': sessionId,
      'student_id': studentId,
      'marked_at': markedAt.toIso8601String(),
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      attendanceId: map['attendance_id'] as String,
      sessionId: map['session_id'] as String,
      studentId: map['student_id'] as String,
      markedAt: DateTime.parse(map['marked_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance.fromMap(json);
}
