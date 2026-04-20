package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

var (
	Version    = "v1.0.0"
	BuildTime  = "unknown"
	CommitHash = "unknown"
)

func main() {
	http.HandleFunc("/", homeHandler)
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/ready", readyHandler)
	http.HandleFunc("/version", versionHandler)

	port := getEnv("PORT", "8080")
	log.Printf("Starting server version %s (build: %s, commit: %s) on port %s",
		Version, BuildTime, CommitHash, port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello from GitOps CI/CD Demo App!\n")
	fmt.Fprintf(w, "Version: %s\n", Version)
	fmt.Fprintf(w, "Environment: %s\n", getEnv("APP_ENV", "development"))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "OK")
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "READY")
}

func versionHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Version: %s\nBuild Time: %s\nCommit Hash: %s\n",
		Version, BuildTime, CommitHash)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
