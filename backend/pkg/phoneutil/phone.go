package phoneutil

import (
	"errors"
	"regexp"
	"strings"
)

var (
	errInvalidPhone = errors.New("invalid phone")
	cnMainlandPhone = regexp.MustCompile(`^1[3-9]\d{9}$`)
)

// Normalize 将手机号统一为 E.164（当前规则：仅中国大陆手机号，+86 前缀）。
func Normalize(raw string) (string, error) {
	phone := strings.TrimSpace(raw)
	if phone == "" {
		return "", errInvalidPhone
	}

	if strings.HasPrefix(phone, "+86") {
		phone = strings.TrimPrefix(phone, "+86")
	} else if strings.HasPrefix(phone, "86") {
		phone = strings.TrimPrefix(phone, "86")
	}

	if !cnMainlandPhone.MatchString(phone) {
		return "", errInvalidPhone
	}

	return "+86" + phone, nil
}

func Mask(e164 string) string {
	if strings.HasPrefix(e164, "+86") && len(e164) == len("+86")+11 {
		return "+86****" + e164[len(e164)-4:]
	}
	if len(e164) <= 4 {
		return "****"
	}
	return "****" + e164[len(e164)-4:]
}
