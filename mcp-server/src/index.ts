#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const BASE_URL = process.env.SIMS_BACKEND_URL ?? "https://me-sims-tracker.ras-alungei.workers.dev";
const API_KEY = process.env.SIMS_API_KEY;

if (!API_KEY) {
  console.error("[me-sims-tracker-mcp] missing SIMS_API_KEY env var");
  process.exit(1);
}

async function api(path: string, init?: RequestInit) {
  const res = await fetch(`${BASE_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      "X-API-Key": API_KEY!,
      ...(init?.headers ?? {})
    }
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}: ${text}`);
  return text ? JSON.parse(text) : null;
}

const NEED_TYPES = [
  "health","energy","nutrition","hydration","bladder",
  "exercise","hygiene","environment","social","leisure"
] as const;

const ASPIRATION_KINDS = ["dailySimple","dailyTimed","treatment","weekly"] as const;

const server = new McpServer({
  name: "me-sims-tracker",
  version: "1.0.0"
});

// ─── ASPIRATIONS ───────────────────────────────────────────────

server.tool(
  "list_aspirations",
  "List all aspirations (challenges) the user is tracking.",
  {},
  async () => {
    const rows = await api("/aspirations");
    return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }] };
  }
);

server.tool(
  "add_aspiration",
  "Create a new aspiration (recurring personal challenge).",
  {
    name: z.string().describe("Display name"),
    kind: z.enum(ASPIRATION_KINDS).describe("dailySimple = once/day · dailyTimed = once/day with duration · treatment = N-day course · weekly = once/week"),
    emoji: z.string().optional(),
    hue: z.number().optional().describe("0–360, color hue"),
    xp: z.number().optional().describe("Points awarded on completion"),
    duration_minutes: z.number().optional().describe("For dailyTimed"),
    total_days: z.number().optional().describe("For treatment"),
    started_at_iso: z.string().optional().describe("ISO date for treatment start. Can be in the future — the aspiration stays hidden until that date arrives. Defaults to today."),
    notes: z.string().optional().describe("Free-form notes (dose schedule, brand name, instructions, etc.).")
  },
  async (args) => {
    const body: Record<string, unknown> = {
      name: args.name,
      kind: args.kind,
      emoji: args.emoji ?? "✨",
      hue: args.hue ?? 220,
      xp: args.xp ?? 10
    };
    if (args.duration_minutes) body.duration_minutes = args.duration_minutes;
    if (args.total_days) body.total_days = args.total_days;
    if (args.notes) body.notes = args.notes;
    if (args.kind === "treatment") {
      body.started_at = args.started_at_iso
        ? Date.parse(args.started_at_iso)
        : Date.now();
    }
    const result = await api("/aspirations", { method: "POST", body: JSON.stringify(body) });
    return { content: [{ type: "text", text: `Created aspiration ${result.id}` }] };
  }
);

server.tool(
  "complete_aspiration",
  "Mark an aspiration as done for today (or this week, depending on kind).",
  { id: z.string().describe("Aspiration UUID") },
  async ({ id }) => {
    const all = await api("/aspirations");
    const target = all.find((a: any) => a.id === id);
    if (!target) throw new Error(`Aspiration ${id} not found`);
    const now = Date.now();
    const log = JSON.parse(target.completions_log ?? "[]") as number[];
    log.push(now);
    await api(`/aspirations/${id}`, {
      method: "PATCH",
      body: JSON.stringify({ last_completed_at: now, completions_log: log })
    });
    return { content: [{ type: "text", text: `Marked "${target.name}" done` }] };
  }
);

server.tool(
  "delete_aspiration",
  "Soft-delete an aspiration (it stops appearing but its history is kept).",
  { id: z.string() },
  async ({ id }) => {
    await api(`/aspirations/${id}`, { method: "DELETE" });
    return { content: [{ type: "text", text: `Deleted aspiration ${id}` }] };
  }
);

// ─── TASKS ─────────────────────────────────────────────────────

server.tool(
  "list_tasks",
  "List all open one-off tasks (agenda items).",
  {},
  async () => {
    const rows = await api("/tasks");
    return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }] };
  }
);

server.tool(
  "add_task",
  "Add a one-off task to the agenda. Use ISO datetime for due_iso (e.g. '2026-04-28T16:00:00').",
  {
    title: z.string(),
    due_iso: z.string().optional().describe("ISO datetime, optional"),
    notes: z.string().optional()
  },
  async ({ title, due_iso, notes }) => {
    const body: Record<string, unknown> = { title };
    if (due_iso) body.due_date = Date.parse(due_iso);
    if (notes) body.notes = notes;
    const result = await api("/tasks", { method: "POST", body: JSON.stringify(body) });
    return { content: [{ type: "text", text: `Created task ${result.id}` }] };
  }
);

server.tool(
  "complete_task",
  "Mark a task as done.",
  { id: z.string() },
  async ({ id }) => {
    await api(`/tasks/${id}`, {
      method: "PATCH",
      body: JSON.stringify({ is_done: 1, completed_at: Date.now() })
    });
    return { content: [{ type: "text", text: "Task completed" }] };
  }
);

server.tool(
  "delete_task",
  "Soft-delete a task.",
  { id: z.string() },
  async ({ id }) => {
    await api(`/tasks/${id}`, { method: "DELETE" });
    return { content: [{ type: "text", text: "Task deleted" }] };
  }
);

// ─── ACTIVITY LOG ──────────────────────────────────────────────

server.tool(
  "log_action",
  "Log a quick action against a need (eats, drinks, exercise, sleep, etc). The need's bar moves by `boost_amount` percent. Use negative boost for harmful actions.",
  {
    need_type: z.enum(NEED_TYPES),
    action_name: z.string().describe("e.g. 'Cena', 'Agua', 'Gym', 'Dormí 8h'"),
    boost_amount: z.number().describe("-100 to 100. Positive fills the bar."),
    action_icon: z.string().optional().describe("SF Symbol name, optional")
  },
  async ({ need_type, action_name, boost_amount, action_icon }) => {
    const body = {
      need_type,
      action_name,
      action_icon: action_icon ?? "circle",
      boost_amount,
      timestamp: Date.now()
    };
    const result = await api("/activity-log", { method: "POST", body: JSON.stringify(body) });
    return { content: [{ type: "text", text: `Logged ${action_name} on ${need_type} (${boost_amount > 0 ? "+" : ""}${boost_amount}%) — id ${result.id}` }] };
  }
);

server.tool(
  "recent_activity",
  "Get the most recent activity log entries (default 20). Optionally filter by need.",
  {
    limit: z.number().optional(),
    need: z.enum(NEED_TYPES).optional()
  },
  async ({ limit, need }) => {
    const params = new URLSearchParams();
    params.set("limit", String(limit ?? 20));
    if (need) params.set("need", need);
    const rows = await api(`/activity-log?${params}`);
    return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }] };
  }
);

// ─── STATE / OVERVIEW ──────────────────────────────────────────

server.tool(
  "get_overview",
  "One-shot pull of the user's full state: aspirations, tasks, recent log, current need values.",
  {},
  async () => {
    const data = await api("/sync?since=0");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

// ─── BOOT ──────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
console.error("[me-sims-tracker-mcp] connected via stdio");
