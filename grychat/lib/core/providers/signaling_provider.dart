import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../network/signaling_service.dart';
import '../database/database_service.dart';
import 'database_provider.dart';

// Provider to manage the local peer ID (generates one if it doesn't exist, loaded from settings box)
final localPeerIdProvider = Provider<String>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  if (Hive.isBoxOpen(DatabaseService.settingsBoxName)) {
    final box = dbService.settingsBox;
    final savedId = box.get('local_peer_id');
    if (savedId != null) {
      return savedId;
    }
    final newId = const Uuid().v4();
    box.put('local_peer_id', newId);
    return newId;
  }
  return const Uuid().v4();
});

// Default signaling server URL
final signalingServerUrlProvider = Provider<String>((ref) {
  // Default fallback URL, can be overridden via app settings later.
  return 'ws://localhost:8080';
});

// SignalingService provider
final signalingServiceProvider = Provider<SignalingService>((ref) {
  final serverUrl = ref.watch(signalingServerUrlProvider);
  final localPeerId = ref.watch(localPeerIdProvider);
  final dbService = ref.watch(databaseServiceProvider);

  final service = SignalingService(
    serverUrl: serverUrl,
    localPeerId: localPeerId,
    databaseService: dbService,
  );

  // Auto connect when the provider is initialized
  service.connect();

  // Clean up and dispose when provider is destroyed or updated
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// A stream provider to listen to signaling events reactively in the UI/other logic
final signalingStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final signalingService = ref.watch(signalingServiceProvider);
  return signalingService.signalStream;
});

// A state notifier and provider to track signaling connection state reactively
class SignalingConnectedNotifier extends StateNotifier<bool> {
  final SignalingService _service;
  StreamSubscription? _subscription;

  SignalingConnectedNotifier(this._service) : super(_service.isConnected) {
    _subscription = _service.signalStream.listen((event) {
      if (event['type'] == 'server_connection') {
        state = event['data']?['connected'] as bool? ?? false;
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final signalingConnectedProvider =
    StateNotifierProvider<SignalingConnectedNotifier, bool>((ref) {
  final service = ref.watch(signalingServiceProvider);
  return SignalingConnectedNotifier(service);
});
