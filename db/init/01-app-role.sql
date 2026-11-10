-- The API's database role: not a superuser, no CREATE, no DDL. The owner role (tsr) runs the
-- migrations and the seed; after each migration run the migrate job grants this role the domain
-- schemas (shared/api/DomainContexts.cs). Production creates the same role with its own secret.
-- Local only: the password below is a placeholder, never a production value.
CREATE ROLE tsr_app LOGIN PASSWORD 'local-only-app'
    NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
