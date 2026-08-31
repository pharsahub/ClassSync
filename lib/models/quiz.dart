import 'question.dart';

class Quiz {
  final String id;
  final String title;
  final String description;
  final int timeLimitMinutes;
  final List<Question> questions;
  final DateTime createdAt;

  Quiz({
    required this.id,
    required this.title,
    this.description = '',
    required this.timeLimitMinutes,
    required this.questions,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalMarks => questions.fold(0, (sum, q) => sum + q.marks);
  int get questionCount => questions.length;

  Quiz copyWith({
    String? id,
    String? title,
    String? description,
    int? timeLimitMinutes,
    List<Question>? questions,
    DateTime? createdAt,
  }) {
    return Quiz(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
      questions: questions ?? List.from(this.questions),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'timeLimitMinutes': timeLimitMinutes,
      'questions': questions.map((q) => q.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      timeLimitMinutes: json['timeLimitMinutes'] as int? ?? 10,
      questions: (json['questions'] as List? ?? [])
          .map((q) => Question.fromJson(q as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
