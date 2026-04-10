import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import '../../services/audio_service.dart';
import '../../services/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatService = context.read<ChatService>();
      chatService.loadMessages(widget.currentUserId, widget.otherUser.id);
      chatService.markAsRead(widget.currentUserId, widget.otherUser.id);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    super.dispose();
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
      // 上传语音文件
      try {
        final voiceUrl = await _apiService.uploadVoice(File(path));
        if (!mounted) return;
        
        await context.read<ChatService>().sendMessage(
          senderId: widget.currentUserId,
          receiverId: widget.otherUser.id,
          content: '[语音消息]',
          type: MessageType.voice,
          voiceUrl: voiceUrl,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('发送语音失败')),
          );
        }
      }
    }
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
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
            color: Theme.of(context).primaryColor,
          ),
        ],
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
                message.type == MessageType.voice
                  ? VoiceMessageWidget(
                      voiceUrl: message.voiceUrl ?? message.content,
                      isMe: isMe,
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue : Colors.grey[300],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ),
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
