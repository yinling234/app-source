# 构建阶段
FROM golang:1.22-alpine AS builder
WORKDIR /app

# 正确！代码在 src 目录下
COPY src/main.go .

RUN CGO_ENABLED=0 GOOS=linux go build -o server main.go

# 运行阶段
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/server .

EXPOSE 8080
CMD ["./server"]
