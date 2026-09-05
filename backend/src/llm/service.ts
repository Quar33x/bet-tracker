import { Repo } from "../repo";
import type { Env, FetchLike } from "../types";
import {
  callPreview,
  collectBatchResults,
  createClient,
  DEFAULT_DAILY_BUDGET_USD,
  submitSummaryBatch,
  SUMMARY_MODEL,
} from "./client";
import { collectDossier } from "./collect";
import { dossierFingerprint } from "./dossier";
import {
  parseJsonResponse,
  PREVIEW_PROMPT_VERSION,
  PREVIEW_SYSTEM,
  renderDossier,
  SUMMARY_PROMPT_VERSION,
  SUMMARY_SYSTEM,
  type PreviewResult,
  type SummaryResult,
} from "./prompts";

const DAY_SECONDS = 24 * 60 * 60;

/** За раз в батч уходит не больше этого числа матчей. */
const SUMMARY_BATCH_LIMIT = 25;

export interface PreviewPayload {
  matchId: number;
  cached: boolean;
  generatedAt: number;
  model: string;
  costUsd: number | null;
  analysis: PreviewResult;
  sources: string[];
}

function dailyBudget(env: Env): number {
  const raw = (env as unknown as { DAILY_BUDGET_USD?: string }).DAILY_BUDGET_USD;
  const parsed = raw ? Number(raw) : Number.NaN;
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_DAILY_BUDGET_USD;
}

/**
 * Предматчевый анализ с кэшем.
 *
 * Ключ кэша включает отпечаток досье: пока факты не изменились, повторный
 * запрос по тому же матчу ничего не стоит. Как только появились новые
 * матчи или агрегаты — отпечаток другой, и анализ пересчитывается.
 */
export async function getPreview(
  env: Env,
  matchId: number,
  { force = false, fetchImpl = fetch }: { force?: boolean; fetchImpl?: FetchLike } = {},
): Promise<PreviewPayload> {
  if (!env.ANTHROPIC_API_KEY) {
    throw new Error("ANTHROPIC_API_KEY не настроен");
  }

  const repo = new Repo(env.DB);
  const match = await repo.matchById(matchId);
  if (!match) throw new Error(`Матч ${matchId} не найден`);

  const dossier = await collectDossier(env, match, fetchImpl);
  const version = `${PREVIEW_PROMPT_VERSION}:${dossierFingerprint(dossier)}`;

  if (!force) {
    const cached = await repo.findAnalysis(matchId, "preview", version);
    if (cached) {
      return {
        matchId,
        cached: true,
        generatedAt: cached.created_at,
        model: cached.model,
        costUsd: cached.cost_usd,
        analysis: JSON.parse(cached.body) as PreviewResult,
        sources: dossier.sources,
      };
    }
  }

  const spentToday = await repo.spentSince(Math.floor(Date.now() / 1000) - DAY_SECONDS);

  const result = await callPreview({
    client: createClient(env.ANTHROPIC_API_KEY),
    system: PREVIEW_SYSTEM,
    userContent: renderDossier(dossier),
    spentTodayUsd: spentToday,
    dailyBudgetUsd: dailyBudget(env),
  });

  const analysis = parseJsonResponse<PreviewResult>(result.text);

  await repo.saveAnalysis({
    matchId,
    kind: "preview",
    promptVersion: version,
    model: result.model,
    body: JSON.stringify(analysis),
    inputTokens: result.usage.input_tokens,
    outputTokens: result.usage.output_tokens,
    costUsd: result.costUsd,
  });

  return {
    matchId,
    cached: false,
    generatedAt: Math.floor(Date.now() / 1000),
    model: result.model,
    costUsd: result.costUsd,
    analysis,
    sources: dossier.sources,
  };
}

export async function getStoredSummary(
  env: Env,
  matchId: number,
): Promise<{ matchId: number; generatedAt: number; summary: SummaryResult } | null> {
  const repo = new Repo(env.DB);
  const row = await repo.findAnalysis(matchId, "summary", SUMMARY_PROMPT_VERSION);
  if (!row) return null;
  return {
    matchId,
    generatedAt: row.created_at,
    summary: JSON.parse(row.body) as SummaryResult,
  };
}

/** Описание завершённого матча для саммари — коротко, фактами. */
function renderFinishedMatch(match: {
  team_a: string | null;
  team_b: string | null;
  tournament_name: string | null;
  discipline: string;
  score_a: number | null;
  score_b: number | null;
  best_of: number | null;
}): string {
  const lines = [
    `Дисциплина: ${match.discipline}`,
    `Турнир: ${match.tournament_name ?? "неизвестен"}`,
    `Команды: ${match.team_a ?? "?"} против ${match.team_b ?? "?"}`,
    match.best_of ? `Формат: BO${match.best_of}` : "Формат: неизвестен",
    match.score_a !== null && match.score_b !== null
      ? `Счёт серии: ${match.score_a}:${match.score_b}`
      : "Счёт: неизвестен",
  ];
  return lines.join("\n");
}

/**
 * Ставит в очередь саммари для завершённых матчей без текста.
 *
 * Вызывается кроном. Ничего не ждёт: результаты заберёт следующий заход.
 */
export async function queueSummaries(env: Env): Promise<{ queued: number; batchId: string | null }> {
  if (!env.ANTHROPIC_API_KEY) return { queued: 0, batchId: null };

  const repo = new Repo(env.DB);
  const spentToday = await repo.spentSince(Math.floor(Date.now() / 1000) - DAY_SECONDS);
  if (spentToday >= dailyBudget(env)) return { queued: 0, batchId: null };

  const matches = await repo.matchesNeedingSummary(SUMMARY_PROMPT_VERSION, SUMMARY_BATCH_LIMIT);
  if (matches.length === 0) return { queued: 0, batchId: null };

  const batchId = await submitSummaryBatch(
    createClient(env.ANTHROPIC_API_KEY),
    SUMMARY_SYSTEM,
    matches.map((match) => ({ matchId: match.id, userContent: renderFinishedMatch(match) })),
  );

  await repo.recordBatch(batchId, "summary");
  return { queued: matches.length, batchId };
}

/** Забирает готовые батчи и раскладывает саммари по матчам. */
export async function drainSummaryBatches(env: Env): Promise<{ collected: number; stillPending: number }> {
  if (!env.ANTHROPIC_API_KEY) return { collected: 0, stillPending: 0 };

  const repo = new Repo(env.DB);
  const client = createClient(env.ANTHROPIC_API_KEY);
  const pending = await repo.pendingBatches();

  let collected = 0;
  let stillPending = 0;

  for (const batch of pending) {
    try {
      const { done, outcomes } = await collectBatchResults(client, batch.id);
      if (!done) {
        stillPending++;
        continue;
      }

      for (const outcome of outcomes) {
        if (!outcome.text) continue;
        try {
          const summary = parseJsonResponse<SummaryResult>(outcome.text);
          await repo.saveAnalysis({
            matchId: outcome.matchId,
            kind: "summary",
            promptVersion: SUMMARY_PROMPT_VERSION,
            model: SUMMARY_MODEL,
            body: JSON.stringify(summary),
            inputTokens: outcome.usage?.input_tokens ?? null,
            outputTokens: outcome.usage?.output_tokens ?? null,
            costUsd: outcome.costUsd,
          });
          collected++;
        } catch {
          // Модель вернула что-то не то — матч просто останется без
          // саммари и попадёт в следующий батч.
        }
      }

      await repo.closeBatch(batch.id, "done");
    } catch {
      await repo.closeBatch(batch.id, "failed");
    }
  }

  return { collected, stillPending };
}
