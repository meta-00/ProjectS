package infoDB

import (
	"time"
)

type Cat struct{

	ID 			int		`json:"id"`
	Name 		string 	`json:"name"`
	Origin 		string 	`json:"origin"`
	Description	string	`json:"description"`
	Care		string	`json:"care"`
	ImageURL	string	`json:"image_url"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// GET /cats
func GetCats() ([]Cat, error) {
    
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

        err := rows.Scan(&cat.ID, 
						&cat.Name, 
						&cat.Origin, 
						&cat.Description, 
						&cat.Care, 
						&cat.ImageURL,
						&cat.CreatedAt,
            			&cat.UpdatedAt,)

       if err != nil { 
		return nil, err 
		}

        cats = append(cats, cat)
    }
	if err = rows.Err(); err != nil { 
		return nil, err 
	}

    return cats, err
}

// GET /cat
func GetCat(id int) (Cat, error){
	var cat Cat
	row:= db.QueryRow(`
		SELECT id, name, origin, description, care_instructions, image_url,	created_at,	updated_at
		FROM cat_breeds
		WHERE id = $1;`,id)
	
	err := row.Scan(&cat.ID, 
					&cat.Name, 
					&cat.Origin, 
					&cat.Description, 
					&cat.Care, 
					&cat.ImageURL,
					&cat.CreatedAt,
        			&cat.UpdatedAt,)

	if err != nil{
		return Cat{}, err
	}
	
	return cat, err
}

// GREATE /cat
func CreateCat(cat *Cat) error {
	
	row := db.QueryRow(
        `INSERT INTO cat_breeds (name, origin, description, care_instructions, image_url)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, created_at, updated_at`,
        cat.Name,
        cat.Origin,
        cat.Description,
        cat.Care,
        cat.ImageURL,
    )

	err := row.Scan(
		&cat.ID,
        &cat.CreatedAt,
        &cat.UpdatedAt,
	)

	return err
}

// UPDATE /cat
func UpdateCat(id int, in *Cat) (Cat, error) {
	var cat Cat
	row := db.QueryRow(
        `UPDATE cat_breeds
         SET name=$1, origin=$2, description=$3, care_instructions=$4, image_url=$5
         WHERE id=$6
         RETURNING id, name, origin, description, care_instructions, image_url, created_at, updated_at`,
        in.Name,
        in.Origin,
        in.Description,
        in.Care,
        in.ImageURL,
        id,
    )

	err := row.Scan(
		&cat.ID,
        &cat.Name,
        &cat.Origin,
        &cat.Description,
        &cat.Care,
        &cat.ImageURL,
        &cat.CreatedAt,
        &cat.UpdatedAt,)

		if err != nil{
			return Cat{}, err
		}

		return cat, err
}

// DELETE /cat
func DeleteCat(id int) error{
	_, err := db.Exec(
		"DELETE FROM cat_breeds WHERE id=$1;",
		id,
	)
	return err
}