import type { Discipline, FetchLike, IngestedMatch, IngestedTeam } from "../types";

const BASE = "https://api.pandascore.co";

export interface PandaScoreMatch {
  id: number;
  slug: string;
  scheduled_at: string | null;
  begin_at: string | null;
  status: "canceled" | "finished" | "not_started" | "running" | "postponed";
  number_of_games: number;
  videogame: { slug: string };
  league: { name: string; slug: string };
  serie: { full_name: string };
  opponents: Array<{
    opponent: {
      id: number;
      name: string;
      acronym: string | null;
    };
  }>;
  results?: Array<{
    team_id: number;
    score: number;
  }>;
  games?: PandaScoreGame[];
}

export interface PandaScoreGame {
  id: number;
  position: number;
  status: string;
  winner?: { id: number };
  finished: boolean;
}

function toDiscipline(slug: string): Discipline | null {
  if (slug === "valorant") return "valorant";
  if (slug === "cs-go" || slug === "cs2") return "cs2";
  if (slug === "dota-2") return "dota2";
  return null;
}

function toMatchStatus(status: string): "scheduled" | "running" | "finished" {
  if (status === "finished") return "finished";
  if (status === "running") return "running";
  return "scheduled";
}

function parseTimestamp(iso: string | null): number | null {
  if (!iso) return null;
  const ms = Date.parse(iso);
  return Number.isNaN(ms) ? null : Math.floor(ms / 1000);
}

export function toIngestedMatch(raw: PandaScoreMatch): IngestedMatch | null {
  const discipline = toDiscipline(raw.videogame.slug);
  if (!discipline) return null;

  if (raw.opponents.length !== 2) return null;
  const [oppA, oppB] = raw.opponents;

  const teamA: IngestedTeam = {
    name: oppA!.opponent.name,
    shortName: oppA!.opponent.acronym,
    pandaScoreId: oppA!.opponent.id,
  };
  const teamB: IngestedTeam = {
    name: oppB!.opponent.name,
    shortName: oppB!.opponent.acronym,
    pandaScoreId: oppB!.opponent.id,
  };

  let scoreA: number | null = null;
  let scoreB: number | null = null;

  if (raw.results && raw.results.length === 2) {
    const resA = raw.results.find((r) => r.team_id === oppA!.opponent.id);
    const resB = raw.results.find((r) => r.team_id === oppB!.opponent.id);
    scoreA = resA?.score ?? null;
    scoreB = resB?.score ?? null;
  }

  // На бесплатном плане PandaScore отдаёт по карте только победителя: ни
  // названия карты, ни счёта в раундах там нет. Пишем winner, счёт оставляем
  // пустым — его позже заполнят источники, которые раунды знают.
  const maps =
    raw.games?.map((g) => ({
      position: g.position,
      mapName: null,
      scoreA: null,
      scoreB: null,
      winner:
        g.winner?.id === oppA!.opponent.id
          ? ("a" as const)
          : g.winner?.id === oppB!.opponent.id
            ? ("b" as const)
            : null,
    })) ?? [];

  return {
    discipline,
    source: "pandascore",
    externalId: String(raw.id),
    tournamentName: `${raw.league.name} - ${raw.serie.full_name}`,
    teamA,
    teamB,
    bestOf: raw.number_of_games || null,
    scheduledAt: parseTimestamp(raw.scheduled_at ?? raw.begin_at),
    status: toMatchStatus(raw.status),
    scoreA,
    scoreB,
    maps,
  };
}

export function upcomingMatchesUrl(discipline: Discipline, page = 1, perPage = 50): string {
  const games: Record<Discipline, string> = {
    valorant: "valorant",
    cs2: "cs2",
    dota2: "dota-2",
  };
  const game = games[discipline];
  return `${BASE}/${game}/matches/upcoming?page=${page}&per_page=${perPage}&sort=scheduled_at`;
}

export function runningMatchesUrl(discipline: Discipline): string {
  const games: Record<Discipline, string> = {
    valorant: "valorant",
    cs2: "cs2",
    dota2: "dota-2",
  };
  const game = games[discipline];
  return `${BASE}/${game}/matches/running`;
}

export function pastMatchesUrl(discipline: Discipline, page = 1, perPage = 50): string {
  const games: Record<Discipline, string> = {
    valorant: "valorant",
    cs2: "cs2",
    dota2: "dota-2",
  };
  const game = games[discipline];
  return `${BASE}/${game}/matches/past?page=${page}&per_page=${perPage}&sort=-scheduled_at`;
}

export async function fetchMatches(
  fetchImpl: FetchLike,
  url: string,
  apiKey: string,
): Promise<PandaScoreMatch[]> {
  const response = await fetchImpl(url, {
    headers: { Authorization: `Bearer ${apiKey}` },
  });
  if (!response.ok) {
    throw new Error(`PandaScore responded ${response.status}`);
  }
  return (await response.json()) as PandaScoreMatch[];
}
