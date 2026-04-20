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
| Ambiente local | REQ-00.1, REQ-00.3 | Completo |
| Control de versiones | REQ-00.2 | Completo |
| Infraestructura Docker local | REQ-00.4 | Completo (tras 6 fixes) |
| VPS + DNS + Registry + Secretos | REQ-00.5 a REQ-00.9 | Completo |

**Hallazgo más relevante:** La infraestructura Docker inicial tenía 6 bugs no
detectados que impedían que 4 de los 14 servicios levantaran correctamente.
Estos bugs están identificados, explicados y corregidos en el commit cad1049.

**Deuda técnica consciente:** Hardening SSH del VPS y self-hosted runner de
GitHub Actions. Pospuesta porque no bloquea el objetivo del portfolio (demo
de 2 semanas) y los runners hosteados gratuitos de GitHub son suficientes.

---

## REQ-00.1 — Ambiente local (Windows 11)

### Verificaciones ejecutadas

| Componente | Versión | Estado |
|---|---|---|
| Windows | 11 | OK |
| PowerShell | 7.6.0 | OK |
| Java | 21.0.10 LTS (Temurin) | OK |
| Maven | 3.9.14 | OK |
| Git | 2.53.0 | OK |
| Docker | 29.3.1 | OK |
| Docker Compose | v5.1.1 | OK |
| Node.js | 22.22.2 LTS (via nvm-windows 1.2.2) | OK |
| VS Code | instalado con CLI en PATH | OK |
| Disco libre (E:) | 99 GB | OK |

### Decisión: Node.js 22 LTS en vez de Node 25 Current

Se migró de Node 25 a Node 22 LTS vía nvm-windows. Razones:

1. **Alineación dev/prod.** Los Dockerfiles del dashboard usarán node:22-alpine
   o node:lts-alpine. Si el dev local usa una versión distinta, los bugs que
   aparecen en CI no se reproducen localmente.
2. **Ecosistema de CI/CD.** actions/setup-node@v4 con node-version: lts/* resuelve
   a 22. El package-lock.json generado con versiones impares de Node puede
   causar diffs innecesarios en PRs.
3. **Ventana de soporte.** Node 22 tiene soporte hasta abril 2027. Node 25 deja
   de recibir soporte en ~6 meses.

**Evidencia:** docs/stage-0-local-env.log

---

## REQ-00.2 — GitHub y control de versiones

### Verificaciones ejecutadas

| Check | Estado |
|---|---|
| Repo existe: github.com/puchijl-repository/portfolio | OK |
| Branch main sincronizado | OK |
| git fetch sin prompt de credenciales (Credential Manager) | OK |
| git push funcional | OK (verificado al pushear feature/stage-0-infra-fixes) |

### Hallazgo: estado sucio del working tree

Al auditar el repo local se encontraron archivos a medias de una sesión anterior:

- Scaffold de Spring Initializr del payment-service staged sin commitear.
- Un archivo services/payment-service.zip que era el ZIP original de Initializr.
- Archivos de trabajo anticipado (Dockerfile, domain/, db/) en carpetas vacías.
- Un scratch pad comandos.txt con notas personales.

**Decisión:** Dejar el scaffold del payment-service intocado (quedará como
"untracked" hasta REQ-04 cuando se reescriba el dominio desde cero). Ignorar
comandos.txt en .gitignore. Solo commitear los cambios de infraestructura como
checkpoint limpio.

**Evidencia:** docs/stage-0-github.log

---

## REQ-00.4 — Infraestructura Docker local

Este fue el REQ más trabajoso. La declaración del documento maestro decía que
la infraestructura estaba "Completo", pero al ejecutar
docker compose --profile infra up -d aparecieron **4 contenedores con fallos
distintos**. El diagnóstico reveló 6 bugs de fondo.

### Los 6 bugs encontrados y sus fixes

#### Bug 1: Jaeger — mkdir permission denied en volumen Badger

**Síntoma:**

    {"level":"fatal","msg":"Failed to init storage factory",
     "error":"Error Creating Dir: \"/badger/key\" error: mkdir /badger/key: permission denied"}

**Causa:** Jaeger 1.63 intenta crear subdirectorios en /badger dentro de un
volumen Docker nombrado. Los volúmenes nombrados se crean como root en Windows
Docker Desktop, y Jaeger corre como usuario no-root por defecto.

**Fix:** Ejecutar Jaeger como root con user: "0:0". Es seguro en este contexto
porque es un contenedor de desarrollo local con acceso controlado.

#### Bug 2: RabbitMQ — no_such_user al cargar definitions

**Síntoma:**

    BOOT FAILED
    exit:{error,<<"{no_such_user,<<\"portfolio\">>}">>}

**Causa:** El archivo definitions.json declaraba permisos para el usuario
portfolio pero nunca creaba el usuario. RabbitMQ intentaba aplicar los
permisos antes de que RABBITMQ_DEFAULT_USER ejecutara, y fallaba.

**Fix:** Agregar bloque users al definitions.json con el usuario y su password
hasheado con SHA-256. Eliminar RABBITMQ_DEFAULT_USER y RABBITMQ_DEFAULT_PASS
del compose para que el definitions.json sea la única fuente de verdad.

#### Bug 3: Postgres — init script .sh ignorado en Windows

**Síntoma:** Postgres levantó pero solo tenía la base payments. Las bases
kong, audit, n8n nunca se crearon, causando que kong-migrations fallara con
"database kong does not exist".

**Causa:** El init script estaba como 01-init.sh. Docker en Windows no preserva
el bit de ejecución al hacer bind-mount desde el filesystem NTFS, por lo que
Postgres silenciosamente ignora el archivo.

**Fix:** Convertir el script a 01-init.sql (Postgres ejecuta .sql vía psql sin
necesitar bit de ejecución). Usar \gexec para lógica condicional (crear la
base solo si no existe).

#### Bug 4: n8n — variables de auth deprecadas bloquean arranque

**Síntoma:** n8n no llegaba a healthy.

**Causa:** N8N_BASIC_AUTH_ACTIVE, N8N_BASIC_AUTH_USER y N8N_BASIC_AUTH_PASSWORD
fueron removidas en n8n 1.x. El setup de usuario ahora se hace vía UI en la
primera visita.

**Fix:** Eliminar las 3 variables deprecadas. Agregar N8N_ENCRYPTION_KEY como
variable de entorno estable (en REQ-00.9).

#### Bug 5: n8n — healthcheck interno fallaba por DNS/bind

**Síntoma:**

    wget: can't connect to remote host: Connection refused

El healthcheck dentro del contenedor intentaba contactar localhost:5678 pero
fallaba.

**Causa:** n8n se bindeaba a la interfaz definida por N8N_HOST (n8n.localhost)
y no a todas las interfaces. El resolver DNS del contenedor no mapeaba
localhost a esa interfaz específica.

**Fix:** Agregar N8N_LISTEN_ADDRESS: "0.0.0.0" para bind en todas las interfaces.
Cambiar el healthcheck de localhost a 127.0.0.1 para bypasear resolución DNS.

#### Bug 6: Kong — healthcheck usa comando inexistente

**Síntoma:** Kong en estado unhealthy intermitente.

**Causa:** El healthcheck usaba kong health como CLI, pero Kong 3.8 tiene ese
comando con comportamiento diferente al histórico.

**Fix:** Cambiar el healthcheck a un fallback HTTP al endpoint /status del
Admin API, que es más estable entre versiones.

### Resultado final

14 de 14 contenedores levantan healthy con un solo comando:

    docker compose --profile infra up -d

**Evidencia:** commit cad1049 en branch feature/stage-0-infra-fixes.

### Lección clave de este REQ

**La estabilidad de un docker-compose.yml no se verifica leyéndolo, se verifica
ejecutándolo y observando los healthchecks.** Un compose puede estar sintác-
ticamente perfecto y aun así tener 6 bugs silenciosos. El patrón correcto es:
levantar en limpio, esperar a que los healthchecks estabilicen, y recién ahí
afirmar que "funciona".

---

## REQ-00.5 — Verificación e inventario del VPS

### Hallazgos del inventario

**VPS:** Hostinger, Ubuntu 22.04.5 LTS, 8 GB RAM, 2 vCPU AMD EPYC, 97 GB disco.
**Uptime:** 151 días sin reinicio.
**Docker:** 29.1.4, Compose v2.38.2.

### Estado previo del VPS (antes de limpieza)

El VPS compartía recursos con **5 sitios confirmados** (placeholders Nginx) +
**Nginx Proxy Manager** + **db MariaDB** = 7 contenedores corriendo.

Se encontraron residuos de proyectos anteriores:

| Residuo | Tamaño | Decisión |
|---|---|---|
| /root/devitsys-portfolio/ | 420 KB | Borrado |
| /root/task-management-system/ | 1.7 MB | Borrado |
| /opt/devitsys/ (dev, test, prod, jenkins, nginx, sites) | 1.4 GB | Borrado |
| Build cache de Docker | 2.3 GB | Purgado con docker system prune |

**Total liberado:** 6 GB.

### Backup defensivo

Antes de borrar Jenkins, se descargaron a local los archivos secrets/ y
credentials.xml del jenkins_home por si contenían keys que quisiera recuperar
más adelante. Se almacenaron en docs/vps-backups/ (ignorado por Git) y se
confirmó que sin los archivos cifrados asociados son inertes.

### Decisión crítica: estrategia de coexistencia con NPM

El documento maestro planteaba desplegar Traefik en el VPS. **Esto se rechazó**
porque NPM ya ocupa los puertos 80, 81 y 443 y sirve los 5 sitios confirmados.
Reemplazarlo implicaría migrar los certificados Let's Encrypt y aceptar riesgo
de caída de sitios operativos durante la migración.

**Estrategia adoptada (Solución A):**

- NPM sigue gestionando los puertos 80, 81 y 443.
- El portfolio se desplegará en una red Docker nueva (portfolio-net).
- Solo el contenedor del dashboard se conectará adicionalmente a la red
  npm-proxy, permitiendo que NPM enrute tráfico hacia él.
- Los subdominios (portfolio, jaeger, grafana, rabbitmq, kafdrop, kong) se
  configurarán en la UI de NPM como proxy hosts apuntando al contenedor
  correspondiente del portfolio.

**Traefik queda como componente local únicamente** (visible en demos
presenciales desde la máquina local). Esto es consistente con el enfoque
"VPS compartido con tuning mínimo, demo completa en local".

---

## REQ-00.6 — DNS

Los 6 subdominios necesarios ya resuelven correctamente a la IP del VPS
(31.97.99.101) desde múltiples resolvers (DNS local, Google 8.8.8.8,
Cloudflare 1.1.1.1):

- portfolio.devitsys.com (principal)
- jaeger.devitsys.com
- grafana.devitsys.com
- rabbitmq.devitsys.com
- kafdrop.devitsys.com
- kong.devitsys.com

**TTL:** 1800 segundos. Propagación confirmada globalmente.

---

## REQ-00.7 — GitHub Container Registry

### Decisión: classic PAT con scope limitado

Se creó un Personal Access Token (classic) con scopes:

- read:packages
- write:packages
- delete:packages

**Sin otros scopes.** El token no puede leer código del repo, no puede modificar
workflows ni secrets. Si se filtra, el worst case es que alguien publique o
borre packages del registry, no access al código.

### Smoke test ejecutado

1. Login: docker login ghcr.io devolvió "Login Succeeded"
2. Push de imagen de prueba (hello-world retagueada) exitoso
3. Verificación en UI de GitHub: package listado
4. Cleanup local OK

**Registry queda listo para recibir imágenes de los microservicios** cuando
lleguen los Dockerfiles en REQ-15.

---

## REQ-00.9 — Gestión de secretos

### Arquitectura de secretos

Tres ubicaciones, tres responsabilidades:

| Ubicación | Contenido | Commiteado |
|---|---|---|
| .env.example | Plantilla con nombres de variables, sin valores | Sí |
| .env (local) | Valores reales de desarrollo | No (.gitignore) |
| GitHub Secrets (futuro) | Valores para CI/CD y deploy al VPS | Administrado por GitHub |
| .env del VPS (futuro) | Valores de producción, distintos a los locales | Manual, nunca en Git |

### Variables gestionadas

10 variables en total: credenciales de PostgreSQL, Redis, RabbitMQ, Grafana,
pgAdmin, y una encryption key para n8n.

### Lección aprendida sobre encryption keys

Durante la configuración de N8N_ENCRYPTION_KEY apareció el error
"Mismatching encryption keys". Esto llevó a entender la diferencia entre:

- **Password:** autentica un cliente contra un servicio. Se puede cambiar
  libremente.
- **Encryption key:** cifra datos en reposo. Si cambia, los datos cifrados con
  la anterior son irrecuperables.

Para esta etapa se resolvió borrando el volumen de n8n (aceptable porque no
había workflows guardados). En producción la solución sería re-cifrar todos los
datos cifrados con la key antigua usando la nueva antes de descartar la vieja
— un procedimiento de migración específico.

### Patrón edit → validate → commit

Durante la edición del compose se introdujeron silenciosamente errores de
indentación YAML que hicieron que docker compose config reportara services: {}
(sin errores ni warnings visibles). La recuperación se hizo restaurando el
archivo desde el último commit válido.

**Conclusión:** todo cambio a un compose, k8s manifest o archivo de
infraestructura crítico debe ejecutar una validación nativa
(docker compose config --quiet) inmediatamente después de guardar. Si el
exit code es distinto de 0, restaurar desde Git antes de seguir.

---

## REQ-00.8 — Self-hosted runner (pospuesto)

**Decisión:** no se instala self-hosted runner en la Etapa 0.

**Justificación:** GitHub Actions ofrece 2000 minutos/mes gratis en runners
hosteados para repos públicos. Para un portfolio de 2 semanas con pocos deploys,
esto sobra. Self-hosted runner se evaluará únicamente si el throughput de CI se
vuelve un cuello de botella o si se requiere acceso a recursos internos del
VPS desde el pipeline.

---

## Deuda técnica consciente

Documentada para resolución post-presentación:

| Tema | Prioridad | Notas |
|---|---|---|
| Hardening SSH del VPS (usuario sudo, no-root login, SSH keys only, fail2ban, ufw) | Media | Postponed: password ya robusto, demo de 2 semanas |
| 42 updates can be applied immediately en VPS | Baja | apt upgrade seguro de correr, no hace falta reinicio inmediato |
| System restart required en VPS | Baja | Reiniciar post-demo |
| Actualizar n8n de 1.70.3 a 1.121.0+ (aviso critical update) | Baja | Cambiar versión introduce variables nuevas durante la demo |
| Migrar sitios confirmados de Nginx placeholders a Cloudflare Pages | Baja | Decisión producto, no técnica |

---

## Evidencia consolidada

Archivos generados durante la Etapa 0:

    docs/
    ├── stage-0-verification.md          ← este documento
    ├── stage-0-local-env.log            ← REQ-00.1
    ├── stage-0-github.log               ← REQ-00.2
    ├── stage-0-vps-inventory.log        ← REQ-00.5
    └── vps-backups/                     ← backups defensivos (no commiteado)
        ├── old-portfolio.env
        ├── old-task-system.env.example
        ├── jenkins-credentials.xml
        └── jenkins-secrets/

Commits relevantes:

- cad1049 — fix(infra): stabilize docker-compose stack for local development
- 8b05980 — docs(stage-0): add final verification report (parcial)
- [hash del próximo commit] — docs(stage-0): complete verification report

Branch: feature/stage-0-infra-fixes

---

## Estado al cierre de la Etapa 0

### Local (máquina de desarrollo)

- Ambiente: Java 21 + Maven 3.9 + Docker 29 + Node 22 + VS Code: OK
- Repo: clonado y con push funcional: OK
- Infra Docker: 14/14 contenedores healthy con un comando: OK
- Secretos: .env funcional, .env.example público, no hay secretos en Git: OK

### VPS

- Ubuntu 22.04 + Docker 29 + 6.8 GB RAM libres + 87 GB disco libres: OK
- NPM + 5 sitios confirmados + npm-db corriendo sin tocar: OK
- /opt/portfolio creado vacío, listo para el deploy futuro: OK
- DNS de los 6 subdominios del portfolio resuelve a la IP correcta: OK

### Accesos externos

- GitHub: push/pull funcional: OK
- GitHub Container Registry: PAT validado, smoke push exitoso: OK

---

## Próximo paso: Etapa 1 — REQ-04 (Payment Service Domain)

Con todos los pre-requisitos verificados, la siguiente etapa construye el
**dominio hexagonal puro** del Payment Service: aggregates, value objects,
ports in/out y el domain service, **sin ninguna dependencia de framework**.

Este es el corazón pedagógico del portfolio: demostrar arquitectura hexagonal
real, no "hexagonal con Spring en el dominio".

---

*Documento generado el 19 de abril de 2026.*