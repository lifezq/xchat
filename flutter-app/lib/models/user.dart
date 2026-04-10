class User {
  final String id;
  final String email;
  final String nickname;
  final String? avatar;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.nickname,
    this.avatar,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      email: json['email'],
      nickname: json['nickname'],
      avatar: json['avatar'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'avatar': avatar,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
