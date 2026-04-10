package apperrors

type AppError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func (e *AppError) Error() string {
	return e.Message
}

var (
	ErrInvalidParams      = &AppError{Code: "INVALID_PARAMS", Message: "请求参数无效"}
	ErrEmailExists        = &AppError{Code: "EMAIL_EXISTS", Message: "邮箱已被注册"}
	ErrInvalidCredentials = &AppError{Code: "INVALID_CREDENTIALS", Message: "邮箱或密码错误"}
	ErrUnauthorized       = &AppError{Code: "UNAUTHORIZED", Message: "未授权"}
	ErrInternal           = &AppError{Code: "INTERNAL_ERROR", Message: "服务器内部错误"}
)
