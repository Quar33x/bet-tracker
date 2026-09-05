import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  fetchTeamHistory,
  headToHead,
  matchesPageUrl,
  parseAggregates,
  parseMatches,
  summarizeForm,
  USER_AGENT,
  type LiquipediaMatch,
} from "../src/sources/liquipedia";

// vitest запускается из backend/, там же лежит package.json
const fixture = readFileSync("test/fixtures/liquipedia-cs2-matches.html", "utf8");

describe("matchesPageUrl", () => {
  it("собирает адрес нужной вики и заменяет пробелы", () => {
    expect(matchesPageUrl("cs2", "Team Vitality")).toBe(
      "https://liquipedia.net/counterstrike/api.php?action=parse&page=Team_Vitality%2FMatches&prop=text&format=json",
    );
  });

  it("отказывается от VALORANT — там этот путь не работает", () => {
    expect(() => matchesPageUrl("valorant", "Paper Rex")).toThrow(/valorant/);
  });
});

describe("parseAggregates", () => {
  it("читает W-L по матчам, картам и раундам", () => {
    const agg = parseAggregates(fixture)!;
    expect(agg.matches).toEqual({ wins: 165, losses: 45 });
    expect(agg.games).toEqual({ wins: 357, losses: 139 });
    expect(agg.rounds).toEqual({ wins: 6084, losses: 4652 });
  });

  it("забирает период выборки", () => {
    expect(parseAggregates(fixture)!.period).toBe("Oct 16, 2023 and Sep 04, 2026");
  });

  it("возвращает null, когда агрегатов нет", () => {
    expect(parseAggregates("<div>ничего полезного</div>")).toBeNull();
  });
});

describe("parseMatches", () => {
  const matches = parseMatches(fixture);

  it("находит строки матчей", () => {
    expect(matches.length).toBe(3);
  });

  it("разбирает свежий матч целиком", () => {
    const first = matches[0]!;
    expect(first.timestamp).toBe(1788540600);
    expect(first.tier).toBe("S-Tier");
    expect(first.type).toBe("Offline");
    expect(first.tournament).toBe("BLAST Open Fall 2026 - Playoffs");
    expect(first.opponent).toBe("FURIA");
    expect(first.result).toBe("win");
    expect(first.scoreFor).toBe(2);
    expect(first.scoreAgainst).toBe(1);
  });

  it("у каждого матча есть соперник и время", () => {
    for (const match of matches) {
      expect(match.opponent).toBeTruthy();
      expect(match.timestamp).toBeTypeOf("number");
    }
  });

  it("не падает на пустом или чужом HTML", () => {
    expect(parseMatches("")).toEqual([]);
    expect(parseMatches("<table><tbody><tr><td>что-то</td></tr></tbody></table>")).toEqual([]);
  });
});

describe("headToHead и форма", () => {
  const rows: LiquipediaMatch[] = [
    { timestamp: 5, tier: "S-Tier", type: "Offline", tournament: "A", opponent: "FURIA", scoreFor: 2, scoreAgainst: 1, result: "win" },
    { timestamp: 4, tier: "S-Tier", type: "Online", tournament: "B", opponent: "G2", scoreFor: 0, scoreAgainst: 2, result: "loss" },
    { timestamp: 3, tier: "A-Tier", type: "Online", tournament: "C", opponent: "furia", scoreFor: 1, scoreAgainst: 2, result: "loss" },
    { timestamp: 2, tier: "S-Tier", type: "Offline", tournament: "D", opponent: "NAVI", scoreFor: 2, scoreAgainst: 0, result: "win" },
  ];

  it("фильтрует встречи с конкретным соперником, не глядя на регистр", () => {
    const h2h = headToHead(rows, "FURIA");
    expect(h2h).toHaveLength(2);
    expect(h2h.every((m) => m.opponent?.toLowerCase() === "furia")).toBe(true);
  });

  it("на незнакомом сопернике возвращает пусто", () => {
    expect(headToHead(rows, "MOUZ")).toEqual([]);
  });

  it("считает форму по последним матчам", () => {
    expect(summarizeForm(rows)).toEqual({ wins: 2, losses: 2, played: 4 });
    expect(summarizeForm(rows, 2)).toEqual({ wins: 1, losses: 1, played: 2 });
  });

  it("не учитывает матчи без результата", () => {
    const withUnplayed = [{ ...rows[0]!, result: null }, ...rows];
    expect(summarizeForm(withUnplayed).played).toBe(4);
  });
});

describe("fetchTeamHistory", () => {
  const okResponse = (html: string) =>
    new Response(JSON.stringify({ parse: { text: { "*": html } } }), { status: 200 });

  it("представляется своим User-Agent и просит gzip", async () => {
    let seen: RequestInit | undefined;
    await fetchTeamHistory(
      async (_url, init) => {
        seen = init;
        return okResponse(fixture);
      },
      "cs2",
      "Team Vitality",
    );
    const headers = seen?.headers as Record<string, string>;
    expect(headers["user-agent"]).toBe(USER_AGENT);
    expect(headers["accept-encoding"]).toBe("gzip");
  });

  it("возвращает агрегаты и матчи", async () => {
    const history = await fetchTeamHistory(async () => okResponse(fixture), "cs2", "Team Vitality");
    expect(history.aggregates?.rounds.wins).toBe(6084);
    expect(history.matches).toHaveLength(3);
  });

  it("сообщает об ошибке API вместо тихой пустоты", async () => {
    const fetchImpl = async () =>
      new Response(JSON.stringify({ error: { info: "API key is not valid" } }), { status: 200 });
    await expect(fetchTeamHistory(fetchImpl, "cs2", "Team Vitality")).rejects.toThrow(/API key/);
  });

  it("сообщает о пустом ответе — так выглядит VALORANT", async () => {
    const fetchImpl = async () => new Response(JSON.stringify({ parse: { text: {} } }), { status: 200 });
    await expect(fetchTeamHistory(fetchImpl, "cs2", "Team Vitality")).rejects.toThrow(/пустой ответ/);
  });

  it("сообщает о плохом HTTP-статусе", async () => {
    const fetchImpl = async () => new Response("nope", { status: 406 });
    await expect(fetchTeamHistory(fetchImpl, "cs2", "Team Vitality")).rejects.toThrow(/406/);
  });
});
