# 更新日志

## [未发布] - 2024-01-20

### 新增
- 集成 `github.com/lifezq/log v1.0.1` 作为统一日志框架
- 添加日志包装器 `pkg/logger`
- 添加 HTTP 请求日志中间件
- 支持通过配置文件管理日志设置

### 修改
- 替换所有 `log` 包调用为自定义 logger
- 更新 `config/config.go` 使用新日志系统
- 更新 `main.go` 添加日志初始化
- 更新 `services/websocket.go` 使用结构化日志
- 更新 `handlers/websocket_handler.go` 使用新日志

### 修复
- 修复 `log.InitLog` 函数名错误，应为 `log.Init`
- 修复伪版本号问题，使用正式版本 `v1.0.1`

### 技术细节
- 日志框架基于 `go.uber.org/zap`，高性能
- 支持结构化日志和字段添加
- 支持日志级别：debug, info, warn, error, fatal
- 支持日志输出：stdout, file
- 支持日志文件轮转

## [1.0.0] - 2024-01-19

### 新增
- 初始版本
- 用户注册/登录功能
- 好友管理功能
- 实时聊天功能
- WebSocket 支持
- 文件上传功能
- MySQL 数据持久化
- Redis 缓存
- JWT 认证
- CORS 支持
- Docker 部署支持
