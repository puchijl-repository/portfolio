# Etapa 0 — Verificación de pre-requisitos

> **Objetivo de la etapa:** Antes de escribir una sola línea de código del dominio,
> verificar que todos los pre-requisitos de infraestructura, accesos y herramientas
> están en un estado conocido y documentado.

**Fecha de inicio:** 18 de abril de 2026
**Fecha de cierre:** 19 de abril de 2026
**Duración efectiva:** ~6 horas de trabajo

---

## Resumen ejecutivo

Se verificaron y configuraron 9 pre-requisitos agrupados en 4 dominios:

| Dominio | REQs | Resultado |
|---|---|---|
| Ambiente local | REQ-00.1, REQ-00.3 | 🟢 Completo |
| Control de versiones | REQ-00.2 | 🟢 Completo |
| Infraestructura Docker local | REQ-00.4 | 🟢 Completo (tras 6 fixes) |
| VPS + DNS + Registry + Secretos | REQ-00.5 a REQ-00.9 | 🟢 Completo |

**Hallazgo más relevante:** La infraestructura Docker inicial tenía 6 bugs no
detectados que impedían que 4 de los 14 servicios levantaran correctamente.
Estos bugs están identificados, explicados y corregidos en el commit `cad1049`.

**Deuda técnica consciente:** Hardening SSH del VPS y self-hosted runner de
GitHub Actions. Pospuesta porque no bloquea el objetivo del portfolio (demo
de 2 semanas) y los runners hosteados gratuitos de GitHub son suficientes.

---

## REQ-00.1 — Ambiente local (Windows 11)

### Verificaciones ejecutadas

| Componente | Versión | Estado |
|---|---|---|
| Windows | 11 | 🟢 |
| PowerShell | 7.6.0 | 🟢 |
| Java | 21.0.10 LTS (Temurin) | 🟢 |
| Maven | 3.9.14 | 🟢 |
| Git | 2.53.0 | 🟢 |
| Docker | 29.3.1 | 🟢 |
| Docker Compose | v5.1.1 | 🟢 |
| Node.js | 22.22.2 LTS (vía nvm-windows 1.2.2) | 🟢 |
| VS Code | instalado con CLI en PATH | 🟢 |
| Disco libre (E:) | 99 GB | 🟢 |

### Decisión: Node.js 22 LTS en vez de Node 25 Current

Se migró de Node 25 a Node 22 LTS vía `nvm-windows`. Razones:

1. **Alineación dev/prod.** Los Dockerfiles del dashboard usarán `node:22-alpine`
   o `node:lts-alpine`. Si el dev local usa una versión distinta, los bugs que
   aparecen en CI no se reproducen localmente.
2. **Ecosistema de CI/CD.** `actions/setup-node@v4` con `node-version: 'lts/*'`
   resuelve a 22. El `package-lock.json` generado con versiones impares de Node
   puede causar diffs innecesarios en PRs.
3. **Ventana de soporte.** Node 22 tiene soporte hasta abril 2027. Node 25 deja
   de recibir soporte en ~6 meses.

**Evidencia:** `docs/stage-0-local-env.log`

---

## REQ-00.2 — GitHub y control de versiones

### Verificaciones ejecutadas

| Check | Estado |
|---|---|
| Repo existe: `github.com/puchijl-repository/portfolio` | 🟢 |
| Branch `main` sincronizado | 🟢 |
| `git fetch` sin prompt de credenciales (Credential Manager) | 🟢 |
| `git push` funcional | 🟢 (verificado al pushear `feature/stage-0-infra-fixes`) |

### Hallazgo: estado sucio del working tree

Al auditar el repo local se encontraron archivos a medias de una sesión anterior:

- Scaffold de Spring Initializr del `payment-service` staged sin commitear.
- Un archivo `services/payment-service.zip` que era el ZIP original de Initializr.
- Archivos de trabajo anticipado (Dockerfile, `domain/`, `db/`) en carpetas vacías.
- Un scratch pad `comandos.txt` con notas personales.

**Decisión:** Dejar el scaffold del `payment-service` intocado (quedará como
"untracked" hasta REQ-04 cuando se reescriba el dominio desde cero). Ignorar
`comandos.txt` en `.gitignore`. Solo commitear los cambios de infraestructura
como checkpoint limpio.

**Evidencia:** `docs/stage-0-github.log`

---

## REQ-00.4 — Infraestructura Docker local

Este fue el REQ más trabajoso. La declaración del documento maestro decía que
la infraestructura estaba "🟢 Completo", pero al ejecutar
`docker compose --profile infra up -d` aparecieron **4 contenedores con fallos
distintos**. El diagnóstico reveló 6 bugs de fondo.

### Los 6 bugs encontrados y sus fixes

#### Bug 1: Jaeger — `mkdir permission denied` en volumen Badger

**Síntoma:**