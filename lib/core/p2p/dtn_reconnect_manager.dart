import 'dart:async';
import '../storage/database_service.dart';
import '../../models/submission.dart';
import 'p2p_transport.dart';

/// Manages Delay-Tolerant opportunistic store-and-forward syncing for offline submissions.
class DtnReconnectManager {
  final P2PTransport transport;
  final List<Submission> _outboxQueue = [];
  bool _isFlushing = false;

  DtnReconnectManager({required this.transport}) {
    // Listen for peer connection events to opportunistically flush the outbox
    transport.onEndpointConnected.listen((endpointId) {
      flushOutbox(endpointId);
    });
  }

  List<Submission> get pendingOutbox => List.unmodifiable(_outboxQueue);

  /// Enqueues a signed submission to be transmitted to the teacher.
  /// If connected, sends immediately; otherwise queues locally.
  Future<void> enqueueSubmission({
    required Submission submission,
    String? connectedTeacherEndpointId,
  }) async {
    _outboxQueue.removeWhere((s) => s.submissionId == submission.submissionId);
    _outboxQueue.add(submission);

    // Save to local SQLite outbox status
    try {
      final dbService = DatabaseService();
      if (dbService.isInitialized) {
        await dbService.db.upsertSubmission(submission.copyWith(syncStatus: SyncStatus.pending));
      }
    } catch (_) {}

    if (connectedTeacherEndpointId != null && connectedTeacherEndpointId.isNotEmpty) {
      await flushOutbox(connectedTeacherEndpointId);
    }
  }

  /// Flushes all queued submissions to the connected teacher endpoint.
  Future<void> flushOutbox(String teacherEndpointId) async {
    if (_isFlushing || _outboxQueue.isEmpty) return;
    _isFlushing = true;

    final itemsToFlush = List<Submission>.from(_outboxQueue);

    for (final sub in itemsToFlush) {
      try {
        await transport.sendPayload(
          endpointId: teacherEndpointId,
          type: P2PMessageType.submissionPayload,
          data: sub.toJson(),
        );

        // Mark as synced locally
        _outboxQueue.removeWhere((item) => item.submissionId == sub.submissionId);
        final dbService = DatabaseService();
        if (dbService.isInitialized) {
          await dbService.db.upsertSubmission(sub.copyWith(syncStatus: SyncStatus.synced));
        }
      } catch (err) {
        // Failed to transmit this time; will retry on next reconnect
        break;
      }
    }

    _isFlushing = false;
  }
}
