import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../models/quiz.dart';
import '../../providers/app_state_provider.dart';
import 'quiz_creator_screen.dart';
import 'session_controller_screen.dart';
import 'submission_review_screen.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  void _hostSession(BuildContext context, Quiz quiz) {
    final appState = context.read<AppStateProvider>();
    appState.startSession(quiz.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SessionControllerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appState = context.watch<AppStateProvider>();

    final quizzes = appState.quizzes;
    final activeSession = appState.activeSession;
    final completedSessions = appState.completedSessions;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Teacher Banner
              _buildTeacherHero(context, colorScheme),
              const SizedBox(height: 24),

              // Active Session Callout if any
              if (activeSession != null) ...[
                _buildActiveSessionBanner(context, activeSession, colorScheme),
                const SizedBox(height: 24),
              ],

              // Quizzes Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quiz Repository (${quizzes.length})',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Manage questions, configure time limits, and host offline pairing sessions.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QuizCreatorScreen()),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Quiz'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quizzes Grid
              if (quizzes.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.quiz_outlined, size: 48, color: colorScheme.outline),
                          const SizedBox(height: 12),
                          const Text(
                            'No Quizzes in Library',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          const Text('Click "Create New Quiz" to start building your first test.'),
                        ],
                      ),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 520,
                    mainAxisExtent: 210,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: quizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = quizzes[index];
                    final isBeingHosted = activeSession?.quizId == quiz.id;

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isBeingHosted
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(alpha: 0.5),
                          width: isBeingHosted ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    quiz.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isBeingHosted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'LIVE NOW',
                                      style: TextStyle(
                                        color: Colors.green.shade900,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              quiz.description.isNotEmpty ? quiz.description : 'No description provided.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.help_outline, size: 14, color: colorScheme.outline),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${quiz.questionCount} Questions (${quiz.totalMarks} M)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer_outlined, size: 14, color: colorScheme.outline),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${quiz.timeLimitMinutes} Mins',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: 'Delete Quiz',
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                  onPressed: () {
                                    appState.deleteQuiz(quiz.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Quiz "${quiz.title}" deleted')),
                                    );
                                  },
                                ),
                                const SizedBox(width: 6),
                                if (isBeingHosted)
                                  FilledButton.tonalIcon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SessionControllerScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.sensors, size: 16),
                                    label: const Text('Go to Live Controller'),
                                  )
                                else
                                  FilledButton.icon(
                                    onPressed: () => _hostSession(context, quiz),
                                    icon: const Icon(Icons.play_arrow, size: 16),
                                    label: const Text('Host Session'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 36),

              // Past Sessions History Header
              Text(
                'Assessment History & Reports (${completedSessions.length})',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (completedSessions.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Completed sessions and past class reports will appear here.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: completedSessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = completedSessions[index];
                      final subs = s.submissions;
                      final totalMarks = s.quiz?.totalMarks ?? (subs.isNotEmpty ? subs.first.totalPossibleMarks : 0);
                      final avg = subs.isNotEmpty ? (subs.fold(0, (sum, item) => sum + item.score) / subs.length) : 0.0;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.history_edu, color: colorScheme.primary),
                        ),
                        title: Text(
                          s.quiz?.title ?? 'Class Assessment',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Code: ${s.sessionCode} • ${s.studentCount} Students • ${subs.length} Submissions • Avg: ${avg.toStringAsFixed(1)}/$totalMarks',
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SubmissionReviewScreen(session: s),
                              ),
                            );
                          },
                          child: const Text('View Results'),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherHero(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.8),
            colorScheme.secondaryContainer.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            child: const Icon(Icons.school, size: 32),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teacher Portal • ${AppConstants.defaultTeacherName}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppConstants.defaultTeacherDepartment} • Offline-First Assessment Engine',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionBanner(
    BuildContext context,
    dynamic session,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade400, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sensors, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Session Active: ${session.quiz?.title ?? "Assessment"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green.shade900,
                  ),
                ),
                Text(
                  'Code: ${session.sessionCode} • ${session.studentCount} Students Connected • ${session.submittedCount} Submissions',
                  style: TextStyle(color: Colors.green.shade800, fontSize: 13),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SessionControllerScreen(),
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Manage Session'),
          ),
        ],
      ),
    );
  }
}
