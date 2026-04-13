import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            child: Text(
              user.nickname[0].toUpperCase(),
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.nickname,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            user.phoneMasked ?? user.phone,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.switch_account),
            title: const Text('切换账号'),
            onTap: () async {
              await _showSwitchAccountSheet(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('退出登录'),
            onTap: () async {
              context.read<ChatService>().resetForAccountSwitch();
              await context.read<AuthService>().logout();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showSwitchAccountSheet(BuildContext context) async {
    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();
    await auth.loadSavedAccounts();
    if (!context.mounted) return;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final accounts = auth.savedAccounts;
        final currentUserId = auth.currentUser?.id;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Text('切换账号', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('暂无可切换账号，请先登录过其它账号'),
                ),
              ...accounts.map((acc) {
                final isCurrent = acc.userId == currentUserId;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (acc.nickname.isNotEmpty ? acc.nickname[0] : '?').toUpperCase(),
                    ),
                  ),
                  title: Text(acc.nickname.isEmpty ? acc.phoneMasked : acc.nickname),
                  subtitle: Text(acc.phoneMasked.isNotEmpty ? acc.phoneMasked : acc.phone),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrent)
                        const Text('当前', style: TextStyle(color: Colors.blue)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: '删除该账号会话',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: sheetContext,
                            builder: (ctx) => AlertDialog(
                              title: const Text('删除账号会话'),
                              content: const Text('仅删除本地保存的会话，下次需要重新登录。是否继续？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;

                          await auth.removeSavedAccount(acc.userId);
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('账号会话已删除')),
                          );
                        },
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (isCurrent) {
                      Navigator.pop(sheetContext);
                      return;
                    }
                    final ok = await auth.switchToSavedAccount(acc.userId);
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                    if (!context.mounted) return;
                    if (ok) {
                      chat.resetForAccountSwitch();
                      await chat.loadFriends();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('账号切换成功')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(auth.lastError ?? '切换失败，请重新登录')),
                      );
                    }
                  },
                );
              }),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('使用其它账号登录'),
                onTap: () async {
                  chat.resetForAccountSwitch();
                  await auth.switchAccount();
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
