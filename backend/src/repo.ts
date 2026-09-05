import type { Discipline, IngestedMatch, IngestedTeam } from "./types";

const now = () => Math.floor(Date.now() / 1000);

export interface MatchRow {
  id: number;
  discipline: string;
  source: string;
  external_id: string;
  tournament_name: string | null;
  team_a: string | null;
  team_b: string | null;
  best_of: number | null;
  scheduled_at: number | null;
  status: string;
  score_a: number | null;
  score_b: number | null;
}

export class Repo {
  constructor(private db: D1Database) {}

  async upsertTeam(discipline: Discipline, team: IngestedTeam): Promise<number> {
    await this.db
      .prepare(
        `INSERT INTO teams (discipline, name, short_name, opendota_id, pandascore_id, liquipedia_page, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT (discipline, name) DO UPDATE SET
           short_name      = COALESCE(excluded.short_name, teams.short_name),
           opendota_id     = COALESCE(excluded.opendota_id, teams.opendota_id),
           pandascore_id   = COALESCE(excluded.pandascore_id, teams.pandascore_id),
           liquipedia_page = COALESCE(excluded.liquipedia_page, teams.liquipedia_page),
           updated_at      = excluded.updated_at`,
      )
      .bind(
        discipline,
        team.name,
        team.shortName ?? null,
        team.openDotaId ?? null,
        team.pandaScoreId ?? null,
        team.liquipediaPage ?? null,
        now(),
      )
      .run();

    const row = await this.db
      .prepare("SELECT id FROM teams WHERE discipline = ? AND name = ?")
      .bind(discipline, team.name)
      .first<{ id: number }>();
    if (!row) throw new Error(`не удалось сохранить команду ${team.name}`);
    return row.id;
  }

  async upsertMatch(match: IngestedMatch): Promise<number> {
    const teamAId = await this.upsertTeam(match.discipline, match.teamA);
    const teamBId = await this.upsertTeam(match.discipline, match.teamB);

    await this.db
      .prepare(
        `INSERT INTO matches (discipline, source, external_id, tournament_name, team_a_id, team_b_id,
                              best_of, scheduled_at, status, score_a, score_b, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT (source, external_id) DO UPDATE SET
           tournament_name = COALESCE(excluded.tournament_name, matches.tournament_name),
           best_of         = COALESCE(excluded.best_of, matches.best_of),
           scheduled_at    = COALESCE(excluded.scheduled_at, matches.scheduled_at),
           status          = excluded.status,
           score_a         = excluded.score_a,
           score_b         = excluded.score_b,
           updated_at      = excluded.updated_at`,
      )
      .bind(
        match.discipline,
        match.source,
        match.externalId,
        match.tournamentName,
        teamAId,
        teamBId,
        match.bestOf,
        match.scheduledAt,
        match.status,
        match.scoreA,
        match.scoreB,
        now(),
      )
      .run();

    const row = await this.db
      .prepare("SELECT id FROM matches WHERE source = ? AND external_id = ?")
      .bind(match.source, match.externalId)
      .first<{ id: number }>();
    if (!row) throw new Error(`не удалось сохранить матч ${match.externalId}`);

    if (match.maps.length > 0) {
      await this.replaceMaps(row.id, match);
    }
    return row.id;
  }

  private async replaceMaps(matchId: number, match: IngestedMatch): Promise<void> {
    const statements = [
      this.db.prepare("DELETE FROM match_maps WHERE match_id = ?").bind(matchId),
      ...match.maps.map((map) =>
        this.db
          .prepare(
            `INSERT INTO match_maps (match_id, position, map_name, score_a, score_b, winner)
             VALUES (?, ?, ?, ?, ?, ?)`,
          )
          .bind(matchId, map.position, map.mapName, map.scoreA, map.scoreB, map.winner),
      ),
    ];
    await this.db.batch(statements);
  }

  async upcomingMatches(discipline: Discipline | null, limit: number): Promise<MatchRow[]> {
    const sql = `SELECT m.id, m.discipline, m.source, m.external_id, m.tournament_name,
                        a.name AS team_a, b.name AS team_b, m.best_of, m.scheduled_at,
                        m.status, m.score_a, m.score_b
                 FROM matches m
                 LEFT JOIN teams a ON a.id = m.team_a_id
                 LEFT JOIN teams b ON b.id = m.team_b_id
                 WHERE m.status != 'finished'
                   ${discipline ? "AND m.discipline = ?" : ""}
                 ORDER BY m.scheduled_at ASC
                 LIMIT ?`;
    const stmt = discipline
      ? this.db.prepare(sql).bind(discipline, limit)
      : this.db.prepare(sql).bind(limit);
    const { results } = await stmt.all<MatchRow>();
    return results ?? [];
  }

  async pastMatches(discipline: Discipline | null, limit: number): Promise<MatchRow[]> {
    const sql = `SELECT m.id, m.discipline, m.source, m.external_id, m.tournament_name,
                        a.name AS team_a, b.name AS team_b, m.best_of, m.scheduled_at,
                        m.status, m.score_a, m.score_b
                 FROM matches m
                 LEFT JOIN teams a ON a.id = m.team_a_id
                 LEFT JOIN teams b ON b.id = m.team_b_id
                 WHERE m.status = 'finished'
                   ${discipline ? "AND m.discipline = ?" : ""}
                 ORDER BY m.scheduled_at DESC
                 LIMIT ?`;
    const stmt = discipline
      ? this.db.prepare(sql).bind(discipline, limit)
      : this.db.prepare(sql).bind(limit);
    const { results } = await stmt.all<MatchRow>();
    return results ?? [];
  }

  async matchById(id: number): Promise<MatchDetailRow | null> {
    return await this.db
      .prepare(
        `SELECT m.id, m.discipline, m.source, m.external_id, m.tournament_name,
                m.team_a_id, m.team_b_id, a.name AS team_a, b.name AS team_b,
                a.liquipedia_page AS team_a_liquipedia, b.liquipedia_page AS team_b_liquipedia,
                m.best_of, m.scheduled_at, m.status, m.score_a, m.score_b
         FROM matches m
         LEFT JOIN teams a ON a.id = m.team_a_id
         LEFT JOIN teams b ON b.id = m.team_b_id
         WHERE m.id = ?`,
      )
      .bind(id)
      .first<MatchDetailRow>();
  }

  /** Последние сыгранные матчи команды — основа для «формы». */
  async teamRecentMatches(teamId: number, limit: number): Promise<TeamMatchRow[]> {
    const { results } = await this.db
      .prepare(
        `SELECT m.scheduled_at, m.tournament_name, m.score_a, m.score_b,
                m.team_a_id, m.team_b_id,
                a.name AS team_a, b.name AS team_b
         FROM matches m
         LEFT JOIN teams a ON a.id = m.team_a_id
         LEFT JOIN teams b ON b.id = m.team_b_id
         WHERE m.status = 'finished' AND (m.team_a_id = ? OR m.team_b_id = ?)
         ORDER BY m.scheduled_at DESC
         LIMIT ?`,
      )
      .bind(teamId, teamId, limit)
      .all<TeamMatchRow>();
    return results ?? [];
  }

  async headToHeadMatches(teamAId: number, teamBId: number, limit: number): Promise<TeamMatchRow[]> {
    const { results } = await this.db
      .prepare(
        `SELECT m.scheduled_at, m.tournament_name, m.score_a, m.score_b,
                m.team_a_id, m.team_b_id,
                a.name AS team_a, b.name AS team_b
         FROM matches m
         LEFT JOIN teams a ON a.id = m.team_a_id
         LEFT JOIN teams b ON b.id = m.team_b_id
         WHERE m.status = 'finished'
           AND ((m.team_a_id = ? AND m.team_b_id = ?) OR (m.team_a_id = ? AND m.team_b_id = ?))
         ORDER BY m.scheduled_at DESC
         LIMIT ?`,
      )
      .bind(teamAId, teamBId, teamBId, teamAId, limit)
      .all<TeamMatchRow>();
    return results ?? [];
  }

  async startJob(job: string): Promise<number> {
    const result = await this.db
      .prepare("INSERT INTO job_runs (job, started_at) VALUES (?, ?)")
      .bind(job, now())
      .run();
    return Number(result.meta.last_row_id);
  }

  async finishJob(id: number, ok: boolean, detail: string): Promise<void> {
    await this.db
      .prepare("UPDATE job_runs SET finished_at = ?, ok = ?, detail = ? WHERE id = ?")
      .bind(now(), ok ? 1 : 0, detail.slice(0, 2000), id)
      .run();
  }

  async recentJobs(limit = 20): Promise<unknown[]> {
    const { results } = await this.db
      .prepare("SELECT * FROM job_runs ORDER BY started_at DESC LIMIT ?")
      .bind(limit)
      .all();
    return results ?? [];
  }

  // MARK: тексты от модели

  async findAnalysis(
    matchId: number,
    kind: "preview" | "summary",
    promptVersion: string,
  ): Promise<AnalysisRow | null> {
    return await this.db
      .prepare(
        `SELECT match_id, kind, prompt_version, model, body, input_tokens, output_tokens,
                cost_usd, created_at
         FROM analyses WHERE match_id = ? AND kind = ? AND prompt_version = ?`,
      )
      .bind(matchId, kind, promptVersion)
      .first<AnalysisRow>();
  }

  async saveAnalysis(row: {
    matchId: number;
    kind: "preview" | "summary";
    promptVersion: string;
    model: string;
    body: string;
    inputTokens: number | null;
    outputTokens: number | null;
    costUsd: number;
  }): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO analyses (match_id, kind, prompt_version, model, body, input_tokens,
                               output_tokens, cost_usd, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT (match_id, kind, prompt_version) DO UPDATE SET
           model         = excluded.model,
           body          = excluded.body,
           input_tokens  = excluded.input_tokens,
           output_tokens = excluded.output_tokens,
           cost_usd      = excluded.cost_usd,
           created_at    = excluded.created_at`,
      )
      .bind(
        row.matchId,
        row.kind,
        row.promptVersion,
        row.model,
        row.body,
        row.inputTokens,
        row.outputTokens,
        row.costUsd,
        now(),
      )
      .run();
  }

  /** Сколько потрачено на модель за последние сутки. */
  async spentSince(sinceUnix: number): Promise<number> {
    const row = await this.db
      .prepare("SELECT COALESCE(SUM(cost_usd), 0) AS total FROM analyses WHERE created_at >= ?")
      .bind(sinceUnix)
      .first<{ total: number }>();
    return row?.total ?? 0;
  }

  async matchesNeedingSummary(promptVersion: string, limit: number): Promise<MatchRow[]> {
    const { results } = await this.db
      .prepare(
        `SELECT m.id, m.discipline, m.source, m.external_id, m.tournament_name,
                a.name AS team_a, b.name AS team_b, m.best_of, m.scheduled_at,
                m.status, m.score_a, m.score_b
         FROM matches m
         LEFT JOIN teams a ON a.id = m.team_a_id
         LEFT JOIN teams b ON b.id = m.team_b_id
         WHERE m.status = 'finished'
           AND NOT EXISTS (
             SELECT 1 FROM analyses an
             WHERE an.match_id = m.id AND an.kind = 'summary' AND an.prompt_version = ?
           )
         ORDER BY m.scheduled_at DESC
         LIMIT ?`,
      )
      .bind(promptVersion, limit)
      .all<MatchRow>();
    return results ?? [];
  }

  async recordBatch(id: string, kind: string): Promise<void> {
    await this.db
      .prepare("INSERT OR REPLACE INTO llm_batches (id, kind, status, created_at) VALUES (?, ?, 'pending', ?)")
      .bind(id, kind, now())
      .run();
  }

  async pendingBatches(): Promise<Array<{ id: string; kind: string; created_at: number }>> {
    const { results } = await this.db
      .prepare("SELECT id, kind, created_at FROM llm_batches WHERE status = 'pending' ORDER BY created_at")
      .all<{ id: string; kind: string; created_at: number }>();
    return results ?? [];
  }

  async closeBatch(id: string, status: "done" | "failed"): Promise<void> {
    await this.db
      .prepare("UPDATE llm_batches SET status = ?, closed_at = ? WHERE id = ?")
      .bind(status, now(), id)
      .run();
  }
}

export interface MatchDetailRow extends MatchRow {
  team_a_id: number | null;
  team_b_id: number | null;
  team_a_liquipedia: string | null;
  team_b_liquipedia: string | null;
}

export interface TeamMatchRow {
  scheduled_at: number | null;
  tournament_name: string | null;
  score_a: number | null;
  score_b: number | null;
  team_a_id: number | null;
  team_b_id: number | null;
  team_a: string | null;
  team_b: string | null;
}

export interface AnalysisRow {
  match_id: number;
  kind: string;
  prompt_version: string;
  model: string;
  body: string;
  input_tokens: number | null;
  output_tokens: number | null;
  cost_usd: number | null;
  created_at: number;
}
