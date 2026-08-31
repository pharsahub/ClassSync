import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/timer_display.dart';
import '../../providers/app_state_provider.dart';
import 'quiz_result_screen.dart';

class QuizAttemptScreen extends StatefulWidget {
  const QuizAttemptScreen({super.key});

  @override
  State<QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends State<QuizAttemptScreen> {
  int _currentQuestionIndex = 0;
  late int _remainingSeconds;
  late int _totalSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppStateProvider>();
    final quiz = appState.activeSession?.quiz;
    final durationMins = quiz?.timeLimitMinutes ?? 10;

    _totalSeconds = durationMins * 60;
    _remainingSeconds = _totalSeconds;

    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _handleAutoSubmit();
      }
    });
  }

  void _handleAutoSubmit() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Time is up! Your answers are being automatically submitted.'),
        backgroundColor: Colors.amber,
      ),
    );
    _performSubmit();
  }

  void _performSubmit() {
    _countdownTimer?.cancel();
    final appState = context.read<AppStateProvider>();
    final submission = appState.submitQuiz();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(submission: submission),
      ),
    );
  }

  void _confirmSubmitDialog(BuildContext context) {
    final appState = context.read<AppStateProvider>();
    final quiz = appState.activeSession?.quiz;
    final answeredCount = appState.studentAnswers.length;
    final totalQuestions = quiz?.questions.length ?? 0;
    final unanswered = totalQuestions - answeredCount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Assessment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have answered $answeredCount of $totalQuestions questions.'),
            if (unanswered > 0) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ $unanswered question${unanswered > 1 ? "s are" : " is"} currently unanswered.',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Are you sure you want to submit your answers now?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Review Questions'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () {
              Navigator.pop(ctx);
              _performSubmit();
            },
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appState = context.watch<AppStateProvider>();
    final session = appState.activeSession;
    final student = appState.currentStudent;

    if (session == null || session.quiz == null || student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assessment')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Active session or student profile not found.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    final quiz = session.quiz!;
    final questions = quiz.questions;
    final currentQuestion = questions[_currentQuestionIndex];
    final selectedOption = appState.studentAnswers[currentQuestion.id];
    final answeredCount = appState.studentAnswers.length;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${student.name} (${student.rollNumber})',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TimerDisplay(
            remainingSeconds: _remainingSeconds,
            totalSeconds: _totalSeconds,
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () => _confirmSubmitDialog(context),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Submit'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Bar
                LinearProgressIndicator(
                  value: questions.isNotEmpty ? (answeredCount / questions.length) : 0,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 16),

                // Question Navigator Pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(questions.length, (idx) {
                    final q = questions[idx];
                    final isAnswered = appState.studentAnswers.containsKey(q.id);
                    final isCurrent = idx == _currentQuestionIndex;

                    Color bg = colorScheme.surface;
                    Color fg = colorScheme.onSurface;
                    BorderSide border = BorderSide(color: colorScheme.outlineVariant);

                    if (isCurrent) {
                      bg = colorScheme.primary;
                      fg = colorScheme.onPrimary;
                      border = BorderSide(color: colorScheme.primary, width: 2);
                    } else if (isAnswered) {
                      bg = Colors.green.shade100;
                      fg = Colors.green.shade900;
                      border = BorderSide(color: Colors.green.shade400);
                    }

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _currentQuestionIndex = idx),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.fromBorderSide(border),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: fg,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Active Question Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${currentQuestion.marks} Mark${currentQuestion.marks > 1 ? "s" : ""}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: colorScheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Question Prompt
                        Text(
                          currentQuestion.text,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Options
                        Column(
                          children: List.generate(currentQuestion.options.length, (optIdx) {
                            final isSelected = selectedOption == optIdx;
                            final optionLetter = String.fromCharCode(65 + optIdx);
                            final optionText = currentQuestion.options[optIdx];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  appState.recordAnswer(currentQuestion.id, optIdx);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                                        : colorScheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.outlineVariant.withValues(alpha: 0.8),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                                        ),
                                        child: Center(
                                          child: Text(
                                            optionLetter,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          optionText,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected
                                                ? colorScheme.onPrimaryContainer
                                                : colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Navigation Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _currentQuestionIndex > 0
                          ? () => setState(() => _currentQuestionIndex--)
                          : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),
                    Row(
                      children: [
                        if (_currentQuestionIndex < questions.length - 1)
                          FilledButton.icon(
                            onPressed: () => setState(() => _currentQuestionIndex++),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next Question'),
                          )
                        else
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                            onPressed: () => _confirmSubmitDialog(context),
                            icon: const Icon(Icons.send),
                            label: const Text('Submit Quiz'),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
