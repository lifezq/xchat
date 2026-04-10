package services

import (
	"chat-backend/models"
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

type ChatService struct {
	db  *gorm.DB
	rdb *redis.Client
}

func NewChatService(db *gorm.DB, rdb *redis.Client) *ChatService {
	return &ChatService{db: db, rdb: rdb}
}

func (s *ChatService) SendMessage(senderID, receiverID uint, content, msgType, voiceURL string) (*models.Message, error) {
	message := &models.Message{
		SenderID:   senderID,
		ReceiverID: receiverID,
		Content:    content,
		Type:       msgType,
		VoiceURL:   voiceURL,
		IsRead:     false,
	}

	if err := s.db.Create(message).Error; err != nil {
		return nil, err
	}

	// 缓存最新消息到 Redis
	s.cacheLastMessage(senderID, receiverID, message)

	// 增加未读计数
	s.incrementUnreadCount(receiverID, senderID)

	return message, nil
}

func (s *ChatService) GetMessages(userID, friendID uint, limit, offset int) ([]models.Message, error) {
	var messages []models.Message

	err := s.db.Where(
		"(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)",
		userID, friendID, friendID, userID,
	).Order("created_at ASC").Limit(limit).Offset(offset).Find(&messages).Error

	return messages, err
}

func (s *ChatService) MarkAsRead(userID, friendID uint) error {
	err := s.db.Model(&models.Message{}).
		Where("sender_id = ? AND receiver_id = ? AND is_read = ?", friendID, userID, false).
		Update("is_read", true).Error

	if err == nil {
		s.clearUnreadCount(userID, friendID)
	}

	return err
}

func (s *ChatService) GetConversations(userID uint) ([]models.Conversation, error) {
	var friendships []models.Friendship
	if err := s.db.Where("user_id = ?", userID).Preload("Friend").Find(&friendships).Error; err != nil {
		return nil, err
	}

	conversations := make([]models.Conversation, 0, len(friendships))

	for _, friendship := range friendships {
		var lastMessage models.Message
		err := s.db.Where(
			"(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)",
			userID, friendship.FriendID, friendship.FriendID, userID,
		).Order("created_at DESC").First(&lastMessage).Error

		var unreadCount int64
		s.db.Model(&models.Message{}).Where(
			"sender_id = ? AND receiver_id = ? AND is_read = ?",
			friendship.FriendID, userID, false,
		).Count(&unreadCount)

		conv := models.Conversation{
			OtherUser:   friendship.Friend,
			UnreadCount: unreadCount,
		}

		if err == nil {
			conv.LastMessage = &lastMessage
		}

		conversations = append(conversations, conv)
	}

	return conversations, nil
}

func (s *ChatService) cacheLastMessage(senderID, receiverID uint, message *models.Message) {
	ctx := context.Background()
	key := fmt.Sprintf("last_msg:%d:%d", min(senderID, receiverID), max(senderID, receiverID))

	data, _ := json.Marshal(message)
	s.rdb.Set(ctx, key, data, 24*time.Hour)
}

func (s *ChatService) incrementUnreadCount(userID, fromUserID uint) {
	ctx := context.Background()
	key := fmt.Sprintf("unread:%d:%d", userID, fromUserID)
	s.rdb.Incr(ctx, key)
}

func (s *ChatService) clearUnreadCount(userID, fromUserID uint) {
	ctx := context.Background()
	key := fmt.Sprintf("unread:%d:%d", userID, fromUserID)
	s.rdb.Del(ctx, key)
}

func min(a, b uint) uint {
	if a < b {
		return a
	}
	return b
}

func max(a, b uint) uint {
	if a > b {
		return a
	}
	return b
}
