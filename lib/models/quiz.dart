import 'dart:convert';
import 'question.dart';

class Quiz {
  final String quizId;
  final String teacherId;
  final String title;
  final String description;
  final int timeLimitMinutes;
  final DateTime createdAt;
  final String? signature;
  final List<Question> questions;

  // Backward compatibility alias for UI
  String get id => quizId;
  int get totalMarks => questions.fold(0, (sum, q) => sum + q.marks);
  int get questionCount => questions.length;

  Quiz({
    required String quizId,
    this.teacherId = 'teacher_default',
    required this.title,
    this.description = '',
    required this.timeLimitMinutes,
    DateTime? createdAt,
    this.signature,
    List<Question>? questions,
  })  : quizId = quizId,
        createdAt = createdAt ?? DateTime.now(),
        questions = questions ?? [];

  // Convenience constructor supporting legacy parameter name 'id'
  factory Quiz.create({
    required String id,
    String teacherId = 'teacher_default',
    required this_title,
    String description = '',
    required int timeLimitMinutes,
    DateTime? createdAt,
    String? signature,
    List<Question>? questions,
  }) {
    return Quiz(
      quizId: id,
      teacherId: teacherId,
      title: this_title,
      description: description,
      timeLimitMinutes: timeLimitMinutes,
      createdAt: createdAt,
      signature: signature,
      questions: questions,
    );
  }

  Quiz copyWith({
    String? quizId,
    String? teacherId,
    String? title,
    String? description,
    int? timeLimitMinutes,
    DateTime? createdAt,
    String? signature,
    List<Question>? questions,
    String? id, // legacy
  }) {
    return Quiz(
      quizId: quizId ?? id ?? this.quizId,
      teacherId: teacherId ?? this.teacherId,
      title: title ?? this.title,
      description: description ?? this.description,
      timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
      createdAt: createdAt ?? this.createdAt,
      signature: signature ?? this.signature,
      questions: questions ?? List.from(this.questions),
    );
  }

  /// Canonical string payload used for cryptographic signature verification.
  String getSignablePayload() {
    final sortedQuestions = List<Question>.from(questions)
      ..sort((a, b) => a.questionId.compareTo(b.questionId));

    final questionsPayload = sortedQuestions.map((q) => {
      'id': q.questionId,
      'body': q.body,
      'type': q.type.code,
      'options': q.options,
      'correct_answer': q.correctAnswer,
      'marks': q.marks,
    }).toList();

    return jsonEncode({
      'quiz_id': quizId,
      'teacher_id': teacherId,
      'title': title,
      'time_limit': timeLimitMinutes,
      'created_at': createdAt.toIso8601String(),
      'questions': questionsPayload,
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'quiz_id': quizId,
      'teacher_id': teacherId,
      'title': title,
      'description': description,
      'time_limit': timeLimitMinutes,
      'created_at': createdAt.toIso8601String(),
      'signature': signature,
    };
  }

  factory Quiz.fromMap(Map<String, dynamic> map, {List<Question>? questions}) {
    final qId = (map['quiz_id'] ?? map['id'] ?? '') as String;
    final timeLimit = (map['time_limit'] ?? map['timeLimitMinutes'] ?? 10) as int;

    return Quiz(
      quizId: qId,
      teacherId: map['teacher_id'] as String? ?? 'teacher_default',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      timeLimitMinutes: timeLimit,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : (map['createdAt'] != null
              ? DateTime.parse(map['createdAt'] as String)
              : DateTime.now()),
      signature: map['signature'] as String?,
      questions: questions ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'id': quizId,
      'teacher_id': teacherId,
      'title': title,
      'description': description,
      'time_limit': timeLimitMinutes,
      'timeLimitMinutes': timeLimitMinutes,
      'created_at': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'signature': signature,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  factory Quiz.fromJson(Map<String, dynamic> json) {
    final rawQuestions = (json['questions'] as List? ?? [])
        .map((q) => Question.fromJson(q as Map<String, dynamic>))
        .toList();

    return Quiz.fromMap(json, questions: rawQuestions);
  }
}
