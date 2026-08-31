import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/qr_placeholder_widget.dart';
import 'core/widgets/status_badge.dart';
import 'core/widgets/timer_display.dart';
import 'models/student.dart';
import 'providers/app_state_provider.dart';
import 'screens/student/student_join_screen.dart';
import 'screens/teacher/session_controller_screen.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: const ClassSyncApp(),
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

class MainAppShell extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainAppShell({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _selectedTabIndex = 0; // 0: Teacher, 1: Student, 2: Component Showcase

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appState = context.watch<AppStateProvider>();
    final activeSession = appState.activeSession;

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.hub_rounded, color: colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.5),
                ),
              ],
            );
          },
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade400),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sensors, color: Colors.green, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Live: ${activeSession.sessionCode}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Role Switcher Navigation
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.school_outlined, size: 15),
                label: Text('Teacher'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.person_outline, size: 15),
                label: Text('Student'),
              ),
              ButtonSegment(
                value: 2,
                icon: Icon(Icons.widgets_outlined, size: 15),
                label: Text('Showcase'),
              ),
            ],
            selected: {_selectedTabIndex},
            onSelectionChanged: (selection) {
              setState(() => _selectedTabIndex = selection.first);
            },
          ),
          const SizedBox(width: 8),

          // Theme Toggle
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            tooltip: widget.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 18),
          ),
          const SizedBox(width: 12),
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
                      Icon(Icons.developer_mode, size: 36, color: colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UI Component Gallery & Unit Inspect',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Preview standalone widgets, badge states, and responsive color tokens.',
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

              Text('Quiz Timer Display', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 24),

              Text('QR Display Card', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Center(
                child: QrDisplayCard(
                  sessionData: 'classsync://session/CS-4892',
                  sessionCode: 'CS-4892',
                  quizTitle: 'Computer Science Midterm',
                  size: 180,
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
