package services

import (
	"context"
	"encoding/json"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/lifezq/log"
)

var ctx = context.Background()

// Client WebSocket 客户端
type Client struct {
	UserID uint
	Conn   *websocket.Conn
	Send   chan []byte
}

// WebSocketHub WebSocket 连接管理中心
type WebSocketHub struct {
	clients    map[uint]*Client
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
}

// NewWebSocketHub 创建 WebSocket Hub
func NewWebSocketHub() *WebSocketHub {
	return &WebSocketHub{
		clients:    make(map[uint]*Client),
		broadcast:  make(chan []byte),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

// Run 运行 Hub
func (h *WebSocketHub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client.UserID] = client
			h.mu.Unlock()
			log.Infof(ctx, "用户 %d 注册到 WebSocket Hub", client.UserID)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.UserID]; ok {
				delete(h.clients, client.UserID)
				close(client.Send)
				log.Infof(ctx, "用户 %d 从 WebSocket Hub 注销", client.UserID)
			}
			h.mu.Unlock()

		case message := <-h.broadcast:
			h.mu.RLock()
			for _, client := range h.clients {
				select {
				case client.Send <- message:
				default:
					close(client.Send)
					delete(h.clients, client.UserID)
				}
			}
			h.mu.RUnlock()
		}
	}
}

// RegisterClient 注册客户端
func (h *WebSocketHub) RegisterClient(client *Client) {
	h.register <- client
}

// UnregisterClient 注销客户端
func (h *WebSocketHub) UnregisterClient(client *Client) {
	h.unregister <- client
}

// SendToUser 发送消息给指定用户
func (h *WebSocketHub) SendToUser(userID uint, message interface{}) error {
	h.mu.RLock()
	client, ok := h.clients[userID]
	h.mu.RUnlock()

	if !ok {
		return nil // 用户不在线
	}

	data, err := json.Marshal(message)
	if err != nil {
		return err
	}

	select {
	case client.Send <- data:
	default:
		// 发送失败，关闭连接
		h.UnregisterClient(client)
	}

	return nil
}

// ReadPump 读取客户端消息
func (c *Client) ReadPump(hub *WebSocketHub) {
	defer func() {
		hub.UnregisterClient(c)
		c.Conn.Close()
	}()

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Errorf(ctx, "WebSocket 读取错误: %v", err)
			}
			break
		}

		log.Infof(ctx, "收到用户 %d 的消息: %s", c.UserID, string(message))
	}
}

// WritePump 向客户端写入消息
func (c *Client) WritePump() {
	defer func() {
		c.Conn.Close()
	}()

	for {
		message, ok := <-c.Send
		if !ok {
			c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
			return
		}

		if err := c.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
			log.Errorf(ctx, "WebSocket 写入错误: %v", err)
			return
		}
	}
}
