package main

import(
	//"backgo/internal/handler"
	"github.com/gin-gonic/gin"
)

func main(){

	r := gin.Default()

	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{"success":"test"})
	})
	
	r.Run(":8080")
}