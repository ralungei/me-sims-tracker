import { Hono } from "hono";
import { cors } from "hono/cors";
import { SyncHub } from "./syncHub";

export { SyncHub };

type Env = {
  DB: D1Database;
  API_KEY: string;
  SYNC_HUB: DurableObjectNamespace;
};

const app = new Hono<{ Bindings: Env }>();

/// Wire-format event types. Must stay in sync with iOS `SyncEventType`.
const EVENT = {
  aspirations: "aspirations.changed",
  tasks: "tasks.changed",
  activityLog: "activity_log.changed",
  needsState: "needs_state.changed",
} as const;

async function broadcast(env: Env, message: object, fromClient?: string | null) {
  const id = env.SYNC_HUB.idFromName("global");
  const stub = env.SYNC_HUB.get(id);
  const enriched = fromClient ? { ...message, from_client: fromClient } : message;
  await stub.fetch("https://hub/broadcast", {
    method: "POST",
    body: JSON.stringify(enriched)
  });
}

/// Notify all connected clients about a change, tagged with the originating
/// client id so the writer can ignore the echo of its own write.
async function notify(c: { env: Env; req: { header: (k: string) => string | undefined } }, type: string, extra: Record<string, unknown> = {}) {
  await broadcast(c.env, { type, ...extra }, c.req.header("X-Client-ID"));
}

app.use("*", cors());

// Auth middleware: requires X-API-Key header matching env.API_KEY.
// `/events` accepts the key as a query string too, since browsers/URLSession
// can't always set custom headers on the WebSocket upgrade handshake.
app.use("*", async (c, next) => {
  if (c.req.path === "/" || c.req.path === "/health") return next();
  const headerKey = c.req.header("X-API-Key");
  const queryKey = c.req.query("key");
  if (headerKey !== c.env.API_KEY && queryKey !== c.env.API_KEY) {
    return c.json({ error: "unauthorized" }, 401);
  }
  await next();
});

app.get("/", (c) => c.text("me-sims-tracker backend ok"));
app.get("/health", (c) => c.json({ ok: true, ts: Date.now() }));

// WebSocket endpoint: clients connect here to receive real-time change events.
app.get("/events", (c) => {
  if (c.req.header("upgrade")?.toLowerCase() !== "websocket") {
    return c.text("expected websocket upgrade", 400);
  }
  const id = c.env.SYNC_HUB.idFromName("global");
  const stub = c.env.SYNC_HUB.get(id);
  return stub.fetch("https://hub/connect", c.req.raw);
});

const now = () => Date.now();
const newId = () => crypto.randomUUID();

// ─── ASPIRATIONS ────────────────────────────────────────────────

app.get("/aspirations", async (c) => {
  const rows = await c.env.DB
    .prepare("SELECT * FROM aspirations WHERE deleted_at IS NULL ORDER BY sort_order, created_at")
    .all();
  return c.json(rows.results);
});

app.post("/aspirations", async (c) => {
  const body = await c.req.json<any>();
  if (!body?.name || typeof body.name !== "string") {
    return c.json({ error: "name is required" }, 400);
  }
  if (!body?.kind || typeof body.kind !== "string") {
    return c.json({ error: "kind is required" }, 400);
  }
  const id = body.id ?? newId();
  const ts = now();
  await c.env.DB.prepare(
    `INSERT INTO aspirations (id,name,emoji,kind,hue,xp,duration_minutes,total_days,started_at,last_completed_at,completions_log,notes,dosing_moment,reminder_time,sort_order,created_at,updated_at)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`
  ).bind(
    id,
    body.name,
    body.emoji ?? "✨",
    body.kind,
    body.hue ?? 220,
    body.xp ?? 10,
    body.duration_minutes ?? null,
    body.total_days ?? null,
    body.started_at ?? null,
    body.last_completed_at ?? null,
    JSON.stringify(body.completions_log ?? []),
    body.notes ?? null,
    body.dosing_moment ?? null,
    body.reminder_time ?? null,
    body.sort_order ?? 0,
    ts,
    ts
  ).run();
  await notify(c, EVENT.aspirations);
  return c.json({ id, ok: true });
});

app.patch("/aspirations/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json<any>();
  const ts = now();
  const fields: string[] = [];
  const values: any[] = [];
  for (const [k, v] of Object.entries(body)) {
    if (k === "id" || k === "created_at") continue;
    fields.push(`${k} = ?`);
    values.push(k === "completions_log" && Array.isArray(v) ? JSON.stringify(v) : v);
  }
  fields.push("updated_at = ?");
  values.push(ts);
  values.push(id);
  await c.env.DB.prepare(
    `UPDATE aspirations SET ${fields.join(", ")} WHERE id = ?`
  ).bind(...values).run();
  await notify(c, EVENT.aspirations, { id });
  return c.json({ ok: true });
});

app.delete("/aspirations/:id", async (c) => {
  const id = c.req.param("id");
  await c.env.DB.prepare(
    "UPDATE aspirations SET deleted_at = ?, updated_at = ? WHERE id = ?"
  ).bind(now(), now(), id).run();
  await notify(c, EVENT.aspirations, { id });
  return c.json({ ok: true });
});

// ─── TASKS ──────────────────────────────────────────────────────

app.get("/tasks", async (c) => {
  const rows = await c.env.DB
    .prepare("SELECT * FROM tasks WHERE deleted_at IS NULL ORDER BY sort_order, created_at")
    .all();
  return c.json(rows.results);
});

app.post("/tasks", async (c) => {
  const body = await c.req.json<any>();
  if (!body?.title || typeof body.title !== "string") {
    return c.json({ error: "title is required" }, 400);
  }
  const id = body.id ?? newId();
  const ts = now();
  await c.env.DB.prepare(
    `INSERT INTO tasks (id,title,notes,due_date,is_done,completed_at,sort_order,created_at,updated_at)
     VALUES (?,?,?,?,?,?,?,?,?)`
  ).bind(
    id,
    body.title,
    body.notes ?? null,
    body.due_date ?? null,
    body.is_done ? 1 : 0,
    body.completed_at ?? null,
    body.sort_order ?? 0,
    ts,
    ts
  ).run();
  await notify(c, EVENT.tasks, { id });
  return c.json({ id, ok: true });
});

app.patch("/tasks/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json<any>();
  const ts = now();
  const fields: string[] = [];
  const values: any[] = [];
  for (const [k, v] of Object.entries(body)) {
    if (k === "id" || k === "created_at") continue;
    fields.push(`${k} = ?`);
    values.push(k === "is_done" ? (v ? 1 : 0) : v);
  }
  fields.push("updated_at = ?");
  values.push(ts);
  values.push(id);
  await c.env.DB.prepare(
    `UPDATE tasks SET ${fields.join(", ")} WHERE id = ?`
  ).bind(...values).run();
  await notify(c, EVENT.tasks, { id });
  return c.json({ ok: true });
});

app.delete("/tasks/:id", async (c) => {
  const id = c.req.param("id");
  await c.env.DB.prepare(
    "UPDATE tasks SET deleted_at = ?, updated_at = ? WHERE id = ?"
  ).bind(now(), now(), id).run();
  await notify(c, EVENT.tasks, { id });
  return c.json({ ok: true });
});

// ─── ACTIVITY LOG ───────────────────────────────────────────────

app.get("/activity-log", async (c) => {
  const limit = parseInt(c.req.query("limit") ?? "1000", 10);
  const need = c.req.query("need");
  const stmt = need
    ? c.env.DB.prepare(
        "SELECT * FROM activity_log WHERE deleted_at IS NULL AND need_type = ? ORDER BY timestamp DESC LIMIT ?"
      ).bind(need, limit)
    : c.env.DB.prepare(
        "SELECT * FROM activity_log WHERE deleted_at IS NULL ORDER BY timestamp DESC LIMIT ?"
      ).bind(limit);
  const rows = await stmt.all();
  return c.json(rows.results);
});

app.post("/activity-log", async (c) => {
  const body = await c.req.json<any>();
  const id = body.id ?? newId();
  const ts = now();
  await c.env.DB.prepare(
    `INSERT INTO activity_log (id,need_type,action_name,action_icon,boost_amount,notes,timestamp,created_at)
     VALUES (?,?,?,?,?,?,?,?)`
  ).bind(
    id,
    body.need_type,
    body.action_name,
    body.action_icon ?? "circle",
    body.boost_amount,
    body.notes ?? null,
    body.timestamp ?? ts,
    ts
  ).run();
  await notify(c, EVENT.activityLog, { id });
  return c.json({ id, ok: true });
});

app.delete("/activity-log/:id", async (c) => {
  const id = c.req.param("id");
  await c.env.DB.prepare(
    "UPDATE activity_log SET deleted_at = ? WHERE id = ?"
  ).bind(now(), id).run();
  await notify(c, EVENT.activityLog, { id });
  return c.json({ ok: true });
});

// ─── NEEDS STATE ────────────────────────────────────────────────

app.get("/needs-state", async (c) => {
  const rows = await c.env.DB.prepare("SELECT * FROM needs_state").all();
  return c.json(rows.results);
});

app.put("/needs-state/:need", async (c) => {
  const need = c.req.param("need");
  const body = await c.req.json<any>();
  const ts = now();
  await c.env.DB.prepare(
    `INSERT INTO needs_state (need_type, value, last_updated, enabled, updated_at)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(need_type) DO UPDATE SET
       value = excluded.value,
       last_updated = excluded.last_updated,
       enabled = excluded.enabled,
       updated_at = excluded.updated_at`
  ).bind(
    need,
    body.value,
    body.last_updated ?? ts,
    // Client wires bools as ints (0/1). Treat 0/false as disabled, anything
    // else (including missing) as enabled.
    body.enabled === 0 || body.enabled === false ? 0 : 1,
    ts
  ).run();
  await notify(c, EVENT.needsState, { need });
  return c.json({ ok: true });
});

// ─── FULL SYNC ──────────────────────────────────────────────────

app.get("/sync", async (c) => {
  const since = parseInt(c.req.query("since") ?? "0", 10);
  const [aspirations, tasks, log, needsState] = await Promise.all([
    c.env.DB.prepare(
      "SELECT * FROM aspirations WHERE updated_at > ? ORDER BY sort_order"
    ).bind(since).all(),
    c.env.DB.prepare(
      "SELECT * FROM tasks WHERE updated_at > ? ORDER BY sort_order"
    ).bind(since).all(),
    c.env.DB.prepare(
      // Include soft-deleted rows so undo propagates: created_at OR deleted_at past `since`.
      "SELECT * FROM activity_log WHERE created_at > ? OR (deleted_at IS NOT NULL AND deleted_at > ?) ORDER BY timestamp DESC LIMIT 500"
    ).bind(since, since).all(),
    c.env.DB.prepare(
      "SELECT * FROM needs_state WHERE updated_at > ?"
    ).bind(since).all()
  ]);
  return c.json({
    server_time: now(),
    aspirations: aspirations.results,
    tasks: tasks.results,
    activity_log: log.results,
    needs_state: needsState.results
  });
});

export default app;
