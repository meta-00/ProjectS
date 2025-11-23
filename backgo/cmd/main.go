package main

import(
	"os"
	"backgo/internal/handler"
	"github.com/gin-gonic/gin"
	"database/sql"
	"log"
	"fmt"
    _ "github.com/lib/pq"
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

func main(){

	r := gin.Default()

	r.GET("/cat",GetCatsHandler)
	r.GET("/cat/:id", GetCatHandler)
	r.POST("/cat",CreateCatHandler)
	r.PUT("/cat/:id",UpdateCatHandler)
	r.DELETE("/cat/:id",DeleteCatHandler)
	
	r.Run(":8080")
}