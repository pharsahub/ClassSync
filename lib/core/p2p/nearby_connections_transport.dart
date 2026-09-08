import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'p2p_transport.dart';

/// P2P Transport implementation using Google Nearby Connections for Android.
///
/// ============================================================================
/// [IMPORTANT] iOS Compatibility Notice:
/// Google Nearby Connections operates natively on Android via Google Play Services
/// using Wi-Fi Direct and Bluetooth Low Energy. On iOS, Nearby Connections does
/// not support the same offline Wi-Fi Direct star topology due to Apple sandbox
/// constraints. For production iOS targets, ClassSync uses Apple Multipeer
/// Connectivity (or `flutter_nearby_connections` plugin).
/// ============================================================================
class NearbyConnectionsTransport implements P2PTransport {
  static const Strategy defaultStrategy = Strategy.P2P_STAR;

  final Nearby _nearby = Nearby();
  bool _isRunning = false;

  final Set<String> _connectedEndpoints = {};

  final _endpointDiscoveredCtrl = StreamController<DiscoveredEndpoint>.broadcast();
  final _endpointLostCtrl = StreamController<String>.broadcast();
  final _connectionInitiatedCtrl = StreamController<ConnectionRequest>.broadcast();
  final _endpointConnectedCtrl = StreamController<String>.broadcast();
  final _endpointDisconnectedCtrl = StreamController<String>.broadcast();
  final _payloadReceivedCtrl = StreamController<P2PPayloadMessage>.broadcast();

  @override
  bool get isRunning => _isRunning;

  @override
  Stream<DiscoveredEndpoint> get onEndpointDiscovered => _endpointDiscoveredCtrl.stream;
  @override
  Stream<String> get onEndpointLost => _endpointLostCtrl.stream;
  @override
  Stream<ConnectionRequest> get onConnectionInitiated => _connectionInitiatedCtrl.stream;
  @override
  Stream<String> get onEndpointConnected => _endpointConnectedCtrl.stream;
  @override
  Stream<String> get onEndpointDisconnected => _endpointDisconnectedCtrl.stream;
  @override
  Stream<P2PPayloadMessage> get onPayloadReceived => _payloadReceivedCtrl.stream;

  @override
  Future<void> startAdvertising({
    required String hostName,
    required String serviceId,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    await _nearby.startAdvertising(
      hostName,
      defaultStrategy,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
      serviceId: serviceId,
    );
    _isRunning = true;
  }

  @override
  Future<void> startDiscovery({
    required String studentName,
    required String serviceId,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    await _nearby.startDiscovery(
      studentName,
      defaultStrategy,
      onEndpointFound: (endpointId, endpointName, serviceIdFound) {
        _endpointDiscoveredCtrl.add(DiscoveredEndpoint(
          endpointId: endpointId,
          endpointName: endpointName,
          serviceId: serviceIdFound,
        ));
      },
      onEndpointLost: (endpointId) {
        _endpointLostCtrl.add(endpointId ?? '');
      },
      serviceId: serviceId,
    );
    _isRunning = true;
  }

  @override
  Future<void> requestConnection({
    required String userName,
    required String endpointId,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    await _nearby.requestConnection(
      userName,
      endpointId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
  }

  @override
  Future<void> acceptConnection(String endpointId) async {
    if (kIsWeb || !Platform.isAndroid) return;

    await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpoint, payload) {
        _handleIncomingBytes(endpoint, payload.bytes);
      },
    );
  }

  @override
  Future<void> rejectConnection(String endpointId) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _nearby.rejectConnection(endpointId);
  }

  @override
  Future<void> sendPayload({
    required String endpointId,
    required P2PMessageType type,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    final wireMap = {
      'type': type.name,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final jsonStr = jsonEncode(wireMap);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

    await _nearby.sendBytesPayload(endpointId, bytes);
  }

  @override
  Future<void> broadcastPayload({
    required P2PMessageType type,
    required Map<String, dynamic> data,
  }) async {
    for (final endpoint in _connectedEndpoints) {
      await sendPayload(endpointId: endpoint, type: type, data: data);
    }
  }

  @override
  Future<void> stopAllEndpoints() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _nearby.stopAllEndpoints();
    _connectedEndpoints.clear();
    _isRunning = false;
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _connectionInitiatedCtrl.add(ConnectionRequest(
      endpointId: endpointId,
      endpointName: info.endpointName,
      authenticationToken: info.authenticationToken,
    ));
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedEndpoints.add(endpointId);
      _endpointConnectedCtrl.add(endpointId);
    } else {
      _connectedEndpoints.remove(endpointId);
      _endpointDisconnectedCtrl.add(endpointId);
    }
  }

  void _onDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    _endpointDisconnectedCtrl.add(endpointId);
  }

  void _handleIncomingBytes(String endpointId, Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return;
    try {
      final jsonStr = utf8.decode(bytes);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final typeName = map['type'] as String? ?? 'ack';
      final type = P2PMessageType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => P2PMessageType.ack,
      );
      final data = map['data'] as Map<String, dynamic>? ?? {};

      _payloadReceivedCtrl.add(P2PPayloadMessage(
        senderEndpointId: endpointId,
        type: type,
        data: data,
      ));
    } catch (_) {}
  }
}
