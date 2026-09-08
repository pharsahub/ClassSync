import 'dart:async';

/// Payload type markers for P2P messages between teacher and students.
enum P2PMessageType {
  quizBroadcast,     // Teacher -> Students (Signed Quiz + Session metadata)
  attendancePing,    // Student -> Teacher (Student Check-in with Student ID + Public Key)
  submissionPayload, // Student -> Teacher (Signed Submission + Answers)
  ack,               // Generic acknowledgment
}

/// Discovered peer endpoint.
class DiscoveredEndpoint {
  final String endpointId;
  final String endpointName;
  final String serviceId;

  const DiscoveredEndpoint({
    required this.endpointId,
    required this.endpointName,
    required this.serviceId,
  });
}

/// Incoming connection request from a peer.
class ConnectionRequest {
  final String endpointId;
  final String endpointName;
  final String authenticationToken;

  const ConnectionRequest({
    required this.endpointId,
    required this.endpointName,
    required this.authenticationToken,
  });
}

/// Incoming message payload received over P2P.
class P2PPayloadMessage {
  final String senderEndpointId;
  final P2PMessageType type;
  final Map<String, dynamic> data;
  final DateTime receivedAt;

  P2PPayloadMessage({
    required this.senderEndpointId,
    required this.type,
    required this.data,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();
}

/// Abstract contract for peer-to-peer classroom transport.
///
/// Implementations:
/// - `NearbyConnectionsTransport`: Google Nearby Connections for Android (Wi-Fi Direct / Bluetooth Low Energy)
/// - `SimulatedP2PTransport`: In-memory virtual DTN bridge for Desktop targets & resilience test harnesses
abstract class P2PTransport {
  /// Starts advertising as a host (Teacher device).
  Future<void> startAdvertising({
    required String hostName,
    required String serviceId,
  });

  /// Starts discovering available assessment hosts (Student device).
  Future<void> startDiscovery({
    required String studentName,
    required String serviceId,
  });

  /// Stops advertising, discovering, and disconnects all endpoints.
  Future<void> stopAllEndpoints();

  /// Accepts an incoming connection request.
  Future<void> acceptConnection(String endpointId);

  /// Rejects an incoming connection request.
  Future<void> rejectConnection(String endpointId);

  /// Requests a connection to a discovered endpoint.
  Future<void> requestConnection({
    required String userName,
    required String endpointId,
  });

  /// Sends a structured payload to a specific connected peer.
  Future<void> sendPayload({
    required String endpointId,
    required P2PMessageType type,
    required Map<String, dynamic> data,
  });

  /// Broadcasts a payload to all currently connected peers.
  Future<void> broadcastPayload({
    required P2PMessageType type,
    required Map<String, dynamic> data,
  });

  /// Streams
  Stream<DiscoveredEndpoint> get onEndpointDiscovered;
  Stream<String> get onEndpointLost;
  Stream<ConnectionRequest> get onConnectionInitiated;
  Stream<String> get onEndpointConnected;
  Stream<String> get onEndpointDisconnected;
  Stream<P2PPayloadMessage> get onPayloadReceived;

  /// Returns true if currently advertising or discovering.
  bool get isRunning;
}
