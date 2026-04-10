package main

import (
	"chat-backend/config"
	"chat-backend/handlers"
	"chat-backend/middleware"
	"chat-backend/models"
	"chat-backend/services"
	"context"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/lifezq/log"
	"go.uber.org/zap/zapcore"
)

var ctx = context.Background()

func main() {
	// 初始化配置
	cfg := config.LoadConfig()

	// 初始化日志系统
	var zapLevel zapcore.Level
	switch cfg.Log.Level {
	case "debug":
		zapLevel = zapcore.DebugLevel
	case "info":
		zapLevel = zapcore.InfoLevel
	case "warn":
		zapLevel = zapcore.WarnLevel
	case "error":
		zapLevel = zapcore.ErrorLevel
	default:
		zapLevel = zapcore.InfoLevel
	}

	// 创建日志目录
	if cfg.Log.Output == "file" {
		if err := os.MkdirAll("./logs", 0755); err != nil {
			panic("创建日志目录失败: " + err.Error())
		}
	}

	// 配置日志选项
	logOpts := log.Options{
		Filename:     cfg.Log.FilePath,
		MaxCount:     uint(cfg.Log.MaxBackups),
		CallerEnable: true,
		LogLevel:     zapLevel,
		CloseConsole: cfg.Log.Output == "file",
	}

	// 初始化日志
	log.Init(logOpts)

	log.Info(ctx, "=== 聊天应用后端服务启动 ===")

	// 设置 Gin 模式
	gin.SetMode(cfg.Server.Mode)

	// 初始化数据库
	db := config.InitDB(cfg)

	// 自动迁移数据表
	if err := models.AutoMigrate(db); err != nil {
		log.Fatalf(ctx, "数据库迁移失败: %v", err)
	}

	// 初始化 Redis
	rdb := config.InitRedis(cfg)

	// 创建上传目录
	log.Infof(ctx, "创建上传目录: %s", cfg.Upload.VoiceDir)
	if err := os.MkdirAll(cfg.Upload.VoiceDir, 0755); err != nil {
		log.Fatalf(ctx, "创建上传目录失败: %v", err)
	}

	// 初始化服务
	log.Info(ctx, "初始化服务...")
	authService := services.NewAuthService(db, cfg.GetJWTSecret(), cfg.GetJWTExpireDuration())
	chatService := services.NewChatService(db, rdb)
	wsHub := services.NewWebSocketHub()

	// 启动 WebSocket Hub
	log.Info(ctx, "启动 WebSocket Hub...")
	go wsHub.Run()

	// 初始化路由
	r := gin.Default()

	// 使用自定义日志中间件
	r.Use(middleware.LoggerMiddleware())
	r.Use(gin.Recovery())

	// CORS 中间件
	r.Use(middleware.CORSMiddleware(cfg))

	// 静态文件服务
	r.Static("/uploads", "./uploads")

	// 公开路由
	auth := r.Group("/api/auth")
	{
		authHandler := handlers.NewAuthHandler(authService)
		auth.POST("/register", authHandler.Register)
		auth.POST("/login", authHandler.Login)
		auth.POST("/refresh", authHandler.Refresh)
	}

	// 需要认证的路由
	api := r.Group("/api")
	api.Use(middleware.AuthMiddleware(cfg.GetJWTSecret()))
	{
		// 用户相关
		userHandler := handlers.NewUserHandler(db)
		api.GET("/users/search", userHandler.SearchUsers)
		api.GET("/users/me", userHandler.GetCurrentUser)
		authHandler := handlers.NewAuthHandler(authService)
		api.POST("/auth/logout", authHandler.Logout)

		// 好友相关
		friendHandler := handlers.NewFriendHandler(db)
		api.GET("/friends", friendHandler.GetFriends)
		api.GET("/friends/search", friendHandler.SearchByPhone)
		api.POST("/friends/add-by-phone", friendHandler.AddByPhone)

		// 消息相关
		messageHandler := handlers.NewMessageHandler(chatService, wsHub)
		api.GET("/messages/:friendId", messageHandler.GetMessages)
		api.POST("/messages", messageHandler.SendMessage)
		api.GET("/conversations", messageHandler.GetConversations)

		// WebSocket
		wsHandler := handlers.NewWebSocketHandler(wsHub, chatService)
		api.GET("/ws", wsHandler.HandleWebSocket)

		// 文件上传
		uploadHandler := handlers.NewUploadHandler(cfg.Upload.VoiceDir, cfg.Upload.MaxSize, cfg.Upload.AllowedExts)
		api.POST("/upload/voice", uploadHandler.UploadVoice)
	}

	log.Infof(ctx, "服务器启动在端口 %s (模式: %s)", cfg.GetServerAddr(), cfg.Server.Mode)
	log.Info(ctx, "=== 服务器启动成功 ===")

	if err := r.Run(cfg.GetServerAddr()); err != nil {
		log.Fatalf(ctx, "服务器启动失败: %v", err)
	}
}
