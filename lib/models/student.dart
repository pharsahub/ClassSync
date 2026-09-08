enum StudentStatus {
  notStarted,
  inProgress,
  submitted,
}

extension StudentStatusExtension on StudentStatus {
  String get label {
    switch (this) {
      case StudentStatus.notStarted:
        return 'Not Started';
      case StudentStatus.inProgress:
        return 'In Progress';
      case StudentStatus.submitted:
        return 'Submitted';
    }
  }

  String get code => toString().split('.').last;

  static StudentStatus fromString(String val) {
    switch (val) {
      case 'inProgress':
        return StudentStatus.inProgress;
      case 'submitted':
        return StudentStatus.submitted;
      default:
        return StudentStatus.notStarted;
    }
  }
}

class Student {
  final String studentId;
  final String name;
  final String publicKey;
  final String classId;

  // UI / session transient metadata
  final String rollNumber;
  final StudentStatus status;
  final int? score;
  final DateTime joinedAt;
  final DateTime? submittedAt;
  final int currentQuestionIndex;

  // Convenient alias for id -> studentId
  String get id => studentId;

  Student({
    required this.studentId,
    required this.name,
    this.publicKey = '',
    this.classId = 'CLASS-1',
    String? rollNumber,
    this.status = StudentStatus.notStarted,
    this.score,
    DateTime? joinedAt,
    this.submittedAt,
    this.currentQuestionIndex = 0,
  })  : rollNumber = rollNumber ?? studentId,
        joinedAt = joinedAt ?? DateTime.now();

  Student copyWith({
    String? studentId,
    String? name,
    String? publicKey,
    String? classId,
    String? rollNumber,
    StudentStatus? status,
    int? score,
    DateTime? joinedAt,
    DateTime? submittedAt,
    int? currentQuestionIndex,
  }) {
    return Student(
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      publicKey: publicKey ?? this.publicKey,
      classId: classId ?? this.classId,
      rollNumber: rollNumber ?? this.rollNumber,
      status: status ?? this.status,
      score: score ?? this.score,
      joinedAt: joinedAt ?? this.joinedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'name': name,
      'public_key': publicKey,
      'class_id': classId,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    final sId = (map['student_id'] ?? map['id'] ?? '') as String;
    return Student(
      studentId: sId,
      name: map['name'] as String? ?? '',
      publicKey: map['public_key'] as String? ?? '',
      classId: map['class_id'] as String? ?? 'CLASS-1',
      rollNumber: map['rollNumber'] as String? ?? sId,
      status: map['status'] != null
          ? StudentStatusExtension.fromString(map['status'] as String)
          : StudentStatus.notStarted,
      score: map['score'] as int?,
      joinedAt: map['joinedAt'] != null
          ? DateTime.parse(map['joinedAt'] as String)
          : DateTime.now(),
      submittedAt: map['submittedAt'] != null
          ? DateTime.parse(map['submittedAt'] as String)
          : null,
      currentQuestionIndex: map['currentQuestionIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'id': studentId,
      'name': name,
      'public_key': publicKey,
      'class_id': classId,
      'rollNumber': rollNumber,
      'status': status.code,
      'score': score,
      'joinedAt': joinedAt.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'currentQuestionIndex': currentQuestionIndex,
    };
  }

  factory Student.fromJson(Map<String, dynamic> json) => Student.fromMap(json);
}
