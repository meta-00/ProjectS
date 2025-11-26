package handler

import (
	"database/sql"
	"net/http"
	"strconv"

	"backgo/internal/infoDB"

	"github.com/gin-gonic/gin"
)

// ===================== Cat Breed Handlers =====================

// GetAllCatsHandler handles GET /api/cats
func GetAllCatsHandler(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	// Get current user ID if authenticated
	var currentUserID *int
	if userID, exists := c.Get("user_id"); exists {
		uid := userID.(int)
		currentUserID = &uid
	}

	cats, err := infoDB.GetAllCats(currentUserID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data":  cats,
		"count": len(cats),
	})
}

// GetCatHandler handles GET /api/cats/:id
func GetCatHandler(c *gin.Context) {
	catID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	// Get current user ID if authenticated
	var currentUserID *int
	if userID, exists := c.Get("user_id"); exists {
		uid := userID.(int)
		currentUserID = &uid
	}

	cat, err := infoDB.GetCat(catID, currentUserID)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "cat not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, cat)
}

// CreateCatHandler handles POST /api/admin/cats (Admin only)
func CreateCatHandler(c *gin.Context) {
    userIDVal, exists := c.Get("user_id")
    if !exists {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
        return
    }
    userID := userIDVal.(int)

    var req infoDB.CreateCatRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{
            "error":   "invalid request body",
            "details": err.Error(),
        })
        return
    }

    cat, err := infoDB.CreateCat(userID, req)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    c.JSON(http.StatusCreated, cat)
}

// UpdateCatHandler handles PUT /api/admin/cats/:id (Admin only)
func UpdateCatHandler(c *gin.Context) {
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	catID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	var req infoDB.UpdateCatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body", "details": err.Error()})
		return
	}

	cat, err := infoDB.UpdateCat(catID, req)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "cat not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, cat)
}

// DeleteCatHandler handles DELETE /api/admin/cats/:id (Admin only)
func DeleteCatHandler(c *gin.Context) {
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	catID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	err = infoDB.DeleteCat(catID)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "cat not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "cat deleted successfully"})
}

// ===================== Cat Reaction Handlers (Like/Dislike) =====================

// ToggleCatReactionHandler handles POST /api/cats/:id/react
func ToggleCatReactionHandler(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	catID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	var req struct {
		ReactionType string `json:"reaction_type" binding:"required,oneof=like dislike"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body", "details": err.Error()})
		return
	}

	response, err := infoDB.ToggleCatReaction(catID, userID.(int), req.ReactionType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, response)
}

// GetCatReactionStatsHandler handles GET /api/cats/:id/reactions
func GetCatReactionStatsHandler(c *gin.Context) {
	catID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	var currentUserID *int
	if userID, exists := c.Get("user_id"); exists {
		uid := userID.(int)
		currentUserID = &uid
	}

	response, err := infoDB.GetCatReactionStats(catID, currentUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, response)
}

// ===================== Discussion Handlers =====================

// GetCatDiscussionsHandler handles GET /api/cats/:id/discussions
func GetCatDiscussionsHandler(c *gin.Context) {
	catID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	var currentUserID *int
	if userID, exists := c.Get("user_id"); exists {
		uid := userID.(int)
		currentUserID = &uid
	}

	discussions, err := infoDB.GetCatDiscussions(catID, currentUserID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data":  discussions,
		"count": len(discussions),
	})
}

// CreateDiscussionHandler handles POST /api/discussions
func CreateDiscussionHandler(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req infoDB.CreateDiscussionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body", "details": err.Error()})
		return
	}

	discussion, err := infoDB.CreateDiscussion(userID.(int), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, discussion)
}

// UpdateDiscussionHandler handles PUT /api/discussions/:id
func UpdateDiscussionHandler(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	discussionID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid discussion id"})
		return
	}

	var req infoDB.UpdateDiscussionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body", "details": err.Error()})
		return
	}

	discussion, err := infoDB.UpdateDiscussion(discussionID, userID.(int), req)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "discussion not found or you don't have permission"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, discussion)
}

// DeleteDiscussionHandler handles DELETE /api/discussions/:id
func DeleteDiscussionHandler(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	discussionID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid discussion id"})
		return
	}

	// Check if user is admin/moderator
	roles, _ := c.Get("roles")
	isAdmin := false
	if roles != nil {
		for _, role := range roles.([]string) {
			if role == "admin" || role == "moderator" {
				isAdmin = true
				break
			}
		}
	}

	err = infoDB.DeleteDiscussion(discussionID, userID.(int), isAdmin)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "discussion not found or you don't have permission"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "discussion deleted successfully"})
}

// ToggleDiscussionReactionHandler handles POST /api/discussions/:id/react
func ToggleDiscussionReactionHandler(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	discussionID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid discussion id"})
		return
	}

	var req struct {
		ReactionType string `json:"reaction_type" binding:"required,oneof=like dislike"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body", "details": err.Error()})
		return
	}

	response, err := infoDB.ToggleDiscussionReaction(discussionID, userID.(int), req.ReactionType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, response)
}