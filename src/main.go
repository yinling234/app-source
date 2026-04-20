package main

import (
	"fmt"
	"net/http"
)

// 首页接口
func indexHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "✅ Go 服务运行成功！\n")
	fmt.Fprintf(w, "👋 Hello from Go + Docker\n")
}

// 健康检查
func healthHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "ok")
}

func main() {
	http.HandleFunc("/", indexHandler)
	http.HandleFunc("/health", healthHandler)

	fmt.Println("🚀 Go 服务启动，监听端口 8080")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		fmt.Println("启动失败：", err)
	}
}
