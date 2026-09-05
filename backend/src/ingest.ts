import { SourceCache } from "./cache";
import { Repo } from "./repo";
import { fetchTeamMatches, toIngestedMatches } from "./sources/opendota";
import { ingestPandaScore } from "./sources/pandascore-ingest";
import type { Discipline, Env, FetchLike } from "./types";

/**
 * Команды, за которыми следим. Пока список зашит: OpenDota работает по
 * числовым id, а сопоставление «моё сокращение → внешний id» — это Этап 4
 * из SPEC. До него держим здесь несколько тир-1 команд, чтобы пайплайн было
 * на чём проверять.
 */
export const WATCHED_DOTA_TEAMS: ReadonlyArray<{ id: number; name: string }> = [
  { id: 7119388, name: "Team Spirit" },
  { id: 8261500, name: "Gaimin Gladiators" },
  { id: 8291895, name: "Tundra Esports" },
  { id: 2163, name: "Team Liquid" },
  { id: 8599101, name: "Xtreme Gaming" },
  { id: 8255888, name: "BetBoom Team" },
];

/** Сколько матчей одной команды забираем за проход. */
const MATCHES_PER_TEAM = 20;

export interface IngestResult {
  teamsProcessed: number;
  matchesUpserted: number;
  errors: string[];
}

export async function ingestDota(
  env: Env,
  fetchImpl: FetchLike = fetch,
  teams = WATCHED_DOTA_TEAMS,
): Promise<IngestResult> {
  const repo = new Repo(env.DB);
  const cache = new SourceCache(env.DB);
  const result: IngestResult = { teamsProcessed: 0, matchesUpserted: 0, errors: [] };

  for (const team of teams) {
    try {
      const cacheKey = `opendota:team:${team.id}`;
      let rawJson = await cache.get(cacheKey);

      if (!rawJson) {
        const rows = await fetchTeamMatches(fetchImpl, team.id);
        rawJson = JSON.stringify(rows);
        await cache.set(cacheKey, rawJson, 3600);
      }

      const rows = JSON.parse(rawJson);
      const matches = toIngestedMatches(team, rows.slice(0, MATCHES_PER_TEAM));
      for (const match of matches) {
        await repo.upsertMatch(match);
        result.matchesUpserted++;
      }
      result.teamsProcessed++;
    } catch (error) {
      result.errors.push(`${team.name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await cache.prune();
  return result;
}

/**
 * Команды CS2, для которых знаем страницу на Liquipedia.
 *
 * Без этой привязки не подтянутся агрегаты по раундам — то, ради чего
 * Liquipedia и нужна. Полноценный мэппинг «моё сокращение → внешний id» —
 * это Этап 4; пока хватает тир-1 списка.
 */
export const CS2_LIQUIPEDIA_PAGES: Readonly<Record<string, string>> = {
  Vitality: "Team Vitality",
  "Team Vitality": "Team Vitality",
  FURIA: "FURIA",
  "FURIA Esports": "FURIA",
  G2: "G2 Esports",
  "G2 Esports": "G2 Esports",
  NAVI: "Natus Vincere",
  "Natus Vincere": "Natus Vincere",
  MOUZ: "MOUZ",
  Falcons: "Team Falcons",
  "Team Falcons": "Team Falcons",
  Spirit: "Team Spirit",
  "Team Spirit": "Team Spirit",
  Astralis: "Astralis",
  Liquid: "Team Liquid",
  "Team Liquid": "Team Liquid",
  Heroic: "Heroic",
  "The MongolZ": "The MongolZ",
  Aurora: "Aurora Gaming",
};

/** Проставляет командам CS2 страницу Liquipedia там, где её ещё нет. */
export async function linkLiquipediaPages(env: Env): Promise<number> {
  const repo = new Repo(env.DB);
  let linked = 0;

  for (const [name, page] of Object.entries(CS2_LIQUIPEDIA_PAGES)) {
    linked += await repo.setLiquipediaPage("cs2", name, page);
  }

  return linked;
}

export async function runScheduledIngest(env: Env, fetchImpl: FetchLike = fetch): Promise<IngestResult> {
  const repo = new Repo(env.DB);
  const jobId = await repo.startJob("ingest");
  try {
    const result = await ingestDota(env, fetchImpl);

    // Расписание и результаты по трём дисциплинам — только если есть ключ.
    if (env.PANDASCORE_KEY) {
      for (const discipline of ["valorant", "cs2", "dota2"] as const) {
        try {
          const panda = await ingestPandaScore(env, discipline, fetchImpl);
          result.matchesUpserted += panda.upcoming + panda.running + panda.past;
          result.errors.push(...panda.errors.map((e) => `pandascore/${discipline}: ${e}`));
        } catch (error) {
          result.errors.push(
            `pandascore/${discipline}: ${error instanceof Error ? error.message : String(error)}`,
          );
        }
      }
    }

    await linkLiquipediaPages(env);
    await repo.finishJob(
      jobId,
      result.errors.length === 0,
      JSON.stringify(result),
    );
    return result;
  } catch (error) {
    await repo.finishJob(jobId, false, error instanceof Error ? error.message : String(error));
    throw error;
  }
}
