import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:classsync/main.dart';
import 'package:classsync/providers/app_state_provider.dart';

void main() {
  testWidgets('ClassSync multi-portal app loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppStateProvider(),
        child: const ClassSyncApp(),
      ),
    );

    expect(find.textContaining('ClassSync'), findsWidgets);
    expect(find.text('Teacher'), findsWidgets);
    expect(find.text('Student'), findsWidgets);
  });

  test('AppStateProvider creates and hosts quiz session lifecycle', () {
    final provider = AppStateProvider();
    expect(provider.quizzes.isNotEmpty, true);

    final quiz = provider.quizzes.first;
    final session = provider.startSession(quiz.id);

    expect(provider.activeSession != null, true);
    expect(session.sessionCode.startsWith('CS-'), true);

    // Student joins
    final joined = provider.joinSession(
      sessionCode: session.sessionCode,
      studentName: 'Test Student',
      rollNumber: 'TS-001',
    );
    expect(joined, true);
    expect(provider.activeSession!.studentCount, 1);

    // Teacher starts
    provider.startQuizForSession();
    expect(provider.activeSession!.status.name, 'inProgress');

    // Student answers questions
    for (final q in quiz.questions) {
      provider.recordAnswer(q.id, q.correctOptionIndex);
    }

    // Submit
    final sub = provider.submitQuiz();
    expect(sub.score, quiz.totalMarks);
    expect(sub.percentage, 100.0);
    expect(provider.activeSession!.submittedCount, 1);

    // End session
    provider.endSession();
    expect(provider.activeSession, null);
    expect(provider.completedSessions.first.submissions.isNotEmpty, true);
  });
}
