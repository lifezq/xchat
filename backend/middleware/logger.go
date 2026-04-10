package middleware

import (
	"context"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/lifezq/log"
)

// LoggerMiddleware 日志中间件
func LoggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 开始时间
		startTime := time.Now()

		// 处理请求
		c.Next()

		// 结束时间
		endTime := time.Now()

		// 执行时间
		latencyTime := endTime.Sub(startTime)

		// 请求方式
		reqMethod := c.Request.Method

		// 请求路由
		reqUri := c.Request.RequestURI

		// 状态码
		statusCode := c.Writer.Status()

		// 请求IP
		clientIP := c.ClientIP()

		// 日志格式
		ctx := context.Background()
		log.Infof(ctx, "HTTP请求 | status=%d | latency=%s | ip=%s | method=%s | uri=%s",
			statusCode, latencyTime.String(), clientIP, reqMethod, reqUri)
	}
}
