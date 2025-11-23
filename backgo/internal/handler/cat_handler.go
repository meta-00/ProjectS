package handler

import (
    "net/http"
	"strconv"
    "github.com/gin-gonic/gin"

    "backgo/internal/infoDB" 
)

func GetCatHandler(c *gin.Context) {
	catID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	cat, err := GetCat(catID)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "cat not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, cat)
}

func GetCatsHandler(c *gin.Context){
	cats, err := GetCats()
	if err != nil{
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, cats)
}

func CreateCatHandler(c *gin.Context){
	var newCat Cat
	
	if err := c.ShouldBindJSON(&newCat); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	
	if err := CreateCat(&newCat); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}


	c.JSON(http.StatusCreated, newCat)
}

func UpdateCatHandler(c *gin.Context){
	catID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	var newCat Cat
	if err := c.ShouldBindJSON(&newCat); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return 
	}

	updatedCat, err := UpdateCat(catID, &newCat)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "cat not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, updatedCat)
}

func DeleteCatHandler(c *gin.Context){
	catID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	err = DeleteCat(catID)

	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "cat not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	 c.Status(http.StatusNoContent)
}