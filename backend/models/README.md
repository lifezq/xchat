# 数据库模型说明

## 概述

本项目使用 GORM 作为 ORM 框架，支持自动迁移和索引管理。

## 数据表结构

### 1. users（用户表）

| 字段 | 类型 | 说明 | 索引 |
|------|------|------|------|
| id | uint | 主键 | PRIMARY |
| email | string(100) | 邮箱（唯一） | UNIQUE |
| password | string(255) | 密码（加密） | - |
| nickname | string(50) | 昵称 | - |
| avatar | string(255) | 头像 URL | - |
| status | string(20) | 在线状态 | - |
| created_at | timestamp | 创建时间 | - |
| updated_at | timestamp | 更新时间 | - |
| deleted_at | timestamp | 软删除时间 | INDEX |

**状态值：**
- `online`: 在线
- `offline`: 离线
- `busy`: 忙碌

### 2. messages（消息表）

| 字段 | 类型 | 说明 | 索引 |
|------|------|------|------|
| id | uint | 主键 | PRIMARY |
| sender_id | uint | 发送者 ID | INDEX |
| receiver_id | uint | 接收者 ID | INDEX |
| content | text | 消息内容 | - |
| type | string(20) | 消息类型 | - |
| voice_url | string(255) | 语音文件 URL | - |
| duration | int | 语音时长（秒） | - |
| is_read | bool | 是否已读 | INDEX |
| created_at | timestamp | 创建时间 | INDEX |

**消息类型：**
- `text`: 文本消息
- `voice`: 语音消息
- `image`: 图片消息
- `file`: 文件消息

**复合索引：**
- `idx_sender_receiver`: (sender_id, receiver_id)
- `idx_sender_receiver_time`: (sender_id, receiver_id, created_at)

### 3. friendships（好友关系表）

| 字段 | 类型 | 说明 | 索引 |
|------|------|------|------|
| id | uint | 主键 | PRIMARY |
| user_id | uint | 用户 ID | INDEX |
| friend_id | uint | 好友 ID | INDEX |
| status | string(20) | 关系状态 | - |
| created_at | timestamp | 创建时间 | - |
| updated_at | timestamp | 更新时间 | - |

**关系状态：**
- `pending`: 待确认
- `accepted`: 已接受
- `blocked`: 已屏蔽

**复合索引：**
- `idx_user_friend`: (user_id, friend_id)
- `idx_unique_friendship`: (user_id, friend_id) UNIQUE
- `idx_user_status`: (user_id, status)

## 使用方法

### 自动迁移

在应用启动时自动执行：

```go
import "chat-backend/models"

// 自动迁移所有表
if err := models.AutoMigrate(db); err != nil {
    log.Fatal(err)
}
```

### 删除所有表（开发环境）

```go
// 谨慎使用！会删除所有数据
if err := models.DropAllTables(db); err != nil {
    log.Fatal(err)
}
```

## 外键约束

所有外键都设置了 `OnDelete:CASCADE`，当删除用户时会自动删除相关的：
- 发送和接收的消息
- 好友关系

## 性能优化

1. **索引优化**
   - 为高频查询字段创建索引
   - 使用复合索引优化多条件查询
   - 为时间字段创建索引支持排序

2. **查询优化**
   - 使用 `Preload` 预加载关联数据
   - 避免 N+1 查询问题
   - 使用 `Select` 只查询需要的字段

3. **软删除**
   - User 表使用软删除，保留历史数据
   - 查询时自动过滤已删除记录

## 注意事项

1. 密码字段使用 `json:"-"` 标签，不会在 JSON 序列化时暴露
2. 所有表名使用复数形式（users, messages, friendships）
3. 时间字段使用 GORM 自动管理（created_at, updated_at）
4. 使用 `gorm.DeletedAt` 实现软删除功能
