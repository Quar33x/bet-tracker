import { describe, expect, it } from "vitest";
import {
  headToHeadQuery,
  summarizeForm,
  teamMatchesUrl,
  toIngestedMatches,
  type OpenDotaTeamMatch,
} from "../src/sources/opendota";

const team = { id: 7119388, name: "Team Spirit" };

function match(overrides: Partial<OpenDotaTeamMatch> = {}): OpenDotaTeamMatch {
  return {
    match_id: 1,
    radiant: true,
    radiant_win: true,
    start_time: 1_757_000_000,
    leagueid: 17_000,
    league_name: "PGL Wallachia Season 5",
    opposing_team_id: 8_291_895,
    opposing_team_name: "Tundra Esports",
    ...overrides,
  };
}

describe("toIngestedMatches", () => {
  it("считает победой, когда сторона команды совпала с победившей стороной", () => {
    const [result] = toIngestedMatches(team, [match({ radiant: true, radiant_win: true })]);
    expect(result?.scoreA).toBe(1);
    expect(result?.scoreB).toBe(0);
  });

  it("считает поражением игру за Dire, когда выиграл Radiant", () => {
    const [result] = toIngestedMatches(team, [match({ radiant: false, radiant_win: true })]);
    expect(result?.scoreA).toBe(0);
    expect(result?.scoreB).toBe(1);
  });

  it("считает победой игру за Dire, когда Radiant проиграл", () => {
    const [result] = toIngestedMatches(team, [match({ radiant: false, radiant_win: false })]);
    expect(result?.scoreA).toBe(1);
  });

  it("ставит запрошенную команду первой и переносит турнир", () => {
    const [result] = toIngestedMatches(team, [match()]);
    expect(result?.teamA.name).toBe("Team Spirit");
    expect(result?.teamA.openDotaId).toBe(7119388);
    expect(result?.teamB.name).toBe("Tundra Esports");
    expect(result?.tournamentName).toBe("PGL Wallachia Season 5");
    expect(result?.discipline).toBe("dota2");
    expect(result?.status).toBe("finished");
  });

  it("выбрасывает матчи без соперника — они бесполезны и ломают связи", () => {
    const results = toIngestedMatches(team, [
      match({ opposing_team_id: null }),
      match({ match_id: 2, opposing_team_name: null }),
      match({ match_id: 3 }),
    ]);
    expect(results).toHaveLength(1);
    expect(results[0]?.externalId).toBe("3");
  });
});

describe("headToHeadQuery", () => {
  it("подставляет оба id в обе стороны, чтобы поймать встречу при любой расстановке", () => {
    const sql = headToHeadQuery(1, 2, 5);
    expect(sql).toContain("m.radiant_team_id in (1, 2)");
    expect(sql).toContain("m.dire_team_id in (1, 2)");
    expect(sql).toContain("limit 5");
  });

  it("отказывается строить запрос на нецелых id — это дыра для инъекции", () => {
    expect(() => headToHeadQuery(1.5, 2)).toThrow();
    expect(() => headToHeadQuery(1, -2)).toThrow();
    expect(() => headToHeadQuery(Number.NaN, 2)).toThrow();
    expect(() => headToHeadQuery(1, 2, 0)).toThrow();
  });

  it("не даёт протащить SQL через id", () => {
    expect(() => headToHeadQuery("1; drop table matches" as unknown as number, 2)).toThrow();
  });
});

describe("teamMatchesUrl", () => {
  it("собирает адрес по числовому id", () => {
    expect(teamMatchesUrl(2586976)).toBe("https://api.opendota.com/api/teams/2586976/matches");
  });

  it("не принимает мусор вместо id", () => {
    expect(() => teamMatchesUrl(0)).toThrow();
    expect(() => teamMatchesUrl(1.2)).toThrow();
  });
});

describe("summarizeForm", () => {
  const wins = (n: number) => Array.from({ length: n }, () => match({ radiant: true, radiant_win: true }));
  const losses = (n: number) => Array.from({ length: n }, () => match({ radiant: true, radiant_win: false }));

  it("считает победы и поражения по последним матчам", () => {
    const form = summarizeForm(team, [...wins(3), ...losses(2)]);
    expect(form.wins).toBe(3);
    expect(form.losses).toBe(2);
  });

  it("ограничивается запрошенным окном", () => {
    const form = summarizeForm(team, [...wins(3), ...losses(7)], 3);
    expect(form.wins).toBe(3);
    expect(form.losses).toBe(0);
  });

  it("считает серию побед положительной, серию поражений отрицательной", () => {
    expect(summarizeForm(team, [...wins(4), ...losses(1)]).streak).toBe(4);
    expect(summarizeForm(team, [...losses(3), ...wins(1)]).streak).toBe(-3);
  });

  it("на пустом списке не падает", () => {
    expect(summarizeForm(team, [])).toEqual({ wins: 0, losses: 0, streak: 0 });
  });
});
