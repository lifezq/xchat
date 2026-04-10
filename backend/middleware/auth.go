package middleware

import (
	"chat-backend/pkg/apperrors"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

func AuthMiddleware(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		tokenString := ""
		if authHeader != "" {
			if !strings.HasPrefix(authHeader, "Bearer ") {
				writeAuthError(c, apperrors.ErrUnauthorized.Message)
				c.Abort()
				return
			}
			tokenString = strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
		} else {
			// WebSocket 握手不方便统一加 Authorization，允许 query token 作为备用方式
			tokenString = strings.TrimSpace(c.Query("token"))
		}
		if tokenString == "" {
			writeAuthError(c, apperrors.ErrUnauthorized.Message)
			c.Abort()
			return
		}

		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok || token.Method.Alg() != jwt.SigningMethodHS256.Alg() {
				return nil, jwt.ErrTokenSignatureInvalid
			}
			return []byte(jwtSecret), nil
		})

		if err != nil || !token.Valid {
			writeAuthError(c, apperrors.ErrUnauthorized.Message)
			c.Abort()
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			writeAuthError(c, apperrors.ErrUnauthorized.Message)
			c.Abort()
			return
		}

		if typ, exists := claims["typ"].(string); exists && typ != "access" {
			writeAuthError(c, apperrors.ErrUnauthorized.Message)
			c.Abort()
			return
		}

		userID, ok := parseUserIDFromClaims(claims)
		if !ok {
			writeAuthError(c, apperrors.ErrUnauthorized.Message)
			c.Abort()
			return
		}
		c.Set("userID", userID)

		c.Next()
	}
}

func parseUserIDFromClaims(claims jwt.MapClaims) (uint, bool) {
	if raw, exists := claims["user_id"]; exists {
		switch v := raw.(type) {
		case float64:
			return uint(v), true
		case int64:
			return uint(v), true
		case string:
			id, err := strconv.ParseUint(v, 10, 64)
			if err == nil {
				return uint(id), true
			}
		}
	}
	if sub, exists := claims["sub"].(string); exists && sub != "" {
		id, err := strconv.ParseUint(sub, 10, 64)
		if err == nil {
			return uint(id), true
		}
	}
	return 0, false
}

func writeAuthError(c *gin.Context, message string) {
	c.JSON(http.StatusUnauthorized, gin.H{
		"code":    apperrors.ErrUnauthorized.Code,
		"message": message,
		"error":   message,
	})
}
