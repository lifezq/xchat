.PHONY: build run test clean docker-build docker-up docker-down

build:
	go build -o main .

run:
	go run main.go

test:
	go test -v ./...

clean:
	rm -f main
	rm -rf uploads/*

docker-build:
	docker-compose build

docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

docker-logs:
	docker-compose logs -f backend

migrate:
	go run main.go migrate

dev:
	air

install-air:
	go install github.com/cosmtrek/air@latest
