import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'signaling_provider.dart';
import 'database_provider.dart';
import '../network/webrtc_service.dart';

// Provides a singleton instance of the WebRTCService
final webrtcServiceProvider = Provider<WebRTCService>((ref) {
  final signalingService = ref.watch(signalingServiceProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  final webrtcService = WebRTCService(signalingService, databaseService);

  ref.onDispose(() {
    webrtcService.dispose();
  });

  return webrtcService;
});

// A StateNotifier to expose active peer connection states reactively to the UI
class PeerConnectionStateNotifier extends StateNotifier<Map<String, String>> {
  final WebRTCService _webrtcService;
  StreamSubscription? _subscription;

  PeerConnectionStateNotifier(this._webrtcService) : super({}) {
    // Listen to connection state update events from the WebRTCService
    _subscription = _webrtcService.connectionStateStream.listen((update) {
      state = {
        ...state,
        update.peerId: update.state,
      };
    });
  }

  /// Triggers a connection request to a specific peer
  Future<void> connectToPeer(String peerId) async {
    await _webrtcService.connectToPeer(peerId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Provider for tracking the connection state of all peers
final peerConnectionStateProvider =
    StateNotifierProvider<PeerConnectionStateNotifier, Map<String, String>>((ref) {
  final webrtcService = ref.watch(webrtcServiceProvider);
  return PeerConnectionStateNotifier(webrtcService);
});
