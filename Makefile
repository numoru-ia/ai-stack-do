.PHONY: up down logs certs seed-ollama backup restore health update

DOMAIN ?= $(shell grep ^DOMAIN= .env | cut -d= -f2)

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f --tail=100

certs:
	docker run --rm -it \
		-v $(PWD)/certs:/etc/letsencrypt \
		-v $(PWD)/nginx/webroot:/var/www/html \
		certbot/certbot:latest certonly \
		--webroot -w /var/www/html \
		-d api.$(DOMAIN) \
		-d langfuse.$(DOMAIN) \
		-d grafana.$(DOMAIN) \
		-d qdrant.$(DOMAIN) \
		--agree-tos --no-eff-email -m admin@$(DOMAIN)
	docker compose exec nginx nginx -s reload

seed-ollama:
	docker compose exec ollama ollama pull llama3.3:8b-instruct-q4_K_M
	docker compose exec ollama ollama pull qwen2.5:7b-instruct-q4_K_M
	docker compose exec ollama ollama pull nomic-embed-text

backup:
	docker compose run --rm restic backup

restore:
	@echo "Snapshots:"
	@docker compose run --rm restic snapshots
	@echo "Run: docker compose run --rm restic restore <id> --target /"

health:
	@curl -fsS http://localhost:6333/readyz && echo " qdrant ok" || echo " qdrant FAIL"
	@curl -fsS http://localhost:4000/health && echo " litellm ok" || echo " litellm FAIL"
	@curl -fsS http://localhost:3000/api/public/health && echo " langfuse ok" || echo " langfuse FAIL"
	@curl -fsS http://localhost:11434/api/tags && echo " ollama ok" || echo " ollama FAIL"

update:
	docker compose pull
	docker compose up -d
