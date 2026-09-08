import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/session.dart';

class CloudSyncResult {
  final bool success;
  final String message;
  final int syncedCount;

  const CloudSyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
  });
}

class CloudSyncService {
  final String baseUrl;

  CloudSyncService({this.baseUrl = 'http://127.0.0.1:8000'});

  /// Manually syncs an assessment session and all verified submissions to the FastAPI cloud backend.
  Future<CloudSyncResult> syncSessionToCloud(Session session) async {
    try {
      final url = Uri.parse('$baseUrl/api/sync/session');
      final payload = {
        'session_id': session.sessionId,
        'quiz_id': session.quizId,
        'teacher_id': session.teacherId,
        'teacher_name': session.teacherName,
        'session_code': session.sessionCode,
        'qr_token': session.qrToken,
        'started_at': session.startedAt.toIso8601String(),
        'status': session.status.name,
        'submissions': session.submissions.map((s) => s.toJson()).toList(),
      };

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return CloudSyncResult(
          success: true,
          message: decoded['message'] as String? ?? 'Sync completed successfully',
          syncedCount: decoded['submissions_synced'] as int? ?? session.submissions.length,
        );
      } else {
        return CloudSyncResult(
          success: false,
          message: 'Server returned HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (err) {
      return CloudSyncResult(
        success: false,
        message: 'Could not connect to Cloud Sync server ($baseUrl): $err',
      );
    }
  }
}
