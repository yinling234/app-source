package main

import (
	"fmt"
	"net/http"
)

// 处理请求的函数
func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello from Docker + Go!")
}

func main() {
	// 访问根路径 / 就会触发 handler
	http.HandleFunc("/", handler)

	// 监听 8080 端口
	fmt.Println("服务启动在 :8080")
	http.ListenAndServe(":8080", nil)
}
