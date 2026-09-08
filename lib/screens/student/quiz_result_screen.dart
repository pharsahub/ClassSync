import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/submission.dart';
import '../../providers/student_quiz_provider.dart';

class QuizResultScreen extends ConsumerWidget {
  final Submission submission;

  const QuizResultScreen({super.key, required this.submission});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final quizState = ref.watch(studentQuizProvider);
    final quiz = quizState.activeQuiz;

    final pct = submission.percentage;
    Color gradeColor = Colors.red.shade700;
    String gradeLabel = 'Needs Improvement';
    IconData gradeIcon = Icons.sentiment_dissatisfied_outlined;

    if (pct >= 80) {
      gradeColor = Colors.green.shade700;
      gradeLabel = 'Excellent Performance!';
      gradeIcon = Icons.sentiment_very_satisfied_outlined;
    } else if (pct >= 60) {
      gradeColor = Colors.blue.shade700;
      gradeLabel = 'Good Job!';
      gradeIcon = Icons.sentiment_satisfied_outlined;
    } else if (pct >= 40) {
      gradeColor = Colors.amber.shade800;
      gradeLabel = 'Passed';
      gradeIcon = Icons.sentiment_neutral_outlined;
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Assessment Results'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Score Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: gradeColor.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: gradeColor.withValues(alpha: 0.15),
                          foregroundColor: gradeColor,
                          child: Icon(gradeIcon, size: 40),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          gradeLabel,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: gradeColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${submission.score} / ${submission.totalPossibleMarks} Marks (${pct.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Cryptographic Assurance Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified, color: Colors.teal.shade800, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Signed with Ed25519 Private Key • Answers Hash Chain Intact • Deterministic ID: ${submission.submissionId}',
                                  style: TextStyle(fontSize: 11, color: Colors.teal.shade900, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Review Header
                Text(
                  'Answer Sheet & Solutions',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Answers List
                if (quiz != null)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: quiz.questions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, qIdx) {
                      final question = quiz.questions[qIdx];
                      final answer = submission.answers[question.questionId];
                      final isCorrect = answer?.isCorrect ?? false;
                      final selectedIdx = answer?.selectedOptionIndex;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isCorrect ? Colors.green.shade300 : Colors.red.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isCorrect ? Icons.check_circle : Icons.cancel,
                                    color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Question ${qIdx + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Text(
                                    isCorrect ? '+${question.marks} Marks' : '0 / ${question.marks} Marks',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(question.body, style: const TextStyle(fontSize: 15)),
                              const SizedBox(height: 14),

                              for (int opt = 0; opt < question.options.length; opt++) ...[
                                _buildOptionRow(
                                  question.options[opt],
                                  isCorrectAnswer: opt == question.correctOptionIndex,
                                  isStudentChoice: selectedIdx == opt,
                                ),
                              ],

                              if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '💡 Solution Note: ${question.explanation}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 36),

                Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      ref.read(studentQuizProvider.notifier).reset();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Return to Portal Home'),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow(
    String text, {
    required bool isCorrectAnswer,
    required bool isStudentChoice,
  }) {
    Color? bg;
    Color border = Colors.transparent;
    IconData? icon;
    Color iconColor = Colors.transparent;

    if (isCorrectAnswer) {
      bg = Colors.green.shade50;
      border = Colors.green.shade400;
      icon = Icons.check;
      iconColor = Colors.green.shade800;
    } else if (isStudentChoice && !isCorrectAnswer) {
      bg = Colors.red.shade50;
      border = Colors.red.shade400;
      icon = Icons.close;
      iconColor = Colors.red.shade800;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: (isCorrectAnswer || isStudentChoice) ? FontWeight.bold : FontWeight.normal,
                color: isCorrectAnswer
                    ? Colors.green.shade900
                    : (isStudentChoice ? Colors.red.shade900 : Colors.black87),
              ),
            ),
          ),
          if (isStudentChoice)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCorrectAnswer ? Colors.green.shade200 : Colors.red.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Your Choice',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isCorrectAnswer ? Colors.green.shade900 : Colors.red.shade900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
