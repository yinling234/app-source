# 构建阶段
FROM golang:alpine AS builder
WORKDIR /app

# 复制项目文件（正确路径）
COPY go.mod .
COPY src/main.go .

# 编译
RUN CGO_ENABLED=0 GOOS=linux go build -o ai-gateway .

# 运行阶段
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/ai-gateway .

EXPOSE 8080
CMD ["./ai-gateway"]
