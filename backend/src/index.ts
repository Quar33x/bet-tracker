import { isAuthorized } from "./auth";
import { runScheduledIngest } from "./ingest";
import { ModelRefusedError } from "./llm/client";
import { BudgetExceededError } from "./llm/cost";
import { drainSummaryBatches, getPreview, getStoredSummary, queueSummaries } from "./llm/service";
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

    case "/spend": {
      const day = Math.floor(Date.now() / 1000) - 24 * 60 * 60;
      return json({ spentTodayUsd: await repo.spentSince(day) });
    }
  }

  const preview = /^\/matches\/(\d+)\/preview$/.exec(path);
  if (preview) {
    const matchId = Number(preview[1]);
    const force = url.searchParams.get("force") === "1";
    try {
      return json(await getPreview(env, matchId, { force }));
    } catch (error) {
      if (error instanceof BudgetExceededError) return json({ error: error.message }, 429);
      if (error instanceof ModelRefusedError) return json({ error: error.message }, 422);
      throw error;
    }
  }

  const summary = /^\/matches\/(\d+)\/summary$/.exec(path);
  if (summary) {
    const stored = await getStoredSummary(env, Number(summary[1]));
    return stored ? json(stored) : json({ error: "саммари ещё не готово" }, 404);
  }

  return json({ error: "not found" }, 404);
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
    // Порядок важен: сначала свежие матчи, потом саммари для тех, что
    // уже завершились, потом сбор готовых батчей с прошлого захода.
    ctx.waitUntil(
      (async () => {
        await runScheduledIngest(env);
        await drainSummaryBatches(env);
        await queueSummaries(env);
      })(),
    );
  },
} satisfies ExportedHandler<Env>;
