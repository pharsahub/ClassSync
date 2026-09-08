import 'dart:async';
import 'p2p_transport.dart';

/// Central virtual DTN mesh hub connecting simulated P2P endpoints in memory.
class VirtualMeshHub {
  static final VirtualMeshHub _instance = VirtualMeshHub._internal();
  factory VirtualMeshHub() => _instance;
  VirtualMeshHub._internal();

  final Map<String, SimulatedP2PTransport> _nodes = {};
  final Set<String> _droppedEndpoints = {};

  void registerNode(SimulatedP2PTransport node) {
    _nodes[node.nodeId] = node;
  }

  void unregisterNode(String nodeId) {
    _nodes.remove(nodeId);
    _droppedEndpoints.remove(nodeId);
  }

  bool isEndpointDropped(String nodeId) => _droppedEndpoints.contains(nodeId);

  void simulateNetworkDrop(String nodeId) {
    _droppedEndpoints.add(nodeId);
    for (final node in _nodes.values) {
      if (node.nodeId != nodeId && node.connectedEndpoints.contains(nodeId)) {
        node.notifyPeerDisconnected(nodeId);
      }
    }
  }

  void simulateReconnect(String nodeId) {
    _droppedEndpoints.remove(nodeId);
    for (final node in _nodes.values) {
      if (node.nodeId != nodeId && node.isRunning && _nodes[nodeId]?.isRunning == true) {
        node.notifyPeerConnected(nodeId);
        _nodes[nodeId]?.notifyPeerConnected(node.nodeId);
      }
    }
  }

  bool routeMessage({
    required String senderNodeId,
    required String targetNodeId,
    required P2PMessageType type,
    required Map<String, dynamic> data,
  }) {
    if (_droppedEndpoints.contains(senderNodeId) || _droppedEndpoints.contains(targetNodeId)) {
      // Packet dropped due to disconnected network state
      return false;
    }

    final target = _nodes[targetNodeId];
    if (target != null && target.isRunning) {
      target.deliverIncomingPayload(
        senderEndpointId: senderNodeId,
        type: type,
        data: data,
      );
      return true;
    }
    return false;
  }

  void broadcastMessage({
    required String senderNodeId,
    required P2PMessageType type,
    required Map<String, dynamic> data,
  }) {
    if (_droppedEndpoints.contains(senderNodeId)) return;

    for (final targetId in _nodes.keys) {
      if (targetId != senderNodeId && !_droppedEndpoints.contains(targetId)) {
        final target = _nodes[targetId];
        if (target != null && target.isRunning) {
          target.deliverIncomingPayload(
            senderEndpointId: senderNodeId,
            type: type,
            data: data,
          );
        }
      }
    }
  }

  void clear() {
    _nodes.clear();
    _droppedEndpoints.clear();
  }
}

/// Simulated P2P Transport running over VirtualMeshHub for Desktop and Multi-Device testing.
class SimulatedP2PTransport implements P2PTransport {
  final String nodeId;
  final VirtualMeshHub _hub = VirtualMeshHub();
  bool _isRunning = false;

  final Set<String> connectedEndpoints = {};

  final _endpointDiscoveredCtrl = StreamController<DiscoveredEndpoint>.broadcast();
  final _endpointLostCtrl = StreamController<String>.broadcast();
  final _connectionInitiatedCtrl = StreamController<ConnectionRequest>.broadcast();
  final _endpointConnectedCtrl = StreamController<String>.broadcast();
  final _endpointDisconnectedCtrl = StreamController<String>.broadcast();
  final _payloadReceivedCtrl = StreamController<P2PPayloadMessage>.broadcast();

  SimulatedP2PTransport({required this.nodeId}) {
    _hub.registerNode(this);
  }

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
    _isRunning = true;
  }

  @override
  Future<void> startDiscovery({
    required String studentName,
    required String serviceId,
  }) async {
    _isRunning = true;
    for (final otherNode in _hub._nodes.values) {
      if (otherNode.nodeId != nodeId && otherNode.isRunning) {
        _endpointDiscoveredCtrl.add(DiscoveredEndpoint(
          endpointId: otherNode.nodeId,
          endpointName: otherNode.nodeId,
          serviceId: serviceId,
        ));
      }
    }
  }

  @override
  Future<void> requestConnection({
    required String userName,
    required String endpointId,
  }) async {
    final target = _hub._nodes[endpointId];
    if (target != null) {
      target._connectionInitiatedCtrl.add(ConnectionRequest(
        endpointId: nodeId,
        endpointName: userName,
        authenticationToken: 'auth_token_simulated',
      ));
    }
  }

  @override
  Future<void> acceptConnection(String endpointId) async {
    connectedEndpoints.add(endpointId);
    _endpointConnectedCtrl.add(endpointId);

    final target = _hub._nodes[endpointId];
    if (target != null) {
      target.connectedEndpoints.add(nodeId);
      target._endpointConnectedCtrl.add(nodeId);
    }
  }

  @override
  Future<void> rejectConnection(String endpointId) async {
    final target = _hub._nodes[endpointId];
    if (target != null) {
      target._endpointDisconnectedCtrl.add(nodeId);
    }
  }

  @override
  Future<void> sendPayload({
    required String endpointId,
    required P2PMessageType type,
    required Map<String, dynamic> data,
  }) async {
    if (!_isRunning || _hub.isEndpointDropped(nodeId) || _hub.isEndpointDropped(endpointId)) {
      throw StateError('Cannot send payload: node $nodeId or target $endpointId is disconnected');
    }

    final delivered = _hub.routeMessage(
      senderNodeId: nodeId,
      targetNodeId: endpointId,
      type: type,
      data: data,
    );

    if (!delivered) {
      throw StateError('Delivery failed: endpoint $endpointId unreachable');
    }
  }

  @override
  Future<void> broadcastPayload({
    required P2PMessageType type,
    required Map<String, dynamic> data,
  }) async {
    if (!_isRunning || _hub.isEndpointDropped(nodeId)) return;

    _hub.broadcastMessage(
      senderNodeId: nodeId,
      type: type,
      data: data,
    );
  }

  @override
  Future<void> stopAllEndpoints() async {
    _isRunning = false;
    connectedEndpoints.clear();
  }

  void deliverIncomingPayload({
    required String senderEndpointId,
    required P2PMessageType type,
    required Map<String, dynamic> data,
  }) {
    _payloadReceivedCtrl.add(P2PPayloadMessage(
      senderEndpointId: senderEndpointId,
      type: type,
      data: data,
    ));
  }

  void notifyPeerConnected(String peerId) {
    connectedEndpoints.add(peerId);
    _endpointConnectedCtrl.add(peerId);
  }

  void notifyPeerDisconnected(String peerId) {
    connectedEndpoints.remove(peerId);
    _endpointDisconnectedCtrl.add(peerId);
  }
}
