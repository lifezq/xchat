import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import '../../models/conversation.dart';
import '../chat/chat_screen.dart';

class ConversationsTab extends StatelessWidget {
  final String currentUserId;

  const ConversationsTab({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息')),
      body: Consumer<ChatService>(
        builder: (context, chatService, _) {
          final conversations = chatService.getConversations(currentUserId);
          
          if (conversations.isEmpty) {
            return const Center(
              child: Text('暂无消息\n去添加好友开始聊天吧', textAlign: TextAlign.center),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _ConversationItem(
                conversation: conversation,
                currentUserId: currentUserId,
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationItem extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;

  const _ConversationItem({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final lastMessage = conversation.lastMessage;
    
    return ListTile(
      leading: CircleAvatar(
        child: Text(conversation.otherUser.nickname[0].toUpperCase()),
      ),
      title: Text(conversation.otherUser.nickname),
      subtitle: lastMessage != null
        ? Text(
            lastMessage.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMessage != null)
            Text(
              _formatTime(lastMessage.timestamp),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          if (conversation.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              currentUserId: currentUserId,
              otherUser: conversation.otherUser,
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return DateFormat('MM/dd').format(time);
    }
  }
}
