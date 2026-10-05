import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../models/session.dart';
import '../../models/student.dart';
import '../../models/submission.dart';

/// Lightweight offline LAN server & client enabling cross-device communication
/// between Windows (Teacher Host) and Android phones (Students) over Local Wi-Fi / Hotspot.
class ClassroomLanServer {
  static const int defaultHttpPort = 8765;
  static const int defaultUdpPort = 8766;

  HttpServer? _httpServer;
  RawDatagramSocket? _udpSocket;
  final List<WebSocket> _activeWebSockets = [];

  Session? Function()? _getSessionCallback;
  Future<bool> Function(Student student)? _onStudentJoinCallback;
  Future<bool> Function(Submission submission)? _onSubmissionCallback;

  String? _hostIp;
  String? get hostIp => _hostIp;
  int get port => _httpServer?.port ?? defaultHttpPort;
  bool get isRunning => _httpServer != null;

  /// Retrieves all valid non-virtual candidate local IPv4 addresses.
  static Future<List<String>> getAllCandidateIps() async {
    final List<String> candidateIps = [];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      bool isVirtual(String name) {
        final n = name.toLowerCase();
        return n.contains('virtual') ||
            n.contains('vbox') ||
            n.contains('vmware') ||
            n.contains('vethernet') ||
            n.contains('wsl') ||
            n.contains('cloudflare') ||
            n.contains('warp') ||
            n.contains('docker') ||
            n.contains('tailscale') ||
            n.contains('tap') ||
            n.contains('tun') ||
            n.contains('loopback') ||
            n.contains('teredo') ||
            n.contains('isatap') ||
            n.contains('hyper-v');
      }

      bool isValidIp(String ip) {
        if (ip.startsWith('127.') || ip.startsWith('169.254.') || ip.startsWith('192.168.56.')) {
          return false;
        }
        return true;
      }

      // 1. Wi-Fi & Wireless adapters
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (!isVirtual(name) && (name.contains('wlan') || name.contains('wi-fi') || name.contains('wifi') || name.contains('wireless') || name.contains('hotspot') || name.contains('ap'))) {
          for (final addr in interface.addresses) {
            if (isValidIp(addr.address) && !candidateIps.contains(addr.address)) {
              candidateIps.add(addr.address);
            }
          }
        }
      }

      // 2. Physical Ethernet & LAN
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (!isVirtual(name)) {
          for (final addr in interface.addresses) {
            if (isValidIp(addr.address) && !candidateIps.contains(addr.address)) {
              candidateIps.add(addr.address);
            }
          }
        }
      }

      // 3. Fallback to any valid IP
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254.') && !candidateIps.contains(addr.address)) {
            candidateIps.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint('[LAN Server] Error resolving Candidate IPs: $e');
    }
    return candidateIps;
  }

  /// Retrieves the device's primary non-loopback local IPv4 address (e.g. 192.168.x.x, 172.x.x.x, 10.x.x.x).
  static Future<String> getPrimaryLocalIp() async {
    final candidates = await getAllCandidateIps();
    if (candidates.isNotEmpty) {
      return candidates.first;
    }
    return '127.0.0.1';
  }

  /// Starts the embedded HTTP & WebSocket server and UDP discovery responder.
  Future<int> start({
    required Session? Function() getSession,
    required Future<bool> Function(Student student) onStudentJoin,
    required Future<bool> Function(Submission submission) onSubmission,
    int port = defaultHttpPort,
    String? preferredHostIp,
  }) async {
    await stop();

    _getSessionCallback = getSession;
    _onStudentJoinCallback = onStudentJoin;
    _onSubmissionCallback = onSubmission;

    _hostIp = preferredHostIp ?? await getPrimaryLocalIp();

    try {
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
      debugPrint('[LAN Server] HTTP Server running on http://$_hostIp:${_httpServer!.port}');

      _httpServer!.listen(_handleHttpRequest, onError: (err) {
        debugPrint('[LAN Server] HTTP Server error: $err');
      });

      // Start UDP auto-discovery responder
      try {
        _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          defaultUdpPort,
          reuseAddress: true,
        );
        _udpSocket?.broadcastEnabled = true;
        _udpSocket?.listen((event) {
          if (event == RawSocketEvent.read) {
            final dg = _udpSocket?.receive();
            if (dg != null) {
              final msg = utf8.decode(dg.data).trim();
              if (msg.startsWith('CLASSSYNC_DISCOVER')) {
                final session = _getSessionCallback?.call();
                if (session != null) {
                  final reply = jsonEncode({
                    'type': 'classsync_host',
                    'session_code': session.sessionCode,
                    'session_id': session.sessionId,
                    'host_ip': _hostIp,
                    'port': _httpServer!.port,
                    'quiz_title': session.quiz?.title ?? 'Class Assessment',
                    'teacher_name': session.teacherName,
                  });
                  _udpSocket?.send(utf8.encode(reply), dg.address, dg.port);
                }
              }
            }
          }
        });
        debugPrint('[LAN Server] UDP Discovery listening on port $defaultUdpPort');
      } catch (udpErr) {
        debugPrint('[LAN Server] UDP bind warning: $udpErr');
      }

      return _httpServer!.port;
    } catch (e) {
      debugPrint('[LAN Server] Failed to bind HTTP server: $e');
      rethrow;
    }
  }

  void _handleHttpRequest(HttpRequest req) async {
    // Enable CORS for all incoming student requests
    req.response.headers.add('Access-Control-Allow-Origin', '*');
    req.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    req.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method == 'OPTIONS') {
      req.response.statusCode = HttpStatus.ok;
      await req.response.close();
      return;
    }

    final path = req.uri.path;

    try {
      // 1. WebSocket endpoint for live session events
      if (path == '/api/ws') {
        if (WebSocketTransformer.isUpgradeRequest(req)) {
          final ws = await WebSocketTransformer.upgrade(req);
          _activeWebSockets.add(ws);
          debugPrint('[LAN Server] Student WebSocket connected (${_activeWebSockets.length} total)');

          // Send current state
          final session = _getSessionCallback?.call();
          if (session != null) {
            ws.add(jsonEncode({
              'event': 'session_info',
              'status': session.status.name,
              'session_code': session.sessionCode,
            }));
          }

          ws.listen(
            (message) {
              debugPrint('[LAN Server] Received WS message: $message');
            },
            onDone: () {
              _activeWebSockets.remove(ws);
              debugPrint('[LAN Server] Student WebSocket disconnected (${_activeWebSockets.length} left)');
            },
            onError: (e) {
              _activeWebSockets.remove(ws);
            },
          );
          return;
        }
      }

      // 2. GET /api/session -> Get session details & signed quiz
      if (req.method == 'GET' && path == '/api/session') {
        final session = _getSessionCallback?.call();
        if (session == null) {
          req.response.statusCode = HttpStatus.notFound;
          req.response.write(jsonEncode({'error': 'No active session found on this host'}));
        } else {
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'session_id': session.sessionId,
            'session_code': session.sessionCode,
            'status': session.status.name,
            'teacher_id': session.teacherId,
            'teacher_name': session.teacherName,
            'quiz': session.quiz?.toJson(),
          }));
        }
        await req.response.close();
        return;
      }

      // 3. GET /api/status -> Poll session status
      if (req.method == 'GET' && path == '/api/status') {
        final session = _getSessionCallback?.call();
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({
          'active': session != null,
          'status': session?.status.name ?? 'none',
          'session_code': session?.sessionCode,
          'student_count': session?.studentCount ?? 0,
        }));
        await req.response.close();
        return;
      }

      // 4. POST /api/join -> Student check-in / roster join
      if (req.method == 'POST' && path == '/api/join') {
        final bodyStr = await utf8.decodeStream(req);
        final map = jsonDecode(bodyStr) as Map<String, dynamic>;
        final student = Student.fromJson(map);

        final ok = await _onStudentJoinCallback?.call(student) ?? false;

        broadcastEvent('student_joined', {
          'student_id': student.studentId,
          'name': student.name,
          'roll_number': student.rollNumber,
        });

        req.response.headers.contentType = ContentType.json;
        req.response.statusCode = ok ? HttpStatus.ok : HttpStatus.badRequest;
        req.response.write(jsonEncode({'success': ok, 'student_id': student.studentId}));
        await req.response.close();
        return;
      }

      // 5. POST /api/submit -> Receive signed student submission
      if (req.method == 'POST' && path == '/api/submit') {
        final bodyStr = await utf8.decodeStream(req);
        final map = jsonDecode(bodyStr) as Map<String, dynamic>;
        final submission = Submission.fromJson(map);

        final ok = await _onSubmissionCallback?.call(submission) ?? false;

        broadcastEvent('submission_received', {
          'student_id': submission.studentId,
          'student_name': submission.studentName,
          'score': submission.score,
          'verified': submission.isSignatureVerified,
        });

        req.response.headers.contentType = ContentType.json;
        req.response.statusCode = ok ? HttpStatus.ok : HttpStatus.badRequest;
        req.response.write(jsonEncode({
          'success': ok,
          'submission_id': submission.submissionId,
          'verified': submission.isSignatureVerified,
        }));
        await req.response.close();
        return;
      }

      // Default: Not found
      req.response.statusCode = HttpStatus.notFound;
      req.response.write('ClassSync Offline Assessment API');
      await req.response.close();
    } catch (e, st) {
      debugPrint('[LAN Server] Error processing request $path: $e\n$st');
      req.response.statusCode = HttpStatus.internalServerError;
      req.response.write(jsonEncode({'error': e.toString()}));
      await req.response.close();
    }
  }

  /// Broadcasts an event to all connected student WebSockets.
  void broadcastEvent(String event, Map<String, dynamic> data) {
    final payload = jsonEncode({'event': event, ...data});
    for (final ws in List.of(_activeWebSockets)) {
      try {
        if (ws.readyState == WebSocket.open) {
          ws.add(payload);
        }
      } catch (_) {}
    }
  }

  /// Stops server and closes all active sockets.
  Future<void> stop() async {
    for (final ws in _activeWebSockets) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _activeWebSockets.clear();

    try {
      await _httpServer?.close(force: true);
    } catch (_) {}
    _httpServer = null;

    try {
      _udpSocket?.close();
    } catch (_) {}
    _udpSocket = null;

    debugPrint('[LAN Server] Server stopped.');
  }
}

/// Lightweight offline LAN Client for Student devices to connect to Teacher Host.
class ClassroomLanClient {
  static const int defaultHttpPort = 8765;
  static const int defaultUdpPort = 8766;

  /// Broadcasts a UDP ping to auto-discover the Teacher Host on the local network.
  static Future<Map<String, dynamic>?> discoverHost({
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final completer = Completer<Map<String, dynamic>?>();

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null && !completer.isCompleted) {
            try {
              final str = utf8.decode(dg.data);
              final map = jsonDecode(str) as Map<String, dynamic>;
              if (map['type'] == 'classsync_host') {
                // If host_ip in packet is 0.0.0.0 or 127.0.0.1, use sender's remote IP
                if (map['host_ip'] == null || map['host_ip'] == '0.0.0.0' || map['host_ip'] == '127.0.0.1') {
                  map['host_ip'] = dg.address.address;
                }
                completer.complete(map);
              }
            } catch (_) {}
          }
        }
      });

      // Send broadcast query
      final query = utf8.encode('CLASSSYNC_DISCOVER');
      socket.send(query, InternetAddress('255.255.255.255'), defaultUdpPort);

      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      final res = await completer.future;
      socket.close();
      return res;
    } catch (e) {
      debugPrint('[LAN Client] UDP Discovery error: $e');
      socket?.close();
      return null;
    }
  }

  /// Fetches session metadata and signed Quiz from Teacher Host via HTTP.
  static Future<Map<String, dynamic>> fetchSession({
    required String hostIp,
    int port = defaultHttpPort,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse('http://$hostIp:$port/api/session');
      final req = await client.getUrl(uri);
      final res = await req.close();

      if (res.statusCode == HttpStatus.ok) {
        final body = await utf8.decodeStream(res);
        return jsonDecode(body) as Map<String, dynamic>;
      } else {
        throw Exception('Server returned ${res.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// Registers student in Teacher's session.
  static Future<bool> joinSession({
    required String hostIp,
    int port = defaultHttpPort,
    required Student student,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse('http://$hostIp:$port/api/join');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(student.toJson()));
      final res = await req.close();

      if (res.statusCode == HttpStatus.ok) {
        final body = await utf8.decodeStream(res);
        final map = jsonDecode(body) as Map<String, dynamic>;
        return map['success'] == true;
      }
      return false;
    } finally {
      client.close();
    }
  }

  /// Sends student's cryptographically signed submission to the Teacher Host.
  static Future<bool> submitQuiz({
    required String hostIp,
    int port = defaultHttpPort,
    required Submission submission,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final uri = Uri.parse('http://$hostIp:$port/api/submit');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(submission.toJson()));
      final res = await req.close();

      if (res.statusCode == HttpStatus.ok) {
        final body = await utf8.decodeStream(res);
        final map = jsonDecode(body) as Map<String, dynamic>;
        return map['success'] == true;
      }
      return false;
    } finally {
      client.close();
    }
  }

  /// Connects to the Teacher Host's WebSocket for real-time events.
  static Stream<Map<String, dynamic>> connectWebSocket({
    required String hostIp,
    int port = defaultHttpPort,
  }) async* {
    WebSocket? ws;
    try {
      final uri = Uri.parse('ws://$hostIp:$port/api/ws');
      ws = await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 4));

      await for (final rawMsg in ws) {
        try {
          final map = jsonDecode(rawMsg.toString()) as Map<String, dynamic>;
          yield map;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[LAN Client] WebSocket error: $e');
    } finally {
      try {
        await ws?.close();
      } catch (_) {}
    }
  }
}
