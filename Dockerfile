FROM golang:alpine AS builder 
WORKDIR /app
COPY src/go.mod src/go.sum ./
COPY src/main.go .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o ai-gateway .
FROM alpine:latestWORKDIR /app
COPY --from=builder /app/ai-gateway .
EXPOSE 3000
CMD ["./ai-gateway"]
