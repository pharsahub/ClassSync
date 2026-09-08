import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/sync/cloud_sync_service.dart';
import '../../models/quiz.dart';
import '../../models/session.dart';
import '../../models/student.dart';
import '../../providers/teacher_session_provider.dart';
import 'quiz_creator_screen.dart';
import 'session_controller_screen.dart';
import 'submission_review_screen.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  Future<void> _hostSession(BuildContext context, WidgetRef ref, Quiz quiz) async {
    final notifier = ref.read(teacherSessionProvider.notifier);
    await notifier.startSession(quiz.quizId);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SessionControllerScreen(),
        ),
      );
    }
  }

  void _showRosterDialog(BuildContext context, WidgetRef ref) {
    final teacherState = ref.read(teacherSessionProvider);
    final roster = teacherState.registeredRoster;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.badge_outlined, color: Colors.blue),
            const SizedBox(width: 10),
            Text('Registered Student Roster (${roster.length})'),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trust Bootstrapping: Students below have their Ed25519 public keys pre-registered. Submissions are verified against these keys offline.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (roster.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No student keys imported yet.')),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: roster.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final s = roster[idx];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text('${idx + 1}', style: const TextStyle(fontSize: 10)),
                        ),
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'ID: ${s.studentId} • Key: ${s.publicKey.length > 16 ? "${s.publicKey.substring(0, 16)}..." : s.publicKey}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Generate sample students with Ed25519 keys
              final crypto = CryptoService();
              final List<Student> sampleList = [];
              final names = ['Fatima Zahra', 'Amina Al-Mansoor', 'Devon Vance', 'Elena Rostova', 'Marcus Chen'];
              for (int i = 0; i < names.length; i++) {
                final kp = await crypto.generateEd25519KeyPair();
                final pk = await crypto.exportPublicKeyHex(kp);
                sampleList.add(Student(
                  studentId: 'std_00${i + 1}',
                  name: names[i],
                  publicKey: pk,
                  classId: 'CS401',
                  rollNumber: 'CS23-00${i + 1}',
                ));
              }

              await ref.read(teacherSessionProvider.notifier).importStudentRoster(sampleList);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Imported 5 students with Ed25519 public keys!')),
                );
              }
            },
            child: const Text('Import Sample Roster'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showCloudSyncDialog(BuildContext context, Session session) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        String? syncResult;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('Sync Session to Cloud'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session: ${session.quiz?.title ?? session.sessionCode} (${session.submissions.length} submissions)'),
                  const SizedBox(height: 8),
                  const Text(
                    'Submits validated attendance and graded submissions to FastAPI + PostgreSQL cloud sync endpoint.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (syncResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: syncResult!.contains('success') ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: syncResult!.contains('success') ? Colors.green.shade400 : Colors.amber.shade400,
                        ),
                      ),
                      child: Text(syncResult!, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          final client = CloudSyncService();
                          final res = await client.syncSessionToCloud(session);
                          setState(() {
                            isLoading = false;
                            syncResult = res.message;
                          });
                        },
                  icon: isLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  label: const Text('Sync Now'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final teacherState = ref.watch(teacherSessionProvider);

    final quizzes = teacherState.quizzes;
    final activeSession = teacherState.activeSession;
    final completedSessions = teacherState.completedSessions;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Teacher Banner
              _buildTeacherHero(context, colorScheme, ref),
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
                          'Signed test packages, question builders, and DTN pairing.',
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
                    mainAxisExtent: 220,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: quizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = quizzes[index];
                    final isBeingHosted = activeSession?.quizId == quiz.quizId;

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
                                if (quiz.signature != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified, size: 14, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Signed (Ed25519)',
                                        style: TextStyle(fontSize: 11, color: Colors.green.shade800),
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
                                    ref.read(teacherSessionProvider.notifier).deleteQuiz(quiz.quizId);
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
                                    label: const Text('Live Controller'),
                                  )
                                else
                                  FilledButton.icon(
                                    onPressed: () => _hostSession(context, ref, quiz),
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Sync to Cloud (Phase 7)',
                              icon: const Icon(Icons.cloud_upload_outlined, color: Colors.blue),
                              onPressed: () => _showCloudSyncDialog(context, s),
                            ),
                            const SizedBox(width: 6),
                            FilledButton.tonal(
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
                          ],
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

  Widget _buildTeacherHero(BuildContext context, ColorScheme colorScheme, WidgetRef ref) {
    final teacherState = ref.watch(teacherSessionProvider);
    final pubKey = teacherState.teacherPublicKeyHex;

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
                  'Ed25519 Key: ${pubKey.length > 20 ? "${pubKey.substring(0, 20)}..." : pubKey} • Roster: ${teacherState.registeredRoster.length} Students',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showRosterDialog(context, ref),
            icon: const Icon(Icons.group_outlined, size: 16),
            label: const Text('Manage Roster'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionBanner(
    BuildContext context,
    Session session,
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
