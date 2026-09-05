export type Discipline = "valorant" | "cs2" | "dota2";
export type MatchStatus = "scheduled" | "running" | "finished";
export type SourceName = "opendota" | "pandascore" | "liquipedia" | "lpdb";

export interface Env {
  DB: D1Database;
  /** Токен, которым приложение авторизуется в этом API. */
  APP_TOKEN: string;
  PANDASCORE_KEY?: string;
  ANTHROPIC_API_KEY?: string;
}

/** Матч в том виде, в каком его приносит коннектор — ещё без наших id. */
export interface IngestedMatch {
  discipline: Discipline;
  source: SourceName;
  externalId: string;
  tournamentName: string | null;
  teamA: IngestedTeam;
  teamB: IngestedTeam;
  bestOf: number | null;
  scheduledAt: number | null;
  status: MatchStatus;
  scoreA: number | null;
  scoreB: number | null;
  maps: IngestedMap[];
}

export interface IngestedTeam {
  name: string;
  shortName?: string | null;
  openDotaId?: number | null;
  pandaScoreId?: number | null;
  liquipediaPage?: string | null;
}

export interface IngestedMap {
  position: number;
  mapName: string | null;
  /** Счёт в раундах. null у источников, которые раундов не отдают. */
  scoreA: number | null;
  scoreB: number | null;
  /** Победитель карты — заполняется даже когда счёта в раундах нет. */
  winner: "a" | "b" | null;
}

/** Минимум, который нужен коннекторам: подменяется в тестах. */
export type FetchLike = (url: string, init?: RequestInit) => Promise<Response>;
