import { SourceCache, } from "../cache";
import type { MatchDetailRow, TeamMatchRow } from "../repo";
import { Repo } from "../repo";
import { fetchTeamHistory } from "../sources/liquipedia";
import type { Discipline, Env, FetchLike } from "../types";
import { buildDossier, type MatchDossier, type RecentMatch, type TeamDossier } from "./dossier";

const RECENT_LIMIT = 15;
const H2H_LIMIT = 10;

/** Кэш истории Liquipedia: их лимит — 1 запрос в 30 секунд на action=parse. */
const LIQUIPEDIA_TTL_SECONDS = 6 * 60 * 60;

/** Разворачивает строку матча «с точки зрения» нужной команды. */
export function toRecentMatch(row: TeamMatchRow, teamId: number): RecentMatch {
  const isA = row.team_a_id === teamId;
  const scoreFor = isA ? row.score_a : row.score_b;
  const scoreAgainst = isA ? row.score_b : row.score_a;

  let result: "win" | "loss" | "draw" | null = null;
  if (scoreFor !== null && scoreAgainst !== null) {
    if (scoreFor > scoreAgainst) result = "win";
    else if (scoreFor < scoreAgainst) result = "loss";
    else result = "draw";
  }

  return {
    timestamp: row.scheduled_at,
    opponent: isA ? row.team_b : row.team_a,
    tournament: row.tournament_name,
    tier: null,
    scoreFor,
    scoreAgainst,
    result,
  };
}

export function summarizeForm(matches: RecentMatch[], lastN = 10) {
  const played = matches.filter((m) => m.result !== null).slice(0, lastN);
  return {
    wins: played.filter((m) => m.result === "win").length,
    losses: played.filter((m) => m.result === "loss").length,
    played: played.length,
  };
}

/**
 * Собирает досье на матч из того, что есть в базе, и обогащает агрегатами
 * Liquipedia для CS2 — именно оттуда берётся винрейт по раундам, без
 * которого разговор про форы беспредметен.
 */
export async function collectDossier(
  env: Env,
  match: MatchDetailRow,
  fetchImpl: FetchLike = fetch,
): Promise<MatchDossier> {
  const repo = new Repo(env.DB);
  const cache = new SourceCache(env.DB);
  const discipline = match.discipline as Discipline;
  const sources = new Set<string>();

  async function teamDossier(
    teamId: number | null,
    name: string | null,
    liquipediaPage: string | null,
  ): Promise<TeamDossier> {
    const teamName = name ?? "неизвестная команда";
    if (teamId === null) {
      return { name: teamName, form: null, aggregates: null, recentMatches: [] };
    }

    const rows = await repo.teamRecentMatches(teamId, RECENT_LIMIT);
    const recentMatches = rows.map((row) => toRecentMatch(row, teamId));
    if (recentMatches.length > 0) sources.add("PandaScore");

    let aggregates: TeamDossier["aggregates"] = null;

    if (discipline === "cs2" && liquipediaPage) {
      try {
        const key = `liquipedia:${discipline}:${liquipediaPage}`;
        const cached = await cache.get(key);
        const history = cached
          ? (JSON.parse(cached) as Awaited<ReturnType<typeof fetchTeamHistory>>)
          : await fetchTeamHistory(fetchImpl, discipline, liquipediaPage);

        if (!cached) {
          await cache.set(key, JSON.stringify(history), LIQUIPEDIA_TTL_SECONDS);
        }

        if (history.aggregates) {
          aggregates = {
            matches: history.aggregates.matches,
            games: history.aggregates.games,
            rounds: history.aggregates.rounds,
            period: history.aggregates.period,
          };
          sources.add("Liquipedia (CC-BY-SA 3.0)");
        }

        // История Liquipedia полнее нашей: в базе лежит только то, что мы
        // успели забрать, а у них — весь сезон.
        if (history.matches.length > 0) {
          recentMatches.splice(
            0,
            recentMatches.length,
            ...history.matches.slice(0, RECENT_LIMIT).map((m) => ({
              timestamp: m.timestamp,
              opponent: m.opponent,
              tournament: m.tournament,
              tier: m.tier,
              scoreFor: m.scoreFor,
              scoreAgainst: m.scoreAgainst,
              result: m.result,
            })),
          );
        }
      } catch {
        // Liquipedia недоступна — досье просто останется беднее, и это
        // честно попадёт в раздел «чего в данных нет».
      }
    }

    return {
      name: teamName,
      form: recentMatches.length > 0 ? summarizeForm(recentMatches) : null,
      aggregates,
      recentMatches,
    };
  }

  const teamA = await teamDossier(match.team_a_id, match.team_a, match.team_a_liquipedia);
  const teamB = await teamDossier(match.team_b_id, match.team_b, match.team_b_liquipedia);

  const h2hRows =
    match.team_a_id !== null && match.team_b_id !== null
      ? await repo.headToHeadMatches(match.team_a_id, match.team_b_id, H2H_LIMIT)
      : [];

  const headToHead = h2hRows.map((row) => ({
    ...toRecentMatch(row, match.team_a_id!),
    perspective: "a" as const,
  }));

  return buildDossier({
    discipline,
    tournament: match.tournament_name,
    scheduledAt: match.scheduled_at,
    bestOf: match.best_of,
    teamA,
    teamB,
    headToHead,
    sources: [...sources],
  });
}
