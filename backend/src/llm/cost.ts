/**
 * Учёт расходов на модель.
 *
 * Цены — с 2026-09-05, $ за миллион токенов. Если Anthropic их поменяет,
 * менять надо здесь, в одном месте.
 */
export const MODEL_PRICES: Record<string, { input: number; output: number; cacheRead: number }> = {
  "claude-opus-5": { input: 5, output: 25, cacheRead: 0.5 },
  "claude-sonnet-5": { input: 2, output: 10, cacheRead: 0.2 },
  "claude-haiku-4-5": { input: 1, output: 5, cacheRead: 0.1 },
};

export interface TokenUsage {
  input_tokens: number;
  output_tokens: number;
  cache_creation_input_tokens?: number | null;
  cache_read_input_tokens?: number | null;
}

export interface CostOptions {
  /** Batch API считает вдвое дешевле. */
  batch?: boolean;
}

/**
 * Стоимость одного вызова в долларах.
 *
 * Токены, записанные в кэш, стоят дороже обычных (примерно 1.25×), а
 * прочитанные из кэша — заметно дешевле. Игнорировать это нельзя: именно
 * на кэше держится смысл гонять один и тот же контекст турнира.
 */
export function costUsd(
  model: string,
  usage: TokenUsage,
  { batch = false }: CostOptions = {},
): number {
  const price = MODEL_PRICES[model];
  if (!price) return 0;

  const cacheWrite = usage.cache_creation_input_tokens ?? 0;
  const cacheRead = usage.cache_read_input_tokens ?? 0;

  const dollars =
    (usage.input_tokens * price.input +
      cacheWrite * price.input * 1.25 +
      cacheRead * price.cacheRead +
      usage.output_tokens * price.output) /
    1_000_000;

  return round6(batch ? dollars / 2 : dollars);
}

function round6(value: number): number {
  return Math.round(value * 1_000_000) / 1_000_000;
}

/** Сколько потрачено за последние сутки, чтобы упереться в потолок, а не в счёт. */
export interface BudgetState {
  spentUsd: number;
  limitUsd: number;
}

export function isWithinBudget({ spentUsd, limitUsd }: BudgetState): boolean {
  return spentUsd < limitUsd;
}

export class BudgetExceededError extends Error {
  constructor(readonly spentUsd: number, readonly limitUsd: number) {
    super(
      `Дневной лимит расходов исчерпан: потрачено $${spentUsd.toFixed(2)} из $${limitUsd.toFixed(2)}`,
    );
    this.name = "BudgetExceededError";
  }
}
