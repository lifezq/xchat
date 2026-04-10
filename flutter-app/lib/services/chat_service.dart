import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'local_storage_service.dart';

class ChatService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalStorageService _localStorage = LocalStorageService();

  List<User> _friends = [];
  final Map<String, List<Message>> _messagesCache = {};
  final Set<String> _loadingChats = {};

  List<User> get friends => _friends;

  Future<void> loadFriends() async {
    try {
      _friends = await _apiService.getFriends();
      notifyListeners();
    } catch (e) {
      debugPrint('加载好友列表失败: $e');
    }
  }

  List<Conversation> getConversations(String currentUserId) {
    final conversations = <Conversation>[];

    for (final friend in _friends) {
      final chatKey = _getChatKey(currentUserId, friend.id);
      final messages = _messagesCache[chatKey] ?? [];
      final unreadCount = messages
          .where((m) => m.receiverId == currentUserId && !m.isRead)
          .length;

      conversations.add(
        Conversation(
          id: chatKey,
          otherUser: friend,
          lastMessage: messages.isNotEmpty ? messages.last : null,
          unreadCount: unreadCount,
        ),
      );
    }

    conversations.sort((a, b) {
      final aTime = a.lastMessage?.timestamp ?? DateTime(2000);
      final bTime = b.lastMessage?.timestamp ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    return conversations;
  }

  List<Message> getMessages(String userId1, String userId2) {
    final chatKey = _getChatKey(userId1, userId2);
    return _messagesCache[chatKey] ?? [];
  }

  Future<void> loadMessages(String userId1, String userId2) async {
    final chatKey = _getChatKey(userId1, userId2);
    if (_loadingChats.contains(chatKey)) {
      return;
    }

    _loadingChats.add(chatKey);
    try {
      final localMessages = await _localStorage.getMessages(userId1, userId2);
      final receiverId = int.tryParse(userId2);
      final remoteMessages = receiverId == null
          ? <Message>[]
          : await _apiService.getMessages(receiverId);

      final merged = <String, Message>{};
      for (final m in [...localMessages, ...remoteMessages]) {
        merged[m.id] = m;
      }

      final messages = merged.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _messagesCache[chatKey] = messages;

      for (final message in messages) {
        await _localStorage.saveMessage(message);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('获取消息失败: $e');
    } finally {
      _loadingChats.remove(chatKey);
    }
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    required MessageType type,
    String? voiceUrl,
  }) async {
    final receiver = int.tryParse(receiverId);
    if (receiver == null) {
      debugPrint('发送消息失败: receiverId 不是数字: $receiverId');
      return;
    }

    try {
      final message = await _apiService.sendMessage(
        receiver,
        content,
        type,
        voiceUrl: voiceUrl,
      );

      await _localStorage.saveMessage(message);

      final chatKey = _getChatKey(senderId, receiverId);
      _messagesCache[chatKey] = [...(_messagesCache[chatKey] ?? []), message]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      notifyListeners();
    } catch (e) {
      debugPrint('发送消息失败: $e');
    }
  }

  Future<bool> addFriend(String email) async {
    try {
      final friend = await _apiService.addFriend(email);
      await _localStorage.saveUser(friend);

      final exists = _friends.any((f) => f.id == friend.id);
      if (!exists) {
        _friends.add(friend);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('添加好友失败: $e');
      return false;
    }
  }

  void markAsRead(String currentUserId, String otherUserId) {
    final chatKey = _getChatKey(currentUserId, otherUserId);
    final messages = _messagesCache[chatKey];

    if (messages == null) {
      return;
    }

    var changed = false;
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].receiverId == currentUserId && !messages[i].isRead) {
        messages[i] = Message(
          id: messages[i].id,
          senderId: messages[i].senderId,
          receiverId: messages[i].receiverId,
          content: messages[i].content,
          voiceUrl: messages[i].voiceUrl,
          type: messages[i].type,
          timestamp: messages[i].timestamp,
          isRead: true,
        );
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  String _getChatKey(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}
