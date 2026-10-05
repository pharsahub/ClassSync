import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/p2p/lan_p2p_transport.dart';
import '../../models/session.dart';
import '../../models/student.dart';
import '../../providers/crypto_providers.dart';
import '../../providers/student_quiz_provider.dart';
import '../../providers/teacher_session_provider.dart';
import 'qr_scanner_screen.dart';
import 'quiz_attempt_screen.dart';
import 'student_lobby_screen.dart';

class StudentJoinScreen extends ConsumerStatefulWidget {
  const StudentJoinScreen({super.key});

  @override
  ConsumerState<StudentJoinScreen> createState() => _StudentJoinScreenState();
}

class _StudentJoinScreenState extends ConsumerState<StudentJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _codeController = TextEditingController();
  final _hostIpController = TextEditingController();

  bool _isDiscovering = false;
  bool _isJoining = false;
  String? _discoveryMessage;

  @override
  void initState() {
    super.initState();
    _nameController.text = 'Fatima Zahra';
    _rollController.text = 'CS23-018';
  }

  Future<void> _autoDiscoverHost({bool silent = false}) async {
    if (_isDiscovering) return;
    setState(() {
      _isDiscovering = true;
      if (!silent) _discoveryMessage = 'Searching Wi-Fi network for Teacher Host...';
    });

    final found = await ClassroomLanClient.discoverHost(timeout: const Duration(milliseconds: 2500));

    if (!mounted) return;

    setState(() {
      _isDiscovering = false;
      if (found != null) {
        final code = found['session_code'] as String? ?? '';
        final ip = found['host_ip'] as String? ?? '';
        final title = found['quiz_title'] as String? ?? 'Assessment';
        final teacher = found['teacher_name'] as String? ?? 'Teacher';

        if (code.isNotEmpty) _codeController.text = code;
        if (ip.isNotEmpty) _hostIpController.text = ip;

        _discoveryMessage = '✅ Found Host: "$title" by $teacher at $ip';
      } else {
        if (!silent) {
          _discoveryMessage = '⚠️ No host auto-discovered. Please enter the Host IP or Session Code manually.';
        }
      }
    });
  }

  Future<void> _openQrScanner() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (scanned != null && scanned.isNotEmpty && mounted) {
      _applyQrPayload(scanned);
    }
  }

  void _applyQrPayload(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['session_code'] != null) {
        _codeController.text = map['session_code'].toString();
      }
      if (map['host_ip'] != null) {
        final ip = map['host_ip'].toString();
        final port = map['port'] ?? 8765;
        _hostIpController.text = '$ip:$port';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Code Applied Successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (raw.contains('CS-')) {
        _codeController.text = raw;
      }
    }
  }

  void _showScanQrDialog() {
    final qrInputController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code, color: Colors.blue),
            SizedBox(width: 10),
            Text('Paste QR Payload'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the raw QR JSON payload or session URL generated on the teacher screen:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qrInputController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '{"type":"classsync_session","session_code":"CS-1234","host_ip":"192.168.1.5"}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final raw = qrInputController.text.trim();
              if (raw.isNotEmpty) {
                _applyQrPayload(raw);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinSession() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isJoining = true);

    try {
      final code = _codeController.text.trim().toUpperCase();
      final hostIpInput = _hostIpController.text.trim();

      final crypto = ref.read(cryptoServiceProvider);
      final studentKeyPair = await ref.read(studentKeyPairProvider.future);
      final studentPubKeyHex = await crypto.exportPublicKeyHex(studentKeyPair);

      final student = Student(
        studentId: 'std_${_rollController.text.trim().replaceAll('-', '_').toLowerCase()}',
        name: _nameController.text.trim(),
        rollNumber: _rollController.text.trim(),
        publicKey: studentPubKeyHex,
        classId: 'CS401',
      );

      final teacherState = ref.read(teacherSessionProvider);
      final activeLocalSession = teacherState.activeSession;

      // 1. Local single-process demo fallback
      if (activeLocalSession != null && activeLocalSession.sessionCode.toUpperCase().trim() == code) {
        await ref.read(teacherSessionProvider.notifier).importStudentRoster([student]);

        await ref.read(studentQuizProvider.notifier).startQuizSession(
          student: student,
          sessionId: activeLocalSession.sessionId,
          quiz: activeLocalSession.quiz!,
          teacherPublicKeyHex: teacherState.teacherPublicKeyHex,
        );

        if (!mounted) return;
        _navigateToQuizOrLobby(activeLocalSession.status == SessionStatus.inProgress);
        return;
      }

      // 2. Cross-Device Network Join (Phone -> Windows PC over LAN)
      String targetIp = hostIpInput;
      if (targetIp.isEmpty) {
        // Try quick discovery
        final found = await ClassroomLanClient.discoverHost(timeout: const Duration(seconds: 1));
        if (found != null && found['host_ip'] != null) {
          targetIp = found['host_ip'].toString();
        }
      }

      if (targetIp.isEmpty) {
        throw Exception('Please enter the Teacher Host IP Address (displayed on the Teacher screen, e.g. 172.20.113.53).');
      }

      // Clean host IP (strip http:// or port if pasted)
      String cleanHost = targetIp.replaceAll('http://', '').replaceAll('https://', '').trim();
      int port = 8765;
      if (cleanHost.contains(':')) {
        final parts = cleanHost.split(':');
        cleanHost = parts[0];
        port = int.tryParse(parts[1]) ?? 8765;
      }

      final success = await ref.read(studentQuizProvider.notifier).joinRemoteSession(
        hostIp: cleanHost,
        port: port,
        student: student,
        sessionCode: code,
      );

      if (!success) {
        final err = ref.read(studentQuizProvider).errorMessage ?? 'Could not join session.';
        throw Exception(err);
      }

      if (!mounted) return;
      final quizState = ref.read(studentQuizProvider);
      _navigateToQuizOrLobby(quizState.isSessionStarted);
    } catch (e) {
      if (!mounted) return;
      String userMsg = '$e';
      if (userMsg.contains('Network is unreachable') || userMsg.contains('errno = 101') || userMsg.contains('Failed host lookup')) {
        userMsg = 'Network unreachable: Ensure your PC is connected to your Phone\'s Hotspot (or both on the same Wi-Fi).';
      } else if (userMsg.contains('Connection refused') || userMsg.contains('errno = 111')) {
        userMsg = 'Connection refused: Make sure the Teacher has started hosting the quiz on the PC.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMsg),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _navigateToQuizOrLobby(bool isStarted) {
    if (isStarted) {
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
    _hostIpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final teacherState = ref.watch(teacherSessionProvider);
    final activeSession = teacherState.activeSession;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              // Hero Header
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
                      radius: 30,
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      child: const Icon(Icons.school_outlined, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Student Assessment Portal',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join your teacher\'s offline assessment over local Wi-Fi / Hotspot or Bluetooth.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Auto-Discovery Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi_tethering, color: colorScheme.primary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Local Wi-Fi Discovery', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('Auto-detects Teacher Host on your network', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _isDiscovering ? null : () => _autoDiscoverHost(silent: false),
                            icon: _isDiscovering
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh, size: 16),
                            label: const Text('Scan'),
                          ),
                        ],
                      ),
                      if (_discoveryMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _discoveryMessage!.contains('Found') ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _discoveryMessage!.contains('Found') ? Colors.green.shade300 : Colors.amber.shade300,
                            ),
                          ),
                          child: Text(
                            _discoveryMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _discoveryMessage!.contains('Found') ? Colors.green.shade900 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Join Form Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Assessment Details',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Wrap(
                              spacing: 6,
                              children: [
                                FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  onPressed: _openQrScanner,
                                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                                  label: const Text('Scan QR', style: TextStyle(fontSize: 12)),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                  onPressed: _showScanQrDialog,
                                  icon: const Icon(Icons.paste, size: 14),
                                  label: const Text('Paste', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
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
                                    tooltip: 'Fill with local code',
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
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _hostIpController,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Teacher Host IP / Address (Optional if on same Wi-Fi)',
                            hintText: 'e.g. 172.20.113.53:8765',
                            prefixIcon: Icon(Icons.lan_outlined),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _isJoining ? null : _joinSession,
                            icon: _isJoining
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.login),
                            label: Text(
                              _isJoining ? 'Connecting to Host...' : 'Join Assessment Session',
                              style: const TextStyle(fontSize: 16),
                            ),
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
