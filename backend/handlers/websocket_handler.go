package handlers

import (
	"chat-backend/services"
	"context"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/lifezq/log"
)

var ctx = context.Background()

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type WebSocketHandler struct {
	hub         *services.WebSocketHub
	chatService *services.ChatService
}

func NewWebSocketHandler(hub *services.WebSocketHub, chatService *services.ChatService) *WebSocketHandler {
	return &WebSocketHandler{
		hub:         hub,
		chatService: chatService,
	}
}

func (h *WebSocketHandler) HandleWebSocket(c *gin.Context) {
	userID := c.GetUint("userID")

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Errorf(ctx, "WebSocket 升级失败: %v", err)
		return
	}

	client := &services.Client{
		UserID: userID,
		Conn:   conn,
		Send:   make(chan []byte, 256),
	}

	h.hub.RegisterClient(client)

	go client.WritePump()
	go client.ReadPump(h.hub)

	log.Infof(ctx, "用户 %d 建立 WebSocket 连接", userID)
}
