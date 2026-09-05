import type { Discipline, FetchLike } from "../types";

/**
 * Liquipedia MediaWiki API.
 *
 * Правила из их terms of use (<https://liquipedia.net/api-terms-of-use>)
 * соблюдаются здесь и в вызывающем коде:
 *   - свой User-Agent с названием проекта и контактом, дженерики блокируются;
 *   - обязательный gzip, без него приходит 406;
 *   - не чаще 1 запроса в 2 секунды, а `action=parse` — 1 запроса в 30 секунд;
 *   - результаты кэшировать как можно дольше;
 *   - контент под CC-BY-SA 3.0, атрибуция обязательна в интерфейсе.
 *
 * Данные матчей лежат в LPDB и рендерятся Lua-модулями, поэтому викитекст
 * страницы бесполезен — нужен именно отрендеренный HTML из `action=parse`.
 *
 * Важно: для VALORANT этот путь не работает. Проверено 2026-09-05: на
 * valorant-вики тот же шаблон отдаёт пустоту (см. docs/DATA_SOURCES.md).
 */

export const USER_AGENT = "BetTrackerBot/1.0 (https://github.com/Quar33x/bet-tracker)";

/** Пауза между тяжёлыми `action=parse` запросами. */
export const PARSE_MIN_INTERVAL_MS = 30_000;

const WIKI: Partial<Record<Discipline, string>> = {
  cs2: "counterstrike",
  dota2: "dota2",
};

export interface LiquipediaMatch {
  /** Unix-секунды: Liquipedia кладёт готовый timestamp в data-sort-value. */
  timestamp: number | null;
  tier: string | null;
  /** Offline / Online. */
  type: string | null;
  tournament: string | null;
  opponent: string | null;
  scoreFor: number | null;
  scoreAgainst: number | null;
  result: "win" | "loss" | "draw" | null;
}

export interface LiquipediaAggregates {
  matches: { wins: number; losses: number };
  games: { wins: number; losses: number };
  rounds: { wins: number; losses: number };
  period: string | null;
}

export interface LiquipediaTeamHistory {
  aggregates: LiquipediaAggregates | null;
  matches: LiquipediaMatch[];
}

export function matchesPageUrl(discipline: Discipline, teamPage: string): string {
  const wiki = WIKI[discipline];
  if (!wiki) {
    throw new Error(`Liquipedia: дисциплина ${discipline} не поддерживается этим путём`);
  }
  const page = encodeURIComponent(teamPage.replace(/ /g, "_") + "/Matches");
  return `https://liquipedia.net/${wiki}/api.php?action=parse&page=${page}&prop=text&format=json`;
}

function decodeEntities(input: string): string {
  return input
    .replace(/&#160;|&nbsp;/g, " ")
    .replace(/&#58;/g, ":")
    .replace(/&#95;/g, "_")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function stripTags(html: string): string {
  return decodeEntities(html.replace(/<[^>]*>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function attr(html: string, name: string): string | null {
  const match = new RegExp(`${name}="([^"]*)"`).exec(html);
  return match?.[1] ?? null;
}

/** Агрегаты вида «165W : 45L (78.57%) in matches and ... in games and ... in rounds». */
export function parseAggregates(html: string): LiquipediaAggregates | null {
  const text = decodeEntities(html.replace(/<[^>]*>/g, " ")).replace(/\s+/g, " ");

  const read = (unit: string): { wins: number; losses: number } | null => {
    const match = new RegExp(`(\\d+)W\\s*:\\s*(\\d+)L[^)]*\\)\\s*in ${unit}`).exec(text);
    if (!match) return null;
    return { wins: Number(match[1]), losses: Number(match[2]) };
  };

  const matches = read("matches");
  const games = read("games");
  const rounds = read("rounds");
  if (!matches && !games && !rounds) return null;

  const period = /For matches between ([^:<]+):/.exec(text)?.[1]?.trim() ?? null;

  return {
    matches: matches ?? { wins: 0, losses: 0 },
    games: games ?? { wins: 0, losses: 0 },
    rounds: rounds ?? { wins: 0, losses: 0 },
    period,
  };
}

function parseResult(cell: string): "win" | "loss" | "draw" | null {
  const type = attr(cell, "data-label-type");
  if (!type) return null;
  if (type.includes("win")) return "win";
  if (type.includes("loss") || type.includes("defeat")) return "loss";
  if (type.includes("draw")) return "draw";
  return null;
}

function parseScore(cell: string): { scoreFor: number | null; scoreAgainst: number | null } {
  const numbers = stripTags(cell).match(/\d+/g);
  if (!numbers || numbers.length < 2) return { scoreFor: null, scoreAgainst: null };
  return { scoreFor: Number(numbers[0]), scoreAgainst: Number(numbers[1]) };
}

/**
 * Разбирает таблицу матчей команды.
 *
 * Порядок ячеек: дата, тир, тип, иконка игры, иконка лиги, турнир, метка
 * результата, счёт, соперник, VOD. Разметка держится на этом порядке — если
 * Liquipedia его поменяет, тесты на фикстуре это покажут.
 */
export function parseMatches(html: string): LiquipediaMatch[] {
  const rows = html.match(/<tr[^>]*table2__row--body[^>]*>[\s\S]*?<\/tr>/g)
    ?? html.match(/<tr[^>]*row--body[^>]*>[\s\S]*?<\/tr>/g)
    ?? [];

  return rows.map((row) => {
    const cells = row.match(/<td[\s\S]*?<\/td>/g) ?? [];
    const cell = (i: number) => cells[i] ?? "";

    const timestampRaw = attr(cell(0), "data-sort-value");
    const timestamp = timestampRaw && /^\d+$/.test(timestampRaw) ? Number(timestampRaw) : null;
    const { scoreFor, scoreAgainst } = parseScore(cell(7));

    return {
      timestamp,
      tier: stripTags(cell(1)) || null,
      type: stripTags(cell(2)) || null,
      tournament: stripTags(cell(5)) || null,
      result: parseResult(cell(6)),
      scoreFor,
      scoreAgainst,
      opponent: attr(cell(8), "data-sort-value") ?? (stripTags(cell(8)) || null),
    };
  });
}

export function parseTeamHistory(html: string): LiquipediaTeamHistory {
  return { aggregates: parseAggregates(html), matches: parseMatches(html) };
}

/** Личные встречи: фильтр истории команды по сопернику. */
export function headToHead(matches: LiquipediaMatch[], opponent: string): LiquipediaMatch[] {
  const needle = opponent.trim().toLowerCase();
  return matches.filter((m) => m.opponent?.trim().toLowerCase() === needle);
}

/** Форма по последним N матчам. */
export function summarizeForm(
  matches: LiquipediaMatch[],
  lastN = 10,
): { wins: number; losses: number; played: number } {
  const recent = matches.filter((m) => m.result !== null).slice(0, lastN);
  const wins = recent.filter((m) => m.result === "win").length;
  const losses = recent.filter((m) => m.result === "loss").length;
  return { wins, losses, played: recent.length };
}

export async function fetchTeamHistory(
  fetchImpl: FetchLike,
  discipline: Discipline,
  teamPage: string,
): Promise<LiquipediaTeamHistory> {
  const response = await fetchImpl(matchesPageUrl(discipline, teamPage), {
    headers: {
      "user-agent": USER_AGENT,
      "accept-encoding": "gzip",
    },
  });
  if (!response.ok) throw new Error(`Liquipedia ответила ${response.status}`);

  const body = (await response.json()) as {
    parse?: { text?: { "*"?: string } };
    error?: { info?: string };
  };
  if (body.error) throw new Error(`Liquipedia: ${body.error.info ?? "неизвестная ошибка"}`);

  const html = body.parse?.text?.["*"];
  if (!html) throw new Error("Liquipedia: пустой ответ, страницы матчей нет");

  return parseTeamHistory(html);
}
