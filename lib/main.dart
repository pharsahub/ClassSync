import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/storage/database_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/qr_placeholder_widget.dart';
import 'core/widgets/status_badge.dart';
import 'core/widgets/timer_display.dart';
import 'models/question.dart';
import 'models/quiz.dart';
import 'models/student.dart';
import 'providers/teacher_session_provider.dart';
import 'screens/student/student_join_screen.dart';
import 'screens/teacher/session_controller_screen.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite storage layer
  await DatabaseService().init();

  runApp(
    const ProviderScope(
      child: ClassSyncApp(),
    ),
  );
}

class ClassSyncApp extends StatefulWidget {
  const ClassSyncApp({super.key});

  @override
  State<ClassSyncApp> createState() => _ClassSyncAppState();
}

class _ClassSyncAppState extends State<ClassSyncApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppConstants.appName} — Offline-First Classroom Assessment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: MainAppShell(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class MainAppShell extends ConsumerStatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainAppShell({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  ConsumerState<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends ConsumerState<MainAppShell> {
  int _selectedTabIndex = 0; // 0: Teacher, 1: Student, 2: Resilience Showcase

  @override
  void initState() {
    super.initState();
    // Seed default quizzes in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedDefaultQuizzesIfEmpty();
    });
  }

  Future<void> _seedDefaultQuizzesIfEmpty() async {
    final teacherState = ref.read(teacherSessionProvider);
    if (teacherState.quizzes.isEmpty) {
      final sampleQuiz1 = Quiz(
        quizId: 'quiz_dsa_101',
        teacherId: 'teacher_1',
        title: 'Data Structures & Algorithms Basics',
        description: 'Covers Big-O notation, binary search trees, hashing, and arrays.',
        timeLimitMinutes: 10,
        questions: [
          Question(
            questionId: 'q1_dsa',
            quizId: 'quiz_dsa_101',
            body: 'What is the average time complexity of searching an element in a Balanced Binary Search Tree (BST)?',
            type: QuestionType.mcq,
            options: ['O(1)', 'O(log n)', 'O(n)', 'O(n log n)'],
            correctAnswer: '1',
            marks: 2,
            explanation: 'A balanced BST divides search space in half at each step, resulting in O(log n) time.',
          ),
          Question(
            questionId: 'q2_dsa',
            quizId: 'quiz_dsa_101',
            body: 'Which data structure operates on a First-In, First-Out (FIFO) principle?',
            type: QuestionType.mcq,
            options: ['Stack', 'Queue', 'Priority Queue', 'Deque'],
            correctAnswer: '1',
            marks: 2,
            explanation: 'Queues process elements in the order they arrive (FIFO).',
          ),
          Question(
            questionId: 'q3_dsa',
            quizId: 'quiz_dsa_101',
            body: 'In Python and Dart, hash table lookups have an average time complexity of O(1).',
            type: QuestionType.trueFalse,
            options: ['True', 'False'],
            correctAnswer: '0',
            marks: 1,
            explanation: 'Hash maps provide constant average-time O(1) key lookups with a good hash distribution.',
          ),
          Question(
            questionId: 'q4_dsa',
            quizId: 'quiz_dsa_101',
            body: 'What happens when two distinct keys produce the same hash value in a hash table?',
            type: QuestionType.mcq,
            options: ['Stack Overflow', 'Hash Collision', 'Segmentation Fault', 'Deadlock'],
            correctAnswer: '1',
            marks: 2,
            explanation: 'When two keys map to the same bucket index, it is called a Hash Collision.',
          ),
        ],
      );

      final sampleQuiz2 = Quiz(
        quizId: 'quiz_net_201',
        teacherId: 'teacher_1',
        title: 'Computer Networks & Security',
        description: 'Quiz on OSI model, TCP/IP, and digital signatures.',
        timeLimitMinutes: 15,
        questions: [
          Question(
            questionId: 'q1_net',
            quizId: 'quiz_net_201',
            body: 'Which OSI layer is responsible for end-to-end reliable communication?',
            type: QuestionType.mcq,
            options: ['Network Layer', 'Transport Layer', 'Data Link Layer', 'Session Layer'],
            correctAnswer: '1',
            marks: 2,
          ),
          Question(
            questionId: 'q2_net',
            quizId: 'quiz_net_201',
            body: 'UDP provides guaranteed packet delivery and ordered sequencing.',
            type: QuestionType.trueFalse,
            options: ['True', 'False'],
            correctAnswer: '1',
            marks: 1,
          ),
        ],
      );

      final notifier = ref.read(teacherSessionProvider.notifier);
      await notifier.saveQuiz(sampleQuiz1);
      await notifier.saveQuiz(sampleQuiz2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final teacherState = ref.watch(teacherSessionProvider);
    final activeSession = teacherState.activeSession;

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.hub_rounded, color: colorScheme.primary, size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              AppConstants.appName,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          // Active Session Indicator
          if (activeSession != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SessionControllerScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade400),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sensors, color: Colors.green, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Live: ${activeSession.sessionCode}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Role Switcher Navigation
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.school_outlined, size: 14),
                label: Text('Teacher', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.person_outline, size: 14),
                label: Text('Student', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: 2,
                icon: Icon(Icons.security, size: 14),
                label: Text('Crypto', style: TextStyle(fontSize: 11)),
              ),
            ],
            selected: {_selectedTabIndex},
            onSelectionChanged: (selection) {
              setState(() => _selectedTabIndex = selection.first);
            },
          ),
          const SizedBox(width: 6),

          // Theme Toggle
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: widget.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 16),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: IndexedStack(
        index: _selectedTabIndex,
        children: const [
          TeacherDashboardScreen(),
          StudentJoinScreen(),
          DeveloperShowcaseScreen(),
        ],
      ),
    );
  }
}

class DeveloperShowcaseScreen extends StatefulWidget {
  const DeveloperShowcaseScreen({super.key});

  @override
  State<DeveloperShowcaseScreen> createState() => _DeveloperShowcaseScreenState();
}

class _DeveloperShowcaseScreenState extends State<DeveloperShowcaseScreen> {
  int _timerRemaining = 120;
  final int _timerTotal = 300;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_outlined, size: 36, color: colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ClassSync Security & DTN Resilience Architecture',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Ed25519 Signatures • AES-256-GCM Encryption • SHA-256 Incremental Hash Chains • Deterministic ID Deduplication',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('Cryptographic Security Features', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildSecurityItem(
                        icon: Icons.key_rounded,
                        title: '1. Trust Bootstrapping',
                        desc: 'Pre-registered Ed25519 student public keys guarantee non-repudiation without requiring internet CA / PKI during assessments.',
                      ),
                      const Divider(height: 24),
                      _buildSecurityItem(
                        icon: Icons.qr_code_2,
                        title: '2. Ephemeral QR Pairing',
                        desc: 'QR codes encode session ID and ephemeral AES-256 symmetric key only — never revealing student private identity.',
                      ),
                      const Divider(height: 24),
                      _buildSecurityItem(
                        icon: Icons.link,
                        title: '3. Incremental SHA-256 Hash Chaining',
                        desc: 'Each answer calculates link[i] = hash(link[i-1] + response + timestamp). Mid-quiz answer tampering invalidates subsequent links.',
                      ),
                      const Divider(height: 24),
                      _buildSecurityItem(
                        icon: Icons.fingerprint,
                        title: '4. Deterministic Submission Deduplication',
                        desc: 'submission_id = hash(student_id + session_id + device_id), ensuring zero data loss and collapsing duplicate reconnect syncs.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('Status Badges', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: StudentStatus.values.map((s) => StatusBadge(status: s)).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('Countdown Timer Display', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TimerDisplay(remainingSeconds: _timerRemaining, totalSeconds: _timerTotal),
                      OutlinedButton(
                        onPressed: () => setState(() => _timerRemaining = 300),
                        child: const Text('Normal (5m)'),
                      ),
                      OutlinedButton(
                        onPressed: () => setState(() => _timerRemaining = 45),
                        child: const Text('Urgent (45s)'),
                      ),
                      OutlinedButton(
                        onPressed: () => setState(() => _timerRemaining = 0),
                        child: const Text('Expired (0s)'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.teal.shade700, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
