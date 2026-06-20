import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../database/database_service.dart';
import '../database/models.dart';
import 'webrtc_provider.dart';
import '../network/webrtc_service.dart';

// Singleton DatabaseService provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// Initialize database boxes on app startup
final databaseInitProvider = FutureProvider<void>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  await dbService.initializeBoxes();
});

// User profile provider
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile?>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final notifier = UserProfileNotifier(dbService);

  ref.listen(databaseInitProvider, (previous, next) {
    if (next.hasValue) {
      notifier.initSubscription();
    }
  });

  return notifier;
});

// Get all peers (reactive)
final peersProvider = StateNotifierProvider<PeersNotifier, List<PeerModel>>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final notifier = PeersNotifier(dbService);

  ref.listen(databaseInitProvider, (previous, next) {
    if (next.hasValue) {
      notifier.initSubscription();
    }
  });

  return notifier;
});

// Get all messages for a specific peer (reactive)
final messagesProvider = StateNotifierProvider.family<
    MessagesNotifier,
    List<MessageModel>,
    String>((ref, peerId) {
  final dbService = ref.watch(databaseServiceProvider);
  final webrtcService = ref.watch(webrtcServiceProvider);
  final notifier = MessagesNotifier(dbService, webrtcService, peerId);

  ref.listen(databaseInitProvider, (previous, next) {
    if (next.hasValue) {
      notifier.initSubscription();
    }
  });

  return notifier;
});

// Database statistics
final dbStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  await ref.watch(databaseInitProvider.future);
  return dbService.getStats();
});

class PeersNotifier extends StateNotifier<List<PeerModel>> {
  final DatabaseService _dbService;
  StreamSubscription? _subscription;

  PeersNotifier(this._dbService) : super([]) {
    if (Hive.isBoxOpen(DatabaseService.peersBoxName)) {
      initSubscription();
    }
  }

  void initSubscription() {
    _subscription?.cancel();
    _loadPeers();
    try {
      _subscription = _dbService.peersBox.watch().listen((_) {
        _loadPeers();
      });
    } catch (e) {
      print('[PeersNotifier] Error subscribing to box watch: $e');
    }
  }

  void _loadPeers() {
    try {
      final peers = _dbService.getAllPeers();
      state = peers;
      print('[PeersNotifier] Loaded ${peers.length} peers');
    } catch (e) {
      print('[PeersNotifier] ERROR loading peers: $e');
    }
  }

  Future<void> addOrUpdatePeer(PeerModel peer) async {
    try {
      await _dbService.addOrUpdatePeer(peer);
      _loadPeers();
      print('[PeersNotifier] Peer updated: ${peer.deviceName}');
    } catch (e) {
      print('[PeersNotifier] ERROR adding peer: $e');
      rethrow;
    }
  }

  Future<void> deletePeer(String peerId) async {
    try {
      await _dbService.deletePeer(peerId);
      _loadPeers();
      print('[PeersNotifier] Peer deleted: $peerId');
    } catch (e) {
      print('[PeersNotifier] ERROR deleting peer: $e');
      rethrow;
    }
  }

  Future<void> clearAllPeers() async {
    try {
      await _dbService.clearAllPeers();
      state = [];
      print('[PeersNotifier] All peers cleared');
    } catch (e) {
      print('[PeersNotifier] ERROR clearing peers: $e');
      rethrow;
    }
  }

  List<PeerModel> getOnlinePeers() {
    return state.where((peer) => peer.isOnline).toList();
  }

  List<PeerModel> getOfflinePeers() {
    return state.where((peer) => !peer.isOnline).toList();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class MessagesNotifier extends StateNotifier<List<MessageModel>> {
  final DatabaseService _dbService;
  final WebRTCService _webrtcService;
  final String _peerId;
  StreamSubscription? _subscription;

  MessagesNotifier(this._dbService, this._webrtcService, this._peerId) : super([]) {
    if (Hive.isBoxOpen(DatabaseService.messagesBoxName)) {
      initSubscription();
    }
  }

  void initSubscription() {
    _subscription?.cancel();
    _loadMessages();
    try {
      _subscription = _dbService.messagesBox.watch().listen((_) {
        _loadMessages();
      });
    } catch (e) {
      print('[MessagesNotifier] Error subscribing to box watch: $e');
    }
  }

  void _loadMessages() {
    try {
      final messages = _dbService.getMessagesByPeerIdSorted(_peerId);
      state = messages;
      print('[MessagesNotifier] Loaded ${messages.length} messages for peer: $_peerId');
    } catch (e) {
      print('[MessagesNotifier] ERROR loading messages: $e');
    }
  }

  Future<void> addMessage(MessageModel message) async {
    try {
      await _dbService.addMessage(message);
      _loadMessages();
      print('[MessagesNotifier] Message added: ${message.id}');
    } catch (e) {
      print('[MessagesNotifier] ERROR adding message: $e');
      rethrow;
    }
  }

  /// Exposes a single action to send a message over the network and commit to local storage
  Future<void> sendMessage(String content) async {
    try {
      await _webrtcService.sendMessage(_peerId, content);
      print('[MessagesNotifier] Message sent: $content');
    } catch (e) {
      print('[MessagesNotifier] ERROR sending message: $e');
      rethrow;
    }
  }

  /// Exposes a single action to send a file over the network and commit to local storage in chunks
  Future<void> sendFile(String filePath) async {
    try {
      await _webrtcService.sendFileInChunks(_peerId, filePath);
      print('[MessagesNotifier] File transfer initiated: $filePath');
    } catch (e) {
      print('[MessagesNotifier] ERROR sending file: $e');
      rethrow;
    }
  }

  Future<void> updateMessage(MessageModel message) async {
    try {
      await _dbService.updateMessage(message);
      _loadMessages();
      print('[MessagesNotifier] Message updated: ${message.id}');
    } catch (e) {
      print('[MessagesNotifier] ERROR updating message: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _dbService.deleteMessage(messageId);
      _loadMessages();
      print('[MessagesNotifier] Message deleted: $messageId');
    } catch (e) {
      print('[MessagesNotifier] ERROR deleting message: $e');
      rethrow;
    }
  }

  Future<void> clearAllMessages() async {
    try {
      await _dbService.deleteMessagesByPeerId(_peerId);
      state = [];
      print('[MessagesNotifier] All messages cleared for peer: $_peerId');
    } catch (e) {
      print('[MessagesNotifier] ERROR clearing messages: $e');
      rethrow;
    }
  }

  int getFileTransferCount() {
    return state.where((msg) => msg.messageType == 'FILE').length;
  }

  int getCompletedTransfersCount() {
    return state
        .where((msg) => msg.messageType == 'FILE' && msg.isTransferComplete)
        .length;
  }

  double getAverageTransferProgress() {
    final fileMessages = state.where((msg) => msg.messageType == 'FILE').toList();
    if (fileMessages.isEmpty) return 0.0;
    final totalProgress = fileMessages.fold<double>(
      0.0,
      (sum, msg) => sum + msg.calculatedProgress,
    );
    return totalProgress / fileMessages.length;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class UserProfileNotifier extends StateNotifier<UserProfile?> {
  final DatabaseService _dbService;
  StreamSubscription? _subscription;

  UserProfileNotifier(this._dbService) : super(null) {
    if (Hive.isBoxOpen(DatabaseService.profileBoxName)) {
      initSubscription();
    }
  }

  void initSubscription() {
    _subscription?.cancel();
    _loadProfile();
    try {
      _subscription = _dbService.profileBox.watch(key: 'user_profile').listen((_) {
        _loadProfile();
      });
    } catch (e) {
      print('[UserProfileNotifier] Error subscribing to profile box: $e');
    }
  }

  void _loadProfile() {
    state = _dbService.getUserProfile();
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _dbService.saveUserProfile(profile);
    _loadProfile();
  }

  Future<void> clearProfile() async {
    await _dbService.profileBox.delete('user_profile');
    state = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
