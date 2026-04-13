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
  List<Conversation> _conversations = [];
  String? _lastError;
  final Map<String, List<Message>> _messagesCache = {};
  final Set<String> _loadingChats = {};

  List<User> get friends => _friends;
  List<Conversation> get conversations => _conversations;
  String? get lastError => _lastError;

  void resetForAccountSwitch() {
    _friends = [];
    _conversations = [];
    _messagesCache.clear();
    _loadingChats.clear();
    _lastError = null;
    notifyListeners();
  }

  Future<void> loadFriends() async {
    try {
      _friends = await _apiService.getFriends();
      notifyListeners();
    } catch (e) {
      debugPrint('加载好友列表失败: $e');
    }
  }

  Future<void> loadConversations() async {
    try {
      final rawConversations = await _apiService.getConversations();
      final List<Conversation> parsed = rawConversations.map((item) {
        final map = _asMap(item);
        final otherUser = User.fromJson(_asMap(map['otherUser']));
        final lastMessageRaw = map['lastMessage'];
        final Message? lastMessage = lastMessageRaw == null
            ? null
            : Message.fromJson(_asMap(lastMessageRaw));
        final unreadCount = (map['unreadCount'] as num?)?.toInt() ?? 0;
        final currentUserId = lastMessage == null
            ? ''
            : (lastMessage.senderId == otherUser.id ? lastMessage.receiverId : lastMessage.senderId);
        final chatKey = currentUserId.isEmpty
            ? '${otherUser.id}_${otherUser.id}'
            : _getChatKey(currentUserId, otherUser.id);

        if (lastMessage != null) {
          final cached = List<Message>.from(_messagesCache[chatKey] ?? const <Message>[]);
          final exists = cached.any((m) => m.id == lastMessage.id);
          if (!exists) {
            cached.add(lastMessage);
            cached.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            _messagesCache[chatKey] = cached;
          }
        }

        return Conversation(
          id: chatKey,
          otherUser: otherUser,
          lastMessage: lastMessage,
          unreadCount: unreadCount,
        );
      }).toList();

      _conversations = parsed;
      notifyListeners();
    } catch (e) {
      debugPrint('加载会话列表失败: $e');
    }
  }

  List<Conversation> getConversations(String currentUserId) {
    if (_conversations.isNotEmpty) {
      return _conversations;
    }

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

  Future<void> handleIncomingMessage(Message message) async {
    final chatKey = _getChatKey(message.senderId, message.receiverId);
    final List<Message> messages =
        List<Message>.from(_messagesCache[chatKey] ?? const <Message>[]);
    final exists = messages.any((m) => m.id == message.id);
    if (!exists) {
      messages.add(message);
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _messagesCache[chatKey] = messages;
      await _localStorage.saveMessage(message);
      notifyListeners();
    }
  }

  void handleReadReceipt({
    required String readerId,
    required String readUptoMessageId,
    DateTime? readAt,
  }) {
    var changed = false;
    for (final entry in _messagesCache.entries) {
      final msgs = entry.value;
      for (var i = 0; i < msgs.length; i++) {
        final m = msgs[i];
        final mid = int.tryParse(m.id);
        final upto = int.tryParse(readUptoMessageId);
        if (mid == null || upto == null) continue;

        if (m.receiverId == readerId &&
            mid <= upto &&
            m.status != MessageStatus.read) {
          msgs[i] = Message(
            id: m.id,
            senderId: m.senderId,
            receiverId: m.receiverId,
            content: m.content,
            voiceUrl: m.voiceUrl,
            type: m.type,
            timestamp: m.timestamp,
            isRead: true,
            status: MessageStatus.read,
            deliveredAt: m.deliveredAt,
            readAt: readAt ?? DateTime.now(),
          );
          changed = true;
        }
      }
    }

    if (changed) {
      notifyListeners();
    }
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
      final List<Message> messages =
          List<Message>.from(_messagesCache[chatKey] ?? const <Message>[]);
      messages.add(message);
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _messagesCache[chatKey] = messages;

      notifyListeners();
    } catch (e) {
      debugPrint('发送消息失败: $e');
    }
  }

  Future<bool> addFriend(String phone) async {
    _lastError = null;
    try {
      final friend = await _apiService.addFriend(phone);
      await _localStorage.saveUser(friend);

      final exists = _friends.any((f) => f.id == friend.id);
      if (!exists) {
        _friends.add(friend);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
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
        final now = DateTime.now();
        messages[i] = Message(
          id: messages[i].id,
          senderId: messages[i].senderId,
          receiverId: messages[i].receiverId,
          content: messages[i].content,
          voiceUrl: messages[i].voiceUrl,
          type: messages[i].type,
          timestamp: messages[i].timestamp,
          isRead: true,
          status: MessageStatus.read,
          deliveredAt: messages[i].deliveredAt ?? now,
          readAt: now,
        );
        changed = true;
      }
    }

    if (changed) {
      for (var i = 0; i < _conversations.length; i++) {
        if (_conversations[i].otherUser.id == otherUserId) {
          _conversations[i] = Conversation(
            id: _conversations[i].id,
            otherUser: _conversations[i].otherUser,
            lastMessage: _conversations[i].lastMessage,
            unreadCount: 0,
          );
          break;
        }
      }
      notifyListeners();
    }
  }

  String _getChatKey(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
