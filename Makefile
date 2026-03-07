# Kodemeio Mattermost - Team Chat
COMPOSE = docker compose -f docker-compose.prod.yml --env-file .env.prod

.PHONY: help up down restart logs logs-mm ps health validate backup dashboard test lint

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

logs-mm:
	$(COMPOSE) logs -f mattermost

ps:
	$(COMPOSE) ps

health:
	@./scripts/health.sh 2>/dev/null || $(COMPOSE) ps --format "table {{.Name}}\t{{.Status}}"

validate:
	$(COMPOSE) config --quiet && echo "Compose file is valid"

backup:
	@./scripts/deploy.sh backup 2>/dev/null || echo "Run: ./scripts/deploy.sh backup"

dashboard:
	@./scripts/dashboard.sh 2>/dev/null || echo "Run: ./scripts/dashboard.sh"

test:
	@echo "Running validation..."
	@$(COMPOSE) config --quiet && echo "Compose: OK"
	@bash -n scripts/*.sh scripts/lib/*.sh && echo "Scripts: OK"

lint:
	@ERRORS=0; for s in scripts/*.sh scripts/lib/*.sh; do \
		if [ -f "$$s" ]; then bash -n "$$s" || ERRORS=1; fi; \
	done; \
	if [ "$$ERRORS" -eq 0 ]; then echo "All scripts: syntax OK"; fi

help:
	@echo "Kodemeio Mattermost - Team Chat"
	@echo ""
	@echo "Lifecycle:"
	@echo "  make up              Start services"
	@echo "  make down            Stop services"
	@echo "  make restart         Restart services"
	@echo "  make logs            Follow logs"
	@echo "  make logs-mm         Follow Mattermost logs"
	@echo "  make ps              Show services"
	@echo ""
	@echo "Operations:"
	@echo "  make health          Check health"
	@echo "  make validate        Validate config"
	@echo "  make backup          Create backup"
	@echo "  make dashboard       Show dashboard"
	@echo ""
	@echo "Quality:"
	@echo "  make test            Run tests"
	@echo "  make lint            Lint scripts"
