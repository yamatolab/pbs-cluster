package main

import (
	"bytes"
	"database/sql"
	"html/template"
	"io"
	"strconv"

	"github.com/gin-gonic/gin"
	_ "modernc.org/sqlite"
)

type KickstartParams struct {
	Hostname string
}

func main() {

	db, err := sql.Open("sqlite", "file:kickstart.db?mode=rwc")
	if err != nil {
		panic(err)
	}
	defer db.Close()

	err = migrateDB(db)
	if err != nil {
		panic(err)
	}

	// Read the kickstart template file
	kickstartTemplate, err := template.ParseFiles("ks_template.cfg")
	if err != nil {
		panic(err)
	}

	// Setup server
	r := gin.Default()
	r.GET("/worker", func(c *gin.Context) {
		var kickstartParams KickstartParams
		// Insert a new host into the database
		id, err := insertHost(db)
		if err != nil {
			c.AbortWithError(500, err)
			return
		}
		kickstartParams.Hostname = "worker-" + strconv.FormatInt(id, 10)

		// Render kickstart
		var kickstartBuffer bytes.Buffer
		kickstartTemplate.Execute(&kickstartBuffer, kickstartParams)

		kickstart, err := io.ReadAll(&kickstartBuffer)

		c.Data(200, "text/plain", kickstart)
	})
	r.Run()
}

func migrateDB(db *sql.DB) error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS hosts (
			id INTEGER PRIMARY KEY NOT NULL,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP
		);`)
	if err != nil {
		return err
	}
	return nil
}

func insertHost(db *sql.DB) (int64, error) {
	result, err := db.Exec("INSERT INTO hosts VALUES(null, null);")
	if err != nil {
		return 0, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return 0, err
	}

	return id, nil
}
