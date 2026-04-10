import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../chat/chat_screen.dart';

class FriendsTab extends StatelessWidget {
  final String currentUserId;

  const FriendsTab({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddFriendDialog(context),
          ),
        ],
      ),
      body: Consumer<ChatService>(
        builder: (context, chatService, _) {
          final friends = chatService.friends;
          
          if (friends.isEmpty) {
            return const Center(
              child: Text('暂无好友\n点击右上角添加好友'),
            );
          }

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(friend.nickname[0].toUpperCase()),
                ),
                title: Text(friend.nickname),
                subtitle: Text(friend.phoneMasked ?? friend.phone),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        currentUserId: currentUserId,
                        otherUser: friend,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加好友'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '输入好友手机号',
            hintText: '13812345678',
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final phone = controller.text.trim();
              if (phone.isEmpty) return;
              
              final success = await context.read<ChatService>().addFriend(phone);
              if (context.mounted) {
                Navigator.pop(context);
                final errorMsg = context.read<ChatService>().lastError;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '添加成功' : (errorMsg ?? '添加失败，请稍后重试')),
                  ),
                );
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
