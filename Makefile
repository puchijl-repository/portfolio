# =============================================================================
# PORTFOLIO — Makefile
# Comandos rápidos para desarrollo y demo
# =============================================================================

.PHONY: help infra services tools down reset logs ps health

# Muestra este menú
help:
	@echo ""
	@echo "  Portfolio — Comandos disponibles"
	@echo ""
	@echo "  make infra       Levanta toda la infraestructura compartida"
	@echo "  make services    Levanta los microservicios Java (requiere infra)"
	@echo "  make all         Levanta todo (infra + services)"
	@echo "  make tools       Levanta herramientas de desarrollo (pgAdmin, Redis Commander)"
	@echo "  make down        Detiene todos los contenedores"
	@echo "  make reset       Detiene + borra volúmenes + levanta infra (demo reset)"
	@echo "  make logs        Logs en tiempo real de todos los servicios"
	@echo "  make ps          Estado de todos los contenedores"
	@echo "  make health      Health check de todos los servicios"
	@echo "  make build       Construye las imágenes Docker de los servicios"
	@echo ""

# Infraestructura base (Kafka, RabbitMQ, PostgreSQL, Redis, Kong, observabilidad, n8n)
infra:
	docker compose --profile infra up -d
	@echo ""
	@echo "  Infraestructura levantada. Accesos:"
	@echo "  Traefik Dashboard  → http://localhost:8080"
	@echo "  Jaeger UI          → http://localhost:16686"
	@echo "  Grafana            → http://localhost:3001  (admin/admin)"
	@echo "  Prometheus         → http://localhost:9090"
	@echo "  Kafdrop (Kafka)    → http://kafdrop.localhost"
	@echo "  RabbitMQ Mgmt      → http://localhost:15672 (portfolio/rabbitmq_secret)"
	@echo "  Kong Admin         → http://localhost:8001"
	@echo "  Portainer          → http://portainer.localhost"
	@echo "  n8n                → http://n8n.localhost"
	@echo ""

# Microservicios Java
services:
	docker compose --profile services up -d
	@echo ""
	@echo "  Servicios levantados:"
	@echo "  Dashboard          → http://portfolio.localhost"
	@echo "  Kong Proxy         → http://localhost:8000"
	@echo "  Payment Service    → http://localhost:8000/api/payments"
	@echo "  Fraud Service      → http://localhost:8000/api/fraud"
	@echo ""

# Todo junto
all:
	docker compose --profile infra --profile services up -d

# Herramientas de desarrollo
tools:
	docker compose --profile tools up -d
	@echo "  pgAdmin            → http://localhost:5050"
	@echo "  Redis Commander    → http://localhost:8082"

# Construir imágenes
build:
	docker compose --profile services build --no-cache

# Detener todo
down:
	docker compose --profile infra --profile services --profile tools down

# Reset completo para demo (borra datos)
reset:
	docker compose --profile infra --profile services --profile tools down -v
	docker compose --profile infra up -d
	@echo "Demo reseteado. Datos limpios."

# Logs en tiempo real
logs:
	docker compose --profile infra --profile services logs -f --tail=100

# Logs de un servicio específico: make logs-payment
logs-%:
	docker compose logs -f --tail=100 $*

# Estado de contenedores
ps:
	docker compose --profile infra --profile services --profile tools ps

# Health checks
health:
	@echo "Verificando health de servicios..."
	@docker inspect --format='{{.Name}}: {{.State.Health.Status}}' \
		$$(docker compose --profile infra --profile services ps -q) 2>/dev/null || \
		echo "Algunos contenedores no tienen health check configurado"
