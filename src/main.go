cat > src/main.go << 'EOF'
package main

import (
	"fmt"
	"net/http"
)

func healthHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "OK")
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello from AI Gateway! Service running on port 8080")
}

func main() {
	http.HandleFunc("/", indexHandler)
	http.HandleFunc("/health", healthHandler)

	fmt.Println("Server starting on :8080...")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		fmt.Printf("Failed to start server: %v\n", err)
	}
}
EOF
