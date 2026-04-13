import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/audio_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/voice_message_widget.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final User otherUser;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _audioService = AudioService();
  final _apiService = ApiService();
  bool _isRecording = false;
  bool _isUploading = false;
  bool _showEmojiPanel = false;
  bool _isSyncingReadReceipt = false;
  late final ChatService _chatService;

  static const List<String> _emojiList = <String>[
    "😀", "😁", "😂", "🤣", "😊", "😍", "😘", "😎", "😭", "😡",
    "👍", "👎", "👏", "🙏", "❤️", "🔥", "🎉", "💪", "🤝", "🌹",
  ];

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _chatService.addListener(_onChatServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChatData();
    });
  }

  @override
  void dispose() {
    _chatService.removeListener(_onChatServiceChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  void _onChatServiceChanged() {
    if (!mounted || _isSyncingReadReceipt) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;

    final messages = _chatService.getMessages(widget.currentUserId, widget.otherUser.id);
    final hasUnreadIncoming = messages.any(
      (m) => m.receiverId == widget.currentUserId && !m.isRead,
    );
    if (!hasUnreadIncoming) return;

    _isSyncingReadReceipt = true;
    _syncReadReceipt().whenComplete(() {
      _isSyncingReadReceipt = false;
    });
  }

  Future<void> _startRecording() async {
    if (!await _audioService.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限')),
        );
      }
      return;
    }

    final path = await _audioService.startRecording();
    if (path != null) {
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioService.stopRecording();
    setState(() => _isRecording = false);

    if (path != null && mounted) {
      try {
        final voiceUrl = await _apiService.uploadVoice(File(path));
        if (!mounted) return;

        await context.read<ChatService>().sendMessage(
          senderId: widget.currentUserId,
          receiverId: widget.otherUser.id,
          content: '[语音消息]',
          type: MessageType.voice,
          voiceUrl: _toAbsoluteUrl(voiceUrl),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('发送语音失败')),
          );
        }
      }
    }
  }

  Future<void> _loadChatData() async {
    final chatService = context.read<ChatService>();
    await chatService.loadMessages(widget.currentUserId, widget.otherUser.id);
    await _syncReadReceipt();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _syncReadReceipt() async {
    final messages = _chatService.getMessages(widget.currentUserId, widget.otherUser.id);
    final incoming = messages
        .where((m) => m.receiverId == widget.currentUserId)
        .toList();
    if (incoming.isEmpty) return;

    final latestIncoming = incoming.last;
    final latestID = int.tryParse(latestIncoming.id);
    if (latestID == null) return;

    final peerID = int.tryParse(widget.otherUser.id);
    if (peerID == null) return;

    try {
      await _apiService.markMessagesRead(peerID, readUptoMessageId: latestID);
      _chatService.markAsRead(widget.currentUserId, widget.otherUser.id);
    } catch (_) {
      // 已读回执失败不阻塞聊天主流程
    }
  }

  Future<void> _pickAndSendImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      return;
    }
    await _uploadAndSendMedia(File(result.files.single.path!), MessageType.image);
  }

  Future<void> _pickAndSendVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>["mp4", "mov", "avi", "mkv", "webm"],
    );
    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      return;
    }
    await _uploadAndSendMedia(File(result.files.single.path!), MessageType.video);
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      return;
    }
    await _uploadAndSendMedia(File(result.files.single.path!), MessageType.file);
  }

  Future<void> _uploadAndSendMedia(File file, MessageType type) async {
    setState(() => _isUploading = true);
    try {
      final relativeUrl = await _apiService.uploadFile(file);
      final mediaUrl = _toAbsoluteUrl(relativeUrl);
      if (!mounted) return;

      await context.read<ChatService>().sendMessage(
            senderId: widget.currentUserId,
            receiverId: widget.otherUser.id,
            content: mediaUrl,
            type: type,
          );

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发送附件失败')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _sendEmoji(String emoji) {
    context.read<ChatService>().sendMessage(
          senderId: widget.currentUserId,
          receiverId: widget.otherUser.id,
          content: emoji,
          type: MessageType.emoji,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _toAbsoluteUrl(String url) {
    if (url.startsWith('http')) return url;
    final baseUri = Uri.parse(ApiService.baseUrl);
    return '${baseUri.scheme}://${baseUri.host}:${baseUri.port}$url';
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();

    await context.read<ChatService>().sendMessage(
          senderId: widget.currentUserId,
          receiverId: widget.otherUser.id,
          content: content,
          type: MessageType.text,
        );

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUser.nickname),
      ),
      body: Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Consumer<ChatService>(
              builder: (context, chatService, _) {
                final messages = chatService.getMessages(
                  widget.currentUserId,
                  widget.otherUser.id,
                );

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('开始聊天吧'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == widget.currentUserId;

                    return _MessageBubble(
                      message: message,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
          if (_showEmojiPanel) _buildEmojiPanel(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.image),
                        title: const Text('图片'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndSendImage();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.videocam),
                        title: const Text('视频'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndSendVideo();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: const Text('文件'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndSendFile();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          GestureDetector(
            onLongPress: _startRecording,
            onLongPressEnd: (_) => _stopRecording(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic,
                color: _isRecording ? Colors.white : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: '输入消息...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onTap: () {
                if (_showEmojiPanel) {
                  setState(() => _showEmojiPanel = false);
                }
              },
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined),
            onPressed: () => setState(() => _showEmojiPanel = !_showEmojiPanel),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPanel() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFF5F5F5),
      child: GridView.builder(
        itemCount: _emojiList.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final emoji = _emojiList[index];
          return InkWell(
            onTap: () => _sendEmoji(emoji),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 20)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildMessageBody(context),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Text(
                        _statusText(message.status),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 20)),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBody(BuildContext context) {
    switch (message.type) {
      case MessageType.voice:
        return VoiceMessageWidget(
          voiceUrl: message.voiceUrl ?? message.content,
          isMe: isMe,
        );
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message.content,
            width: 180,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackBubble('图片加载失败'),
          ),
        );
      case MessageType.video:
        return _linkBubble(
          icon: Icons.videocam,
          title: '视频消息',
          url: message.content,
        );
      case MessageType.file:
        return _linkBubble(
          icon: Icons.insert_drive_file,
          title: _fileNameFromUrl(message.content),
          url: message.content,
        );
      case MessageType.emoji:
        return Text(
          message.content,
          style: const TextStyle(fontSize: 34),
        );
      case MessageType.text:
        return _textBubble(message.content);
    }
  }

  Widget _textBubble(String content) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue : Colors.grey[300],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        content,
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _fallbackBubble(String text) {
    return Container(
      width: 180,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    );
  }

  Widget _linkBubble({required IconData icon, required String title, required String url}) {
    return InkWell(
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri == null) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isMe ? Colors.white : Colors.black87),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) {
      return '文件';
    }
    return uri.pathSegments.last;
  }

  String _statusText(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return '已发送';
      case MessageStatus.delivered:
        return '已送达';
      case MessageStatus.read:
        return '已读';
    }
  }
}
