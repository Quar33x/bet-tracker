# Заявки на бесплатный доступ к данным

Две заявки, обе бесплатные. Отправляешь ты — они идут от твоего имени.

**Важно про формулировки.** Тексты ниже описывают проект честно, включая то, что
он ведёт учёт твоих ставок. Скрывать это нельзя: у GRID betting-применение идёт
по отдельному коммерческому треку, и если они узнают потом, доступ отзовут. Пусть
решают, зная правду. Мы не производим и не распространяем коэффициенты — это
главный аргумент, и он правдивый.

---

## 1. Liquipedia LPDB API v3 — приоритет

**Зачем:** таблицы `match2` / `match2game` дают покарточные данные по всем трём
дисциплинам без парсинга HTML. Единственный легальный бесплатный способ получить
карты и раунды по VALORANT.

**Куда:** канал `#api-help` в Discord Liquipedia (ссылка на сервер — со страницы
<https://liquipedia.net/api>). Там же форма запроса ключа.

**Условие допуска:** open-source community-проект, некоммерческий. Твой репозиторий
публичный — это ровно то, что они просят.

### Текст

> Hi! I'd like to request an LPDB API v3 key for a personal, non-commercial project.
>
> **What it is:** an open-source iOS app I built for myself and one colleague to
> track our own esports bets and review matches we missed. Source code:
> https://github.com/Quar33x/bet-tracker (MIT-style personal project, fully public).
>
> **What I need:** `match2` and `match2game` for VALORANT, Counter-Strike and
> Dota 2 — match history, per-map scores, and team head-to-head records. I use
> this to show a pre-match summary of two teams' recent form and their previous
> meetings, and a short recap of finished matches.
>
> **Volume:** very low. A background job runs every 15-30 minutes and caches
> aggressively; I expect to stay far below the 60 requests/hour limit.
>
> **Attribution:** the app will credit Liquipedia and CC-BY-SA 3.0 on every screen
> that shows your data.
>
> **Full disclosure:** the app does track my own betting record (profit, ROI,
> win rate). It does not generate, publish or distribute odds, it is not sold,
> and it has no users beyond the two of us. If that puts it outside what the free
> tier covers, I'd rather know now — happy to answer any questions.
>
> I've read the API terms of use and will follow the rate limits, the custom
> User-Agent requirement and gzip.

---

## 2. GRID Open Access

**Зачем:** официальные данные от организаторов турниров по CS2 и Dota 2 —
покарточная статистика и состояние серии. VALORANT в Open Access не входит.

**Куда:** форма на <https://grid.gg/open-access/>

**Условие допуска:** pre-revenue стартапы, академические институты, независимые
разработчики, фанаты.

### Текст

> **Project:** Bet Tracker — a personal, open-source iOS app that I use to track
> my own esports bets and to review matches. Not a company, no revenue, no users
> beyond myself and one colleague. Code: https://github.com/Quar33x/bet-tracker
>
> **What I'd use Open Access for:** Central Data (tournaments, series, teams,
> players) and Series State (per-map scores and team statistics) for CS2 and
> Dota 2, to show recent form, head-to-head history and a short recap of finished
> matches inside the app.
>
> **Volume:** a background job every 15-30 minutes with caching — well within the
> 20 req/min Central Data limit.
>
> **Disclosure:** the app records my own bets and calculates my profit and ROI.
> I do not produce, publish or resell odds, and nothing is distributed publicly.
> I understand betting-related usage may fall under a different track — if that's
> the case here, please tell me and I'll follow whatever process applies.

---

## 3. PandaScore — регистрация, не заявка

Бесплатный план Fixtures оформляется самостоятельно на
<https://www.pandascore.co/pricing>, заявки не нужно. Проверить при регистрации:

- требуют ли карту (по странице тарифов — €0/мес, но не проверено);
- какую глубину истории отдаёт `/matches/past` (в документации не указано).

Писать в `sales@pandascore.co` нужно только перед апгрейдом на платный Historical
(от €400 за дисциплину в месяц) — на бесплатном тире это не требуется.

Атрибуция **«Source: PandaScore»** обязательна и на бесплатном плане.
