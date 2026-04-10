package models

import (
	"time"

	"gorm.io/gorm"
)

// User 用户表
type User struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	Phone     string         `gorm:"size:20;not null;unique" json:"phone"`
	Password  string         `gorm:"size:255;not null" json:"-"`
	Nickname  string         `gorm:"size:50;not null" json:"nickname"`
	Avatar    string         `gorm:"size:255" json:"avatar"`
	Status    string         `gorm:"size:20;default:'offline'" json:"status"` // online, offline, busy
	CreatedAt time.Time      `json:"createdAt"`
	UpdatedAt time.Time      `json:"updatedAt"`
	DeletedAt gorm.DeletedAt `gorm:"index:idx_users_deleted_at" json:"-"`
}

// TableName 指定表名
func (User) TableName() string {
	return "users"
}

// AuthSession 登录会话（用于 Refresh Token 管理）
type AuthSession struct {
	ID               uint       `gorm:"primarykey" json:"id"`
	UserID           uint       `gorm:"not null;index:idx_auth_sessions_user_id" json:"userId"`
	RefreshTokenHash string     `gorm:"size:64;not null;unique" json:"-"`
	DeviceID         string     `gorm:"size:100" json:"deviceId"`
	UserAgent        string     `gorm:"size:255" json:"userAgent"`
	IP               string     `gorm:"size:64" json:"ip"`
	ExpiresAt        time.Time  `gorm:"not null;index:idx_auth_sessions_expires_at" json:"expiresAt"`
	RevokedAt        *time.Time `gorm:"index:idx_auth_sessions_revoked_at" json:"revokedAt,omitempty"`
	CreatedAt        time.Time  `json:"createdAt"`
	UpdatedAt        time.Time  `json:"updatedAt"`

	User User `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE" json:"-"`
}

// TableName 指定表名
func (AuthSession) TableName() string {
	return "auth_sessions"
}

// Message 消息表
type Message struct {
	ID          uint       `gorm:"primarykey" json:"id"`
	SenderID    uint       `gorm:"not null;index:idx_sender_receiver" json:"senderId"`
	ReceiverID  uint       `gorm:"not null;index:idx_sender_receiver" json:"receiverId"`
	Content     string     `gorm:"type:text;not null" json:"content"`
	Type        string     `gorm:"size:20;not null;default:'text'" json:"type"` // text, voice, image, file
	VoiceURL    string     `gorm:"size:255" json:"voiceUrl,omitempty"`
	Duration    int        `gorm:"default:0" json:"duration,omitempty"` // 语音时长（秒）
	IsRead      bool       `gorm:"default:false;index:idx_messages_is_read" json:"isRead"`
	Status      string     `gorm:"size:20;not null;default:'sent';index:idx_messages_status" json:"status"` // sent, delivered, read
	DeliveredAt *time.Time `json:"deliveredAt,omitempty"`
	ReadAt      *time.Time `json:"readAt,omitempty"`
	CreatedAt   time.Time  `gorm:"index:idx_messages_created_at" json:"timestamp"`

	Sender   User `gorm:"foreignKey:SenderID;constraint:OnDelete:CASCADE" json:"-"`
	Receiver User `gorm:"foreignKey:ReceiverID;constraint:OnDelete:CASCADE" json:"-"`
}

// TableName 指定表名
func (Message) TableName() string {
	return "messages"
}

// Friendship 好友关系表
type Friendship struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	UserID    uint      `gorm:"not null;index:idx_user_friend;uniqueIndex:idx_unique_friendship" json:"userId"`
	FriendID  uint      `gorm:"not null;index:idx_user_friend;uniqueIndex:idx_unique_friendship" json:"friendId"`
	Status    string    `gorm:"size:20;default:'pending'" json:"status"` // pending, accepted, blocked
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`

	User   User `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE" json:"-"`
	Friend User `gorm:"foreignKey:FriendID;constraint:OnDelete:CASCADE" json:"friend"`
}

// TableName 指定表名
func (Friendship) TableName() string {
	return "friendships"
}

// Conversation 会话（非数据库表，用于 API 响应）
type Conversation struct {
	OtherUser   User     `json:"otherUser"`
	LastMessage *Message `json:"lastMessage"`
	UnreadCount int64    `json:"unreadCount"`
}
