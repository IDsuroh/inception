COMPOSE_FILE = srcs/docker-compose.yml
PROJECT = inception

.PHONY: all build up down logs ps clean fclean re

all: up

up:
	docker compose -p $(PROJECT) -f $(COMPOSE_FILE) up -d --build

build:
	docker compose -p $(PROJECT) -f $(COMPOSE_FILE) build

down:
	docker compose -p $(PROJECT) -f $(COMPOSE_FILE) down

logs:
	docker compose -p $(PROJECT) -f $(COMPOSE_FILE) logs -f

ps:
	docker compose -p $(PROJECT) -f $(COMPOSE_FILE) ps

clean:
	docker compose -p $(PROJECT) -f $(COMPOSE_FILE) down -v

fclean:
	docker compose -p $(PROJECT) -f $(COMPOSE_FILE) down -v --rmi all

re: fclean up