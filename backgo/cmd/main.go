package main

import(
	"database/sql"
	"fmt"
	"log"
	"time"
	"os"

	"backgo/internal/handler"
	"backgo/internal/infoDB"
	"backgo/internal/middleware"

	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
	"github.com/gin-contrib/cors"
)

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

var db *sql.DB

func initDB() {
	var err error
	host := getEnv("DB_HOST", "localhost")
	port := getEnv("DB_PORT", "5432")
	user := getEnv("DB_USER", "catbase_user")
	password := getEnv("DB_PASSWORD", "your_strong_password")
	name := getEnv("DB_NAME", "catbase")

	conStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, name)

	db, err = sql.Open("postgres", conStr)
	if err != nil {
		log.Fatal("Failed to open database:", err)
	}

	// กำหนดจำนวน Connection สูงสุด
	db.SetMaxOpenConns(25)

	// กำหนดจำนวน Idle connection สูงสุด
	db.SetMaxIdleConns(20)

	// กำหนดอายุของ Connection
	db.SetConnMaxLifetime(5 * time.Minute)

	err = db.Ping()
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	log.Println("Connected to the database successfully!")
}

func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

func main(){
	initDB()
	infoDB.SetDB(db)
	defer db.Close()

	r := gin.Default()
	r.Use(cors.Default())
	r.Use(corsMiddleware())

	// ===================== PUBLIC ROUTES =====================
	public := r.Group("/api")
	{
		// Health check
		public.GET("/health", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"status":  "ok",
				"message": "Cat Breeds API is running",
			})
		})

		// Auth routes
		auth := public.Group("/auth")
		{
			auth.POST("/login", handler.LoginHandler)
			auth.POST("/refresh", handler.RefreshTokenHandler)
			auth.POST("/logout", handler.LogoutHandler)
		}

		// Public cat routes (view only)
		public.GET("/cats", handler.GetAllCatsHandler)
		public.GET("/cats/:id", handler.GetCatHandler)
		public.GET("/cats/:id/reactions", handler.GetCatReactionStatsHandler)
		public.GET("/cats/:id/discussions", handler.GetCatDiscussionsHandler)
	}

	// ===================== USER PROTECTED ROUTES =====================
	user := r.Group("/api")
	user.Use(middleware.AuthMiddleware())
	{
		// Current user info
		user.GET("/auth/me", handler.GetMeHandler)

		// Cat reactions (like/dislike)
		user.POST("/cats/:id/react", handler.ToggleCatReactionHandler)

		// Discussions (comments)
		user.POST("/discussions", handler.CreateDiscussionHandler)
		user.PUT("/discussions/:id", handler.UpdateDiscussionHandler)
		user.DELETE("/discussions/:id", handler.DeleteDiscussionHandler)
		user.POST("/discussions/:id/react", handler.ToggleDiscussionReactionHandler)
	}

	// ===================== ADMIN ROUTES =====================
	admin := r.Group("/api/admin")
	admin.Use(middleware.AuthMiddleware(), middleware.RequireRole("admin"))
	{
		// Cat breed management
		admin.POST("/cats", handler.CreateCatHandler)
		admin.PUT("/cats/:id", handler.UpdateCatHandler)
		admin.DELETE("/cats/:id", handler.DeleteCatHandler)
	}

	
	r.Run(":8080")
}