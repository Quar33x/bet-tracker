import type { MatchDossier } from "./dossier";
import { mapWinRate, roundWinRate } from "./dossier";

/**
 * Версия промпта. Входит в ключ кэша: правишь текст — старые ответы
 * перестают считаться актуальными и пересчитываются.
 */
export const PREVIEW_PROMPT_VERSION = "preview-v1";
export const SUMMARY_PROMPT_VERSION = "summary-v1";

/**
 * Системный промпт предматчевого анализа.
 *
 * Он стабильный и кэшируется целиком — меняется только досье в сообщении
 * пользователя. Держать его неизменным байт в байт важно: любая правка
 * сбрасывает кэш и удорожает следующий запрос.
 */
export const PREVIEW_SYSTEM = `Ты аналитик киберспортивных матчей. Твой читатель ведёт личный учёт ставок и смотрит твой разбор перед тем, как решить: ставить или пройти мимо. Он ставит в основном форы по картам и раундам (например «-3.5 по раундам на первой карте»), поэтому запас прочности фаворита важнее факта победы.

ЖЁСТКИЕ ПРАВИЛА:

1. Опирайся ТОЛЬКО на факты из досье. Ничего не добавляй по памяти: ни составы, ни трансферы, ни результаты, ни репутацию команд. Если в досье этого нет — значит ты этого не знаешь.
2. Прямо говори, чего не знаешь. Раздел «unknowns» обязателен и не может быть пустым, если в досье есть gaps. Читатель должен видеть, на каком объёме данных построен вывод.
3. Никаких предсказаний исхода в процентах и никаких утверждений о выгодности ставки. Ты не знаешь коэффициентов и не оцениваешь их. Твоя работа — разложить факты, а решение принимает читатель.
4. Если данных мало, так и напиши. «Данных недостаточно для содержательного вывода» — это допустимый и часто правильный ответ. Не растягивай пустоту на абзацы.
5. Разделяй факт и интерпретацию. Числа из досье — факт. Всё остальное — твоя интерпретация, и она должна быть помечена как таковая словами «похоже», «скорее», «это может означать».

НА ЧТО СМОТРЕТЬ В ПЕРВУЮ ОЧЕРЕДЬ:
- доля выигранных раундов: она говорит о запасе прочности точнее, чем винрейт по матчам;
- разрыв между винрейтом по матчам и по раундам: команда может выигрывать много, но впритык — для форы это плохо;
- форма за последние матчи против общего уровня;
- уровень турниров (тир) у соперников: победы над слабыми не переносятся на сильных;
- личные встречи, если их достаточно, чтобы говорить о тенденции, а не о совпадении.

ФОРМАТ ОТВЕТА:
Верни ТОЛЬКО валидный JSON, без markdown-обёртки и без текста вокруг, по схеме:

{
  "verdict": "одно-два предложения: главное, что нужно знать перед решением",
  "confidence": "high | medium | low — насколько досье позволяет судить",
  "factors_a": ["фактор за команду A с числами из досье"],
  "factors_b": ["фактор за команду B с числами из досье"],
  "handicap_note": "что данные говорят о форах по раундам и картам; если данных нет — прямо сказать",
  "unknowns": ["чего нет в данных и как это ограничивает вывод"],
  "watch": ["на что посмотреть перед самым матчем, чего досье не покрывает"]
}

Пиши по-русски, коротко и по делу. Никакой воды и никаких общих слов вроде «обе команды сильны».`;

export const SUMMARY_SYSTEM = `Ты пишешь короткое саммари завершённого киберспортивного матча для человека, который его не смотрел и хочет за полминуты понять, что произошло.

ЖЁСТКИЕ ПРАВИЛА:
1. Только факты из данных. Ничего не додумывай: ни моментов, ни имён игроков, которых нет в данных, ни причин.
2. Если данных мало — напиши коротко ровно то, что известно. Одно предложение вместо трёх это нормально. Не выдумывай драматургию там, где есть только счёт.
3. Никаких оценок ставок и коэффициентов.

ФОРМАТ ОТВЕТА:
Верни ТОЛЬКО валидный JSON, без markdown-обёртки:

{
  "headline": "одно предложение с итогом матча",
  "body": "2-4 предложения: как шла серия, где переломилось, что видно по счёту",
  "notable": ["отдельные факты, если они есть в данных"]
}

Пиши по-русски.`;

function formatPercent(value: number | null): string {
  return value === null ? "нет данных" : `${(value * 100).toFixed(1)}%`;
}

/** Человекочитаемая выжимка — модель читает её лучше, чем сырой JSON. */
export function renderDossier(dossier: MatchDossier): string {
  const lines: string[] = [];

  lines.push(`ДИСЦИПЛИНА: ${dossier.discipline}`);
  lines.push(`ТУРНИР: ${dossier.tournament ?? "неизвестен"}`);
  if (dossier.bestOf) lines.push(`ФОРМАТ: BO${dossier.bestOf}`);
  lines.push("");

  for (const [label, team] of [
    ["A", dossier.teamA],
    ["B", dossier.teamB],
  ] as const) {
    lines.push(`=== КОМАНДА ${label}: ${team.name} ===`);

    if (team.form) {
      lines.push(`Форма (последние ${team.form.played}): ${team.form.wins}W-${team.form.losses}L`);
    } else {
      lines.push("Форма: нет данных");
    }

    const agg = team.aggregates;
    if (agg) {
      if (agg.period) lines.push(`Период выборки: ${agg.period}`);
      if (agg.matches) lines.push(`По матчам: ${agg.matches.wins}W-${agg.matches.losses}L`);
      if (agg.games) {
        lines.push(`По картам: ${agg.games.wins}W-${agg.games.losses}L (${formatPercent(mapWinRate(team))})`);
      }
      if (agg.rounds) {
        lines.push(
          `По раундам: ${agg.rounds.wins}W-${agg.rounds.losses}L (${formatPercent(roundWinRate(team))})`,
        );
      }
    } else {
      lines.push("Агрегаты: нет данных");
    }

    if (team.recentMatches.length > 0) {
      lines.push("Последние матчи:");
      for (const match of team.recentMatches.slice(0, 10)) {
        const score =
          match.scoreFor !== null && match.scoreAgainst !== null
            ? `${match.scoreFor}:${match.scoreAgainst}`
            : "счёт неизвестен";
        const result = match.result ? match.result.toUpperCase() : "?";
        lines.push(
          `  ${result} ${score} vs ${match.opponent ?? "?"} — ${match.tournament ?? "?"}${match.tier ? ` (${match.tier})` : ""}`,
        );
      }
    }
    lines.push("");
  }

  lines.push("=== ЛИЧНЫЕ ВСТРЕЧИ ===");
  if (dossier.headToHead.length === 0) {
    lines.push("Не найдены.");
  } else {
    for (const match of dossier.headToHead.slice(0, 10)) {
      const score =
        match.scoreFor !== null && match.scoreAgainst !== null
          ? `${match.scoreFor}:${match.scoreAgainst}`
          : "счёт неизвестен";
      lines.push(
        `  ${(match.result ?? "?").toUpperCase()} ${score} — ${match.tournament ?? "?"}${match.tier ? ` (${match.tier})` : ""}`,
      );
    }
  }
  lines.push("");

  lines.push("=== ЧЕГО В ДАННЫХ НЕТ ===");
  if (dossier.gaps.length === 0) {
    lines.push("Существенных пробелов не отмечено.");
  } else {
    for (const gap of dossier.gaps) lines.push(`  - ${gap}`);
  }

  if (dossier.sources.length > 0) {
    lines.push("");
    lines.push(`ИСТОЧНИКИ: ${dossier.sources.join(", ")}`);
  }

  return lines.join("\n");
}

export interface PreviewResult {
  verdict: string;
  confidence: string;
  factors_a: string[];
  factors_b: string[];
  handicap_note: string;
  unknowns: string[];
  watch: string[];
}

export interface SummaryResult {
  headline: string;
  body: string;
  notable: string[];
}

/**
 * Разбирает ответ модели.
 *
 * Модель просят вернуть голый JSON, но обёртка в ```json``` — самый частый
 * способ, которым это ломается, поэтому снимаем её молча.
 */
export function parseJsonResponse<T>(text: string): T {
  const cleaned = text
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();

  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) {
    throw new Error("Ответ модели не содержит JSON");
  }

  return JSON.parse(cleaned.slice(start, end + 1)) as T;
}
