package models

import (
	"context"
	"fmt"
	"strings"

	"github.com/lifezq/log"
	"gorm.io/gorm"
)

var ctx = context.Background()

// AutoMigrate 自动迁移所有数据表
func AutoMigrate(db *gorm.DB) error {
	log.Info(ctx, "开始数据库表迁移...")

	// 迁移所有模型
	err := db.AutoMigrate(
		&User{},
		&AuthSession{},
		&Message{},
		&Friendship{},
	)

	if err != nil {
		log.Errorf(ctx, "数据库迁移失败: %v", err)
		return err
	}

	log.Info(ctx, "数据库表迁移完成")

	// 创建额外的索引
	if err := createIndexes(db); err != nil {
		log.Errorf(ctx, "创建索引失败: %v", err)
		return err
	}

	log.Info(ctx, "数据库索引创建完成")
	return nil
}

// createIndexes 创建额外的复合索引
func createIndexes(db *gorm.DB) error {
	// 为消息表创建复合索引，优化会话消息查询
	if err := ensureIndex(db, "messages", "idx_sender_receiver_time", "sender_id, receiver_id, created_at"); err != nil {
		log.Warnf(ctx, "创建索引 messages.idx_sender_receiver_time 失败: %v", err)
	} else {
		log.Info(ctx, "创建索引: messages.idx_sender_receiver_time")
	}

	// 为好友关系表创建索引
	if err := ensureIndex(db, "friendships", "idx_user_status", "user_id, status"); err != nil {
		log.Warnf(ctx, "创建索引 friendships.idx_user_status 失败: %v", err)
	} else {
		log.Info(ctx, "创建索引: friendships.idx_user_status")
	}

	return nil
}

func ensureIndex(db *gorm.DB, tableName, indexName, columns string) error {
	exists, err := indexExists(db, tableName, indexName)
	if err != nil {
		return err
	}
	if exists {
		return nil
	}

	createSQL := fmt.Sprintf("CREATE INDEX %s ON %s (%s)", indexName, tableName, columns)
	if err := db.Exec(createSQL).Error; err != nil {
		// 并发启动场景下可能出现重复创建，忽略该错误
		if isDuplicateIndexError(err) {
			return nil
		}
		return err
	}

	return nil
}

func ensureUniqueIndex(db *gorm.DB, tableName, indexName, columns string) error {
	exists, err := indexExists(db, tableName, indexName)
	if err != nil {
		return err
	}
	if exists {
		return nil
	}

	createSQL := fmt.Sprintf("CREATE UNIQUE INDEX %s ON %s (%s)", indexName, tableName, columns)
	if err := db.Exec(createSQL).Error; err != nil {
		if isDuplicateIndexError(err) {
			return nil
		}
		return err
	}
	return nil
}

func indexExists(db *gorm.DB, tableName, indexName string) (bool, error) {
	var count int64
	err := db.Raw(
		`SELECT COUNT(1)
FROM information_schema.statistics
WHERE table_schema = DATABASE() AND table_name = ? AND index_name = ?`,
		tableName, indexName,
	).Scan(&count).Error
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

func isDuplicateIndexError(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "duplicate key name") || strings.Contains(msg, "already exists")
}

// DropAllTables 删除所有表（谨慎使用，仅用于开发环境）
func DropAllTables(db *gorm.DB) error {
	log.Warn(ctx, "警告：正在删除所有数据表...")

	err := db.Migrator().DropTable(
		&User{},
		&AuthSession{},
		&Message{},
		&Friendship{},
	)

	if err != nil {
		log.Errorf(ctx, "删除数据表失败: %v", err)
		return err
	}

	log.Info(ctx, "所有数据表已删除")
	return nil
}
