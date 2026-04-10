import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/websocket_service.dart';
import 'conversations_tab.dart';
import 'friends_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  WsConnectionStatus _previousWsStatus = WsConnectionStatus.disconnected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatService>().loadFriends();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final currentUser = auth.currentUser;
    final wsStatus = auth.wsConnectionStatus;
    _handleWsStatusTransition(wsStatus);
    
    final tabs = [
      ConversationsTab(currentUserId: currentUser!.id),
      FriendsTab(currentUserId: currentUser.id),
      const ProfileTab(),
    ];

    return Scaffold(
      body: tabs[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (wsStatus != WsConnectionStatus.connected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: _wsStatusColor(wsStatus),
              child: Text(
                _wsStatusText(wsStatus),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.chat), label: '消息'),
              BottomNavigationBarItem(icon: Icon(Icons.people), label: '好友'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
            ],
          ),
        ],
      ),
    );
  }

  String _wsStatusText(WsConnectionStatus status) {
    switch (status) {
      case WsConnectionStatus.connecting:
        return '实时连接中...';
      case WsConnectionStatus.reconnecting:
        return '实时连接已断开，正在重连...';
      case WsConnectionStatus.failed:
        return '实时连接失败，请检查网络或重新登录';
      case WsConnectionStatus.disconnected:
        return '实时连接未建立';
      case WsConnectionStatus.connected:
        return '实时连接正常';
    }
  }

  Color _wsStatusColor(WsConnectionStatus status) {
    switch (status) {
      case WsConnectionStatus.failed:
        return Colors.red;
      case WsConnectionStatus.reconnecting:
      case WsConnectionStatus.connecting:
        return Colors.orange;
      case WsConnectionStatus.disconnected:
        return Colors.grey;
      case WsConnectionStatus.connected:
        return Colors.green;
    }
  }

  void _handleWsStatusTransition(WsConnectionStatus current) {
    final previous = _previousWsStatus;
    _previousWsStatus = current;

    final recovered = current == WsConnectionStatus.connected &&
        (previous == WsConnectionStatus.reconnecting || previous == WsConnectionStatus.failed);
    if (!recovered) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('实时连接已恢复'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }
}
