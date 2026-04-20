FROM golang:1.21-alpine AS builder

WORKDIR /app

# 不用复制 go.mod，直接编译
COPY src/ .

RUN CGO_ENABLED=0 go build -o myapp .

FROM alpine:3.18

WORKDIR /app

COPY --from=builder /app/myapp .

EXPOSE 8080

CMD ["/app/myapp"]
