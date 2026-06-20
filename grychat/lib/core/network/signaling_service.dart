import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import '../database/database_service.dart';
import '../database/models.dart';

class SignalingService {
  final String serverUrl;
  final String localPeerId;
  final DatabaseService? databaseService;

  IOWebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _signalStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  
  bool _isDisposed = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  StreamSubscription? _channelSubscription;

  SignalingService({
    required this.serverUrl,
    required this.localPeerId,
    this.databaseService,
  });

  /// Exposes the stream of incoming signaling messages from other peers
  Stream<Map<String, dynamic>> get signalStream => _signalStreamController.stream;

  /// Check if the service is currently connected to the signaling server
  bool get isConnected => _channel != null;

  /// Connects to the WebSocket signaling server
  void connect() {
    if (_isDisposed || _isConnecting || _channel != null) return;
    _isConnecting = true;
    print('[SignalingService] Connecting to $serverUrl for peer $localPeerId...');

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(serverUrl),
        pingInterval: const Duration(seconds: 10),
      );

      _channelSubscription = _channel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> payload = jsonDecode(message as String);
            _signalStreamController.add(payload);
          } catch (e) {
            print('[SignalingService] Error decoding signal message: $e');
          }
        },
        onError: (error) {
          print('[SignalingService] WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('[SignalingService] WebSocket connection closed by server');
          _handleDisconnect();
        },
      );

      _isConnecting = false;
      _registerPresence();
      _signalStreamController.add({
        'senderId': 'system',
        'targetId': localPeerId,
        'type': 'server_connection',
        'data': {'connected': true},
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('[SignalingService] Connection failed: $e');
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  /// Sends a presence registration message to the signaling server
  void _registerPresence() {
    final UserProfile? profile = databaseService?.getUserProfile();
    final data = {
      'peerId': localPeerId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    if (profile != null) {
      data['deviceName'] = '${profile.firstName} ${profile.lastName}';
      data['phoneNumber'] = profile.phoneNumber;
      data['profilePicBase64'] = profile.profilePicBase64 ?? '';
    }
    sendSignal('', 'register', data);
  }

  /// Refreshes/updates the presence registration with new profile info
  void updateProfilePresence() {
    if (isConnected) {
      _registerPresence();
    }
  }

  /// Formats and transmits a signal to a target peer or the server
  void sendSignal(String targetPeerId, String type, Map<String, dynamic> data) {
    if (_channel == null) {
      print('[SignalingService] Cannot send signal: Not connected');
      return;
    }

    final envelope = {
      'senderId': localPeerId,
      'targetId': targetPeerId,
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      _channel!.sink.add(jsonEncode(envelope));
    } catch (e) {
      print('[SignalingService] Error sending signal: $e');
    }
  }

  /// Handles disconnection events by starting the reconnect timer
  void _handleDisconnect() {
    _cleanupChannel();
    _signalStreamController.add({
      'senderId': 'system',
      'targetId': localPeerId,
      'type': 'server_connection',
      'data': {'connected': false},
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      print('[SignalingService] Attempting auto-reconnect...');
      connect();
    });
  }

  /// Cleans up connection resources for the channel
  void _cleanupChannel() {
    _channelSubscription?.cancel();
    _channelSubscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Disconnects manually from the WebSocket signaling server
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupChannel();
    print('[SignalingService] Disconnected manually');
  }

  /// Disposes the signaling service completely
  void dispose() {
    _isDisposed = true;
    disconnect();
    _signalStreamController.close();
    print('[SignalingService] Disposed');
  }
}
