package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func writeSuccess(c *gin.Context, status int, message string, data gin.H) {
	resp := gin.H{
		"code":    "OK",
		"message": message,
		"data":    data,
	}
	// legacy flat fields for existing clients
	for k, v := range data {
		resp[k] = v
	}
	c.JSON(status, resp)
}

func writeBadRequest(c *gin.Context, message string) {
	writeFailure(c, http.StatusBadRequest, "BAD_REQUEST", message)
}

func writeNotFound(c *gin.Context, message string) {
	writeFailure(c, http.StatusNotFound, "NOT_FOUND", message)
}

func writeInternalError(c *gin.Context, message string) {
	writeFailure(c, http.StatusInternalServerError, "INTERNAL_ERROR", message)
}

func writeConflict(c *gin.Context, message string) {
	writeFailure(c, http.StatusConflict, "CONFLICT", message)
}

func writeFailure(c *gin.Context, status int, code, message string) {
	c.JSON(status, gin.H{
		"code":    code,
		"message": message,
		// legacy field for existing clients
		"error": message,
	})
}
