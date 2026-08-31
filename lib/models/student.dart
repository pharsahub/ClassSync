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
  final String id;
  final String name;
  final String rollNumber;
  final StudentStatus status;
  final int? score;
  final DateTime joinedAt;
  final DateTime? submittedAt;
  final int currentQuestionIndex;

  Student({
    required this.id,
    required this.name,
    required this.rollNumber,
    this.status = StudentStatus.notStarted,
    this.score,
    DateTime? joinedAt,
    this.submittedAt,
    this.currentQuestionIndex = 0,
  }) : joinedAt = joinedAt ?? DateTime.now();

  Student copyWith({
    String? id,
    String? name,
    String? rollNumber,
    StudentStatus? status,
    int? score,
    DateTime? joinedAt,
    DateTime? submittedAt,
    int? currentQuestionIndex,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNumber: rollNumber ?? this.rollNumber,
      status: status ?? this.status,
      score: score ?? this.score,
      joinedAt: joinedAt ?? this.joinedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rollNumber': rollNumber,
      'status': status.code,
      'score': score,
      'joinedAt': joinedAt.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'currentQuestionIndex': currentQuestionIndex,
    };
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      name: json['name'] as String,
      rollNumber: json['rollNumber'] as String? ?? '',
      status: StudentStatusExtension.fromString(json['status'] as String? ?? 'notStarted'),
      score: json['score'] as int?,
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'] as String)
          : DateTime.now(),
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      currentQuestionIndex: json['currentQuestionIndex'] as int? ?? 0,
    );
  }
}
