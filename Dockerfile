FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY src/ .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o ai-gateway .

# 修复后
FROM alpine:latest
WORKDIR /app

COPY --from=builder /app/ai-gateway .
EXPOSE 3000
CMD ["/app/ai-gateway"]
