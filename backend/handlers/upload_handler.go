package handlers

import (
	"fmt"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type UploadHandler struct {
	uploadDir   string
	maxSize     int64
	allowedExts []string
}

func NewUploadHandler(uploadDir string, maxSize int64, allowedExts []string) *UploadHandler {
	return &UploadHandler{
		uploadDir:   uploadDir,
		maxSize:     maxSize,
		allowedExts: allowedExts,
	}
}

func (h *UploadHandler) UploadVoice(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		writeBadRequest(c, "文件上传失败")
		return
	}

	// 验证文件大小
	if file.Size > h.maxSize {
		writeBadRequest(c, fmt.Sprintf("文件大小超过限制 (%d MB)", h.maxSize/1024/1024))
		return
	}

	// 验证文件类型
	ext := filepath.Ext(file.Filename)
	allowed := false
	for _, allowedExt := range h.allowedExts {
		if ext == allowedExt {
			allowed = true
			break
		}
	}
	if !allowed {
		writeBadRequest(c, "不支持的文件格式")
		return
	}

	// 生成唯一文件名
	filename := fmt.Sprintf("%s_%d%s", uuid.New().String(), time.Now().Unix(), ext)
	filePath := filepath.Join(h.uploadDir, filename)

	if err := c.SaveUploadedFile(file, filePath); err != nil {
		writeInternalError(c, "保存文件失败")
		return
	}

	// 返回文件 URL
	url := fmt.Sprintf("/uploads/voice/%s", filename)
	writeSuccess(c, 200, "上传语音成功", gin.H{"url": url})
}
