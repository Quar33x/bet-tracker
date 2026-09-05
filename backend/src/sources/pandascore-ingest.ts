import { SourceCache } from "../cache";
import { Repo } from "../repo";
import type { Discipline, Env, FetchLike, IngestedMatch } from "../types";
import {
  fetchMatches as fetchPandaScoreMatches,
  pastMatchesUrl,
  runningMatchesUrl,
  toIngestedMatch as pandaScoreToIngested,
  upcomingMatchesUrl,
} from "./pandascore";

export interface PandaScoreIngestResult {
  discipline: Discipline;
  upcoming: number;
  running: number;
  past: number;
  errors: string[];
}

export async function ingestPandaScore(
  env: Env,
  discipline: Discipline,
  fetchImpl: FetchLike = fetch,
): Promise<PandaScoreIngestResult> {
  if (!env.PANDASCORE_KEY) {
    throw new Error("PANDASCORE_KEY не настроен");
  }

  const repo = new Repo(env.DB);
  const cache = new SourceCache(env.DB);
  const result: PandaScoreIngestResult = {
    discipline,
    upcoming: 0,
    running: 0,
    past: 0,
    errors: [],
  };

  async function processMatches(
    kind: "upcoming" | "running" | "past",
    url: string,
    ttl: number,
  ): Promise<void> {
    try {
      const cacheKey = `pandascore:${discipline}:${kind}`;
      let rawJson = await cache.get(cacheKey);

      if (!rawJson) {
        const matches = await fetchPandaScoreMatches(fetchImpl, url, env.PANDASCORE_KEY!);
        rawJson = JSON.stringify(matches);
        await cache.set(cacheKey, rawJson, ttl);
      }

      const raw = JSON.parse(rawJson);
      const ingested: IngestedMatch[] = raw.map(pandaScoreToIngested).filter(Boolean);

      for (const match of ingested) {
        await repo.upsertMatch(match);
        result[kind]++;
      }
    } catch (error) {
      result.errors.push(
        `${kind}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  await processMatches("upcoming", upcomingMatchesUrl(discipline, 1, 50), 3600);
  await processMatches("running", runningMatchesUrl(discipline), 300);
  await processMatches("past", pastMatchesUrl(discipline, 1, 20), 7200);

  return result;
}
