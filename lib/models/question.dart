import 'dart:convert';

enum QuestionType {
  mcq,
  trueFalse,
}

extension QuestionTypeExtension on QuestionType {
  String get displayName {
    switch (this) {
      case QuestionType.mcq:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True / False';
    }
  }

  String get code {
    switch (this) {
      case QuestionType.mcq:
        return 'mcq';
      case QuestionType.trueFalse:
        return 'true_false';
    }
  }

  static QuestionType fromString(String val) {
    final lower = val.toLowerCase().replaceAll('_', '');
    if (lower.contains('true') || lower.contains('tf')) {
      return QuestionType.trueFalse;
    }
    return QuestionType.mcq;
  }
}

class Question {
  final String questionId;
  final String quizId;
  final QuestionType type;
  final String body;
  final List<String> options;
  final String correctAnswer;
  final int marks;
  final String? explanation;

  // Backward compatibility alias for UI
  String get id => questionId;
  String get text => body;
  int get correctOptionIndex {
    final parsed = int.tryParse(correctAnswer);
    if (parsed != null) return parsed;
    final idx = options.indexOf(correctAnswer);
    return idx >= 0 ? idx : 0;
  }

  Question({
    required String questionId,
    required this.quizId,
    required this.type,
    required this.body,
    required this.options,
    required this.correctAnswer,
    this.marks = 1,
    this.explanation,
  }) : questionId = questionId;

  // Convenience constructor supporting legacy parameter names (id, text, correctOptionIndex)
  factory Question.create({
    required String id,
    required String quizId,
    required String text,
    required QuestionType type,
    required List<String> options,
    int? correctOptionIndex,
    String? correctAnswer,
    int marks = 1,
    String? explanation,
  }) {
    final answerStr = correctAnswer ?? (correctOptionIndex != null ? correctOptionIndex.toString() : '0');
    return Question(
      questionId: id,
      quizId: quizId,
      type: type,
      body: text,
      options: options,
      correctAnswer: answerStr,
      marks: marks,
      explanation: explanation,
    );
  }

  Question copyWith({
    String? questionId,
    String? quizId,
    QuestionType? type,
    String? body,
    List<String>? options,
    String? correctAnswer,
    int? marks,
    String? explanation,
    // Legacy support
    String? id,
    String? text,
    int? correctOptionIndex,
  }) {
    return Question(
      questionId: questionId ?? id ?? this.questionId,
      quizId: quizId ?? this.quizId,
      type: type ?? this.type,
      body: body ?? text ?? this.body,
      options: options ?? List.from(this.options),
      correctAnswer: correctAnswer ??
          (correctOptionIndex != null ? correctOptionIndex.toString() : this.correctAnswer),
      marks: marks ?? this.marks,
      explanation: explanation ?? this.explanation,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question_id': questionId,
      'quiz_id': quizId,
      'type': type.code,
      'body': body,
      'options': jsonEncode(options),
      'correct_answer': correctAnswer,
      'marks': marks,
      'explanation': explanation,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    List<String> parsedOptions = [];
    if (map['options'] is String) {
      try {
        final decoded = jsonDecode(map['options'] as String);
        if (decoded is List) {
          parsedOptions = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedOptions = [];
      }
    } else if (map['options'] is List) {
      parsedOptions = (map['options'] as List).map((e) => e.toString()).toList();
    }

    final qId = (map['question_id'] ?? map['id'] ?? '') as String;
    final qBody = (map['body'] ?? map['text'] ?? '') as String;
    final rawType = (map['type'] ?? 'mcq') as String;
    final rawCorrect = map['correct_answer'] != null
        ? map['correct_answer'].toString()
        : (map['correctOptionIndex']?.toString() ?? '0');

    return Question(
      questionId: qId,
      quizId: map['quiz_id'] as String? ?? map['quizId'] as String? ?? '',
      type: QuestionTypeExtension.fromString(rawType),
      body: qBody,
      options: parsedOptions,
      correctAnswer: rawCorrect,
      marks: map['marks'] as int? ?? 1,
      explanation: map['explanation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'id': questionId,
      'quiz_id': quizId,
      'quizId': quizId,
      'type': type.code,
      'body': body,
      'text': body,
      'options': options,
      'correct_answer': correctAnswer,
      'correctOptionIndex': correctOptionIndex,
      'marks': marks,
      'explanation': explanation,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) => Question.fromMap(json);
}
