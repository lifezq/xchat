package apperrors

type AppError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func (e *AppError) Error() string {
	return e.Message
}

var (
	ErrInvalidParams      = &AppError{Code: "INVALID_PARAM", Message: "参数错误"}
	ErrPhoneInvalid       = &AppError{Code: "PHONE_INVALID", Message: "手机号格式不正确"}
	ErrPhoneExists        = &AppError{Code: "PHONE_ALREADY_EXISTS", Message: "手机号已注册"}
	ErrInvalidCredentials = &AppError{Code: "PHONE_OR_PASSWORD_INVALID", Message: "手机号或密码错误"}
	ErrUnauthorized       = &AppError{Code: "TOKEN_INVALID", Message: "登录状态无效"}
	ErrInternal           = &AppError{Code: "INTERNAL_ERROR", Message: "服务器内部错误"}
)
