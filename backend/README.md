# me-sims-tracker · backend

Cloudflare Worker + D1 (SQLite) que da una API REST para que la app iOS y un cliente MCP local puedan sincronizar y editar datos.

## Setup

```bash
cd backend
npm install
```

### 1. Crear la base D1

```bash
npx wrangler d1 create me-sims-tracker
```

Copia el `database_id` que imprime y pégalo en `wrangler.toml` reemplazando `REPLACE_WITH_REAL_ID_AFTER_db:create`.

### 2. Aplicar el schema

```bash
# En remoto (producción)
npm run db:migrate:remote

# En local (para `wrangler dev`)
npm run db:migrate:local
```

### 3. API key

Genera una key larga (32+ chars random):

```bash
openssl rand -hex 32
```

**En desarrollo** — crea `backend/.dev.vars`:

```
API_KEY=la-key-que-acabas-de-generar
```

**En producción** — sube como secret:

```bash
echo "la-key-que-acabas-de-generar" | npx wrangler secret put API_KEY
```

### 4. Probar local

```bash
npm run dev
# Ventana aparte:
curl http://localhost:8787/health
curl -H "X-API-Key: TU_KEY" http://localhost:8787/aspirations
```

### 5. Deploy

```bash
npm run deploy
```

Te imprime la URL pública (ej. `https://me-sims-tracker.<usuario>.workers.dev`). Esa URL + la API key son las credenciales que usa la app iOS y el MCP server.

## Endpoints

Todos requieren header `X-API-Key`.

- `GET /sync?since=<ms>` — pull incremental de todo lo modificado después de `since`.
- `GET|POST /aspirations`, `PATCH|DELETE /aspirations/:id`
- `GET|POST /tasks`, `PATCH|DELETE /tasks/:id`
- `GET|POST /activity-log`, `DELETE /activity-log/:id`
- `GET /needs-state`, `PUT /needs-state/:need`

Soft delete (los DELETE setean `deleted_at`, no borran row) para no perder cambios concurrentes.
