package handlers

import (
	"chat-backend/models"
	"chat-backend/pkg/phoneutil"

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
	Phone  string `json:"phone" binding:"required"`
	Remark string `json:"remark"`
}

func (h *FriendHandler) SearchByPhone(c *gin.Context) {
	userID := c.GetUint("userID")
	phone := c.Query("phone")
	if phone == "" {
		writeFailure(c, 400, "PHONE_INVALID", "手机号格式不正确")
		return
	}

	normalizedPhone, err := phoneutil.Normalize(phone)
	if err != nil {
		writeFailure(c, 400, "PHONE_INVALID", "手机号格式不正确")
		return
	}

	var user models.User
	if err := h.db.Where("phone = ?", normalizedPhone).First(&user).Error; err != nil {
		writeFailure(c, 404, "FRIEND_NOT_FOUND", "未找到该手机号用户")
		return
	}

	isFriend := false
	if user.ID != userID {
		var existing models.Friendship
		if err := h.db.Where("user_id = ? AND friend_id = ?", userID, user.ID).First(&existing).Error; err == nil {
			isFriend = true
		}
	}

	writeSuccess(c, 200, "查询用户成功", gin.H{
		"user": gin.H{
			"id":           user.ID,
			"phoneMasked":  phoneutil.Mask(user.Phone),
			"phone_masked": phoneutil.Mask(user.Phone),
			"nickname":     user.Nickname,
			"avatar":       user.Avatar,
		},
		"relation": gin.H{
			"is_self":         user.ID == userID,
			"is_friend":       isFriend,
			"request_pending": false,
		},
	})
}

func (h *FriendHandler) AddByPhone(c *gin.Context) {
	userID := c.GetUint("userID")

	var req AddFriendRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		writeFailure(c, 400, "INVALID_PARAM", "参数错误")
		return
	}

	normalizedPhone, err := phoneutil.Normalize(req.Phone)
	if err != nil {
		writeFailure(c, 400, "PHONE_INVALID", "手机号格式不正确")
		return
	}

	var friend models.User
	if err := h.db.Where("phone = ?", normalizedPhone).First(&friend).Error; err != nil {
		writeFailure(c, 404, "FRIEND_NOT_FOUND", "未找到该手机号用户")
		return
	}

	if friend.ID == userID {
		writeFailure(c, 400, "FRIEND_ADD_SELF_FORBIDDEN", "不能添加自己为好友")
		return
	}

	var existing models.Friendship
	if err := h.db.Where("user_id = ? AND friend_id = ?", userID, friend.ID).First(&existing).Error; err == nil {
		writeFailure(c, 409, "FRIEND_ALREADY_EXISTS", "对方已是好友")
		return
	}

	friendship := models.Friendship{
		UserID:   userID,
		FriendID: friend.ID,
		Status:   "accepted",
	}
	reverseFriendship := models.Friendship{
		UserID:   friend.ID,
		FriendID: userID,
		Status:   "accepted",
	}

	if err := h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&friendship).Error; err != nil {
			return err
		}
		if err := tx.Create(&reverseFriendship).Error; err != nil {
			return err
		}
		return nil
	}); err != nil {
		writeInternalError(c, "添加好友失败")
		return
	}

	writeSuccess(c, 200, "添加好友成功", gin.H{
		"friend": gin.H{
			"id":           friend.ID,
			"phoneMasked":  phoneutil.Mask(friend.Phone),
			"phone_masked": phoneutil.Mask(friend.Phone),
			"nickname":     friend.Nickname,
			"avatar":       friend.Avatar,
			"createdAt":    friend.CreatedAt,
		},
	})
}

func (h *FriendHandler) GetFriends(c *gin.Context) {
	userID := c.GetUint("userID")

	var friendships []models.Friendship
	if err := h.db.Where("user_id = ? AND status = ?", userID, "accepted").Preload("Friend").Find(&friendships).Error; err != nil {
		writeInternalError(c, "获取好友列表失败")
		return
	}

	friends := make([]gin.H, 0, len(friendships))
	for _, f := range friendships {
		friends = append(friends, gin.H{
			"id":           f.Friend.ID,
			"phoneMasked":  phoneutil.Mask(f.Friend.Phone),
			"phone_masked": phoneutil.Mask(f.Friend.Phone),
			"nickname":     f.Friend.Nickname,
			"avatar":       f.Friend.Avatar,
			"createdAt":    f.Friend.CreatedAt,
		})
	}

	writeSuccess(c, 200, "获取好友列表成功", gin.H{"friends": friends})
}
