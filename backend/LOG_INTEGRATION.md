# 日志框架集成说明

## 概述

后端项目已成功集成 `github.com/lifezq/log v1.0.0` 作为日志框架。

## 集成内容

### 1. 依赖添加

在 `go.mod` 中添加：
```go
github.com/lifezq/log v1.0.0
```

### 2. 日志包装器

创建了 `pkg/logger/logger.go` 包装器，提供统一的日志接口：

- `InitLogger()` - 初始化日志系统
- `Debug/Debugf()` - 调试日志
- `Info/Infof()` - 信息日志
- `Warn/Warnf()` - 警告日志
- `Error/Errorf()` - 错误日志
- `Fatal/Fatalf()` - 致命错误日志
- `WithField/WithFields()` - 添加结构化字段

### 3. 日志中间件

创建了 `middleware/logger.go` 用于记录 HTTP 请求：

- 记录请求方法、URI、状态码
- 记录请求耗时
- 记录客户端 IP

### 4. 配置支持

在 `config.yaml` 中配置日志：

```yaml
log:
  level: info          # debug, info, warn, error
  format: json         # json, text
  output: stdout       # stdout, file
  file_path: ./logs/app.log
  max_size: 100        # MB
  max_backups: 3
  max_age: 28          # 天
  compress: true
```

### 5. 替换位置

已将以下位置的 `log` 包替换为自定义 logger：

- `config/config.go` - 数据库和 Redis 连接日志
- `main.go` - 应用启动日志
- `services/websocket.go` - WebSocket 连接日志
- `handlers/websocket_handler.go` - WebSocket 处理日志

## 使用示例

### 基本日志

```go
import "chat-backend/pkg/logger"

logger.Info("服务器启动")
logger.Infof("监听端口: %d", 8090)
logger.Error("发生错误")
logger.Errorf("连接失败: %v", err)
```

### 结构化日志

```go
logger.WithFields(map[string]interface{}{
    "user_id": 123,
    "action": "login",
    "ip": "192.168.1.1",
}).Info("用户登录")
```

### 日志级别

- `debug` - 调试信息，开发环境使用
- `info` - 一般信息，生产环境推荐
- `warn` - 警告信息
- `error` - 错误信息
- `fatal` - 致命错误，会导致程序退出

## 特性

1. **基于 Zap** - 高性能日志库
2. **结构化日志** - 支持添加字段
3. **日志轮转** - 自动按大小和时间轮转
4. **灵活配置** - 通过配置文件控制
5. **调用栈信息** - 可选开启调用栈追踪

## 注意事项

1. `github.com/lifezq/log` 基于 `go.uber.org/zap`
2. 所有日志方法都需要 `context.Context` 参数（已在包装器中处理）
3. 日志文件会自动创建在 `./logs` 目录
4. 生产环境建议使用 `info` 级别
5. 开发环境可使用 `debug` 级别查看详细信息

## 编译和运行

```bash
# 安装依赖
go mod tidy

# 编译
go build -o main .

# 运行
./main
```

## 日志输出示例

### 控制台输出（stdout）
```
2024-01-20 10:30:15 INFO  === 聊天应用后端服务启动 ===
2024-01-20 10:30:15 INFO  使用配置文件: ./config.yaml
2024-01-20 10:30:15 INFO  数据库连接成功
2024-01-20 10:30:15 INFO  Redis 连接成功
2024-01-20 10:30:15 INFO  服务器启动在端口 :8090 (模式: debug)
```

### 文件输出（JSON 格式）
```json
{"level":"info","ts":"2024-01-20T10:30:15.123Z","caller":"main.go:33","msg":"=== 聊天应用后端服务启动 ==="}
{"level":"info","ts":"2024-01-20T10:30:15.456Z","caller":"config/config.go:98","msg":"数据库连接成功"}
```

## 性能

- 使用 Zap 作为底层，性能优异
- 支持异步日志写入
- 零内存分配的结构化日志
- 适合高并发场景

## 后续优化

1. 可以添加日志采样（高频日志降采样）
2. 可以集成 ELK 或其他日志收集系统
3. 可以添加日志告警功能
4. 可以添加更多自定义字段（如 trace_id）
