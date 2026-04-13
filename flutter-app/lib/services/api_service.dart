import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/message.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://172.16.20.95:8090/api',
  );
  static const String _keyAccessToken = 'accessToken';
  static const String _keyLegacyToken = 'token';
  static const String _keyRefreshToken = 'refreshToken';
  static const String _keyCurrentSessionUserId = 'currentSessionUserId';
  static const String _keyAccountSessions = 'accountSessions';
  
  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_keyAccessToken) ?? prefs.getString(_keyLegacyToken);
    _refreshToken = prefs.getString(_keyRefreshToken);
  }

  Future<void> saveTokens(String accessToken, {String? refreshToken}) async {
    _accessToken = accessToken;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLegacyToken, accessToken);
    await prefs.setString(_keyAccessToken, accessToken);
    if (_refreshToken != null) {
      await prefs.setString(_keyRefreshToken, _refreshToken!);
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLegacyToken);
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyCurrentSessionUserId);
  }

  Future<Map<String, dynamic>> _loadSessions(SharedPreferences prefs) async {
    final raw = prefs.getString(_keyAccountSessions);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return _asMap(decoded);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> saveAccountSession(User user) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final sessions = await _loadSessions(prefs);
    sessions[user.id] = <String, dynamic>{
      'userId': user.id,
      'phone': user.phone,
      'phoneMasked': user.phoneMasked ?? user.phone,
      'nickname': user.nickname,
      'accessToken': token,
      'refreshToken': _refreshToken ?? '',
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_keyAccountSessions, jsonEncode(sessions));
    await prefs.setString(_keyCurrentSessionUserId, user.id);
  }

  Future<List<Map<String, dynamic>>> getSavedAccountSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await _loadSessions(prefs);
    final list = sessions.values.map((e) => _asMap(e)).toList();
    list.sort((a, b) {
      final aTime = DateTime.tryParse(a['updatedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(b['updatedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return list;
  }

  Future<bool> activateAccountSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await _loadSessions(prefs);
    final target = _asMap(sessions[userId]);
    final accessToken = target['accessToken']?.toString() ?? '';
    if (accessToken.isEmpty) return false;

    final refreshToken = target['refreshToken']?.toString();
    await saveTokens(accessToken, refreshToken: refreshToken);
    await prefs.setString(_keyCurrentSessionUserId, userId);
    return true;
  }

  Future<void> removeAccountSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await _loadSessions(prefs);
    sessions.remove(userId);
    await prefs.setString(_keyAccountSessions, jsonEncode(sessions));
    final currentUserId = prefs.getString(_keyCurrentSessionUserId);
    if (currentUserId == userId) {
      await prefs.remove(_keyCurrentSessionUserId);
    }
  }

  Map<String, String> _getHeaders({bool withAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (withAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<http.Response> _withAutoRefresh(Future<http.Response> Function() request) async {
    var response = await request();
    if (response.statusCode != 401) {
      return response;
    }

    final refreshed = await refreshAccessToken();
    if (!refreshed) {
      return response;
    }
    response = await request();
    return response;
  }

  String _extractError(http.Response response, String fallback) {
    try {
      final body = _decodeBody(response.body);
      if (body is Map) {
        if (body['message'] != null) return body['message'].toString();
        if (body['error'] != null) return body['error'].toString();
      }
    } catch (_) {}
    return '$fallback(${response.statusCode})';
  }

  dynamic _decodeBody(String body) {
    return jsonDecode(body);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _payloadMap(dynamic decoded) {
    final root = _asMap(decoded);
    final data = root['data'];
    if (data is Map) {
      return _asMap(data);
    }
    return root;
  }

  dynamic _payloadField(dynamic decoded, String key) {
    final payload = _payloadMap(decoded);
    if (payload.containsKey(key)) return payload[key];
    final root = _asMap(decoded);
    return root[key];
  }

  // 认证相关
  Future<Map<String, dynamic>> register(String phone, String password, String nickname) async {
    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
          'nickname': nickname,
        }),
      );
    } on SocketException {
      throw Exception('无法连接后端: $baseUrl（真机请使用电脑局域网 IP）');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _asMap(_decodeBody(response.body));
    } else {
      final error = _extractError(response, '注册失败');
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = _decodeBody(response.body);
      final payload = _payloadMap(data);

      final token = (payload['accessToken'] ?? payload['access_token'] ?? payload['token'])?.toString();
      final refresh = (payload['refreshToken'] ?? payload['refresh_token'])?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('登录响应缺少 access token');
      }
      await saveTokens(token, refreshToken: refresh);
      return _asMap(data);
    } else {
      throw Exception(_extractError(response, '登录失败'));
    }
  }

  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return false;
    }

    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: _getHeaders(withAuth: false),
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
    } on SocketException {
      return false;
    }

    if (response.statusCode != 200) {
      return false;
    }

    final data = _decodeBody(response.body);
    final payload = _payloadMap(data);
    final token = (payload['accessToken'] ?? payload['access_token'] ?? payload['token'])?.toString();
    final refresh = (payload['refreshToken'] ?? payload['refresh_token'])?.toString();
    if (token == null || token.isEmpty) {
      return false;
    }
    await saveTokens(token, refreshToken: refresh);
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString(_keyCurrentSessionUserId);
    if (currentUserId != null && currentUserId.isNotEmpty) {
      final sessions = await _loadSessions(prefs);
      final session = _asMap(sessions[currentUserId]);
      if (session.isNotEmpty) {
        session['accessToken'] = token;
        session['refreshToken'] = refresh ?? '';
        session['updatedAt'] = DateTime.now().toIso8601String();
        sessions[currentUserId] = session;
        await prefs.setString(_keyAccountSessions, jsonEncode(sessions));
      }
    }
    return true;
  }

  Future<void> logout() async {
    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: _getHeaders(),
          body: jsonEncode({'refresh_token': _refreshToken}),
        );
      } catch (_) {}
    }
    await clearTokens();
  }

  // 用户相关
  Future<User> getCurrentUser() async {
    final response = await _withAutoRefresh(() => http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: _getHeaders(),
    ));

    if (response.statusCode == 200) {
      final data = _decodeBody(response.body);
      return User.fromJson(_asMap(_payloadField(data, 'user')));
    } else {
      throw Exception(_extractError(response, '获取用户信息失败'));
    }
  }

  Future<User> searchUser(String phone) async {
    final response = await _withAutoRefresh(() => http.get(
      Uri.parse('$baseUrl/friends/search?phone=$phone'),
      headers: _getHeaders(),
    ));

    if (response.statusCode == 200) {
      final data = _decodeBody(response.body);
      return User.fromJson(_asMap(_payloadField(data, 'user')));
    } else {
      throw Exception(_extractError(response, '用户不存在'));
    }
  }

  // 好友相关
  Future<List<User>> getFriends() async {
    final response = await _withAutoRefresh(() => http.get(
      Uri.parse('$baseUrl/friends'),
      headers: _getHeaders(),
    ));

    if (response.statusCode == 200) {
      final data = _decodeBody(response.body);
      final friends = _payloadField(data, 'friends') as List;
      return friends.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception(_extractError(response, '获取好友列表失败'));
    }
  }

  Future<User> addFriend(String phone) async {
    final response = await _withAutoRefresh(() => http.post(
      Uri.parse('$baseUrl/friends/add-by-phone'),
      headers: _getHeaders(),
      body: jsonEncode({'phone': phone}),
    ));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = _decodeBody(response.body);
      return User.fromJson(_asMap(_payloadField(data, 'friend')));
    } else {
      throw Exception(_extractError(response, '添加好友失败'));
    }
  }

  // 消息相关
  Future<List<Message>> getMessages(int friendId, {int limit = 50, int offset = 0}) async {
    final response = await _withAutoRefresh(() => http.get(
      Uri.parse('$baseUrl/messages/$friendId?limit=$limit&offset=$offset'),
      headers: _getHeaders(),
    ));

    if (response.statusCode == 200) {
      final data = _decodeBody(response.body);
      final messages = _payloadField(data, 'messages') as List;
      return messages.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception(_extractError(response, '获取消息失败'));
    }
  }

  Future<Message> sendMessage(int receiverId, String content, MessageType type, {String? voiceUrl}) async {
    final response = await _withAutoRefresh(() => http.post(
      Uri.parse('$baseUrl/messages'),
      headers: _getHeaders(),
      body: jsonEncode({
        'receiverId': receiverId,
        'content': content,
        'type': type.toString().split('.').last,
        if (voiceUrl != null) 'voiceUrl': voiceUrl,
      }),
    ));

    if (response.statusCode == 201) {
      final data = _decodeBody(response.body);
      return Message.fromJson(_asMap(_payloadField(data, 'message')));
    } else {
      throw Exception(_extractError(response, '发送消息失败'));
    }
  }

  Future<void> markMessagesRead(int peerId, {int? readUptoMessageId}) async {
    final response = await _withAutoRefresh(() => http.post(
      Uri.parse('$baseUrl/messages/read'),
      headers: _getHeaders(),
      body: jsonEncode({
        'peerId': peerId,
        if (readUptoMessageId != null) 'readUptoMessageId': readUptoMessageId,
      }),
    ));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response, '更新已读状态失败'));
    }
  }

  Future<List<dynamic>> getConversations() async {
    final response = await _withAutoRefresh(() => http.get(
      Uri.parse('$baseUrl/conversations'),
      headers: _getHeaders(),
    ));

    if (response.statusCode == 200) {
      final data = _decodeBody(response.body);
      return _payloadField(data, 'conversations') as List<dynamic>;
    } else {
      throw Exception(_extractError(response, '获取会话列表失败'));
    }
  }

  // 文件上传（语音）
  Future<String> uploadVoice(File file) async {
    Future<http.StreamedResponse> sendOnce() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/voice'),
      );
      request.headers.addAll(_getHeaders());
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      return request.send();
    }

    var response = await sendOnce();
    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await sendOnce();
      }
    }

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final data = _decodeBody(responseData);
      final url = (_payloadField(data, 'url') ?? '').toString();
      if (url.isEmpty) {
        throw Exception('上传语音失败(响应缺少url)');
      }
      return url;
    } else {
      throw Exception('上传语音失败(${response.statusCode})');
    }
  }

  // 文件上传（图片/视频/文件）
  Future<String> uploadFile(File file) async {
    Future<http.StreamedResponse> sendOnce() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/file'),
      );
      request.headers.addAll(_getHeaders());
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      return request.send();
    }

    var response = await sendOnce();
    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await sendOnce();
      }
    }

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final data = _decodeBody(responseData);
      final url = (_payloadField(data, 'url') ?? '').toString();
      if (url.isEmpty) {
        throw Exception('上传文件失败(响应缺少url)');
      }
      return url;
    } else {
      throw Exception('上传文件失败(${response.statusCode})');
    }
  }
}
