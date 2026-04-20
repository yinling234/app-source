FROM golang:1.21-alpine AS builder
LABEL stage=builder
RUN apk add --no-cache git ca-certificates tzdata build-base
WORKDIR /app

# 缓存依赖
COPY src/go.mod src/go.sum ./
RUN go mod download && go mod verify

# 复制源码并构建
COPY src/ .
ARG VERSION=v1.0.0
ARG BUILD_TIME
ARG COMMIT_HASH
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags "\
    -w -s \
    -X main.Version=${VERSION} \
    -X main.BuildTime=${BUILD_TIME} \
    -X main.CommitHash=${COMMIT_HASH}" \
    -o /app/myapp ./main.go

# 运行阶段
FROM alpine:3.18
LABEL maintainer="devops@company.com"

# 安全配置：非 root 用户运行
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -s /sbin/nologin -D appuser

# 安装必要依赖
RUN apk add --no-cache ca-certificates tzdata curl && \
    rm -rf /var/cache/apk/*

# 复制应用
COPY --from=builder --chown=appuser:appgroup /app/myapp /usr/local/bin/

# 工作目录
WORKDIR /home/appuser
USER appuser

# 端口暴露
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 启动命令
ENTRYPOINT ["/usr/local/bin/myapp"]
