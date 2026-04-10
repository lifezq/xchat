import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'websocket_service.dart';

class AuthService extends ChangeNotifier {
  static const Duration _startupAuthTimeout = Duration(seconds: 2);
  final ApiService _apiService = ApiService();
  late final WebSocketService _wsService = WebSocketService(_apiService);
  
  User? _currentUser;
  bool _isLoading = false;
  String? _lastError;
  WsConnectionStatus _wsConnectionStatus = WsConnectionStatus.disconnected;

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
}
