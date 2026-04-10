# 聊天应用 - Flutter 前端

一个基于 Flutter 开发的跨平台移动聊天应用，支持 Android 和 iOS。

## 功能特性

- 📧 邮箱注册/登录
- 👥 添加好友
- 💬 实时文字聊天
- 🎤 语音消息
- 🔔 未读消息提示
- 💾 本地消息持久化
- 🔄 WebSocket 实时通信
- 👤 个人资料管理

## 技术栈

- Flutter 3.0+
- Provider (状态管理)
- SQLite (本地存储)
- WebSocket (实时通信)
- Record & AudioPlayers (语音功能)

## 快速开始

### 1. 安装依赖

```bash
flutter pub get
```

### 2. 配置后端地址

编辑 `lib/services/api_service.dart`：
```dart
static const String baseUrl = 'http://172.16.20.95:8090/api';
```

编辑 `lib/services/websocket_service.dart`：
```dart
static const String wsUrl = 'ws://172.16.20.95:8090/api/ws';
```

如果使用真机测试，将 `localhost` 改为你的电脑 IP 地址。

### 3. 运行应用

```bash
flutter run
```

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── models/                # 数据模型
│   ├── user.dart
│   ├── message.dart
│   └── conversation.dart
├── services/              # 服务层
│   ├── api_service.dart           # HTTP API
│   ├── auth_service.dart          # 认证服务
│   ├── chat_service.dart          # 聊天服务
│   ├── websocket_service.dart     # WebSocket
│   ├── local_storage_service.dart # 本地存储
│   └── audio_service.dart         # 音频服务
├── screens/               # 页面
│   ├── auth/              # 认证相关
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/              # 主页相关
│   │   ├── home_screen.dart
│   │   ├── conversations_tab.dart
│   │   ├── friends_tab.dart
│   │   └── profile_tab.dart
│   ├── chat/              # 聊天相关
│   │   └── chat_screen.dart
│   └── splash_screen.dart
└── widgets/               # 可复用组件
    └── voice_message_widget.dart
```

## 构建发布版本

### Android

```bash
# APK
flutter build apk --release

# App Bundle (推荐用于 Google Play)
flutter build appbundle --release
```

输出文件：
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

### iOS

```bash
flutter build ios --release
```

然后在 Xcode 中 Archive 并上传到 App Store。

## 权限配置

### Android

已在 `android/app/src/main/AndroidManifest.xml` 中配置：
- 网络访问
- 麦克风录音
- 存储读写

### iOS

需要在 `ios/Runner/Info.plist` 中添加：
```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限以录制语音消息</string>
```

## 使用说明

1. 首次使用需要注册账号（邮箱 + 密码 + 昵称）
2. 登录后可以添加好友（通过邮箱）
3. 在好友列表点击好友开始聊天
4. 支持发送文字消息
5. 长按麦克风按钮录制语音消息

## 开发调试

### 查看日志

```bash
flutter logs
```

### 清理构建缓存

```bash
flutter clean
flutter pub get
```

### 运行测试

```bash
flutter test
```

## 常见问题

### Q: 无法连接后端
A: 
1. 确认后端服务正常运行
2. 检查 API 地址配置是否正确
3. 如果使用真机，确保手机和电脑在同一网络

### Q: WebSocket 连接失败
A: 检查 JWT Token 是否有效，尝试重新登录

### Q: 语音消息无法录制
A: 检查麦克风权限是否已授予

### Q: iOS 构建失败
A: 
1. 确保 Xcode 已安装
2. 运行 `pod install` 在 ios 目录下
3. 在 Xcode 中配置签名

## 相关文档

- [后端 API 文档](../backend/README.md)
- [部署指南](../DEPLOYMENT.md)
- [快速开始](../QUICKSTART.md)

## 技术支持

遇到问题？查看项目根目录的文档或提交 Issue。
