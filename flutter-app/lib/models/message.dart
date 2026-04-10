enum MessageType { text, voice }

enum MessageStatus { sent, delivered, read }

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final String? voiceUrl;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final MessageStatus status;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.voiceUrl,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.status = MessageStatus.sent,
    this.deliveredAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      senderId: json['senderId'].toString(),
      receiverId: json['receiverId'].toString(),
      content: json['content'],
      voiceUrl: json['voiceUrl'],
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${json['type']}',
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${json['status'] ?? 'sent'}',
        orElse: () => (json['isRead'] == true ? MessageStatus.read : MessageStatus.sent),
      ),
      deliveredAt: json['deliveredAt'] != null ? DateTime.tryParse(json['deliveredAt']) : null,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'voiceUrl': voiceUrl,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'status': status.toString().split('.').last,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }
}
