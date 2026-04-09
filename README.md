# Portfolio — Senior Java Architect

Stack de demostración empírica para el perfil Senior Java Engineer / Architect.

## Requisitos locales (Windows 11)

1. WSL2 + Ubuntu 22.04
2. Docker Desktop (backend WSL2)
3. Java 21 (Temurin)
4. VS Code con extensiones: Extension Pack for Java, Spring Boot Extension Pack, Docker

## Inicio rápido

```bash
# 1. Clonar el repositorio
git clone https://github.com/tu-usuario/portfolio.git
cd portfolio

# 2. Configurar variables de entorno
cp .env.example .env
# Editar .env si quieres cambiar passwords (opcional en local)

# 3. Levantar la infraestructura
make infra

# 4. Esperar ~60 segundos y verificar que todo está healthy
make health

# 5. Levantar los microservicios (requiere haberlos compilado)
make services
```

## Accesos

| Servicio | URL | Credenciales |
|---|---|---|
| Dashboard | http://portfolio.localhost | — |
| Jaeger | http://localhost:16686 | — |
| Grafana | http://localhost:3001 | admin / admin |
| Prometheus | http://localhost:9090 | — |
| Kafdrop | http://kafdrop.localhost | — |
| RabbitMQ | http://localhost:15672 | portfolio / rabbitmq_secret |
| Kong Admin | http://localhost:8001 | — |
| Portainer | http://portainer.localhost | (primer login crea admin) |
| n8n | http://n8n.localhost | admin / n8n_secret |
| Traefik | http://localhost:8080 | — |

## Arquitectura

```
Dashboard (Next.js)
    ↓
Kong API Gateway  ←─── JWT auth, rate limiting, OTEL traces
    ↓
┌─────────────────────────────────────┐
│  Payment Service  (Hexagonal + CB)  │
│  Fraud Service    (Bulkhead + ML)   │
│  Audit Service    (Event Sourcing)  │
│  Notification Svc (RMQ consumer)   │
└─────────────────────────────────────┘
    ↓ Kafka (EDA)          ↓ RabbitMQ (task queues)
payment.events         email.notification
fraud.scored           webhook.delivery
audit.log              (+ DLQ para cada queue)
    ↓
PostgreSQL + Redis
    ↓
OpenTelemetry → Jaeger (trazas)
Micrometer    → Prometheus → Grafana (métricas)
Logback JSON  → Loki (logs con traceId)
```

## Patrones demostrados

- **Arquitectura Hexagonal** — dominio sin dependencias de infraestructura
- **Circuit Breaker** — Resilience4j, estados CLOSED/OPEN/HALF-OPEN visibles en Grafana
- **Bulkhead** — thread pool aislado en Fraud Service
- **Outbox Pattern** — atomicidad entre PostgreSQL y Kafka
- **CQRS** — comandos y queries en endpoints separados
- **Saga (choreography)** — flujo distribuido sin orquestador central
- **Dead Letter Queue** — mensajes fallidos en RabbitMQ con visibilidad
- **Idempotency keys** — pagos no se duplican con retries
- **Distributed tracing** — OTEL + Jaeger, span tree completo por request
- **EDA vs Task Queues** — Kafka para eventos de dominio, RabbitMQ para tareas discretas

## Demos disponibles desde el dashboard

1. **Trigger payment** — dispara el flujo completo, ver traza en Jaeger
2. **Force circuit breaker** — abre el CB del Fraud Service, ver fallback
3. **Replay event** — republica un evento de Kafka, demuestra idempotencia
4. **DLQ inspector** — ver mensajes en Dead Letter Queue de RabbitMQ
5. **Chaos mode** — inyecta latencia artificial en servicios seleccionados

## AI-Augmented Development

Este portafolio fue construido usando Claude Code como agente de desarrollo.
Las decisiones de arquitectura (hexagonal, EDA sobre RabbitMQ para tasks,
Outbox Pattern, elección de Resilience4j) fueron tomadas por el desarrollador.
El agente aceleró la generación de scaffolding, tests, y documentación.

Ver [`docs/ai-workflow.md`](docs/ai-workflow.md) para detalles del proceso.
