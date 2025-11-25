package handler

import (
	"database/sql"
	"net/http"
	"time"

	"backgo/internal/infoDB"

	"github.com/gin-gonic/gin"
)

// ===================== Authentication Handlers =====================

// LoginHandler handles POST /api/auth/login
func LoginHandler(c *gin.Context) {
	var req infoDB.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	// Get user from database
	user, err := infoDB.GetUserByUsername(req.Username)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}

	// Check if account is active
	if !user.IsActive {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "account is disabled"})
		return
	}

	// Verify password
	if err := infoDB.VerifyPassword(user.PasswordHash, req.Password); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	// Get user roles
	roles, _ := infoDB.GetUserRoles(user.ID)

	// Generate tokens
	accessToken, _ := infoDB.GenerateAccessToken(user.ID, user.Username, roles)
	refreshToken, _ := infoDB.GenerateRefreshToken(user.ID, user.Username)

	// Store refresh token
	expiresAt := time.Now().Add(7 * 24 * time.Hour)
	_ = infoDB.StoreRefreshToken(user.ID, refreshToken, expiresAt)

	// Update last login
	_ = infoDB.UpdateLastLogin(user.ID)

	// Log audit
	infoDB.LogAudit(user.ID, "login", "auth", nil, gin.H{"username": user.Username}, c)

	// Set tokens as httpOnly cookies
	c.SetCookie("access_token", accessToken, 900, "/", "", false, true)      // 15 minutes
	c.SetCookie("refresh_token", refreshToken, 604800, "/", "", false, true) // 7 days

	// Return response
	c.JSON(http.StatusOK, gin.H{
		"user": infoDB.UserInfo{
			ID:       user.ID,
			Username: user.Username,
			Email:    user.Email,
			Roles:    roles,
		},
	})
}

// RefreshTokenHandler handles POST /api/auth/refresh
func RefreshTokenHandler(c *gin.Context) {
	// Try to get refresh token from cookie first
	refreshToken, err := c.Cookie("refresh_token")
	if err != nil {
		// If not in cookie, try to get from request body
		var req infoDB.RefreshRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}
		refreshToken = req.RefreshToken
	}

	// Validate refresh token
	userID, valid := infoDB.IsRefreshTokenValid(refreshToken)
	if !valid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired refresh token"})
		return
	}

	// Get user details
	user, err := infoDB.GetUserByUsername("") // You might want to create GetUserByID
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}

	// Get user roles
	roles, _ := infoDB.GetUserRoles(userID)

	// Generate new access token
	accessToken, _ := infoDB.GenerateAccessToken(userID, user.Username, roles)

	// Set new access token cookie
	c.SetCookie("access_token", accessToken, 900, "/", "", false, true)

	c.JSON(http.StatusOK, gin.H{
		"message": "token refreshed successfully",
	})
}

// LogoutHandler handles POST /api/auth/logout
func LogoutHandler(c *gin.Context) {
	// Get refresh token from cookie
	refreshToken, err := c.Cookie("refresh_token")
	if err == nil {
		// Revoke refresh token if exists
		_ = infoDB.RevokeRefreshToken(refreshToken)
	}

	// Clear cookies
	c.SetCookie("access_token", "", -1, "/", "", false, true)
	c.SetCookie("refresh_token", "", -1, "/", "", false, true)

	c.JSON(http.StatusOK, gin.H{
		"message": "logged out successfully",
	})
}

// GetMeHandler handles GET /api/auth/me - Get current user info
func GetMeHandler(c *gin.Context) {
	// Get user from context (set by auth middleware)
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	username, _ := c.Get("username")
	roles, _ := c.Get("roles")

	c.JSON(http.StatusOK, gin.H{
		"user": infoDB.UserInfo{
			ID:       userID.(int),
			Username: username.(string),
			Email:    "",
			Roles:    roles.([]string),
		},
	})
}