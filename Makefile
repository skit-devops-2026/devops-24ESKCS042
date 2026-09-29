# Every team fills in the commands for their own stack.
# The CI pipeline calls these targets, so the names must not change.
#
# Examples:
#   Node    install: npm ci          test: npm test        build: npm run build
#   Python  install: pip install -r requirements.txt
#                                    test: pytest          build: echo "no build step"
#   Java    install: ./mvnw -B dependency:go-offline
#                                    test: ./mvnw test     build: ./mvnw package

.PHONY: install test build run docker-build docker-up

install:
	@echo "No external dependencies required"

test:
	bash tests/test_project.sh	

build:
	@echo "Static HTML/CSS project - no build step required"

run:
	docker compose up --build

# Needed from M4 onwards
docker-build:
	docker build -t bloodbank .

docker-up:
	docker compose up --build
