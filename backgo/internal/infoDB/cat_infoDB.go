package infoDB

import (
	"errors"
	"os"
	"database/sql"
	_"github.com/lib/pq"
	"log"
	"github.com/gin-gonic/gin"
	"net/http"
	"time"
)

type Cat struct{

	ID 			int		`json:"id"`
	Name 		string 	`json:"name"`
	Origin 		string 	`json:"origin"`
	Description	string	`json:"description"`
	Care		string	`json:"care"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// GET /cats
func GetCats() ([]Cat, error) {
    // SQL query
    rows, err := db.Query(`
        SELECT id, name, origin, description, care_instructions, image_url,	created_at,	updated_at
        FROM cat_breeds
        ORDER BY id ASC
    `)

     if err != nil {
        return nil, err 
    }

    defer rows.Close()

    cats := []Cat{}

    for rows.Next() {
        var cat Cat

        err := rows.Scan(&cat.ID, &cat.Name, &cat.Origin, &cat.Description, &cat.Care, &cat.ImageURL,)

       if err != nil { 
		return nil, err 
		}

        cats = append(cats, cat)
    }
	if err = rows.Err(); err != nil { 
		return nil, err 
	}

    return cats, nil
}

func GetCat(id int) (Cat, error){
	var cat Cat
	rows err := QueryRow("
		SELECT id, name, origin, description, care_instructions, image_url,	created_at,	updated_at
		FROM cat_breeds
		WHERE id = $1;")
	
	err := row.Scan(&cat.ID, &cat.Name, &cat.Origin, &cat.Description, &cat.Care, &cat.ImageURL,)

	if err != nil{
		return Cat{}, err
	}
	
	return cat, err
}

func CreateCat(cat *Cat) {
	
}