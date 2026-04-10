package middleware

import (
	"chat-backend/config"
	"strings"

	"github.com/gin-gonic/gin"
)

func CORSMiddleware(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")

		// 检查是否允许该来源
		allowed := false
		for _, allowedOrigin := range cfg.CORS.AllowOrigins {
			if allowedOrigin == "*" || allowedOrigin == origin {
				allowed = true
				break
			}
		}

		if allowed {
			if origin != "" {
				c.Writer.Header().Set("Access-Control-Allow-Origin", origin)
			} else {
				c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
			}

			c.Writer.Header().Set("Access-Control-Allow-Methods", strings.Join(cfg.CORS.AllowMethods, ", "))
			c.Writer.Header().Set("Access-Control-Allow-Headers", strings.Join(cfg.CORS.AllowHeaders, ", "))
			c.Writer.Header().Set("Access-Control-Expose-Headers", strings.Join(cfg.CORS.ExposeHeaders, ", "))

			if cfg.CORS.AllowCredentials {
				c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
			}

			if cfg.CORS.MaxAge > 0 {
				c.Writer.Header().Set("Access-Control-Max-Age", string(rune(cfg.CORS.MaxAge)))
			}
		}

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}
