G = $(shell printf "\033[0;32m")
C = $(shell printf "\033[0m")

build:
	@docker build -t mongo:keyfile .
	@echo "$(G)[OK]$(C)"

install:
	@docker-compose -f mongo_server/docker-compose.yaml up -d
	@echo "$(G)[OK]$(C)"

redis:
	@docker-compose -f redis_server/docker-compose.yaml up -d
	@echo "$(G)[OK]$(C)"