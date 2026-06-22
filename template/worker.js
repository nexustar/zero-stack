// zero-stack backend — the Worker owns /api/*; the static frontend in public/
// is served automatically by the Assets binding (see wrangler.toml [assets]).
//
// DB access uses TiDB's official HTTP serverless driver (@tidbcloud/serverless):
// plain HTTP (works on Workers, no TCP), with real parameter binding (`?`).
//
// Env (wrangler.toml [vars], injected at deploy):
//   TIDB_URL   mysql://user:pass@host:4000/   (TiDB Cloud Zero connection string)
//   API_TOKEN  optional; if set, /api/* requires Authorization: Bearer <token>

import { connect } from "@tidbcloud/serverless";

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);

    // Anything not under /api/ is a static asset → handled by the Assets binding,
    // so the Worker should never see it. If it does, it's a genuine 404.
    if (!pathname.startsWith("/api/")) return json({ error: "not found" }, 404);

    if (env.API_TOKEN) {
      const got = (request.headers.get("authorization") || "").replace(/^Bearer\s+/i, "");
      if (got !== env.API_TOKEN) return json({ error: "unauthorized" }, 401);
    }

    const conn = connect({ url: env.TIDB_URL });
    try {
      // Lazy schema init — keeps the scaffold single-command (no migration step).
      await conn.execute(
        "CREATE TABLE IF NOT EXISTS notes (id INT PRIMARY KEY AUTO_INCREMENT, body TEXT NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)"
      );

      if (pathname === "/api/notes" && request.method === "GET") {
        const notes = await conn.execute(
          "SELECT id, body, created_at FROM notes ORDER BY id DESC LIMIT 100"
        );
        return json({ notes });
      }

      if (pathname === "/api/notes" && request.method === "POST") {
        const { body } = await request.json().catch(() => ({}));
        if (!body || !String(body).trim()) return json({ error: "body required" }, 400);
        await conn.execute("INSERT INTO notes (body) VALUES (?)", [String(body)]);
        return json({ ok: true }, 201);
      }

      return json({ error: "not found" }, 404);
    } catch (err) {
      return json({ error: String(err.message || err) }, 500);
    }
  },
};
