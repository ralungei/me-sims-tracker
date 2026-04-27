/// <reference types="@cloudflare/workers-types" />

/// Durable Object that holds the open WebSocket connections for one user.
/// One instance per user (we use the singleton id "global" since this app is
/// single-tenant). Mutations on the Worker are funnelled through here so every
/// connected device gets a "sync changed" event in real time.
export class SyncHub {
  private state: DurableObjectState;
  private clients = new Set<WebSocket>();

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url);

    if (url.pathname === "/connect") {
      if (req.headers.get("upgrade")?.toLowerCase() !== "websocket") {
        return new Response("expected websocket", { status: 400 });
      }
      const pair = new WebSocketPair();
      this.acceptSession(pair[1]);
      return new Response(null, { status: 101, webSocket: pair[0] });
    }

    if (url.pathname === "/broadcast" && req.method === "POST") {
      const payload = await req.text();
      const dead: WebSocket[] = [];
      for (const ws of this.clients) {
        try {
          ws.send(payload);
        } catch {
          dead.push(ws);
        }
      }
      for (const ws of dead) this.clients.delete(ws);
      return new Response(JSON.stringify({ delivered: this.clients.size }), {
        headers: { "Content-Type": "application/json" }
      });
    }

    return new Response("not found", { status: 404 });
  }

  private acceptSession(ws: WebSocket) {
    ws.accept();
    this.clients.add(ws);

    ws.send(JSON.stringify({ type: "hello", ts: Date.now() }));

    ws.addEventListener("close", () => this.clients.delete(ws));
    ws.addEventListener("error", () => this.clients.delete(ws));

    ws.addEventListener("message", (event) => {
      // Echo only "ping" messages to keep timeouts at bay.
      if (typeof event.data === "string") {
        try {
          const parsed = JSON.parse(event.data);
          if (parsed?.type === "ping") {
            ws.send(JSON.stringify({ type: "pong", ts: Date.now() }));
          }
        } catch {
          /* ignore non-JSON */
        }
      }
    });
  }
}
