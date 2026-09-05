import { describe, expect, it } from "vitest";
import { parseCustomId } from "../src/llm/client";
import { summarizeForm, toRecentMatch } from "../src/llm/collect";
import { costUsd, isWithinBudget, MODEL_PRICES } from "../src/llm/cost";
import {
  buildDossier,
  collectGaps,
  dossierFingerprint,
  mapWinRate,
  roundWinRate,
  type MatchDossier,
  type TeamDossier,
} from "../src/llm/dossier";
import { parseJsonResponse, renderDossier } from "../src/llm/prompts";

const team = (over: Partial<TeamDossier> = {}): TeamDossier => ({
  name: "Vitality",
  form: { wins: 7, losses: 3, played: 10 },
  aggregates: {
    matches: { wins: 165, losses: 45 },
    games: { wins: 357, losses: 139 },
    rounds: { wins: 6084, losses: 4652 },
    period: "Oct 16, 2023 and Sep 04, 2026",
  },
  recentMatches: [
    { timestamp: 1788540600, opponent: "FURIA", tournament: "BLAST", tier: "S-Tier", scoreFor: 2, scoreAgainst: 1, result: "win" },
  ],
  ...over,
});

const dossier = (over: Partial<MatchDossier> = {}): MatchDossier =>
  buildDossier({
    discipline: "cs2",
    tournament: "BLAST Open Fall 2026",
    scheduledAt: 1788540600,
    bestOf: 3,
    teamA: team(),
    teamB: team({ name: "FURIA" }),
    headToHead: [],
    sources: ["Liquipedia (CC-BY-SA 3.0)"],
    ...over,
  });

describe("costUsd", () => {
  it("считает обычный запрос по прайсу модели", () => {
    const cost = costUsd("claude-opus-5", { input_tokens: 1_000_000, output_tokens: 0 });
    expect(cost).toBeCloseTo(MODEL_PRICES["claude-opus-5"]!.input, 6);
  });

  it("учитывает выход дороже входа", () => {
    const cost = costUsd("claude-opus-5", { input_tokens: 0, output_tokens: 1_000_000 });
    expect(cost).toBeCloseTo(25, 6);
  });

  it("берёт с batch вдвое меньше", () => {
    const usage = { input_tokens: 100_000, output_tokens: 10_000 };
    const normal = costUsd("claude-sonnet-5", usage);
    const batch = costUsd("claude-sonnet-5", usage, { batch: true });
    expect(batch).toBeCloseTo(normal / 2, 6);
  });

  it("считает чтение из кэша заметно дешевле обычного входа", () => {
    const cached = costUsd("claude-opus-5", {
      input_tokens: 0,
      output_tokens: 0,
      cache_read_input_tokens: 1_000_000,
    });
    expect(cached).toBeLessThan(costUsd("claude-opus-5", { input_tokens: 1_000_000, output_tokens: 0 }));
  });

  it("считает запись в кэш дороже обычного входа", () => {
    const written = costUsd("claude-opus-5", {
      input_tokens: 0,
      output_tokens: 0,
      cache_creation_input_tokens: 1_000_000,
    });
    expect(written).toBeGreaterThan(5);
  });

  it("на незнакомой модели возвращает ноль, а не выдумывает цену", () => {
    expect(costUsd("model-which-does-not-exist", { input_tokens: 1000, output_tokens: 1000 })).toBe(0);
  });
});

describe("бюджет", () => {
  it("пропускает, пока лимит не выбран", () => {
    expect(isWithinBudget({ spentUsd: 1.2, limitUsd: 5 })).toBe(true);
  });

  it("останавливает ровно на лимите", () => {
    expect(isWithinBudget({ spentUsd: 5, limitUsd: 5 })).toBe(false);
    expect(isWithinBudget({ spentUsd: 7.4, limitUsd: 5 })).toBe(false);
  });
});

describe("производные по досье", () => {
  it("считает долю выигранных раундов", () => {
    expect(roundWinRate(team())).toBeCloseTo(6084 / (6084 + 4652), 4);
  });

  it("считает долю выигранных карт", () => {
    expect(mapWinRate(team())).toBeCloseTo(357 / (357 + 139), 4);
  });

  it("возвращает null там, где данных нет, вместо нуля", () => {
    expect(roundWinRate(team({ aggregates: null }))).toBeNull();
    expect(mapWinRate(team({ aggregates: null }))).toBeNull();
    expect(roundWinRate(team({ aggregates: { rounds: { wins: 0, losses: 0 } } }))).toBeNull();
  });
});

describe("collectGaps", () => {
  it("на полном досье по CS2 отмечает только отсутствие личных встреч", () => {
    expect(dossier().gaps).toEqual(["Личных встреч в доступных данных не найдено."]);
  });

  it("молчит, когда есть и статистика, и личные встречи", () => {
    const withH2H = dossier({
      headToHead: [
        { timestamp: 1, opponent: "FURIA", tournament: "BLAST", tier: "S-Tier", scoreFor: 2, scoreAgainst: 0, result: "win", perspective: "a" },
      ],
    });
    expect(withH2H.gaps).toEqual([]);
  });

  it("отмечает отсутствие раундовой статистики поимённо", () => {
    const gaps = dossier({ teamA: team({ aggregates: null }) }).gaps;
    expect(gaps.some((g) => g.includes("Vitality") && g.includes("раундам"))).toBe(true);
  });

  it("всегда предупреждает про ограничения VALORANT", () => {
    const gaps = dossier({ discipline: "valorant" }).gaps;
    expect(gaps.some((g) => g.includes("VALORANT"))).toBe(true);
  });

  it("отмечает отсутствие личных встреч и истории", () => {
    const empty = team({ recentMatches: [], aggregates: null, form: null });
    const gaps = collectGaps({
      discipline: "cs2",
      tournament: null,
      scheduledAt: null,
      bestOf: null,
      teamA: empty,
      teamB: empty,
      headToHead: [],
      sources: [],
    });
    expect(gaps.some((g) => g.includes("Личных встреч"))).toBe(true);
    expect(gaps.filter((g) => g.includes("истории последних матчей"))).toHaveLength(2);
  });
});

describe("dossierFingerprint", () => {
  it("одинаков для одинаковых фактов", () => {
    expect(dossierFingerprint(dossier())).toBe(dossierFingerprint(dossier()));
  });

  it("меняется, когда меняются факты — иначе кэш отдаст устаревший анализ", () => {
    const changed = dossier({ teamA: team({ form: { wins: 9, losses: 1, played: 10 } }) });
    expect(dossierFingerprint(changed)).not.toBe(dossierFingerprint(dossier()));
  });
});

describe("renderDossier", () => {
  const text = renderDossier(dossier());

  it("выносит раунды и карты с процентами", () => {
    expect(text).toContain("По раундам: 6084W-4652L");
    expect(text).toContain("56.7%");
  });

  it("всегда содержит раздел про отсутствующие данные", () => {
    expect(text).toContain("ЧЕГО В ДАННЫХ НЕТ");
  });

  it("перечисляет пробелы, когда они есть", () => {
    const thin = renderDossier(dossier({ discipline: "valorant", teamA: team({ aggregates: null }) }));
    expect(thin).toContain("VALORANT");
  });

  it("называет источники — это требование их условий использования", () => {
    expect(text).toContain("Liquipedia");
  });
});

describe("parseJsonResponse", () => {
  it("читает голый JSON", () => {
    expect(parseJsonResponse<{ a: number }>('{"a": 1}')).toEqual({ a: 1 });
  });

  it("снимает markdown-обёртку", () => {
    expect(parseJsonResponse<{ a: number }>('```json\n{"a": 2}\n```')).toEqual({ a: 2 });
    expect(parseJsonResponse<{ a: number }>('```\n{"a": 3}\n```')).toEqual({ a: 3 });
  });

  it("вытаскивает JSON из текста вокруг", () => {
    expect(parseJsonResponse<{ a: number }>('Вот разбор:\n{"a": 4}\nГотово.')).toEqual({ a: 4 });
  });

  it("сообщает об ошибке, когда JSON нет", () => {
    expect(() => parseJsonResponse("никакого json")).toThrow(/не содержит JSON/);
  });
});

describe("toRecentMatch", () => {
  const row = {
    scheduled_at: 100,
    tournament_name: "PGL",
    score_a: 2,
    score_b: 1,
    team_a_id: 1,
    team_b_id: 2,
    team_a: "Spirit",
    team_b: "Tundra",
  };

  it("разворачивает матч с точки зрения первой команды", () => {
    const match = toRecentMatch(row, 1);
    expect(match).toMatchObject({ opponent: "Tundra", scoreFor: 2, scoreAgainst: 1, result: "win" });
  });

  it("разворачивает тот же матч с точки зрения второй команды", () => {
    const match = toRecentMatch(row, 2);
    expect(match).toMatchObject({ opponent: "Spirit", scoreFor: 1, scoreAgainst: 2, result: "loss" });
  });

  it("не выдумывает результат, когда счёта нет", () => {
    expect(toRecentMatch({ ...row, score_a: null, score_b: null }, 1).result).toBeNull();
  });

  it("распознаёт ничью", () => {
    expect(toRecentMatch({ ...row, score_a: 1, score_b: 1 }, 1).result).toBe("draw");
  });
});

describe("summarizeForm", () => {
  it("считает только сыгранные матчи", () => {
    const matches = [
      { timestamp: 3, opponent: "A", tournament: null, tier: null, scoreFor: 2, scoreAgainst: 0, result: "win" as const },
      { timestamp: 2, opponent: "B", tournament: null, tier: null, scoreFor: null, scoreAgainst: null, result: null },
      { timestamp: 1, opponent: "C", tournament: null, tier: null, scoreFor: 0, scoreAgainst: 2, result: "loss" as const },
    ];
    expect(summarizeForm(matches)).toEqual({ wins: 1, losses: 1, played: 2 });
  });
});

describe("parseCustomId", () => {
  it("возвращает номер матча", () => {
    expect(parseCustomId("match-42")).toBe(42);
  });

  it("не принимает чужой формат", () => {
    expect(parseCustomId("42")).toBeNull();
    expect(parseCustomId("match-abc")).toBeNull();
    expect(parseCustomId("")).toBeNull();
  });
});
