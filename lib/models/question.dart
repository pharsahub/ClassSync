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

  String get code => toString().split('.').last;

  static QuestionType fromString(String val) {
    if (val == 'trueFalse') return QuestionType.trueFalse;
    return QuestionType.mcq;
  }
}

class Question {
  final String id;
  final String quizId;
  final String text;
  final QuestionType type;
  final List<String> options;
  final int correctOptionIndex;
  final int marks;
  final String? explanation;

  Question({
    required this.id,
    required this.quizId,
    required this.text,
    required this.type,
    required this.options,
    required this.correctOptionIndex,
    this.marks = 1,
    this.explanation,
  });

  Question copyWith({
    String? id,
    String? quizId,
    String? text,
    QuestionType? type,
    List<String>? options,
    int? correctOptionIndex,
    int? marks,
    String? explanation,
  }) {
    return Question(
      id: id ?? this.id,
      quizId: quizId ?? this.quizId,
      text: text ?? this.text,
      type: type ?? this.type,
      options: options ?? List.from(this.options),
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      marks: marks ?? this.marks,
      explanation: explanation ?? this.explanation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quizId': quizId,
      'text': text,
      'type': type.code,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'marks': marks,
      'explanation': explanation,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      quizId: json['quizId'] as String? ?? '',
      text: json['text'] as String,
      type: QuestionTypeExtension.fromString(json['type'] as String? ?? 'mcq'),
      options: List<String>.from(json['options'] as List? ?? []),
      correctOptionIndex: json['correctOptionIndex'] as int? ?? 0,
      marks: json['marks'] as int? ?? 1,
      explanation: json['explanation'] as String?,
    );
  }
}
