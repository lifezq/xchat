import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'websocket_service.dart';

class SavedAccount {
  final String userId;
  final String phone;
  final String phoneMasked;
  final String nickname;
  final DateTime updatedAt;

  SavedAccount({
    required this.userId,
    required this.phone,
    required this.phoneMasked,
    required this.nickname,
    required this.updatedAt,
  });
}

class AuthService extends ChangeNotifier {
  static const Duration _startupAuthTimeout = Duration(seconds: 2);
  final ApiService _apiService = ApiService();
  late final WebSocketService _wsService = WebSocketService(_apiService);
  
  User? _currentUser;
  bool _isLoading = false;
  String? _lastError;
  WsConnectionStatus _wsConnectionStatus = WsConnectionStatus.disconnected;
  List<SavedAccount> _savedAccounts = <SavedAccount>[];

  AuthService() {
    _wsService.onConnectionChanged = (status) {
      _wsConnectionStatus = status;
      notifyListeners();
    };
  }

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  WebSocketService get wsService => _wsService;
  String? get lastError => _lastError;
  WsConnectionStatus get wsConnectionStatus => _wsConnectionStatus;
  List<SavedAccount> get savedAccounts => _savedAccounts;

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.loadTokens();
      final token = _apiService.accessToken;
      if (token == null || token.isEmpty) {
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentUser = await _apiService
          .getCurrentUser()
          .timeout(_startupAuthTimeout);
      await _apiService.saveAccountSession(_currentUser!);
      await loadSavedAccounts();

      _wsService.connect();
    } on TimeoutException {
      _lastError = '连接服务器超时';
      _currentUser = null;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      _currentUser = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSavedAccounts() async {
    final sessions = await _apiService.getSavedAccountSessions();
    _savedAccounts = sessions.map((s) {
      return SavedAccount(
        userId: s['userId']?.toString() ?? '',
        phone: s['phone']?.toString() ?? '',
        phoneMasked: s['phoneMasked']?.toString() ?? '',
        nickname: s['nickname']?.toString() ?? '',
        updatedAt: DateTime.tryParse(s['updatedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    }).where((a) => a.userId.isNotEmpty).toList();
    notifyListeners();
  }

  Future<bool> register(String phone, String password, String nickname) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      await _apiService.register(phone, password, nickname);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final data = await _apiService.login(phone, password);
      final payload = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data;
      final userJson = payload['user'] ?? data['user'];
      _currentUser = User.fromJson(userJson);
      await _apiService.saveAccountSession(_currentUser!);
      await loadSavedAccounts();

      final token = (_apiService.accessToken ?? payload['accessToken'] ?? data['token'])?.toString();
      if (token != null && token.isNotEmpty) {
        _wsService.connect();
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _wsService.disconnect();
    await _apiService.logout();
    
    _currentUser = null;
    notifyListeners();
  }

  Future<void> switchAccount() async {
    _wsService.disconnect();
    await _apiService.clearTokens();
    _currentUser = null;
    _lastError = null;
    notifyListeners();
  }

  Future<bool> switchToSavedAccount(String userId) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    _wsService.disconnect();
    final activated = await _apiService.activateAccountSession(userId);
    if (!activated) {
      _isLoading = false;
      _lastError = '该账号会话无效，请重新登录';
      notifyListeners();
      return false;
    }

    try {
      _currentUser = await _apiService
          .getCurrentUser()
          .timeout(_startupAuthTimeout);
      await _apiService.saveAccountSession(_currentUser!);
      await loadSavedAccounts();
      _wsService.connect();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      await _apiService.removeAccountSession(userId);
      await _apiService.clearTokens();
      _currentUser = null;
      _isLoading = false;
      _lastError = '该账号登录已失效，请重新登录';
      notifyListeners();
      return false;
    }
  }

  Future<void> removeSavedAccount(String userId) async {
    await _apiService.removeAccountSession(userId);
    if (_currentUser?.id == userId) {
      _wsService.disconnect();
      await _apiService.clearTokens();
      _currentUser = null;
    }
    await loadSavedAccounts();
    notifyListeners();
  }
}
