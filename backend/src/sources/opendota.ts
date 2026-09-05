import type { FetchLike, IngestedMatch } from "../types";

const BASE = "https://api.opendota.com/api";

/** Матч команды в ответе `GET /teams/{id}/matches`. */
export interface OpenDotaTeamMatch {
  match_id: number;
  radiant: boolean;
  radiant_win: boolean;
  start_time: number;
  leagueid: number | null;
  league_name: string | null;
  opposing_team_id: number | null;
  opposing_team_name: string | null;
}

export interface OpenDotaExplorerRow {
  match_id: number;
  start_time: number;
  radiant_team_id: number;
  dire_team_id: number;
  radiant_win: boolean;
  league_name: string | null;
}

/**
 * Приводит матчи команды к нашей форме.
 *
 * OpenDota отдаёт матч «с точки зрения» запрошенной команды: она либо Radiant,
 * либо Dire, а соперник назван одним полем. Раскладываем это в пару A/B, где
 * A — всегда запрошенная команда.
 */
export function toIngestedMatches(
  team: { id: number; name: string },
  rows: OpenDotaTeamMatch[],
): IngestedMatch[] {
  return rows
    .filter((row) => row.opposing_team_id !== null && row.opposing_team_name !== null)
    .map((row) => {
      const teamWon = row.radiant === row.radiant_win;
      return {
        discipline: "dota2" as const,
        source: "opendota" as const,
        externalId: String(row.match_id),
        tournamentName: row.league_name,
        teamA: { name: team.name, openDotaId: team.id },
        teamB: { name: row.opposing_team_name!, openDotaId: row.opposing_team_id },
        bestOf: null,
        scheduledAt: row.start_time,
        status: "finished" as const,
        scoreA: teamWon ? 1 : 0,
        scoreB: teamWon ? 0 : 1,
        maps: [],
      };
    });
}

/**
 * SQL для личных встреч двух команд через `/explorer`.
 *
 * Запрос собирается строкой, поэтому id обязаны быть целыми числами —
 * иначе получаем SQL-инъекцию в чужую базу.
 */
export function headToHeadQuery(teamIdA: number, teamIdB: number, limit = 20): string {
  for (const id of [teamIdA, teamIdB, limit]) {
    if (!Number.isInteger(id) || id <= 0) {
      throw new Error(`headToHeadQuery: ожидалось целое положительное число, получено ${id}`);
    }
  }
  return [
    "select m.match_id, m.start_time, m.radiant_team_id, m.dire_team_id,",
    "       m.radiant_win, l.name as league_name",
    "from matches m left join leagues l on l.leagueid = m.leagueid",
    `where m.radiant_team_id in (${teamIdA}, ${teamIdB})`,
    `  and m.dire_team_id in (${teamIdA}, ${teamIdB})`,
    `order by m.start_time desc limit ${limit}`,
  ].join("\n");
}

export function teamMatchesUrl(teamId: number): string {
  if (!Number.isInteger(teamId) || teamId <= 0) {
    throw new Error(`teamMatchesUrl: некорректный id команды ${teamId}`);
  }
  return `${BASE}/teams/${teamId}/matches`;
}

export function explorerUrl(sql: string): string {
  return `${BASE}/explorer?sql=${encodeURIComponent(sql)}`;
}

export async function fetchTeamMatches(
  fetchImpl: FetchLike,
  teamId: number,
): Promise<OpenDotaTeamMatch[]> {
  const response = await fetchImpl(teamMatchesUrl(teamId));
  if (!response.ok) throw new Error(`OpenDota ответил ${response.status}`);
  return (await response.json()) as OpenDotaTeamMatch[];
}

export async function fetchHeadToHead(
  fetchImpl: FetchLike,
  teamIdA: number,
  teamIdB: number,
  limit = 20,
): Promise<OpenDotaExplorerRow[]> {
  const response = await fetchImpl(explorerUrl(headToHeadQuery(teamIdA, teamIdB, limit)));
  if (!response.ok) throw new Error(`OpenDota explorer ответил ${response.status}`);
  const body = (await response.json()) as { rows?: OpenDotaExplorerRow[] };
  return body.rows ?? [];
}

/** Форма команды по последним матчам: побед, поражений, серия. */
export function summarizeForm(
  team: { id: number },
  rows: OpenDotaTeamMatch[],
  lastN = 10,
): { wins: number; losses: number; streak: number } {
  const recent = rows.slice(0, lastN);
  let wins = 0;
  let losses = 0;
  let streak = 0;
  let streakBroken = false;

  for (const row of recent) {
    const won = row.radiant === row.radiant_win;
    if (won) wins++;
    else losses++;

    if (!streakBroken) {
      const first = recent[0]!;
      const firstWon = first.radiant === first.radiant_win;
      if (won === firstWon) streak += firstWon ? 1 : -1;
      else streakBroken = true;
    }
  }

  return { wins, losses, streak };
}
