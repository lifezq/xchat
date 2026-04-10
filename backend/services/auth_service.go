package services

import (
	"chat-backend/models"
	"chat-backend/pkg/apperrors"
	"chat-backend/pkg/phoneutil"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type AuthService struct {
	db            *gorm.DB
	jwtSecret     string
	jwtExpiration time.Duration
	refreshTTL    time.Duration
}

func NewAuthService(db *gorm.DB, jwtSecret string, jwtExpiration time.Duration) *AuthService {
	return &AuthService{
		db:            db,
		jwtSecret:     jwtSecret,
		jwtExpiration: jwtExpiration,
		refreshTTL:    7 * 24 * time.Hour,
	}
}

func (s *AuthService) Register(phone, password, nickname string) (string, string, *models.User, error) {
	normalizedPhone, err := phoneutil.Normalize(phone)
	if err != nil {
		return "", "", nil, apperrors.ErrPhoneInvalid
	}

	var existingUser models.User
	if err := s.db.Where("phone = ?", normalizedPhone).First(&existingUser).Error; err == nil {
		return "", "", nil, apperrors.ErrPhoneExists
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", "", nil, err
	}

	user := &models.User{
		Phone:    normalizedPhone,
		Password: string(hashedPassword),
		Nickname: nickname,
	}

	if err := s.db.Create(user).Error; err != nil {
		return "", "", nil, err
	}

	accessToken, err := s.generateAccessToken(user.ID)
	if err != nil {
		return "", "", nil, err
	}

	refreshToken, err := s.createSession(user.ID)
	if err != nil {
		return "", "", nil, err
	}

	return accessToken, refreshToken, user, nil
}

func (s *AuthService) Login(phone, password string) (string, string, *models.User, error) {
	normalizedPhone, err := phoneutil.Normalize(phone)
	if err != nil {
		return "", "", nil, apperrors.ErrPhoneInvalid
	}

	var user models.User
	if err := s.db.Where("phone = ?", normalizedPhone).First(&user).Error; err != nil {
		return "", "", nil, apperrors.ErrInvalidCredentials
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password)); err != nil {
		return "", "", nil, apperrors.ErrInvalidCredentials
	}

	accessToken, err := s.generateAccessToken(user.ID)
	if err != nil {
		return "", "", nil, err
	}

	refreshToken, err := s.createSession(user.ID)
	if err != nil {
		return "", "", nil, err
	}

	return accessToken, refreshToken, &user, nil
}

func (s *AuthService) Refresh(refreshToken string) (string, string, error) {
	tokenHash := hashToken(refreshToken)

	var session models.AuthSession
	err := s.db.Where("refresh_token_hash = ? AND revoked_at IS NULL", tokenHash).First(&session).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return "", "", apperrors.ErrUnauthorized
		}
		return "", "", err
	}

	if time.Now().After(session.ExpiresAt) {
		return "", "", apperrors.ErrUnauthorized
	}

	newRefreshToken, err := generateSecureToken(32)
	if err != nil {
		return "", "", err
	}
	newRefreshHash := hashToken(newRefreshToken)

	session.RefreshTokenHash = newRefreshHash
	session.ExpiresAt = time.Now().Add(s.refreshTTL)
	if err := s.db.Save(&session).Error; err != nil {
		return "", "", err
	}

	accessToken, err := s.generateAccessToken(session.UserID)
	if err != nil {
		return "", "", err
	}

	return accessToken, newRefreshToken, nil
}

func (s *AuthService) Logout(refreshToken string) error {
	tokenHash := hashToken(refreshToken)
	now := time.Now()
	result := s.db.Model(&models.AuthSession{}).
		Where("refresh_token_hash = ? AND revoked_at IS NULL", tokenHash).
		Update("revoked_at", &now)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return apperrors.ErrUnauthorized
	}
	return nil
}

func (s *AuthService) createSession(userID uint) (string, error) {
	refreshToken, err := generateSecureToken(32)
	if err != nil {
		return "", err
	}

	session := &models.AuthSession{
		UserID:           userID,
		RefreshTokenHash: hashToken(refreshToken),
		ExpiresAt:        time.Now().Add(s.refreshTTL),
	}
	if err := s.db.Create(session).Error; err != nil {
		return "", err
	}
	return refreshToken, nil
}

func (s *AuthService) generateAccessToken(userID uint) (string, error) {
	claims := jwt.MapClaims{
		"user_id": userID,
		"exp":     time.Now().Add(s.jwtExpiration).Unix(),
		"iat":     time.Now().Unix(),
		"jti":     fmt.Sprintf("%d-%d", userID, time.Now().UnixNano()),
		"typ":     "access",
		"sub":     strconv.FormatUint(uint64(userID), 10),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.jwtSecret))
}

func generateSecureToken(byteLen int) (string, error) {
	b := make([]byte, byteLen)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
