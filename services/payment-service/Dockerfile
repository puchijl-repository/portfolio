# ─────────────────────────────────────────────────────────────────
# Stage 1 — BUILD
# Uses full JDK to compile and package the application.
# The build stage is discarded; only the JAR crosses into the runtime stage.
# ─────────────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jdk-alpine AS build

WORKDIR /build

# Copy Maven wrapper and pom first — Docker layer caching:
# dependency download only re-runs when pom.xml changes, not on source changes.
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN ./mvnw dependency:go-offline -q

# Copy source and build
COPY src ./src
RUN ./mvnw package -DskipTests -q

# ─────────────────────────────────────────────────────────────────
# Stage 2 — RUNTIME
# Minimal JRE image. No compiler, no Maven, no source code.
# ─────────────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine AS runtime

WORKDIR /app

# Create non-root user — security best practice for containers
RUN addgroup -S payment && adduser -S payment -G payment
USER payment

# Copy JAR from build stage
COPY --from=build /build/target/*.jar app.jar

# OpenTelemetry Java agent — auto-instruments Spring Boot, JDBC, Kafka, etc.
# The agent is downloaded separately and mounted via docker-compose volume,
# or baked in here for self-contained builds.
# Reference: https://github.com/open-telemetry/opentelemetry-java-instrumentation
ADD --chown=payment:payment \
    https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.10.0/opentelemetry-javaagent.jar \
    otel-agent.jar

EXPOSE 8080

# JVM tuning for containers:
#   -XX:+UseContainerSupport       — respect Docker memory limits (not host RAM)
#   -XX:MaxRAMPercentage=75.0      — use 75% of container memory for heap
#   -javaagent:otel-agent.jar      — OTEL auto-instrumentation
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

ENTRYPOINT ["sh", "-c", \
  "java $JAVA_OPTS -javaagent:otel-agent.jar -jar app.jar"]