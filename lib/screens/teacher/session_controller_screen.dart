import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/qr_placeholder_widget.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/session.dart';
import '../../models/student.dart';
import '../../models/submission.dart';
import '../../providers/teacher_session_provider.dart';
import 'submission_review_screen.dart';

class SessionControllerScreen extends ConsumerWidget {
  const SessionControllerScreen({super.key});

  void _copyJoinInfo(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session Code $code copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _exportCsv(BuildContext context, WidgetRef ref, Session session) {
    final csv = ref.read(teacherSessionProvider.notifier).exportSessionToCsv(session);
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV Report copied to clipboard! (Ready to paste into Excel/Google Sheets)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final teacherState = ref.watch(teacherSessionProvider);
    final session = teacherState.activeSession;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Session Controller')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'No Active Assessment Session',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Start a session from the Teacher Dashboard to host a quiz.'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      );
    }

    final quiz = session.quiz;
    final isLobby = session.status == SessionStatus.waiting;
    final isInProgress = session.status == SessionStatus.inProgress;
    final qrData = teacherState.qrPayload ?? 'classsync://session/${session.sessionCode}';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLobby ? Colors.amber.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isLobby ? Icons.hourglass_top : Icons.sensors,
                    size: 16,
                    color: isLobby ? Colors.amber.shade900 : Colors.green.shade900,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLobby ? 'LOBBY WAITING' : 'LIVE SESSION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isLobby ? Colors.amber.shade900 : Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                quiz?.title ?? 'Classroom Assessment',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _exportCsv(context, ref, session),
          ),
          const SizedBox(width: 8),
          if (isInProgress)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () {
                _showEndSessionDialog(context, ref, session);
              },
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('End Session'),
            )
          else if (isLobby)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
              onPressed: () {
                ref.read(teacherSessionProvider.notifier).startQuizForSession();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Assessment Started! Students can now begin answering.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Assessment'),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Info & Controls
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    // QR Card with signed session payload
                    QrDisplayCard(
                      sessionData: qrData,
                      sessionCode: session.sessionCode,
                      quizTitle: quiz?.title ?? 'Quiz Session',
                      size: 200,
                    ),

                    // Session Meta & Summary
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 550),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Session Information',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.teal.shade300),
                                        ),
                                        child: Text(
                                          'Ed25519 Signed',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                    'Quiz Duration',
                                    '${quiz?.timeLimitMinutes ?? 15} Minutes',
                                    Icons.timer_outlined,
                                  ),
                                  _buildInfoRow(
                                    'Total Questions',
                                    '${quiz?.questionCount ?? 0} Questions (${quiz?.totalMarks ?? 0} Marks)',
                                    Icons.help_outline,
                                  ),
                                  _buildInfoRow(
                                    'Session Code',
                                    session.sessionCode,
                                    Icons.vpn_key_outlined,
                                  ),
                                  _buildInfoRow(
                                    'Host',
                                    session.teacherName,
                                    Icons.school_outlined,
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _copyJoinInfo(context, session.sessionCode),
                                          icon: const Icon(Icons.copy, size: 16),
                                          label: const Text('Copy Code'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton.tonalIcon(
                                          onPressed: () => _exportCsv(context, ref, session),
                                          icon: const Icon(Icons.table_chart_outlined, size: 16),
                                          label: const Text('Export CSV'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Live Quick Stats
                          Row(
                            children: [
                              _buildStatCard(
                                context,
                                label: 'Connected',
                                value: '${session.studentCount}',
                                color: colorScheme.primary,
                                icon: Icons.people_outline,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                context,
                                label: 'In Progress',
                                value: '${session.inProgressCount}',
                                color: Colors.amber.shade800,
                                icon: Icons.pending_outlined,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                context,
                                label: 'Verified Subs',
                                value: '${session.submissions.where((s) => s.isSignatureVerified).length}',
                                color: Colors.green.shade800,
                                icon: Icons.verified_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Connected Students Roster Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Student Submissions & Roster (${session.submissions.length})',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'All incoming submissions undergo Ed25519 signature + hash chain verification.',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (session.submissions.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubmissionReviewScreen(session: session),
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('View Full Review Sheet'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                if (session.submissions.isEmpty && session.connectedStudents.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.sensors, size: 48, color: colorScheme.outline),
                            const SizedBox(height: 12),
                            const Text(
                              'Waiting for student submissions...',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Students can join using code "${session.sessionCode}" or scanning the QR code.',
                              textAlign: TextAlign.center,
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
                      itemCount: session.submissions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final sub = session.submissions[idx];
                        final isVerified = sub.isSignatureVerified && sub.isHashChainVerified;
                        final isRejected = sub.status == SubmissionStatus.rejected;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: isRejected
                                ? Colors.red.shade100
                                : (isVerified ? Colors.green.shade100 : Colors.blue.shade100),
                            foregroundColor: isRejected
                                ? Colors.red.shade900
                                : (isVerified ? Colors.green.shade900 : Colors.blue.shade900),
                            child: Icon(
                              isRejected ? Icons.error_outline : (isVerified ? Icons.verified : Icons.assignment_outlined),
                              size: 18,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                sub.studentName.isNotEmpty ? sub.studentName : sub.studentId,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sub.studentRollNumber.isNotEmpty ? sub.studentRollNumber : sub.studentId,
                                  style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            isRejected
                                ? 'REJECTED: ${sub.verificationError ?? "Verification Failed"}'
                                : 'Deterministic ID: ${sub.submissionId} • ${sub.answers.length} Answers Chained',
                            style: TextStyle(
                              color: isRejected ? Colors.red.shade800 : null,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isRejected ? Colors.red.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isRejected ? Colors.red.shade300 : Colors.green.shade300,
                                  ),
                                ),
                                child: Text(
                                  isRejected
                                      ? 'REJECTED ❌'
                                      : 'Score: ${sub.score}/${sub.totalPossibleMarks} (${sub.percentage.toStringAsFixed(0)}%) ✅',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isRejected ? Colors.red.shade900 : Colors.green.shade900,
                                    fontSize: 12,
                                  ),
                                ),
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
      ),
    );
  }

  void _showEndSessionDialog(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Assessment Session?'),
        content: Text(
          'Ending this session will finalize all submissions and archive the session to history. (${session.submittedCount}/${session.studentCount} students submitted).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () async {
              Navigator.pop(ctx);
              final currentSession = session;
              await ref.read(teacherSessionProvider.notifier).endSession();

              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubmissionReviewScreen(session: currentSession),
                  ),
                );
              }
            },
            child: const Text('End & View Results'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
