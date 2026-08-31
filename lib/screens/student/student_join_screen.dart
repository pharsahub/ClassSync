import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../models/session.dart';
import '../../providers/app_state_provider.dart';
import 'quiz_attempt_screen.dart';
import 'student_lobby_screen.dart';

class StudentJoinScreen extends StatefulWidget {
  const StudentJoinScreen({super.key});

  @override
  State<StudentJoinScreen> createState() => _StudentJoinScreenState();
}

class _StudentJoinScreenState extends State<StudentJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = 'Fatima Zahra';
    _rollController.text = 'CS23-018';
  }

  void _joinSession() {
    if (!_formKey.currentState!.validate()) return;

    final appState = context.read<AppStateProvider>();
    final code = _codeController.text.trim().toUpperCase();

    final success = appState.joinSession(
      sessionCode: code,
      studentName: _nameController.text.trim(),
      rollNumber: _rollController.text.trim(),
    );

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid session code "$code" or no active session found with this code.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final session = appState.activeSession!;
    if (session.status == SessionStatus.inProgress) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const QuizAttemptScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentLobbyScreen()),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appState = context.watch<AppStateProvider>();
    final activeSession = appState.activeSession;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              // Hero Student Join Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer.withValues(alpha: 0.8),
                      colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      child: const Icon(Icons.school_outlined, size: 36),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Student Assessment Portal',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join your teacher\'s offline assessment session with your name, roll number, and 6-character session code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Active Session Helper Banner
              if (activeSession != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_tethering, color: Colors.blue.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Session Detected',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                            Text(
                              '${activeSession.quiz?.title ?? "Quiz"} (Code: ${activeSession.sessionCode})',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          setState(() {
                            _codeController.text = activeSession.sessionCode;
                          });
                        },
                        child: const Text('Use Code'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Join Form Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter Assessment Details',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Student Full Name *',
                            hintText: 'e.g. Fatima Zahra',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Please enter your full name' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _rollController,
                          decoration: const InputDecoration(
                            labelText: 'Roll Number / Student ID *',
                            hintText: 'e.g. CS23-018',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Please enter your roll number' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Session Code *',
                            hintText: 'e.g. ${AppConstants.sampleSessionCode}',
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                            suffixIcon: activeSession != null
                                ? IconButton(
                                    tooltip: 'Fill with active code',
                                    icon: const Icon(Icons.auto_fix_high),
                                    onPressed: () {
                                      setState(() {
                                        _codeController.text = activeSession.sessionCode;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Please enter the session code' : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _joinSession,
                            icon: const Icon(Icons.login),
                            label: const Text('Join Assessment Session', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
