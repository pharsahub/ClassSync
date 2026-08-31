import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/session.dart';
import '../../providers/app_state_provider.dart';
import 'quiz_attempt_screen.dart';

class StudentLobbyScreen extends StatefulWidget {
  const StudentLobbyScreen({super.key});

  @override
  State<StudentLobbyScreen> createState() => _StudentLobbyScreenState();
}

class _StudentLobbyScreenState extends State<StudentLobbyScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appState = context.watch<AppStateProvider>();
    final session = appState.activeSession;
    final student = appState.currentStudent;

    // If teacher starts session, automatically transition
    if (session != null && session.status == SessionStatus.inProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const QuizAttemptScreen()),
          );
        }
      });
    }

    if (session == null || student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Lobby')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              const Text(
                'Disconnected from Session',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text('The session has ended or was closed by the teacher.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Join Screen'),
              ),
            ],
          ),
        ),
      );
    }

    final quiz = session.quiz;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Lobby', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () {
              appState.resetStudentSession();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Leave Lobby'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Animated Radar Waiting Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Waiting for Teacher to Start...',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You are connected. As soon as your teacher starts the assessment, your questions will appear automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quiz & Student Summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assessment Information',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildLobbyInfo('Quiz Title', quiz?.title ?? 'Class Assessment'),
                        _buildLobbyInfo('Instructor', session.teacherName),
                        _buildLobbyInfo('Session Code', session.sessionCode),
                        _buildLobbyInfo('Questions', '${quiz?.questionCount ?? 0} Questions (${quiz?.totalMarks ?? 0} Marks)'),
                        _buildLobbyInfo('Time Limit', '${quiz?.timeLimitMinutes ?? 15} Minutes'),
                        const Divider(height: 24),
                        Text(
                          'Student Profile',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildLobbyInfo('Student Name', student.name),
                        _buildLobbyInfo('Roll Number', student.rollNumber),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
