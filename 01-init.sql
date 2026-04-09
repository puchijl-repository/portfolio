-- =============================================================================
-- Portfolio — PostgreSQL initialization
-- Se ejecuta automáticamente la primera vez que levanta el contenedor
-- =============================================================================

-- Base de datos para pagos y fraud (Payment + Fraud Service)
CREATE DATABASE payments
    WITH OWNER = portfolio
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8';

-- Base de datos para audit log (Audit Service)
CREATE DATABASE audit
    WITH OWNER = portfolio
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8';

-- Base de datos para Kong API Gateway
CREATE DATABASE kong
    WITH OWNER = portfolio
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8';

-- Base de datos para n8n workflows
CREATE DATABASE n8n
    WITH OWNER = portfolio
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8';

-- Extensiones necesarias en payments
\c payments;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";    -- búsqueda de texto eficiente

-- Extensiones necesarias en audit
\c audit;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
