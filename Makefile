.PHONY: build test docker clean

APP_NAME := myapp
VERSION := $(shell git describe --tags --always --dirty)
BUILD_TIME := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
COMMIT_HASH := $(shell git rev-parse --short HEAD)
IMAGE_REGISTRY ?= 192.168.30.11:30002
IMAGE_NAME := $(IMAGE_REGISTRY)/library/$(APP_NAME)

build:
	@echo "Building $(APP_NAME) version $(VERSION)..."
	cd src && CGO_ENABLED=0 GOOS=linux go build \
		-ldflags "\
		-w -s \
		-X main.Version=$(VERSION) \
		-X main.BuildTime=$(BUILD_TIME) \
		-X main.CommitHash=$(COMMIT_HASH)" \
		-o ../bin/$(APP_NAME) ./main.go

test:
	@echo "Running tests..."
	cd src && go test -v -race ./... -coverprofile=../coverage.out
	go tool cover -func=../coverage.out

docker:
	@echo "Building Docker image..."
	docker build \
		--build-arg VERSION=$(VERSION) \
		--build-arg BUILD_TIME=$(BUILD_TIME) \
		--build-arg COMMIT_HASH=$(COMMIT_HASH) \
		-t $(IMAGE_NAME):$(VERSION) \
		-t $(IMAGE_NAME):latest .

docker-push: docker
	@echo "Pushing Docker image..."
	docker push $(IMAGE_NAME):$(VERSION)
	docker push $(IMAGE_NAME):latest

clean:
	@echo "Cleaning..."
	rm -rf bin/ coverage.out

fmt:
	cd src && go fmt ./...

vet:
	cd src && go vet ./...

lint:
	@if command -v golangci-lint >/dev/null; then \
		cd src && golangci-lint run; \
	else \
		echo "golangci-lint not installed, skipping..."; \
	fi

all: fmt vet lint test build docker
