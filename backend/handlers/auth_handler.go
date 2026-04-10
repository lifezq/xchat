package handlers

import (
	"chat-backend/pkg/apperrors"
	"chat-backend/services"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	authService *services.AuthService
}

func NewAuthHandler(authService *services.AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

type RegisterRequest struct {
	Phone    string `json:"phone" binding:"required"`
	Password string `json:"password" binding:"required,min=6"`
	Nickname string `json:"nickname" binding:"required,min=2"`
}

type LoginRequest struct {
	Phone    string `json:"phone" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type LogoutRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.writeAppError(c, apperrors.ErrInvalidParams, http.StatusBadRequest)
		return
	}

	accessToken, refreshToken, user, err := h.authService.Register(req.Phone, req.Password, req.Nickname)
	if err != nil {
		h.writeError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    "OK",
		"message": "注册成功",
		"data": gin.H{
			"user":          user,
			"access_token":  accessToken,
			"refresh_token": refreshToken,
		},
		// legacy fields for existing app compatibility
		"user":         user,
		"token":        accessToken,
		"accessToken":  accessToken,
		"refreshToken": refreshToken,
	})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.writeAppError(c, apperrors.ErrInvalidParams, http.StatusBadRequest)
		return
	}

	accessToken, refreshToken, user, err := h.authService.Login(req.Phone, req.Password)
	if err != nil {
		h.writeError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    "OK",
		"message": "登录成功",
		"data": gin.H{
			"access_token":  accessToken,
			"refresh_token": refreshToken,
			"user":          user,
		},
		// legacy fields for existing app compatibility
		"token":        accessToken,
		"accessToken":  accessToken,
		"refreshToken": refreshToken,
		"user":         user,
	})
}

func (h *AuthHandler) Refresh(c *gin.Context) {
	var req RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.writeAppError(c, apperrors.ErrInvalidParams, http.StatusBadRequest)
		return
	}

	accessToken, refreshToken, err := h.authService.Refresh(req.RefreshToken)
	if err != nil {
		h.writeError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    "OK",
		"message": "刷新令牌成功",
		"data": gin.H{
			"access_token":  accessToken,
			"refresh_token": refreshToken,
		},
		"token":        accessToken,
		"accessToken":  accessToken,
		"refreshToken": refreshToken,
	})
}

func (h *AuthHandler) Logout(c *gin.Context) {
	var req LogoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.writeAppError(c, apperrors.ErrInvalidParams, http.StatusBadRequest)
		return
	}

	if err := h.authService.Logout(req.RefreshToken); err != nil {
		h.writeError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    "OK",
		"message": "退出登录成功",
	})
}

func (h *AuthHandler) writeError(c *gin.Context, err error) {
	var appErr *apperrors.AppError
	if errors.As(err, &appErr) {
		status := http.StatusBadRequest
		switch appErr.Code {
		case apperrors.ErrInvalidCredentials.Code, apperrors.ErrUnauthorized.Code:
			status = http.StatusUnauthorized
		case apperrors.ErrPhoneExists.Code:
			status = http.StatusConflict
		case apperrors.ErrPhoneInvalid.Code:
			status = http.StatusBadRequest
		}
		h.writeAppError(c, appErr, status)
		return
	}

	h.writeAppError(c, apperrors.ErrInternal, http.StatusInternalServerError)
}

func (h *AuthHandler) writeAppError(c *gin.Context, appErr *apperrors.AppError, status int) {
	c.JSON(status, gin.H{
		"code":    appErr.Code,
		"message": appErr.Message,
		// legacy field for existing app compatibility
		"error": appErr.Message,
	})
}
