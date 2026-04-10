# 快速开始指南

## 5 分钟快速体验

### 1. 启动后端 (使用 Docker)

```bash
cd backend
docker-compose up -d
```

等待 30 秒让服务完全启动。

### 2. 运行前端

```bash
cd flutter-app

# 安装依赖
flutter pub get

# 运行应用
flutter run
```

### 3. 测试应用

1. 注册两个账号：
   - 账号 A: `alice@test.com` / `password123` / `Alice`
   - 账号 B: `bob@test.com` / `password123` / `Bob`

2. 使用账号 A 登录，添加好友 `bob@test.com`

3. 开始聊天：
   - 发送文字消息
   - 长按麦克风按钮录制语音消息

4. 使用账号 B 登录另一台设备，查看实时消息推送

## 本地开发（不使用 Docker）

### 后端

1. 安装 MySQL 和 Redis

2. 创建数据库：
```sql
CREATE DATABASE chat_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

3. 配置环境变量：
```bash
cd backend
cp .env.example .env
# 编辑 .env 文件
```

4. 运行：
```bash
go mod download
go run main.go
```

### 前端

1. 修改 API 地址（如果后端不在 localhost:8080）：

`flutter-app/lib/services/api_service.dart`:
```dart
static const String baseUrl = 'http://YOUR_IP:8080/api';
```

`flutter-app/lib/services/websocket_service.dart`:
```dart
static const String wsUrl = 'ws://YOUR_IP:8080/api/ws';
```

2. 运行：
```bash
cd flutter-app
flutter pub get
flutter run
```

## 常见问题

### Q: 后端启动失败
A: 检查 MySQL 和 Redis 是否正常运行：
```bash
docker-compose ps
```

### Q: 前端无法连接后端
A: 
1. 确认后端正常运行：`curl http://localhost:8080/api/auth/login`
2. 检查防火墙设置
3. 如果使用真机测试，确保手机和电脑在同一网络

### Q: WebSocket 连接失败
A: 检查 JWT Token 是否有效，尝试重新登录

### Q: 语音消息无法录制
A: 
1. Android: 检查麦克风权限
2. iOS: 在 Info.plist 中添加麦克风权限说明

## 下一步

- 查看 [README.md](README.md) 了解完整功能
- 查看 [DEPLOYMENT.md](DEPLOYMENT.md) 了解生产环境部署
- 查看 [backend/README.md](backend/README.md) 了解 API 文档

## 技术支持

遇到问题？
1. 检查日志：`docker-compose logs -f backend`
2. 查看 Issues
3. 提交新 Issue
