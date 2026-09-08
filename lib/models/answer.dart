import '../core/crypto/deterministic_ids.dart';

class Answer {
  final String answerId;
  final String submissionId;
  final String questionId;
  final String response;
  final String hashChainLink;

  // Metadata / UI convenience
  final int timestampMs;
  final bool isCorrect;
  final int marksAwarded;

  int? get selectedOptionIndex => int.tryParse(response);
  bool get isAnswered => response.isNotEmpty;

  Answer({
    String? answerId,
    this.submissionId = '',
    required this.questionId,
    required this.response,
    this.hashChainLink = '',
    int? timestampMs,
    this.isCorrect = false,
    this.marksAwarded = 0,
  })  : answerId = answerId ??
            (submissionId.isNotEmpty
                ? DeterministicIds.generateAnswerId(
                    submissionId: submissionId,
                    questionId: questionId,
                  )
                : 'ans_$questionId'),
        timestampMs = timestampMs ?? DateTime.now().millisecondsSinceEpoch;

  // Convenience constructor for legacy option index usage
  factory Answer.fromOptionIndex({
    String? answerId,
    String submissionId = '',
    required String questionId,
    int? selectedOptionIndex,
    String hashChainLink = '',
    int? timestampMs,
    bool isCorrect = false,
    int marksAwarded = 0,
  }) {
    return Answer(
      answerId: answerId,
      submissionId: submissionId,
      questionId: questionId,
      response: selectedOptionIndex != null ? selectedOptionIndex.toString() : '',
      hashChainLink: hashChainLink,
      timestampMs: timestampMs,
      isCorrect: isCorrect,
      marksAwarded: marksAwarded,
    );
  }

  Answer copyWith({
    String? answerId,
    String? submissionId,
    String? questionId,
    String? response,
    String? hashChainLink,
    int? timestampMs,
    bool? isCorrect,
    int? marksAwarded,
    int? selectedOptionIndex, // legacy
  }) {
    return Answer(
      answerId: answerId ?? this.answerId,
      submissionId: submissionId ?? this.submissionId,
      questionId: questionId ?? this.questionId,
      response: response ??
          (selectedOptionIndex != null ? selectedOptionIndex.toString() : this.response),
      hashChainLink: hashChainLink ?? this.hashChainLink,
      timestampMs: timestampMs ?? this.timestampMs,
      isCorrect: isCorrect ?? this.isCorrect,
      marksAwarded: marksAwarded ?? this.marksAwarded,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'answer_id': answerId,
      'submission_id': submissionId,
      'question_id': questionId,
      'response': response,
      'hash_chain_link': hashChainLink,
    };
  }

  factory Answer.fromMap(Map<String, dynamic> map) {
    final rawResp = map['response'] != null
        ? map['response'].toString()
        : (map['selectedOptionIndex'] != null
            ? map['selectedOptionIndex'].toString()
            : '');

    return Answer(
      answerId: (map['answer_id'] ?? map['answerId']) as String?,
      submissionId: (map['submission_id'] ?? map['submissionId'] ?? '') as String,
      questionId: (map['question_id'] ?? map['questionId'] ?? '') as String,
      response: rawResp,
      hashChainLink: (map['hash_chain_link'] ?? map['hashChainLink'] ?? '') as String,
      timestampMs: map['timestamp_ms'] as int? ?? map['timestampMs'] as int?,
      isCorrect: map['isCorrect'] as bool? ?? false,
      marksAwarded: map['marksAwarded'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer_id': answerId,
      'submission_id': submissionId,
      'question_id': questionId,
      'questionId': questionId,
      'response': response,
      'selectedOptionIndex': selectedOptionIndex,
      'hash_chain_link': hashChainLink,
      'hashChainLink': hashChainLink,
      'timestamp_ms': timestampMs,
      'isCorrect': isCorrect,
      'marksAwarded': marksAwarded,
    };
  }

  factory Answer.fromJson(Map<String, dynamic> json) => Answer.fromMap(json);
}
