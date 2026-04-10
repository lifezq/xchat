# 聊天应用后端

基于 Golang + Gin + MySQL + Redis 的聊天应用后端服务。

## 技术栈

- Golang 1.21+
- Gin Web Framework
- GORM (MySQL ORM)
- Redis (缓存)
- WebSocket (实时通信)
- JWT (身份认证)
- Viper (配置管理)

## 快速开始

### 1. 环境准备

确保已安装：
- Go 1.21+
- MySQL 8.0+
- Redis 7+

### 2. 配置文件

复制配置文件模板：

```bash
cp config.example.yaml config.yaml
```

编辑 `config.yaml` 修改配置：

```yaml
server:
  port: 8090
  mode: debug  # debug, release, test

database:
  host: localhost
  port: 3306
  user: root
  password: your_password
  dbname: chat_db

redis:
  host: localhost
  port: 6379

jwt:
  secret: your-secret-key
  expire_hours: 168
```

### 3. 创建数据库

```sql
CREATE DATABASE chat_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 4. 安装依赖

```bash
go mod download
```

### 5. 运行服务

```bash
go run main.go
```

服务将在 `http://localhost:8090` 启动。

## 使用 Docker

### 启动所有服务

```bash
docker-compose up -d
```

这将启动：
- MySQL (端口 3306)
- Redis (端口 6379)
- 后端服务 (端口 8090)

### 停止服务

```bash
docker-compose down
```

## 配置说明

### 配置文件优先级

1. 配置文件 (`config.yaml`)
2. 环境变量 (前缀 `CHAT_`)
3. 命令行参数

### 环境变量覆盖

可以通过环境变量覆盖配置文件中的设置：

```bash
export DB_HOST=localhost
export DB_PASSWORD=your_password
export JWT_SECRET=your_secret_key
go run main.go
```

### 配置文件位置

程序会按以下顺序查找配置文件：
1. 当前目录 (`./config.yaml`)
2. config 目录 (`./config/config.yaml`)
3. 系统配置目录 (`/etc/chat-backend/config.yaml`)

## API 文档

### 认证相关

#### 注册
```
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123",
  "nickname": "用户昵称"
}
```

#### 登录
```
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}

Response:
{
  "token": "jwt_token",
  "user": {...}
}
```

### 好友相关

#### 获取好友列表
```
GET /api/friends
Authorization: Bearer {token}
```

#### 添加好友
```
POST /api/friends
Authorization: Bearer {token}
Content-Type: application/json

{
  "friendEmail": "friend@example.com"
}
```

### 消息相关

#### 获取聊天记录
```
GET /api/messages/:friendId?limit=50&offset=0
Authorization: Bearer {token}
```

#### 发送消息
```
POST /api/messages
Authorization: Bearer {token}
Content-Type: application/json

{
  "receiverId": 2,
  "content": "消息内容",
  "type": "text"
}
```

#### 获取会话列表
```
GET /api/conversations
Authorization: Bearer {token}
```

### WebSocket

```
ws://localhost:8090/api/ws?token={jwt_token}
```

### 文件上传

#### 上传语音
```
POST /api/upload/voice
Authorization: Bearer {token}
Content-Type: multipart/form-data

file: (binary)
```

## 项目结构

```
backend/
├── config/          # 配置管理
│   └── config.go
├── handlers/        # HTTP 处理器
│   ├── auth_handler.go
│   ├── friend_handler.go
│   ├── message_handler.go
│   ├── user_handler.go
│   ├── websocket_handler.go
│   └── upload_handler.go
├── middleware/      # 中间件
│   ├── auth.go
│   └── cors.go
├── models/          # 数据模型
│   └── models.go
├── services/        # 业务逻辑
│   ├── auth_service.go
│   ├── chat_service.go
│   └── websocket.go
├── main.go          # 入口文件
├── config.yaml      # 配置文件
├── Dockerfile       # Docker 配置
└── docker-compose.yml
```

## 开发工具

### 使用 Makefile

```bash
# 编译
make build

# 运行
make run

# 测试
make test

# 清理
make clean

# Docker 构建
make docker-build

# Docker 启动
make docker-up

# Docker 停止
make docker-down
```

### 热重载开发

安装 air：
```bash
go install github.com/cosmtrek/air@latest
```

运行：
```bash
make dev
# 或
air
```

## 生产环境部署

### 编译

```bash
CGO_ENABLED=0 GOOS=linux go build -o main .
```

### 使用 systemd

创建服务文件 `/etc/systemd/system/chat-backend.service`：

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

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable chat-backend
sudo systemctl start chat-backend
```

## 监控和日志

### 日志配置

在 `config.yaml` 中配置日志：

```yaml
log:
  level: info  # debug, info, warn, error
  format: json  # json, text
  output: file  # stdout, file
  file_path: ./logs/app.log
  max_size: 100  # MB
  max_backups: 3
  max_age: 28  # 天
  compress: true
```

### 查看日志

```bash
# Docker
docker-compose logs -f backend

# systemd
journalctl -u chat-backend -f
```

## 故障排查

### 数据库连接失败

1. 检查 MySQL 是否运行
2. 验证数据库配置
3. 确认数据库已创建

### Redis 连接失败

1. 检查 Redis 是否运行
2. 验证 Redis 配置
3. 测试连接：`redis-cli ping`

### 端口被占用

```bash
# 查看端口占用
lsof -i :8090

# 修改配置文件中的端口
```

## 安全建议

1. 使用强密码和复杂的 JWT Secret
2. 启用 HTTPS
3. 配置防火墙规则
4. 定期更新依赖包
5. 实施 API 速率限制
6. 启用 SQL 注入防护
7. 验证所有用户输入

## 性能优化

1. 启用 Gzip 压缩
2. 配置数据库连接池
3. 使用 Redis 缓存
4. 启用 HTTP/2
5. 优化数据库查询
6. 使用 CDN 加速静态资源

## 许可证

MIT License
