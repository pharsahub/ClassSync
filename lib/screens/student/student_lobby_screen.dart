import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/session.dart';
import '../../providers/student_quiz_provider.dart';
import '../../providers/teacher_session_provider.dart';
import 'quiz_attempt_screen.dart';

class StudentLobbyScreen extends ConsumerWidget {
  const StudentLobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final quizState = ref.watch(studentQuizProvider);
    final teacherState = ref.watch(teacherSessionProvider);
    final activeSession = teacherState.activeSession;

    // If teacher starts the session, automatically navigate to attempt screen
    if (activeSession != null && activeSession.status == SessionStatus.inProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const QuizAttemptScreen()),
        );
      });
    }

    final student = quizState.currentStudent;
    final quiz = quizState.activeQuiz;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Lobby'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.shade300, width: 2),
                  ),
                  child: Icon(Icons.hourglass_top_rounded, size: 64, color: Colors.amber.shade800),
                ),
                const SizedBox(height: 24),
                Text(
                  'Waiting for Teacher to Start Assessment...',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'You have joined "${quiz?.title ?? 'Assessment'}".\nPlease wait until the teacher begins the test.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Student Name:'),
                            Text(student?.name ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Roll Number:'),
                            Text(student?.rollNumber ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Quiz Duration:'),
                            Text('${quiz?.timeLimitMinutes ?? 10} Mins', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(studentQuizProvider.notifier).reset();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Leave Lobby'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
