import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

class DatabaseService {
  static const String peersBoxName = 'peers';
  static const String messagesBoxName = 'messages';
  static const String profileBoxName = 'profile';
  static const String settingsBoxName = 'settings';

  late Box<PeerModel> _peersBox;
  late Box<MessageModel> _messagesBox;
  late Box<UserProfile> _profileBox;
  late Box<String> _settingsBox;

  Box<PeerModel> get peersBox => _peersBox;
  Box<MessageModel> get messagesBox => _messagesBox;
  Box<UserProfile> get profileBox => _profileBox;
  Box<String> get settingsBox => _settingsBox;

  /// Initialize Hive boxes for peers, messages, profile, and settings
  Future<void> initializeBoxes() async {
    try {
      _peersBox = await Hive.openBox<PeerModel>(peersBoxName);
      _messagesBox = await Hive.openBox<MessageModel>(messagesBoxName);
      _profileBox = await Hive.openBox<UserProfile>(profileBoxName);
      _settingsBox = await Hive.openBox<String>(settingsBoxName);
      print('[DatabaseService] Boxes initialized successfully');
    } catch (e) {
      print('[DatabaseService] ERROR initializing boxes: $e');
      rethrow;
    }
  }

  /// Get the user profile
  UserProfile? getUserProfile() {
    try {
      return _profileBox.get('user_profile');
    } catch (e) {
      print('[DatabaseService] ERROR getting profile: $e');
      return null;
    }
  }

  /// Save user profile
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await _profileBox.put('user_profile', profile);
      print('[DatabaseService] User profile saved/updated: ${profile.firstName}');
    } catch (e) {
      print('[DatabaseService] ERROR saving profile: $e');
      rethrow;
    }
  }

  /// Add or update a peer
  Future<void> addOrUpdatePeer(PeerModel peer) async {
    try {
      await _peersBox.put(peer.id, peer);
      print('[DatabaseService] Peer added/updated: ${peer.deviceName}');
    } catch (e) {
      print('[DatabaseService] ERROR adding peer: $e');
      rethrow;
    }
  }

  /// Get a peer by ID
  PeerModel? getPeerById(String peerId) {
    try {
      return _peersBox.get(peerId);
    } catch (e) {
      print('[DatabaseService] ERROR getting peer: $e');
      return null;
    }
  }

  /// Get all peers
  List<PeerModel> getAllPeers() {
    try {
      return _peersBox.values.toList();
    } catch (e) {
      print('[DatabaseService] ERROR getting all peers: $e');
      return [];
    }
  }

  /// Delete a peer by ID
  Future<void> deletePeer(String peerId) async {
    try {
      await _peersBox.delete(peerId);
      print('[DatabaseService] Peer deleted: $peerId');
    } catch (e) {
      print('[DatabaseService] ERROR deleting peer: $e');
      rethrow;
    }
  }

  /// Clear all peers
  Future<void> clearAllPeers() async {
    try {
      await _peersBox.clear();
      print('[DatabaseService] All peers cleared');
    } catch (e) {
      print('[DatabaseService] ERROR clearing peers: $e');
      rethrow;
    }
  }

  /// Add a message
  Future<void> addMessage(MessageModel message) async {
    try {
      await _messagesBox.put(message.id, message);
      print('[DatabaseService] Message added: ${message.id}');
    } catch (e) {
      print('[DatabaseService] ERROR adding message: $e');
      rethrow;
    }
  }

  /// Update a message (for tracking progress)
  Future<void> updateMessage(MessageModel message) async {
    try {
      await _messagesBox.put(message.id, message);
      print('[DatabaseService] Message updated: ${message.id}');
    } catch (e) {
      print('[DatabaseService] ERROR updating message: $e');
      rethrow;
    }
  }

  /// Get a message by ID
  MessageModel? getMessageById(String messageId) {
    try {
      return _messagesBox.get(messageId);
    } catch (e) {
      print('[DatabaseService] ERROR getting message: $e');
      return null;
    }
  }

  /// Get all messages for a peer
  List<MessageModel> getMessagesByPeerId(String peerId) {
    try {
      return _messagesBox.values
          .where((msg) => msg.peerId == peerId)
          .toList();
    } catch (e) {
      print('[DatabaseService] ERROR getting messages: $e');
      return [];
    }
  }

  /// Get messages sorted by timestamp (newest first)
  List<MessageModel> getMessagesByPeerIdSorted(String peerId) {
    try {
      final messages = getMessagesByPeerId(peerId);
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return messages;
    } catch (e) {
      print('[DatabaseService] ERROR getting sorted messages: $e');
      return [];
    }
  }

  /// Delete a message by ID
  Future<void> deleteMessage(String messageId) async {
    try {
      await _messagesBox.delete(messageId);
      print('[DatabaseService] Message deleted: $messageId');
    } catch (e) {
      print('[DatabaseService] ERROR deleting message: $e');
      rethrow;
    }
  }

  /// Delete all messages for a peer
  Future<void> deleteMessagesByPeerId(String peerId) async {
    try {
      final keysToDelete = _messagesBox.keys
          .where((key) => _messagesBox.get(key)?.peerId == peerId)
          .toList();
      await _messagesBox.deleteAll(keysToDelete);
      print('[DatabaseService] All messages deleted for peer: $peerId');
    } catch (e) {
      print('[DatabaseService] ERROR deleting peer messages: $e');
      rethrow;
    }
  }

  /// Clear all messages
  Future<void> clearAllMessages() async {
    try {
      await _messagesBox.clear();
      print('[DatabaseService] All messages cleared');
    } catch (e) {
      print('[DatabaseService] ERROR clearing messages: $e');
      rethrow;
    }
  }

  /// Get box statistics
  Map<String, dynamic> getStats() {
    try {
      return {
        'peersCount': _peersBox.length,
        'messagesCount': _messagesBox.length,
        'onlinePeersCount': _peersBox.values.where((p) => p.isOnline).length,
      };
    } catch (e) {
      print('[DatabaseService] ERROR getting stats: $e');
      return {};
    }
  }

  /// Close all boxes
  Future<void> closeBoxes() async {
    try {
      await _peersBox.close();
      await _messagesBox.close();
      await _profileBox.close();
      await _settingsBox.close();
      print('[DatabaseService] Boxes closed');
    } catch (e) {
      print('[DatabaseService] ERROR closing boxes: $e');
      rethrow;
    }
  }
}
