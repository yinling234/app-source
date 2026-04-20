# 第一阶段：构建 Go 二进制文件
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY main.go .
# 编译静态二进制文件
RUN CGO_ENABLED=0 GOOS=linux go build -o server main.go

# 第二阶段：运行阶段（极小镜像）
FROM alpine:latest
WORKDIR /root/
# 从构建阶段复制编译好的程序
COPY --from=builder /app/server .

# 对外暴露 8080 端口
EXPOSE 8080

# 启动程序
CMD ["./server"]
