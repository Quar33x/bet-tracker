import { describe, expect, it } from "vitest";
import {
  pastMatchesUrl,
  toIngestedMatch,
  upcomingMatchesUrl,
  type PandaScoreMatch,
} from "../src/sources/pandascore";

function raw(overrides: Partial<PandaScoreMatch> = {}): PandaScoreMatch {
  return {
    id: 998877,
    slug: "furia-vs-vitality",
    scheduled_at: "2026-09-04T16:00:00Z",
    begin_at: null,
    status: "finished",
    number_of_games: 3,
    videogame: { slug: "cs2" },
    league: { name: "BLAST Open", slug: "blast-open" },
    serie: { full_name: "Porto 2026" },
    opponents: [
      { opponent: { id: 10, name: "FURIA", acronym: "FUR" } },
      { opponent: { id: 20, name: "Vitality", acronym: "VIT" } },
    ],
    results: [
      { team_id: 10, score: 1 },
      { team_id: 20, score: 2 },
    ],
    ...overrides,
  };
}

describe("toIngestedMatch", () => {
  it("раскладывает матч по нашей форме", () => {
    const match = toIngestedMatch(raw())!;
    expect(match.discipline).toBe("cs2");
    expect(match.source).toBe("pandascore");
    expect(match.externalId).toBe("998877");
    expect(match.tournamentName).toBe("BLAST Open - Porto 2026");
    expect(match.bestOf).toBe(3);
    expect(match.status).toBe("finished");
  });

  it("привязывает счёт к своей команде, а не к порядку в results", () => {
    const match = toIngestedMatch(
      raw({
        results: [
          { team_id: 20, score: 2 },
          { team_id: 10, score: 1 },
        ],
      }),
    )!;
    expect(match.scoreA).toBe(1);
    expect(match.scoreB).toBe(2);
  });

  it("переводит время в unix-секунды", () => {
    expect(toIngestedMatch(raw())!.scheduledAt).toBe(1788537600);
  });

  it("берёт begin_at, когда scheduled_at пуст", () => {
    const match = toIngestedMatch(raw({ scheduled_at: null, begin_at: "2026-09-04T16:00:00Z" }))!;
    expect(match.scheduledAt).toBe(1788537600);
  });

  it("переводит статусы в наши", () => {
    expect(toIngestedMatch(raw({ status: "not_started" }))!.status).toBe("scheduled");
    expect(toIngestedMatch(raw({ status: "postponed" }))!.status).toBe("scheduled");
    expect(toIngestedMatch(raw({ status: "running" }))!.status).toBe("running");
    expect(toIngestedMatch(raw({ status: "finished" }))!.status).toBe("finished");
  });

  it("понимает и cs-go, и cs2", () => {
    expect(toIngestedMatch(raw({ videogame: { slug: "cs-go" } }))!.discipline).toBe("cs2");
    expect(toIngestedMatch(raw({ videogame: { slug: "dota-2" } }))!.discipline).toBe("dota2");
    expect(toIngestedMatch(raw({ videogame: { slug: "valorant" } }))!.discipline).toBe("valorant");
  });

  it("пропускает чужие дисциплины", () => {
    expect(toIngestedMatch(raw({ videogame: { slug: "league-of-legends" } }))).toBeNull();
  });

  it("пропускает матч, где команд не две", () => {
    expect(toIngestedMatch(raw({ opponents: [] }))).toBeNull();
    expect(
      toIngestedMatch(raw({ opponents: [{ opponent: { id: 10, name: "FURIA", acronym: null } }] })),
    ).toBeNull();
  });

  it("оставляет счёт пустым, когда results нет", () => {
    const match = toIngestedMatch(raw({ results: undefined }))!;
    expect(match.scoreA).toBeNull();
    expect(match.scoreB).toBeNull();
  });

  it("пишет по карте победителя, но не выдаёт его за счёт в раундах", () => {
    const match = toIngestedMatch(
      raw({
        games: [
          { id: 1, position: 1, status: "finished", finished: true, winner: { id: 10 } },
          { id: 2, position: 2, status: "finished", finished: true, winner: { id: 20 } },
          { id: 3, position: 3, status: "not_started", finished: false },
        ],
      }),
    )!;

    expect(match.maps).toHaveLength(3);
    expect(match.maps[0]).toMatchObject({ position: 1, winner: "a", scoreA: null, scoreB: null });
    expect(match.maps[1]).toMatchObject({ position: 2, winner: "b" });
    expect(match.maps[2]).toMatchObject({ position: 3, winner: null });
    expect(match.maps.every((m) => m.mapName === null)).toBe(true);
  });
});

describe("построение адресов", () => {
  it("использует слаг дисциплины, принятый у PandaScore", () => {
    expect(upcomingMatchesUrl("dota2")).toContain("/dota-2/matches/upcoming");
    expect(upcomingMatchesUrl("valorant")).toContain("/valorant/matches/upcoming");
    expect(pastMatchesUrl("cs2")).toContain("/cs2/matches/past");
  });

  it("сортирует прошедшие матчи от свежих к старым", () => {
    expect(pastMatchesUrl("cs2")).toContain("sort=-scheduled_at");
  });
});
