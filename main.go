// Sample run-helloworld is a minimal Cloud Run service.
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/tosh223/rfa/search"
)

func main() {
	log.Print("starting server...")
	http.HandleFunc("/", handler)

	// Determine port for HTTP service.
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		log.Printf("defaulting to port %s", port)
	}

	// Start HTTP server.
	log.Printf("listening on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func handler(w http.ResponseWriter, r *http.Request) {
	var Param struct {
		ProjectID string `json:"project_id"`
		Location  string `json:"location"`
		TwitterID string `json:"twitter_id"`
		Size      string `json:"size"`
	}

	if err := json.NewDecoder(r.Body).Decode(&Param); err != nil {
		log.Fatal(err)
	}
	if Param.ProjectID == "" {
		log.Fatal("Parameters not found.")
	}

	var rfa search.Rfa
	rfa.ProjectID = Param.ProjectID
	rfa.Location = Param.Location
	rfa.TwitterID = Param.TwitterID
	rfa.Size = Param.Size
	rfa.Search()
}
