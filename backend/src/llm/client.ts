import Anthropic from "@anthropic-ai/sdk";
import { BudgetExceededError, costUsd, type TokenUsage } from "./cost";

export const PREVIEW_MODEL = "claude-opus-5";
export const SUMMARY_MODEL = "claude-sonnet-5";

/** Потолок расходов в сутки по умолчанию, если не задан в настройках воркера. */
export const DEFAULT_DAILY_BUDGET_USD = 5;

export interface LlmCallResult {
  text: string;
  model: string;
  usage: TokenUsage;
  costUsd: number;
}

export class ModelRefusedError extends Error {
  constructor(readonly category: string | null, readonly explanation: string | null) {
    super(`Модель отказалась отвечать${category ? ` (${category})` : ""}: ${explanation ?? "без пояснения"}`);
    this.name = "ModelRefusedError";
  }
}

export function createClient(apiKey: string): Anthropic {
  return new Anthropic({ apiKey });
}

export interface PreviewCallOptions {
  client: Anthropic;
  system: string;
  userContent: string;
  /** Проверка бюджета до запроса: возвращает потраченное за сутки. */
  spentTodayUsd: number;
  dailyBudgetUsd: number;
}

/**
 * Предматчевый анализ. Синхронный вызов: пользователь ждёт ответ перед
 * ставкой, экономить здесь секунды за счёт качества смысла нет.
 *
 * Системный промпт кэшируется — он не меняется между матчами, меняется
 * только досье. Проверять, что кэш работает, надо по
 * `usage.cache_read_input_tokens`: если там ноль на повторных запросах,
 * значит что-то незаметно ломает префикс.
 *
 * Серверные fallback'и на отказ модели сознательно не подключены: параметр
 * бета-версионный, а проверить его без живого ключа нельзя. Вместо этого
 * отказ обрабатывается явно и доносится до пользователя как есть.
 */
export async function callPreview({
  client,
  system,
  userContent,
  spentTodayUsd,
  dailyBudgetUsd,
}: PreviewCallOptions): Promise<LlmCallResult> {
  if (spentTodayUsd >= dailyBudgetUsd) {
    throw new BudgetExceededError(spentTodayUsd, dailyBudgetUsd);
  }

  const response = await client.messages.create({
    model: PREVIEW_MODEL,
    max_tokens: 16000,
    thinking: { type: "adaptive" },
    output_config: { effort: "high" },
    system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
    messages: [{ role: "user", content: userContent }],
  });

  if (response.stop_reason === "refusal") {
    throw new ModelRefusedError(
      response.stop_details?.category ?? null,
      response.stop_details?.explanation ?? null,
    );
  }

  const text = response.content
    .filter((block): block is Anthropic.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("\n")
    .trim();

  if (!text) throw new Error("Модель вернула пустой ответ");

  return {
    text,
    model: response.model,
    usage: response.usage,
    costUsd: costUsd(PREVIEW_MODEL, response.usage),
  };
}

export interface BatchSummaryRequest {
  /** Наш id матча — по нему разложим результаты обратно. */
  matchId: number;
  userContent: string;
}

/**
 * Ставит саммари в очередь Batch API: вдвое дешевле обычных запросов.
 *
 * Саммари не нужно немедленно — матч уже закончился, текст должен быть к
 * моменту, когда пользователь откроет приложение. Результаты забирает крон.
 */
export async function submitSummaryBatch(
  client: Anthropic,
  system: string,
  requests: BatchSummaryRequest[],
): Promise<string> {
  if (requests.length === 0) throw new Error("Пустой батч");

  const batch = await client.messages.batches.create({
    requests: requests.map((request) => ({
      custom_id: `match-${request.matchId}`,
      params: {
        model: SUMMARY_MODEL,
        max_tokens: 4000,
        system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
        messages: [{ role: "user", content: request.userContent }],
      },
    })),
  });

  return batch.id;
}

export interface BatchOutcome {
  matchId: number;
  text: string | null;
  error: string | null;
  usage: TokenUsage | null;
  costUsd: number;
}

/** Разбирает id вида `match-42` обратно в номер матча. */
export function parseCustomId(customId: string): number | null {
  const match = /^match-(\d+)$/.exec(customId);
  return match ? Number(match[1]) : null;
}

export async function collectBatchResults(
  client: Anthropic,
  batchId: string,
): Promise<{ done: boolean; outcomes: BatchOutcome[] }> {
  const batch = await client.messages.batches.retrieve(batchId);
  if (batch.processing_status !== "ended") {
    return { done: false, outcomes: [] };
  }

  const outcomes: BatchOutcome[] = [];

  for await (const result of await client.messages.batches.results(batchId)) {
    const matchId = parseCustomId(result.custom_id);
    if (matchId === null) continue;

    if (result.result.type === "succeeded") {
      const message = result.result.message;
      const text = message.content
        .filter((block): block is Anthropic.TextBlock => block.type === "text")
        .map((block) => block.text)
        .join("\n")
        .trim();

      outcomes.push({
        matchId,
        text: text || null,
        error: text ? null : "пустой ответ",
        usage: message.usage,
        costUsd: costUsd(SUMMARY_MODEL, message.usage, { batch: true }),
      });
    } else {
      outcomes.push({
        matchId,
        text: null,
        error: result.result.type,
        usage: null,
        costUsd: 0,
      });
    }
  }

  return { done: true, outcomes };
}
