package config

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/lifezq/log"
	"github.com/redis/go-redis/v9"
	"github.com/spf13/viper"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var ctx = context.Background()

type Config struct {
	Server    ServerConfig    `mapstructure:"server"`
	Database  DatabaseConfig  `mapstructure:"database"`
	Redis     RedisConfig     `mapstructure:"redis"`
	JWT       JWTConfig       `mapstructure:"jwt"`
	Upload    UploadConfig    `mapstructure:"upload"`
	Log       LogConfig       `mapstructure:"log"`
	CORS      CORSConfig      `mapstructure:"cors"`
	WebSocket WebSocketConfig `mapstructure:"websocket"`
}

type ServerConfig struct {
	Port         int    `mapstructure:"port"`
	Mode         string `mapstructure:"mode"`
	ReadTimeout  int    `mapstructure:"read_timeout"`
	WriteTimeout int    `mapstructure:"write_timeout"`
}

type DatabaseConfig struct {
	Host            string `mapstructure:"host"`
	Port            int    `mapstructure:"port"`
	User            string `mapstructure:"user"`
	Password        string `mapstructure:"password"`
	DBName          string `mapstructure:"dbname"`
	Charset         string `mapstructure:"charset"`
	ParseTime       bool   `mapstructure:"parse_time"`
	MaxIdleConns    int    `mapstructure:"max_idle_conns"`
	MaxOpenConns    int    `mapstructure:"max_open_conns"`
	ConnMaxLifetime int    `mapstructure:"conn_max_lifetime"`
}

type RedisConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
	PoolSize int    `mapstructure:"pool_size"`
}

type JWTConfig struct {
	Secret      string `mapstructure:"secret"`
	ExpireHours int    `mapstructure:"expire_hours"`
}

type UploadConfig struct {
	VoiceDir    string   `mapstructure:"voice_dir"`
	MaxSize     int64    `mapstructure:"max_size"`
	AllowedExts []string `mapstructure:"allowed_exts"`
}

type LogConfig struct {
	Level      string `mapstructure:"level"`
	Format     string `mapstructure:"format"`
	Output     string `mapstructure:"output"`
	FilePath   string `mapstructure:"file_path"`
	MaxSize    int    `mapstructure:"max_size"`
	MaxBackups int    `mapstructure:"max_backups"`
	MaxAge     int    `mapstructure:"max_age"`
	Compress   bool   `mapstructure:"compress"`
}

type CORSConfig struct {
	AllowOrigins     []string `mapstructure:"allow_origins"`
	AllowMethods     []string `mapstructure:"allow_methods"`
	AllowHeaders     []string `mapstructure:"allow_headers"`
	ExposeHeaders    []string `mapstructure:"expose_headers"`
	AllowCredentials bool     `mapstructure:"allow_credentials"`
	MaxAge           int      `mapstructure:"max_age"`
}

type WebSocketConfig struct {
	ReadBufferSize    int `mapstructure:"read_buffer_size"`
	WriteBufferSize   int `mapstructure:"write_buffer_size"`
	HeartbeatInterval int `mapstructure:"heartbeat_interval"`
	MaxMessageSize    int `mapstructure:"max_message_size"`
}

func LoadConfig() *Config {
	viper.SetDefault("server.port", 8090)

	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("./config")
	viper.AddConfigPath("/etc/chat-backend")

	// 设置环境变量前缀
	viper.SetEnvPrefix("CHAT")
	viper.AutomaticEnv()

	// 读取配置文件
	if err := viper.ReadInConfig(); err != nil {
		log.Warnf(ctx, "无法读取配置文件: %v, 使用默认配置", err)
	} else {
		log.Infof(ctx, "使用配置文件: %s", viper.ConfigFileUsed())
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		log.Fatalf(ctx, "无法解析配置: %v", err)
	}

	// 环境变量覆盖
	if dbHost := os.Getenv("DB_HOST"); dbHost != "" {
		config.Database.Host = dbHost
	}
	if dbPassword := os.Getenv("DB_PASSWORD"); dbPassword != "" {
		config.Database.Password = dbPassword
	}
	if jwtSecret := os.Getenv("JWT_SECRET"); jwtSecret != "" {
		config.JWT.Secret = jwtSecret
	}

	return &config
}

func InitDB(cfg *Config) *gorm.DB {
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=%s&parseTime=%t&loc=Local",
		cfg.Database.User,
		cfg.Database.Password,
		cfg.Database.Host,
		cfg.Database.Port,
		cfg.Database.DBName,
		cfg.Database.Charset,
		cfg.Database.ParseTime,
	)

	// 配置日志级别
	logLevel := logger.Info
	if cfg.Server.Mode == "release" {
		logLevel = logger.Error
	}

	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logLevel),
	})
	if err != nil {
		log.Fatalf(ctx, "数据库连接失败: %v", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		log.Fatalf(ctx, "获取数据库实例失败: %v", err)
	}

	sqlDB.SetMaxIdleConns(cfg.Database.MaxIdleConns)
	sqlDB.SetMaxOpenConns(cfg.Database.MaxOpenConns)
	sqlDB.SetConnMaxLifetime(time.Duration(cfg.Database.ConnMaxLifetime) * time.Second)

	log.Info(ctx, "数据库连接成功")
	return db
}

func InitRedis(cfg *Config) *redis.Client {
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%d", cfg.Redis.Host, cfg.Redis.Port),
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.DB,
		PoolSize: cfg.Redis.PoolSize,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf(ctx, "Redis 连接失败: %v", err)
	}

	log.Info(ctx, "Redis 连接成功")
	return rdb
}

// GetServerAddr 获取服务器地址
func (c *Config) GetServerAddr() string {
	return fmt.Sprintf(":%d", c.Server.Port)
}

// GetJWTSecret 获取 JWT 密钥
func (c *Config) GetJWTSecret() string {
	return c.JWT.Secret
}

// GetJWTExpireDuration 获取 JWT 过期时间
func (c *Config) GetJWTExpireDuration() time.Duration {
	return time.Duration(c.JWT.ExpireHours) * time.Hour
}
