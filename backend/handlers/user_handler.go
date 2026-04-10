package handlers

import (
	"chat-backend/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type UserHandler struct {
	db *gorm.DB
}

func NewUserHandler(db *gorm.DB) *UserHandler {
	return &UserHandler{db: db}
}

func (h *UserHandler) SearchUsers(c *gin.Context) {
	email := c.Query("email")
	if email == "" {
		writeBadRequest(c, "邮箱参数必填")
		return
	}

	var user models.User
	if err := h.db.Where("email = ?", email).First(&user).Error; err != nil {
		writeNotFound(c, "用户不存在")
		return
	}

	writeSuccess(c, 200, "查询用户成功", gin.H{"user": user})
}

func (h *UserHandler) GetCurrentUser(c *gin.Context) {
	userID := c.GetUint("userID")

	var user models.User
	if err := h.db.First(&user, userID).Error; err != nil {
		writeNotFound(c, "用户不存在")
		return
	}

	writeSuccess(c, 200, "获取当前用户成功", gin.H{"user": user})
}
