-- =============================================================================
-- Portfolio — PostgreSQL initialization
-- Crea las bases que no existen: payments, audit, kong, n8n
-- Instala extensiones en payments y audit
-- =============================================================================

-- La base 'payments' ya la crea Postgres via POSTGRES_DB.
-- Creamos las otras tres condicionalmente.

SELECT 'CREATE DATABASE audit'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'audit')\gexec

SELECT 'CREATE DATABASE kong'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'kong')\gexec

SELECT 'CREATE DATABASE n8n'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'n8n')\gexec

-- Extensiones en payments
\c payments
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Extensiones en audit
\c audit
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";