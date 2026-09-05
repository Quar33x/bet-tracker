import { isAuthorized } from "./auth";
import { runScheduledIngest } from "./ingest";
import { Repo } from "./repo";
import type { Discipline, Env } from "./types";

const DISCIPLINES: readonly Discipline[] = ["valorant", "cs2", "dota2"];

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function parseDiscipline(value: string | null): Discipline | null {
  if (!value) return null;
  return DISCIPLINES.includes(value as Discipline) ? (value as Discipline) : null;
}

function parseLimit(value: string | null, fallback = 50): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(Math.trunc(parsed), 1), 200);
}

async function handleRequest(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  if (path === "/health") {
    return json({ ok: true, time: new Date().toISOString() });
  }

  if (!isAuthorized(request, env.APP_TOKEN)) {
    return json({ error: "unauthorized" }, 401);
  }

  const repo = new Repo(env.DB);
  const discipline = parseDiscipline(url.searchParams.get("discipline"));
  const limit = parseLimit(url.searchParams.get("limit"));

  switch (path) {
    case "/matches/upcoming":
      return json({ matches: await repo.upcomingMatches(discipline, limit) });

    case "/matches/past":
      return json({ matches: await repo.pastMatches(discipline, limit) });

    case "/jobs":
      return json({ jobs: await repo.recentJobs() });

    case "/admin/ingest": {
      if (request.method !== "POST") return json({ error: "method not allowed" }, 405);
      const result = await runScheduledIngest(env);
      return json(result);
    }

    default:
      return json({ error: "not found" }, 404);
  }
}

export default {
  async fetch(request, env) {
    try {
      return await handleRequest(request, env);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return json({ error: message }, 500);
    }
  },

  async scheduled(_event, env, ctx) {
    ctx.waitUntil(runScheduledIngest(env));
  },
} satisfies ExportedHandler<Env>;
