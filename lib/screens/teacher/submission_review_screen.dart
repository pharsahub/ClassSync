import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/quiz.dart';
import '../../models/session.dart';
import '../../models/submission.dart';

class SubmissionReviewScreen extends StatelessWidget {
  final Session session;

  const SubmissionReviewScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final quiz = session.quiz;
    final submissions = session.submissions;

    final totalSubmissions = submissions.length;
    final totalMarks = quiz?.totalMarks ?? (submissions.isNotEmpty ? submissions.first.totalPossibleMarks : 0);

    double averageScore = 0.0;
    int highestScore = 0;
    int lowestScore = totalMarks;

    if (submissions.isNotEmpty) {
      final totalScored = submissions.fold(0, (sum, s) => sum + s.score);
      averageScore = totalScored / submissions.length;
      highestScore = submissions.map((s) => s.score).reduce((a, b) => a > b ? a : b);
      lowestScore = submissions.map((s) => s.score).reduce((a, b) => a < b ? a : b);
    }

    final avgPercentage = totalMarks > 0 ? (averageScore / totalMarks) * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Results & Submissions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '${quiz?.title ?? "Quiz"} • Code: ${session.sessionCode}',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Analytics Summary Cards
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildMetricCard(
                      context,
                      label: 'Submissions',
                      value: '$totalSubmissions / ${session.studentCount}',
                      subtext: '${session.studentCount > 0 ? ((totalSubmissions / session.studentCount) * 100).toStringAsFixed(0) : 0}% Turnout',
                      icon: Icons.assignment_turned_in_outlined,
                      color: colorScheme.primary,
                    ),
                    _buildMetricCard(
                      context,
                      label: 'Class Average',
                      value: '${averageScore.toStringAsFixed(1)} / $totalMarks',
                      subtext: '${avgPercentage.toStringAsFixed(1)}% Avg Score',
                      icon: Icons.bar_chart_outlined,
                      color: Colors.teal.shade700,
                    ),
                    _buildMetricCard(
                      context,
                      label: 'Top Score',
                      value: '$highestScore / $totalMarks',
                      subtext: 'Max Achieved',
                      icon: Icons.emoji_events_outlined,
                      color: Colors.amber.shade800,
                    ),
                    _buildMetricCard(
                      context,
                      label: 'Lowest Score',
                      value: submissions.isNotEmpty ? '$lowestScore / $totalMarks' : 'N/A',
                      subtext: 'Min Achieved',
                      icon: Icons.trending_down_outlined,
                      color: Colors.blueGrey,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Submissions Table / List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Graded Submissions ($totalSubmissions)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Tap a student to view full answer sheet',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (submissions.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: colorScheme.outline),
                            const SizedBox(height: 12),
                            const Text(
                              'No Submissions Recorded Yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'When students finish and submit their quizzes, their graded answers will appear here.',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: submissions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final sub = submissions[index];
                        final timeFormatted = DateFormat('hh:mm a').format(sub.submittedAt);
                        final pct = sub.percentage;

                        Color scoreColor = Colors.red.shade700;
                        if (pct >= 80) {
                          scoreColor = Colors.green.shade800;
                        } else if (pct >= 60) {
                          scoreColor = Colors.blue.shade800;
                        } else if (pct >= 40) {
                          scoreColor = Colors.amber.shade900;
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: scoreColor.withValues(alpha: 0.15),
                            foregroundColor: scoreColor,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(sub.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sub.studentRollNumber,
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('Submitted at $timeFormatted • ${sub.answers.length} Questions Graded'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: scoreColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: scoreColor.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${sub.score}/${sub.totalPossibleMarks}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: scoreColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: scoreColor.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${pct.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: scoreColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => _showStudentSubmissionModal(context, sub, quiz),
                        );
                      },
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

  void _showStudentSubmissionModal(BuildContext context, Submission sub, Quiz? quiz) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modal Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.studentName,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Roll Number: ${sub.studentRollNumber}',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Score: ${sub.score} / ${sub.totalPossibleMarks} (${sub.percentage.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  Text(
                    'Question-by-Question Breakdown',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: quiz?.questions.length ?? 0,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (ctx, qIdx) {
                        final question = quiz!.questions[qIdx];
                        final answer = sub.answers[question.id];
                        final isCorrect = answer?.isCorrect ?? false;
                        final selectedIdx = answer?.selectedOptionIndex;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isCorrect ? Colors.green.shade300 : Colors.red.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
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
                                const SizedBox(height: 8),
                                Text(question.text, style: const TextStyle(fontSize: 15)),
                                const SizedBox(height: 12),

                                // Options display
                                for (int i = 0; i < question.options.length; i++) ...[
                                  _buildOptionRow(
                                    question.options[i],
                                    isCorrectAnswer: i == question.correctOptionIndex,
                                    isStudentChoice: selectedIdx == i,
                                  ),
                                ],

                                if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                                        const SizedBox(width: 6),
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
                  ),
                ],
              ),
            );
          },
        );
      },
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
                'Student Choice',
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

  Widget _buildMetricCard(
    BuildContext context, {
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 230),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Icon(icon, size: 20, color: color),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                subtext,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
