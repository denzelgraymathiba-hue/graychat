import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/models.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/signaling_provider.dart';
import '../../core/providers/webrtc_provider.dart';
import 'chat_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _manualPeerIdController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _manualPeerIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddPeerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Connect to Peer Manually',
            style: TextStyle(color: Color(0xFF171B24), fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the Peer ID of the client you wish to discover and connect with.',
                style: TextStyle(color: Color(0xFF7E8494), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _manualPeerIdController,
                style: const TextStyle(color: Color(0xFF171B24)),
                decoration: InputDecoration(
                  hintText: 'Paste Peer UUID here',
                  hintStyle: const TextStyle(color: Color(0xFFC4C8D3)),
                  filled: true,
                  fillColor: const Color(0xFFF4F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1B4EBA), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF7E8494))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4EBA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final targetId = _manualPeerIdController.text.trim();
                if (targetId.isNotEmpty) {
                  final peer = PeerModel(
                    id: targetId,
                    deviceName: 'Manual Peer ${targetId.substring(0, 8)}',
                    localIP: 'Unknown',
                    publicIP: 'Unknown',
                    lastKnownPort: '8080',
                    isOnline: true,
                    lastSeen: DateTime.now(),
                    connectionType: 'WebRTC',
                  );
                  await ref.read(peersProvider.notifier).addOrUpdatePeer(peer);
                  _manualPeerIdController.clear();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Peer ${targetId.substring(0, 8)} added to list'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add & Connect'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsModal(UserProfile profile) {
    final fNameController = TextEditingController(text: profile.firstName);
    final lNameController = TextEditingController(text: profile.lastName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'My Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF171B24)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: fNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4EBA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () async {
                  final newProfile = profile.copyWith(
                    firstName: fNameController.text.trim(),
                    lastName: lNameController.text.trim(),
                  );
                  await ref.read(userProfileProvider.notifier).saveProfile(newProfile);
                  // Notify signaling service of name change
                  ref.read(signalingServiceProvider).updateProfilePresence();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully')),
                    );
                  }
                },
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  await ref.read(userProfileProvider.notifier).clearProfile();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Log Out / Reset Profile', style: TextStyle(color: Colors.redAccent)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String name, String? pathOrUrl, String? base64Str, {double size = 48}) {
    if (base64Str != null && base64Str.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
        );
      } catch (_) {}
    }

    if (pathOrUrl != null && pathOrUrl.isNotEmpty) {
      if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.network(pathOrUrl, width: size, height: size, fit: BoxFit.cover),
        );
      } else {
        final file = File(pathOrUrl);
        if (file.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(size / 2),
            child: Image.file(file, width: size, height: size, fit: BoxFit.cover),
          );
        }
      }
    }

    // Fallback colored initial avatar
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [
      const Color(0xFF1B4EBA),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];
    final color = colors[name.hashCode % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(color: Colors.white, fontSize: size * 0.45, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localPeerId = ref.watch(localPeerIdProvider);
    final peers = ref.watch(peersProvider);
    final connectionStates = ref.watch(peerConnectionStateProvider);
    final signalingConnected = ref.watch(signalingConnectedProvider);
    final userProfile = ref.watch(userProfileProvider);

    // Listen to signaling events to discover peers reactively
    ref.listen<AsyncValue<Map<String, dynamic>>>(signalingStreamProvider, (previous, next) {
      if (next.hasValue) {
        final envelope = next.value!;
        final senderId = envelope['senderId'] as String?;
        final type = envelope['type'] as String?;
        final data = envelope['data'] as Map<String, dynamic>?;

        if (senderId != null && senderId.isNotEmpty && senderId != localPeerId && senderId != 'system') {
          final db = ref.read(databaseServiceProvider);
          final existing = db.getPeerById(senderId);

          final peer = PeerModel(
            id: senderId,
            deviceName: data?['deviceName'] as String? ?? 
                       (existing?.deviceName ?? 'Peer ${senderId.substring(0, 8)}'),
            localIP: data?['localIP'] as String? ?? (existing?.localIP ?? 'Unknown'),
            publicIP: data?['publicIP'] as String? ?? (existing?.publicIP ?? 'Unknown'),
            lastKnownPort: data?['lastKnownPort'] as String? ?? (existing?.lastKnownPort ?? '8080'),
            isOnline: true,
            lastSeen: DateTime.now(),
            connectionType: 'WebRTC',
            phoneNumber: data?['phoneNumber'] as String? ?? existing?.phoneNumber,
            profilePicBase64: data?['profilePicBase64'] as String? ?? existing?.profilePicBase64,
          );
          ref.read(peersProvider.notifier).addOrUpdatePeer(peer);
        }

        if (type == 'register' && data != null) {
          final peerId = data['peerId'] as String?;
          if (peerId != null && peerId != localPeerId) {
            final db = ref.read(databaseServiceProvider);
            final existing = db.getPeerById(peerId);

            final peer = PeerModel(
              id: peerId,
              deviceName: data['deviceName'] as String? ?? (existing?.deviceName ?? 'Peer ${peerId.substring(0, 8)}'),
              localIP: data['localIP'] as String? ?? (existing?.localIP ?? 'Unknown'),
              publicIP: data['publicIP'] as String? ?? (existing?.publicIP ?? 'Unknown'),
              lastKnownPort: data['lastKnownPort'] as String? ?? (existing?.lastKnownPort ?? '8080'),
              isOnline: true,
              lastSeen: DateTime.now(),
              connectionType: 'WebRTC',
              phoneNumber: data['phoneNumber'] as String? ?? existing?.phoneNumber,
              profilePicBase64: data['profilePicBase64'] as String? ?? existing?.profilePicBase64,
            );
            ref.read(peersProvider.notifier).addOrUpdatePeer(peer);
          }
        }

        if (type == 'unregister' && data != null) {
          final peerId = data['peerId'] as String?;
          if (peerId != null && peerId != localPeerId) {
            final db = ref.read(databaseServiceProvider);
            final existing = db.getPeerById(peerId);
            if (existing != null) {
              ref.read(peersProvider.notifier).addOrUpdatePeer(
                existing.copyWith(isOnline: false),
              );
            }
          }
        }
      }
    });

    final userName = userProfile != null ? '${userProfile.firstName} ${userProfile.lastName}' : 'Jhone william';

    // Filter peers based on search query
    final filteredPeers = peers.where((peer) {
      final query = _searchQuery.toLowerCase();
      return peer.deviceName.toLowerCase().contains(query) ||
             (peer.phoneNumber?.toLowerCase().contains(query) ?? false) ||
             peer.id.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4EBA),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : const Text(
                'Liaoke',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
      ),
      // Full screen width custom drawer layout matching the design exactly
      drawer: Drawer(
        width: MediaQuery.of(context).size.width,
        child: Row(
          children: [
            // Left menu panel (75% screen width)
            Expanded(
              flex: 3,
              child: Container(
                color: const Color(0xFF1B4EBA),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAvatar(userName, userProfile?.profilePicPath, userProfile?.profilePicBase64, size: 60),
                            const SizedBox(height: 16),
                            Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userProfile?.phoneNumber ?? 'No Phone',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white12, thickness: 1),
                      // Drawer items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            _buildDrawerItem(Icons.home_outlined, 'Home', () {
                              Navigator.pop(context);
                            }),
                            _buildDrawerItem(Icons.group_outlined, 'New Group', () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('New Group: feature coming soon!')),
                              );
                            }),
                            _buildDrawerItem(Icons.speaker_notes_outlined, 'New Channel', () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('New Channel: feature coming soon!')),
                              );
                            }),
                            _buildDrawerItem(Icons.bookmark_border_outlined, 'Saved Messages', () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(peerId: localPeerId),
                                ),
                              );
                            }),
                            _buildDrawerItem(Icons.phone_outlined, 'Calls', () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Calls: feature coming soon!')),
                              );
                            }),
                            _buildDrawerItem(Icons.contacts_outlined, 'Contacts', () {
                              Navigator.pop(context);
                              _showAddPeerDialog();
                            }),
                            _buildDrawerItem(Icons.settings_outlined, 'Settings', () {
                              Navigator.pop(context);
                              if (userProfile != null) {
                                _showSettingsModal(userProfile);
                              }
                            }),
                            _buildDrawerItem(Icons.person_add_alt_1_outlined, 'Invite Friends', () {
                              Navigator.pop(context);
                              Clipboard.setData(ClipboardData(text: localPeerId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied your Peer ID to invite friends!')),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Right dark dismiss overlay (25% screen width)
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        // 'X' Close icon
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(height: 8),
                        const RotatedBox(
                          quarterTurns: 0,
                          child: Text(
                            'Liaoke',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Connection state bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: signalingConnected
                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                : const Color(0xFFEF4444).withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  signalingConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: signalingConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  signalingConnected
                      ? 'Secure P2P Signaling Connected'
                      : 'Connecting to server...',
                  style: TextStyle(
                    color: signalingConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: filteredPeers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.radar_outlined, size: 54, color: const Color(0xFF1B4EBA).withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        const Text(
                          'Scanning for active peers on network...',
                          style: TextStyle(color: Color(0xFF7E8494), fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _showAddPeerDialog,
                          child: const Text('Add Peer Manually', style: TextStyle(color: Color(0xFF1B4EBA), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: filteredPeers.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 84, color: Color(0xFFF1F3F7)),
                    itemBuilder: (context, index) {
                      final peer = filteredPeers[index];
                      final state = connectionStates[peer.id] ?? 'disconnected';
                      
                      Color statusColor;
                      if (state == 'connected') {
                        statusColor = const Color(0xFF10B981);
                      } else if (state == 'connecting') {
                        statusColor = const Color(0xFFF59E0B);
                      } else {
                        statusColor = Colors.grey;
                      }

                      // Let's load the messages to show last message text
                      final messages = ref.watch(messagesProvider(peer.id));
                      final lastMsg = messages.isNotEmpty ? messages.first : null;
                      
                      String subtext = peer.phoneNumber ?? 'ID: ${peer.id.substring(0, 8)}';
                      String timeText = '';
                      if (lastMsg != null) {
                        subtext = lastMsg.messageType == 'FILE' ? '📁 Sent a file' : lastMsg.content;
                        timeText = DateFormat('hh:mm a').format(lastMsg.timestamp);
                      } else {
                        timeText = DateFormat('hh:mm a').format(peer.lastSeen);
                      }

                      return ListTile(
                        leading: Stack(
                          children: [
                            _buildAvatar(peer.deviceName, null, peer.profilePicBase64),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          peer.deviceName,
                          style: const TextStyle(
                            color: Color(0xFF171B24),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          subtext,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF7E8494),
                            fontSize: 13,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              timeText,
                              style: const TextStyle(
                                color: Color(0xFFB0B5C1),
                                fontSize: 11,
                              ),
                            ),
                            if (state == 'connected')
                              const Padding(
                                padding: EdgeInsets.only(top: 4.0),
                                child: Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                              ),
                          ],
                        ),
                        onTap: () {
                          // Navigate straight to chat room
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(peerId: peer.id),
                            ),
                          );
                          // Auto connect if idle
                          if (state == 'disconnected') {
                            ref.read(peerConnectionStateProvider.notifier).connectToPeer(peer.id);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1B4EBA),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: _showAddPeerDialog,
        child: const Icon(Icons.edit, size: 24),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      horizontalTitleGap: 0,
      dense: true,
      onTap: onTap,
    );
  }
}
