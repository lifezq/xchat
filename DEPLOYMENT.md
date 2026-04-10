# 部署指南

## 后端部署

### 使用 Docker Compose (推荐)

1. 进入后端目录：
```bash
cd backend
```

2. 创建环境变量文件：
```bash
cp .env.example .env
```

3. 编辑 `.env` 文件，修改配置：
```env
DB_HOST=mysql
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_secure_password
DB_NAME=chat_db

REDIS_HOST=redis
REDIS_PORT=6379

JWT_SECRET=your_very_secure_secret_key
SERVER_PORT=:8080
```

4. 启动所有服务：
```bash
docker-compose up -d
```

5. 查看日志：
```bash
docker-compose logs -f backend
```

6. 停止服务：
```bash
docker-compose down
```

### 手动部署

#### 1. 安装依赖

- Go 1.21+
- MySQL 8.0+
- Redis 7+

#### 2. 配置 MySQL

```sql
CREATE DATABASE chat_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'chatuser'@'%' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON chat_db.* TO 'chatuser'@'%';
FLUSH PRIVILEGES;
```

#### 3. 配置环境变量

```bash
export DB_HOST=localhost
export DB_PORT=3306
export DB_USER=chatuser
export DB_PASSWORD=your_password
export DB_NAME=chat_db
export REDIS_HOST=localhost
export REDIS_PORT=6379
export JWT_SECRET=your_secret_key
export SERVER_PORT=:8080
```

#### 4. 编译运行

```bash
cd backend
go mod download
go build -o main .
./main
```

#### 5. 使用 systemd 管理服务

创建 `/etc/systemd/system/chat-backend.service`：

```ini
[Unit]
Description=Chat Backend Service
After=network.target mysql.service redis.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/chat-backend
ExecStart=/opt/chat-backend/main
Restart=always
Environment="DB_HOST=localhost"
Environment="DB_PORT=3306"
Environment="DB_USER=chatuser"
Environment="DB_PASSWORD=your_password"
Environment="DB_NAME=chat_db"
Environment="REDIS_HOST=localhost"
Environment="REDIS_PORT=6379"
Environment="JWT_SECRET=your_secret_key"
Environment="SERVER_PORT=:8080"

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable chat-backend
sudo systemctl start chat-backend
sudo systemctl status chat-backend
```

## 前端部署

### Android

1. 修改 API 地址：

编辑 `flutter-app/lib/services/api_service.dart`：
```dart
static const String baseUrl = 'https://your-domain.com/api';
```

编辑 `flutter-app/lib/services/websocket_service.dart`：
```dart
static const String wsUrl = 'wss://your-domain.com/api/ws';
```

2. 构建 APK：
```bash
cd flutter-app
flutter build apk --release
```

3. 构建 App Bundle (推荐用于 Google Play)：
```bash
flutter build appbundle --release
```

输出文件位置：
- APK: `flutter-app/build/app/outputs/flutter-apk/app-release.apk`
- AAB: `flutter-app/build/app/outputs/bundle/release/app-release.aab`

### iOS

1. 修改 API 地址（同 Android）

2. 配置签名：
- 在 Xcode 中打开 `flutter-app/ios/Runner.xcworkspace`
- 选择 Runner target
- 在 Signing & Capabilities 中配置开发者账号

3. 构建 IPA：
```bash
cd flutter-app
flutter build ios --release
```

4. 在 Xcode 中 Archive 并上传到 App Store

## Nginx 配置

### HTTP 配置

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location /api/ {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /uploads/ {
        proxy_pass http://localhost:8080;
    }
}
```

### HTTPS 配置 (使用 Let's Encrypt)

1. 安装 Certbot：
```bash
sudo apt install certbot python3-certbot-nginx
```

2. 获取证书：
```bash
sudo certbot --nginx -d your-domain.com
```

3. Nginx 配置会自动更新为 HTTPS

## 性能优化

### 后端优化

1. 启用 Gzip 压缩：
```go
import "github.com/gin-contrib/gzip"

r.Use(gzip.Gzip(gzip.DefaultCompression))
```

2. 配置数据库连接池：
```go
sqlDB.SetMaxIdleConns(10)
sqlDB.SetMaxOpenConns(100)
sqlDB.SetConnMaxLifetime(time.Hour)
```

3. Redis 缓存策略：
- 缓存用户信息
- 缓存好友列表
- 缓存最近消息

### 前端优化

1. 启用代码混淆：
```bash
flutter build apk --obfuscate --split-debug-info=build/debug-info
```

2. 图片优化：
- 使用 WebP 格式
- 实现图片懒加载
- 压缩上传图片

## 监控和日志

### 后端日志

使用 logrus 或 zap 进行结构化日志：

```go
import "github.com/sirupsen/logrus"

logrus.SetFormatter(&logrus.JSONFormatter{})
logrus.SetLevel(logrus.InfoLevel)
```

### 监控工具

- Prometheus + Grafana
- ELK Stack (Elasticsearch + Logstash + Kibana)
- Sentry (错误追踪)

## 备份策略

### MySQL 备份

```bash
# 每天凌晨 2 点备份
0 2 * * * mysqldump -u root -p'password' chat_db > /backup/chat_db_$(date +\%Y\%m\%d).sql
```

### Redis 备份

Redis 会自动生成 dump.rdb 文件，定期备份该文件即可。

## 安全建议

1. 使用强密码和复杂的 JWT Secret
2. 启用 HTTPS
3. 配置防火墙规则
4. 定期更新依赖包
5. 实施 API 速率限制
6. 启用 SQL 注入防护
7. 验证所有用户输入
8. 定期备份数据

## 故障排查

### 后端无法启动

1. 检查端口是否被占用：
```bash
lsof -i :8080
```

2. 检查数据库连接：
```bash
mysql -h localhost -u chatuser -p
```

3. 检查 Redis 连接：
```bash
redis-cli ping
```

### WebSocket 连接失败

1. 检查 Nginx 配置是否支持 WebSocket
2. 确认防火墙允许 WebSocket 连接
3. 检查 JWT Token 是否有效

### 前端无法连接后端

1. 检查 API 地址配置
2. 确认后端服务正常运行
3. 检查网络连接
4. 查看浏览器控制台错误信息
