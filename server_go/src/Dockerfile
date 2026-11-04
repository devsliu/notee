FROM golang:1.25-alpine AS builder

WORKDIR /app

# 安装编译依赖 (modernc.org/sqlite 纯 Go, 但我们之前编译的是 cgo 版本)
RUN apk add --no-cache gcc musl-dev

COPY go.mod go.sum ./
RUN go mod download
COPY . .
ENV CGO_ENABLED=1
RUN go build -o /app/app

FROM alpine:latest
WORKDIR /app
RUN apk add --no-cache sqlite-libs
COPY --from=builder /app/app .
EXPOSE 10001
CMD ["./app"]
