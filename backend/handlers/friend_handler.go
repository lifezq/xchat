package handlers

import (
	"chat-backend/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type FriendHandler struct {
	db *gorm.DB
}

func NewFriendHandler(db *gorm.DB) *FriendHandler {
	return &FriendHandler{db: db}
}

type AddFriendRequest struct {
	FriendEmail string `json:"friendEmail" binding:"required,email"`
}

func (h *FriendHandler) AddFriend(c *gin.Context) {
	userID := c.GetUint("userID")

	var req AddFriendRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		writeBadRequest(c, "请求参数无效")
		return
	}

	var friend models.User
	if err := h.db.Where("email = ?", req.FriendEmail).First(&friend).Error; err != nil {
		writeNotFound(c, "用户不存在")
		return
	}

	if friend.ID == userID {
		writeBadRequest(c, "不能添加自己为好友")
		return
	}

	var existing models.Friendship
	if err := h.db.Where("user_id = ? AND friend_id = ?", userID, friend.ID).First(&existing).Error; err == nil {
		writeConflict(c, "已经是好友了")
		return
	}

	friendship := models.Friendship{
		UserID:   userID,
		FriendID: friend.ID,
	}

	if err := h.db.Create(&friendship).Error; err != nil {
		writeInternalError(c, "添加好友失败")
		return
	}

	reverseFriendship := models.Friendship{
		UserID:   friend.ID,
		FriendID: userID,
	}
	h.db.Create(&reverseFriendship)

	writeSuccess(c, 201, "添加好友成功", gin.H{"friend": friend})
}

func (h *FriendHandler) GetFriends(c *gin.Context) {
	userID := c.GetUint("userID")

	var friendships []models.Friendship
	if err := h.db.Where("user_id = ?", userID).Preload("Friend").Find(&friendships).Error; err != nil {
		writeInternalError(c, "获取好友列表失败")
		return
	}

	friends := make([]models.User, len(friendships))
	for i, f := range friendships {
		friends[i] = f.Friend
	}

	writeSuccess(c, 200, "获取好友列表成功", gin.H{"friends": friends})
}
