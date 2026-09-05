import type { Discipline } from "../types";

/**
 * Досье на матч — весь фактический материал, который уходит в модель.
 *
 * Собирается только из того, что реально есть в базе. Пустые места не
 * замалчиваются, а попадают в `gaps`: модель обязана о них сказать, иначе
 * анализ будет выглядеть полным там, где данных нет. Для VALORANT это
 * сейчас норма, а не исключение.
 */
export interface MatchDossier {
  discipline: Discipline;
  tournament: string | null;
  scheduledAt: number | null;
  bestOf: number | null;
  teamA: TeamDossier;
  teamB: TeamDossier;
  headToHead: HeadToHeadEntry[];
  gaps: string[];
  sources: string[];
}

export interface TeamDossier {
  name: string;
  form: { wins: number; losses: number; played: number } | null;
  /** Агрегаты за длинный период: по матчам, картам и раундам. */
  aggregates: {
    matches?: { wins: number; losses: number };
    games?: { wins: number; losses: number };
    rounds?: { wins: number; losses: number };
    period?: string | null;
  } | null;
  recentMatches: RecentMatch[];
}

export interface RecentMatch {
  timestamp: number | null;
  opponent: string | null;
  tournament: string | null;
  tier: string | null;
  scoreFor: number | null;
  scoreAgainst: number | null;
  result: "win" | "loss" | "draw" | null;
}

export interface HeadToHeadEntry extends RecentMatch {
  /** С точки зрения команды A. */
  perspective: "a";
}

/** Доля выигранных раундов — основа для оценки фор вроде «-3.5». */
export function roundWinRate(team: TeamDossier): number | null {
  const rounds = team.aggregates?.rounds;
  if (!rounds) return null;
  const total = rounds.wins + rounds.losses;
  if (total === 0) return null;
  return rounds.wins / total;
}

/** Доля выигранных карт. */
export function mapWinRate(team: TeamDossier): number | null {
  const games = team.aggregates?.games;
  if (!games) return null;
  const total = games.wins + games.losses;
  if (total === 0) return null;
  return games.wins / total;
}

/**
 * Перечисляет, чего в досье не хватает.
 *
 * Список идёт в промпт дословно, поэтому формулировки здесь — это то, что
 * пользователь увидит в разделе «чего не знаем».
 */
export function collectGaps(dossier: Omit<MatchDossier, "gaps">): string[] {
  const gaps: string[] = [];

  for (const [label, team] of [
    ["A", dossier.teamA],
    ["B", dossier.teamB],
  ] as const) {
    if (!team.aggregates?.rounds) {
      gaps.push(
        `Нет статистики по раундам для команды ${team.name} (${label}) — оценить фору по раундам нечем.`,
      );
    }
    if (team.recentMatches.length === 0) {
      gaps.push(`Нет истории последних матчей для команды ${team.name} (${label}).`);
    }
  }

  if (dossier.headToHead.length === 0) {
    gaps.push("Личных встреч в доступных данных не найдено.");
  }

  if (dossier.discipline === "valorant") {
    gaps.push(
      "По VALORANT на бесплатных источниках нет названий карт, счёта по раундам и статистики игроков: доступен только уровень серии.",
    );
  }

  const noMapScores = [dossier.teamA, dossier.teamB].every((t) =>
    t.recentMatches.every((m) => m.scoreFor === null),
  );
  if (noMapScores && dossier.teamA.recentMatches.length > 0) {
    gaps.push("В истории матчей нет счёта — известен только факт победы или поражения.");
  }

  return gaps;
}

export function buildDossier(input: Omit<MatchDossier, "gaps">): MatchDossier {
  return { ...input, gaps: collectGaps(input) };
}

/**
 * Детерминированная сериализация: ключи сортируются на всех уровнях,
 * поэтому одинаковые по смыслу досье дают одинаковую строку независимо от
 * порядка полей.
 */
export function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value) ?? "null";
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;

  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([, v]) => v !== undefined)
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([key, v]) => `${JSON.stringify(key)}:${stableStringify(v)}`);

  return `{${entries.join(",")}}`;
}

/**
 * Отпечаток досье: если факты не изменились, платить за повторный анализ
 * незачем. Считаем по содержимому, а не по времени запроса.
 */
export function dossierFingerprint(dossier: MatchDossier): string {
  const stable = stableStringify(dossier);
  let hash = 0x811c9dc5;
  for (let i = 0; i < stable.length; i++) {
    hash ^= stable.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, "0");
}
