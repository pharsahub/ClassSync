import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/submission.dart';
import '../../providers/app_state_provider.dart';

class QuizResultScreen extends StatelessWidget {
  final Submission submission;

  const QuizResultScreen({super.key, required this.submission});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appState = context.read<AppStateProvider>();
    final quiz = appState.activeSession?.quiz;

    final pct = submission.percentage;
    final totalMarks = submission.totalPossibleMarks;
    final score = submission.score;

    int correctCount = 0;
    int incorrectCount = 0;
    int unansweredCount = 0;

    if (quiz != null) {
      for (final q in quiz.questions) {
        final ans = submission.answers[q.id];
        if (ans == null || ans.selectedOptionIndex == null || ans.selectedOptionIndex! < 0) {
          unansweredCount++;
        } else if (ans.isCorrect) {
          correctCount++;
        } else {
          incorrectCount++;
        }
      }
    }

    Color resultColor = Colors.green.shade700;
    String feedbackText = 'Outstanding Performance!';
    IconData feedbackIcon = Icons.stars_rounded;

    if (pct < 50) {
      resultColor = Colors.red.shade700;
      feedbackText = 'Needs Improvement. Review the topics below.';
      feedbackIcon = Icons.sentiment_dissatisfied;
    } else if (pct < 75) {
      resultColor = Colors.amber.shade800;
      feedbackText = 'Good Effort! Review mistakes to master the subject.';
      feedbackIcon = Icons.thumb_up_alt_outlined;
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Assessment Result', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Score Hero Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        resultColor.withValues(alpha: 0.15),
                        colorScheme.primaryContainer.withValues(alpha: 0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: resultColor.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Icon(feedbackIcon, size: 56, color: resultColor),
                      const SizedBox(height: 12),
                      Text(
                        '${submission.studentName} (${submission.studentRollNumber})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feedbackText,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: resultColor,
                            ),
                          ),
                          Text(
                            ' / $totalMarks Marks',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: resultColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Score: ${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: resultColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Breakdown Row
                Row(
                  children: [
                    _buildStatPill(
                      label: 'Correct',
                      value: '$correctCount',
                      color: Colors.green.shade800,
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 12),
                    _buildStatPill(
                      label: 'Incorrect',
                      value: '$incorrectCount',
                      color: Colors.red.shade800,
                      icon: Icons.cancel_outlined,
                    ),
                    const SizedBox(width: 12),
                    _buildStatPill(
                      label: 'Unanswered',
                      value: '$unansweredCount',
                      color: Colors.grey.shade700,
                      icon: Icons.help_outline,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Detailed Question Review
                Text(
                  'Detailed Question Review',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (quiz != null)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: quiz.questions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, qIdx) {
                      final question = quiz.questions[qIdx];
                      final ans = submission.answers[question.id];
                      final isCorrect = ans?.isCorrect ?? false;
                      final selectedIdx = ans?.selectedOptionIndex;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isCorrect ? Colors.green.shade300 : Colors.red.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
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
                                    isCorrect
                                        ? '+${question.marks} / ${question.marks} Marks'
                                        : '0 / ${question.marks} Marks',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(question.text, style: const TextStyle(fontSize: 15)),
                              const SizedBox(height: 14),

                              for (int i = 0; i < question.options.length; i++) ...[
                                _buildReviewOption(
                                  question.options[i],
                                  isCorrectAnswer: i == question.correctOptionIndex,
                                  isStudentChoice: selectedIdx == i,
                                ),
                              ],

                              if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Explanation: ${question.explanation}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 36),

                // Return to Portal Button
                Center(
                  child: SizedBox(
                    width: 260,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () {
                        appState.resetStudentSession();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Back to Student Portal'),
                    ),
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

  Widget _buildStatPill({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewOption(
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
