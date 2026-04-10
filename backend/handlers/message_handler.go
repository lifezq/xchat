package handlers

import (
	"chat-backend/services"
	"strconv"

	"github.com/gin-gonic/gin"
)

type MessageHandler struct {
	chatService *services.ChatService
}

func NewMessageHandler(chatService *services.ChatService) *MessageHandler {
	return &MessageHandler{chatService: chatService}
}

type SendMessageRequest struct {
	ReceiverID uint   `json:"receiverId" binding:"required"`
	Content    string `json:"content" binding:"required"`
	Type       string `json:"type" binding:"required,oneof=text voice"`
	VoiceURL   string `json:"voiceUrl"`
}

func (h *MessageHandler) SendMessage(c *gin.Context) {
	userID := c.GetUint("userID")

	var req SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		writeBadRequest(c, "请求参数无效")
		return
	}

	message, err := h.chatService.SendMessage(userID, req.ReceiverID, req.Content, req.Type, req.VoiceURL)
	if err != nil {
		writeInternalError(c, "发送消息失败")
		return
	}

	writeSuccess(c, 201, "发送消息成功", gin.H{"message": message})
}

func (h *MessageHandler) GetMessages(c *gin.Context) {
	userID := c.GetUint("userID")
	friendID, err := strconv.ParseUint(c.Param("friendId"), 10, 32)
	if err != nil {
		writeBadRequest(c, "无效的好友ID")
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	messages, err := h.chatService.GetMessages(userID, uint(friendID), limit, offset)
	if err != nil {
		writeInternalError(c, "获取消息失败")
		return
	}

	h.chatService.MarkAsRead(userID, uint(friendID))

	writeSuccess(c, 200, "获取消息成功", gin.H{"messages": messages})
}

func (h *MessageHandler) GetConversations(c *gin.Context) {
	userID := c.GetUint("userID")

	conversations, err := h.chatService.GetConversations(userID)
	if err != nil {
		writeInternalError(c, "获取会话列表失败")
		return
	}

	writeSuccess(c, 200, "获取会话列表成功", gin.H{"conversations": conversations})
}
