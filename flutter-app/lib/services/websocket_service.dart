import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message.dart';
import 'api_service.dart';

enum WsConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class WebSocketService {
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://172.16.20.95:8090/api/ws',
  );

  final ApiService _apiService;
  WebSocketService(this._apiService);
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;
  bool _isConnecting = false;

  Function(Message)? onMessageReceived;
  Function(WsConnectionStatus)? onConnectionChanged;

  bool get isConnected => _channel != null;

  void _setStatus(WsConnectionStatus status) {
    onConnectionChanged?.call(status);
  }

  Future<void> connect() async {
    _manualDisconnect = false;
    _setStatus(WsConnectionStatus.connecting);
    await _connectInternal();
  }

  Future<void> _connectInternal() async {
    if (_manualDisconnect || _isConnecting) return;
    _isConnecting = true;
    _reconnectTimer?.cancel();

    try {
      var token = _apiService.accessToken;
      if (token == null || token.isEmpty) {
        final refreshed = await _apiService.refreshAccessToken();
        if (!refreshed) {
          _setStatus(WsConnectionStatus.failed);
          return;
        }
        token = _apiService.accessToken;
      }
      if (token == null || token.isEmpty) {
        _setStatus(WsConnectionStatus.failed);
        return;
      }

      _subscription?.cancel();
      _channel?.sink.close();
      final uri = Uri.parse('$wsUrl?token=$token');
      // 移动端优先走 Authorization 头，query token 作为兜底，提升与后端鉴权兼容性。
      if (kIsWeb) {
        _channel = WebSocketChannel.connect(uri);
      } else {
        _channel = IOWebSocketChannel.connect(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        );
      }

      _subscription = _channel!.stream.listen(
        (data) {
          final json = jsonDecode(data);
          if (onMessageReceived != null) {
            final message = Message.fromJson(json);
            onMessageReceived!(message);
          }
        },
        onError: (error) {
          debugPrint('WebSocket 错误: $error');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WebSocket 连接关闭');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _reconnectAttempts = 0;
      _setStatus(WsConnectionStatus.connected);
    } catch (e) {
      debugPrint('WebSocket 连接失败: $e');
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _setStatus(WsConnectionStatus.reconnecting);

    _reconnectAttempts += 1;
    final seconds = (_reconnectAttempts > 5 ? 5 : _reconnectAttempts);
    final delay = Duration(seconds: seconds);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      final refreshed = await _apiService.refreshAccessToken();
      if (!refreshed && (_apiService.accessToken == null || _apiService.accessToken!.isEmpty)) {
        _setStatus(WsConnectionStatus.failed);
        return;
      }
      await _connectInternal();
    });
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _setStatus(WsConnectionStatus.disconnected);
  }
}
