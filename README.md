# 聊天应用

一个功能完整的跨平台移动聊天应用，支持 Android 和 iOS。

## 项目结构

```
.
├── flutter-app/         # Flutter 前端项目
├── backend/             # Golang 后端项目
├── README.md            # 项目总览
├── QUICKSTART.md        # 快速开始指南
└── DEPLOYMENT.md        # 部署指南
```

## 功能特性

### 前端 (Flutter)
- 📧 邮箱注册/登录
- 👥 添加好友
- 💬 实时文字聊天
- 🎤 语音消息
- 🔔 未读消息提示
- 💾 本地消息持久化
- 🔄 WebSocket 实时通信
- 👤 个人资料管理

### 后端 (Golang)
- 🔐 JWT 身份认证
- 🗄️ MySQL 数据持久化
- ⚡ Redis 缓存
- 🔌 WebSocket 实时推送
- 📁 文件上传（语音）
- 🐳 Docker 容器化部署

## 技术栈

### 前端
- Flutter 3.0+
- Provider (状态管理)
- SQLite (本地存储)
- WebSocket (实时通信)
- Record & AudioPlayers (语音功能)

### 后端
- Golang 1.21+
- Gin Web Framework
- GORM + MySQL
- Redis
- Gorilla WebSocket
- JWT

## 快速开始

### 1. 启动后端

```bash
cd backend
docker-compose up -d
```

### 2. 运行前端

```bash
cd flutter-app
flutter pub get
flutter run
```

详细说明请查看 [QUICKSTART.md](QUICKSTART.md)

## 详细结构

### 后端 (backend/)
```
backend/
├── config/             # 配置
├── handlers/           # HTTP 处理器
├── middleware/         # 中间件
├── models/             # 数据模型
├── services/           # 业务逻辑
├── main.go             # 入口文件
├── Dockerfile
└── docker-compose.yml
```

### 前端 (flutter-app/)
```
flutter-app/
├── lib/
│   ├── models/         # 数据模型
│   ├── services/       # 服务层
│   ├── screens/        # 页面
│   ├── widgets/        # 组件
│   └── main.dart
├── android/            # Android 配置
├── ios/                # iOS 配置
└── pubspec.yaml        # 依赖配置
```

## API 文档

详见 [backend/README.md](backend/README.md)

## 功能说明

### 1. 用户认证
- 邮箱注册（需验证邮箱格式）
- 邮箱登录
- JWT Token 认证
- 自动登录状态保持

### 2. 好友管理
- 通过邮箱搜索添加好友
- 好友列表展示
- 双向好友关系

### 3. 消息功能
- 文字消息发送/接收
- 语音消息录制/播放
- 消息已读/未读状态
- 消息本地持久化
- WebSocket 实时推送

### 4. 会话列表
- 显示最后一条消息
- 未读消息数量提示
- 按时间排序

## 权限配置

### Android (android/app/src/main/AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### iOS (ios/Runner/Info.plist)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限以录制语音消息</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以发送图片</string>
```

## 开发计划

- [ ] 图片消息
- [ ] 视频通话
- [ ] 群聊功能
- [ ] 消息撤回
- [ ] 表情包
- [ ] 消息转发
- [ ] 朋友圈

## 许可证

MIT License
