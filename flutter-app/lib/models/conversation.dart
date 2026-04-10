import 'user.dart';
import 'message.dart';

class Conversation {
  final String id;
  final User otherUser;
  final Message? lastMessage;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
  });
}
