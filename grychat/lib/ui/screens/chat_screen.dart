import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/database/models.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/signaling_provider.dart';
import '../../core/providers/webrtc_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String peerId;

  const ChatScreen({super.key, required this.peerId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _filePathController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _filePathController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final messagesNotifier = ref.read(messagesProvider(widget.peerId).notifier);
    messagesNotifier.sendMessage(text).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });

    _messageController.clear();
  }

  Future<void> _handleSendFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: File does not exist at specified path'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final messagesNotifier = ref.read(messagesProvider(widget.peerId).notifier);
    try {
      await messagesNotifier.sendFile(filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File transfer initiated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send file: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String> _generateMockFile(String name, int sizeInBytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$name');
    
    // Efficiently write a mock file filled with zero bytes
    final raf = await file.open(mode: FileMode.write);
    final chunk = Uint8List(64 * 1024); // 64KB chunk of zeros
    int written = 0;
    while (written < sizeInBytes) {
      final toWrite = sizeInBytes - written;
      if (toWrite < chunk.length) {
        await raf.writeFrom(Uint8List(toWrite));
        written += toWrite;
      } else {
        await raf.writeFrom(chunk);
        written += chunk.length;
      }
    }
    await raf.close();
    return file.path;
  }

  void _showAttachmentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Send File Attachment',
                  style: TextStyle(
                    color: Color(0xFF171B24),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Predefined test files
                const Text(
                  'GENERATE & SEND DUMMY P2P TEST FILES',
                  style: TextStyle(
                    color: Color(0xFF1B4EBA),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMockFileButton('1 MB', 'mock_1mb.bin', 1024 * 1024),
                    _buildMockFileButton('5 MB', 'mock_5mb.bin', 5 * 1024 * 1024),
                    _buildMockFileButton('10 MB', 'mock_10mb.bin', 10 * 1024 * 1024),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  'ENTER CUSTOM FILE PATH MANUALLY',
                  style: TextStyle(
                    color: Color(0xFF1B4EBA),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _filePathController,
                        style: const TextStyle(color: Color(0xFF171B24), fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'C:\\path\\to\\file.txt',
                          hintStyle: const TextStyle(color: Color(0xFFC4C8D3)),
                          filled: true,
                          fillColor: const Color(0xFFF4F6FA),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B4EBA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final path = _filePathController.text.trim();
                        if (path.isNotEmpty) {
                          Navigator.pop(context);
                          _handleSendFile(path);
                        }
                      },
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMockFileButton(String label, String fileName, int bytes) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF4F6FA),
        foregroundColor: const Color(0xFF171B24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
      ),
      onPressed: () async {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generating $label test file...'),
            duration: const Duration(seconds: 1),
          ),
        );
        final path = await _generateMockFile(fileName, bytes);
        await _handleSendFile(path);
      },
      child: Column(
        children: [
          const Icon(Icons.insert_drive_file, color: Color(0xFF1B4EBA)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _getFileName(MessageModel message) {
    final parts = message.content.split('/');
    final lastPart = parts.isEmpty ? '' : parts.last;
    final backslashParts = lastPart.split('\\');
    return backslashParts.isEmpty ? 'File' : backslashParts.last;
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.peerId));
    final localPeerId = ref.watch(localPeerIdProvider);
    
    // Watch peer details from database
    final peers = ref.watch(peersProvider);
    final peer = peers.firstWhere(
      (p) => p.id == widget.peerId,
      orElse: () => PeerModel(
        id: widget.peerId,
        deviceName: 'Peer ${widget.peerId.substring(0, 8)}',
        localIP: 'Unknown',
        publicIP: 'Unknown',
        lastKnownPort: '',
        isOnline: false,
        lastSeen: DateTime.now(),
        connectionType: '',
      ),
    );

    // Watch peer connection status
    final connectionStates = ref.watch(peerConnectionStateProvider);
    final connectionState = connectionStates[widget.peerId] ?? 'disconnected';

    Color statusColor = Colors.grey;
    String statusText = 'Offline';
    if (connectionState == 'connected') {
      statusColor = const Color(0xFF10B981);
      statusText = 'Connected';
    } else if (connectionState == 'connecting') {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'Connecting...';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4EBA),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              peer.deviceName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white70),
            tooltip: 'Clear Messages',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: const Text('Clear Chat History', style: TextStyle(color: Color(0xFF171B24), fontWeight: FontWeight.bold)),
                  content: const Text(
                    'Are you sure you want to delete all messages and file references for this peer?',
                    style: TextStyle(color: Color(0xFF7E8494)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF7E8494))),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(messagesProvider(widget.peerId).notifier).clearAllMessages();
                        Navigator.pop(context);
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Message Feed
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        const Text(
                          'No messages yet. Send a message to start.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == localPeerId;
                      final isFile = message.messageType == 'FILE' || message.fileSizeInBytes > 0;

                      return _buildMessageBubble(message, isMe, isFile);
                    },
                  ),
          ),

          // Message Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE2E6EE), width: 0.8),
              ),
            ),
            child: Row(
              children: [
                // Attachment Clip Button
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Color(0xFF1B4EBA)),
                  tooltip: 'Attach file',
                  onPressed: _showAttachmentModal,
                ),
                
                // Text Field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Color(0xFF171B24)),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: const TextStyle(color: Color(0xFFB0B5C1)),
                      filled: true,
                      fillColor: const Color(0xFFF4F6FA),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFF1B4EBA), width: 1.0),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),

                // Send Button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B4EBA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe, bool isFile) {
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1B4EBA) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: const Color(0xFFE2E6EE), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFile)
              _buildFileCard(message, isMe)
            else
              Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF171B24),
                  fontSize: 14.5,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : const Color(0xFF7E8494),
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isTransferComplete ? Icons.done_all : Icons.done,
                    color: Colors.white70,
                    size: 11,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(MessageModel message, bool isMe) {
    final fileName = _getFileName(message);
    final sizeText = _formatFileSize(message.fileSizeInBytes);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isMe ? const Color(0x40000000) : const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMe ? Colors.white24 : const Color(0xFFE2E6EE), width: 0.8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insert_drive_file,
                color: isMe ? Colors.white70 : const Color(0xFF1B4EBA),
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        color: isMe ? Colors.white : const Color(0xFF171B24),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sizeText,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : const Color(0xFF7E8494),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (!message.isTransferComplete) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: message.fileProgress,
              backgroundColor: isMe ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(isMe ? Colors.white : const Color(0xFF1B4EBA)),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(message.fileProgress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isMe ? Colors.white : const Color(0xFF1B4EBA),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_formatFileSize(message.bytesTransferred)} of $sizeText',
                  style: TextStyle(
                    color: isMe ? Colors.white70 : const Color(0xFF7E8494),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Divider(color: isMe ? Colors.white24 : Colors.black12, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                const SizedBox(width: 6),
                const Text(
                  'Transfer Complete',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Path: ${message.content}',
              style: TextStyle(
                color: isMe ? Colors.white60 : const Color(0xFF7E8494),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
