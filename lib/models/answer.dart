class Answer {
  final String questionId;
  final int? selectedOptionIndex; // null or -1 if skipped
  final bool isCorrect;
  final int marksAwarded;

  Answer({
    required this.questionId,
    this.selectedOptionIndex,
    this.isCorrect = false,
    this.marksAwarded = 0,
  });

  bool get isAnswered => selectedOptionIndex != null && selectedOptionIndex! >= 0;

  Answer copyWith({
    String? questionId,
    int? selectedOptionIndex,
    bool? isCorrect,
    int? marksAwarded,
  }) {
    return Answer(
      questionId: questionId ?? this.questionId,
      selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
      isCorrect: isCorrect ?? this.isCorrect,
      marksAwarded: marksAwarded ?? this.marksAwarded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'selectedOptionIndex': selectedOptionIndex,
      'isCorrect': isCorrect,
      'marksAwarded': marksAwarded,
    };
  }

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      questionId: json['questionId'] as String,
      selectedOptionIndex: json['selectedOptionIndex'] as int?,
      isCorrect: json['isCorrect'] as bool? ?? false,
      marksAwarded: json['marksAwarded'] as int? ?? 0,
    );
  }
}
