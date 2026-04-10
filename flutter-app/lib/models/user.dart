class User {
  final String id;
  final String phone;
  final String? phoneMasked;
  final String nickname;
  final String? avatar;
  final DateTime createdAt;

  User({
    required this.id,
    required this.phone,
    this.phoneMasked,
    required this.nickname,
    this.avatar,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'] ?? json['created_at'];
    final masked = (json['phoneMasked'] ?? json['phone_masked'])?.toString();
    final rawPhone = (json['phone'] ?? '').toString();
    return User(
      id: json['id'].toString(),
      // friends/search 可能只返回脱敏手机号，回退使用 masked 防止空值破坏展示链路
      phone: rawPhone.isNotEmpty ? rawPhone : (masked ?? ''),
      phoneMasked: masked,
      nickname: json['nickname'],
      avatar: json['avatar'],
      createdAt: DateTime.tryParse((created ?? DateTime.now().toIso8601String()).toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'phoneMasked': phoneMasked,
      'nickname': nickname,
      'avatar': avatar,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
