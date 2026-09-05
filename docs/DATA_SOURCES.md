# Источники данных о матчах: VALORANT / CS2 / Dota 2

Исследование проведено 2026-09-05. Все лимиты и условия проверялись по живым
страницам и живыми запросами к API в этот день, а не по памяти. Там, где что-то
проверить не удалось, это прямо написано.

Цель — две фичи:

1. **Предматчевый анализ пары команд**: H2H, последние игры и форма, статистика
   по картам, составы и их изменения.
2. **Саммари прошедшего матча**: счёт по картам, ключевые моменты, кто выделился.

---

## 1. Сводная таблица

| Источник | VAL | CS2 | Dota 2 | Ключ | Карта | Лимит бесплатного тира | H2H | Счёт по картам | Статы игроков |
|---|:---:|:---:|:---:|---|---|---|:---:|:---:|:---:|
| **PandaScore Free (Fixtures)** | ✅ | ✅ | ✅ | да | не требуется (не проверено лично) | 1000 req/час | ⚠️ вручную | ⚠️ только победитель карты | ❌ |
| **OpenDota** | ❌ | ❌ | ✅ | не нужен | нет | 60 req/мин, 3000 req/сутки (замерено) | ✅ | ✅ | ✅ |
| **Stratz** | ❌ | ❌ | ✅ | да (bearer) | нет | 2000 req/час, 10000/сутки | ✅ | ✅ | ✅ |
| **Liquipedia MediaWiki API** | ✅ | ✅ | ✅ | не нужен | нет | 1 req/2 сек; `action=parse` 1 req/30 сек | ✅ | ⚠️ агрегаты | ❌ |
| **Liquipedia LPDB API v3** | ✅ | ✅ | ✅ | да, по заявке | нет | 60 req/час | ✅ | ✅ | ⚠️ |
| **GRID Open Access** | ❌ | ✅ | ✅ | да, по заявке | нет | Central Data 20 req/мин; Series State 180/мин | ✅ | ✅ | ✅ |
| **bo3.gg (внутренний API)** | ✅ | ✅ | ✅ | не нужен | нет | не документирован | ✅ | ✅ только CS2 | ❌ (не найдено) |
| **vlr.gg обёртки (vlrggapi и др.)** | ✅ | ❌ | ❌ | нет | нет | публичные инстансы лежат | ✅ | ✅ | ✅ |
| **Valve Steam Web API** | ❌ | ❌ | ✅ | да, бесплатный | нет | 100 000 вызовов/сутки | ⚠️ вручную | ✅ | ✅ |
| **Abios (Kambi)** | ✅ | ✅ | ✅ | да | — | бесплатного тира нет | — | — | — |
| **Tachio Sports** | ✅ | ✅ | ✅ | да (GitHub) | нет | 300 req/мин | ? | ? | ? |
| **HLTV** | ❌ | ✅ | ❌ | — | — | публичного API нет | — | — | — |
| **esport.is** | — | — | — | — | — | **домен не резолвится, источника нет** | — | — | — |

Легенда: ✅ есть, ⚠️ есть частично / требует ручной сборки, ❌ нет, ? не проверено.

---

## 2. Разбор источников

### 2.1 PandaScore

Документация: <https://developers.pandascore.co/docs/introduction>
Тарифы: <https://www.pandascore.co/pricing>
**Ключевой документ — таблица «какой эндпоинт на каком плане»:**
<https://developers.pandascore.co/docs/plan-reference> (обновлена 2026-08-18)

**Покрытие:** VALORANT, CS2, Dota 2 — все три, плюс ещё ~11 тайтлов.

**Ключ:** нужен. Карта при регистрации, судя по странице тарифов (план «Fixtures»
за €0/месяц), не требуется, но лично зарегистрироваться и это проверить я не мог —
принимайте как непроверенное.

**Лимиты:** 1000 запросов/час на бесплатном плане, 10 000/час на платных
(<https://developers.pandascore.co/docs/rate-and-connections-limits>). Остаток —
в заголовке `X-Rate-Limit-Remaining`.

#### Что реально доступно бесплатно (план Fixtures)

По официальной таблице plan-reference, «All plans» = бесплатный план и выше:

Одинаково для CS2 / Dota 2 / VALORANT:

- `GET /{game}/matches/upcoming`, `/past`, `/running` — **списки матчей**
- `GET /{game}/teams`, `/{game}/players` — команды и игроки (составы)
- `GET /{game}/leagues`, `/{game}/series`, `/{game}/tournaments/upcoming`
- справочники: `/csgo/maps`, `/csgo/weapons`, `/dota2/heroes`, `/dota2/items`,
  `/dota2/abilities`

В объекте матча из списка (проверено по схеме ответа
`get_csgo_matches_past`) есть:

- `results` — итоговый счёт по картам (2:0, 2:1);
- `opponents` — команды с id, названием, акронимом, логотипом;
- `games[]` — массив карт, но **только** с полями `id`, `position`, `status`,
  `finished`, `length`, `winner{id,type}`. **Ни названия карты, ни счёта по
  раундам в бесплатном тире нет.**
- `league` / `serie` / `tournament`, `number_of_games`, `scheduled_at`,
  `match_type`, `detailed_stats`, `forfeit`, `draw`.

Фильтр `filter[opponent_id]` на `/matches/past` доступен — то есть **последние N
матчей команды** достать можно. H2H придётся собирать самому: тянуть историю
команды A и отфильтровать по команде B на своей стороне (фильтр с несколькими
значениями работает как OR, не как AND).

#### Что закрыто платным планом

| Нужно | Эндпоинт | Минимальный план |
|---|---|---|
| Матч по id | `GET /{game}/matches/{id}` | Historical |
| Карты внутри матча | `GET /{game}/matches/{id}/games` | Historical |
| Карта детально (название карты, счёт) | `GET /{game}/games/{id}` | Historical |
| Статистика команды (общая) | `GET /{game}/teams/{id}/stats` | Historical |
| Статистика игрока (общая) | `GET /{game}/players/{id}/stats` | Historical |
| Статы игроков в матче | `GET /{game}/matches/{id}/players/stats` | Historical |
| Статы на турнире / серии | `.../tournaments/{id}/teams/{id}/stats` и т.п. | Historical |
| Раунды CS2 | `GET /csgo/games/{id}/rounds` | **Basic Live** |
| Play-by-play CS2 | `GET /csgo/games/{id}/events` | **Pro Live** |
| Фреймы Dota 2 | `GET /dota2/games/{id}/frames` | **Historical Pro** |
| Раунды и события VALORANT | `GET /valorant/games/{id}/rounds` и `/events` | **Valorant Historical Pro** |
| `map_picks` (пики карт в VALORANT) | поле в объекте матча | Valorant Historical |
| Возраст/дата рождения игрока | поля в объекте игрока | Historical |

Сводка из их же документа:

> Post-game stats (players & teams) — ❌ Free, ✅ Historical
> Games within a match — ❌ Free, ✅ Historical

**Цены:** Historical — от €400 за тайтл в месяц, Live Basic — от €1000 за тайтл
в месяц, Live Pro — по запросу. То есть «дёшево» это не будет ни при каком
раскладе (<https://www.pandascore.co/pricing>).

**Глубина истории:** сколько лет отдаёт `/matches/past` на бесплатном плане —
выяснить не удалось, в документации это не указано. Нужно проверять эмпирически
после регистрации.

#### Условия использования и betting — то, что было открытым вопросом в SPEC

Проверено по <https://www.pandascore.co/terms-and-condition>. Ключевые пункты:

- **Статья 2.8:** «Subscriptions do not include the provision of odds. Under no
  circumstances shall the customer develop, attempt to develop, distribute,
  supply, or commercialize odds or odds-related products or services, whether for
  their own benefit or for a third party, using the data and services provided
  through the Subscriptions.»
- **Статья 6.4:** запрещает использовать данные, чтобы «develop, or attempt to
  develop, distribute, supply or commercialize odds or odds-related products and
  services»; там же требование атрибуции — на любом материале с их данными должно
  стоять **«Source: PandaScore»**.
- **Статья 6.3:** воспроизводить данные на своём сайте «for information purposes»
  разрешено.
- На странице тарифов и на <https://www.pandascore.co/stats> отдельно написано:
  «These stats plans are only available to customers with non betting-related
  usage» — и предложено писать на sales@pandascore.co за индивидуальным планом.

**Как это читать применительно к личному трекеру:**

1. Запрет 2.8/6.4 — про **создание и распространение коэффициентов** и продуктов
   вокруг них. Приложение, которое записывает ваши собственные ставки и считает
   ваш ROI, коэффициенты не производит и никому не поставляет. Формально под
   запрет 2.8/6.4 оно не подпадает.
2. Ограничение «stats plans only for non betting-related usage» — это условие
   **допуска к платным stats-планам**, а не пункт договора про данные. Бесплатный
   Fixtures-план — не stats-план, так что формально это ограничение к нему не
   относится.
3. Но формулировка «betting-related usage» размытая, и решение о допуске
   принимает их sales. Приложение с названием Bet Tracker при апгрейде на
   Historical почти наверняка вызовет вопрос.

**Вывод: рекомендация из SPEC («написать им до начала интеграции») остаётся
верной.** На бесплатном тире риска почти нет, но апгрейд на Historical нужно
согласовывать заранее — иначе можно построить архитектуру на планах, до которых
вас не допустят. Требование атрибуции «Source: PandaScore» действует и на
бесплатном плане.

---

### 2.2 OpenDota (Dota 2)

Документация: <https://docs.opendota.com>
Ключи и тарифы: <https://www.opendota.com/api-keys>
Исторический анонс лимитов: <https://blog.opendota.com/2018/04/17/changes-to-the-api/>

**Покрытие:** только Dota 2.

**Ключ:** **не нужен** для бесплатного тира. Проверено живым запросом без
авторизации — `GET https://api.opendota.com/api/teams/2586976/matches` вернул 200
и данные. Ключ нужен только для премиум-тира (там требуется платёжный метод).

**Лимиты (замерено 2026-09-05 по заголовкам ответа):**

```
X-Rate-Limit-Remaining-Minute: 57
X-Rate-Limit-Remaining-Day: 2997
```

То есть **60 запросов/минуту и 3000 запросов/сутки** на анонимный доступ.
В официальных материалах фигурирует «50 000 бесплатных вызовов в месяц и
60 req/min» — суточный потолок в 3000 в документации не описан, но по факту он
есть. Для крона раз в 15–30 минут это с гигантским запасом.

**Что даёт:**

| Данные | Эндпоинт | Проверено |
|---|---|---|
| Матчи команды с id соперника | `GET /teams/{id}/matches` | ✅ отдаёт `opposing_team_id`, `opposing_team_name`, `radiant_win`, `radiant_score`/`dire_score`, `duration`, `leagueid`, `league_name` |
| Профиль команды | `GET /teams/{id}` | ✅ рейтинг, wins, losses, tag, logo |
| Состав команды | `GET /teams/{id}/players` | ✅ `account_id`, `name`, `games_played`, `wins`, `is_current_team_member` |
| Все про-матчи | `GET /proMatches` | ✅ |
| Матч детально | `GET /matches/{id}` | пики/баны, KDA, предметы, GPM/XPM, лог по минутам |
| Лиги | `GET /leagues`, `/leagues/{id}/matches` | |
| **Произвольный SQL** | `GET /explorer?sql=...` | ✅ |

**`/explorer` — самая ценная штука для H2H.** Это прямой SQL к их PostgreSQL.
Проверенный живой запрос вернул историю личных встреч двух команд:

```sql
select m.match_id, m.start_time, m.radiant_team_id, m.dire_team_id,
       m.radiant_win, l.name
from matches m left join leagues l on l.leagueid = m.leagueid
where m.radiant_team_id in (2586976, 9247354)
  and m.dire_team_id in (2586976, 9247354)
order by m.start_time desc limit 5
```

Ответ содержал 5 последних встреч OG vs 9247354 с турнирами «1win Essence II»,
«BLAST SLAM VII», «ESL One Birmingham 2026». То есть H2H по Dota 2 решается
одним запросом.

**Глубина истории:** полная, с момента появления публичного WebAPI Valve.
Ограничений по глубине нет.

**Условия использования:** OpenDota — open-source проект (MIT, `odota/core`).
Отдельного ToS с запретом на betting-related использование я **не нашёл**. Это
означает «не нашёл», а не «его точно нет» — но публично сформулированного запрета
нет.

---

### 2.3 Stratz (Dota 2)

Сайт API: <https://stratz.com/api>
База знаний: <https://stratz.com/knowledge-base/API>

**Покрытие:** только Dota 2.

**Ключ:** **нужен**. Проверено живым запросом к `https://api.stratz.com/graphql`
без токена — 403 и ответ:

```json
{"message":"A bearer token is required for a request. View more at https://stratz.com/api"}
```

Токен выдаётся бесплатно после логина через Steam. Карта не нужна.

**Лимиты** (источник — их база знаний, продублирована в
<https://github.com/STRATZ-Esports/knowledge-base/issues/15>):

| Тип токена | В секунду | В минуту | В час | В сутки |
|---|---|---|---|---|
| Default (просто логин на stratz.com) | 20 | 250 | 2 000 | 10 000 |
| Individual | 20 | 250 | 4 000 | 20 000 |
| Multi-Token | 20/юзер | 20/юзер | 50/юзер | 100/юзер |

**Важная оговорка:** страницы базы знаний Stratz рендерятся на JS и напрямую
через HTTP отдают только каркас — актуальность этих цифр на 2026-09-05 я
подтвердить не смог. Первоисточник этих чисел датирован 2020 годом. Проверяйте
в личном кабинете «My Tokens» после регистрации.

**Что даёт:** GraphQL, схема глубже OpenDota — матчи, драфты, тайминги, статы
игроков, лиги, команды, ростеры. Гибкость GraphQL позволяет забрать ровно нужные
поля одним запросом, что при лимите 2000/час удобно.

**Условия использования применительно к ставкам:** отдельного публичного пункта
про betting найти не удалось (страница terms рендерится на JS). Не проверено.

---

### 2.4 Liquipedia

**В SPEC (раздел «Что не делать») написано: «Не тянуть данные парсингом HLTV /
Liquipedia: у них нет публичного API». Про Liquipedia это неверно — публичный API
у них есть, и он документирован.** Запрещён именно парсинг сгенерированных
HTML-страниц, а не работа с API.

Условия: <https://liquipedia.net/api-terms-of-use> (проверено живым запросом)
Страница API: <https://liquipedia.net/api> (за Cloudflare Turnstile)

**Покрытие:** все три дисциплины, каждая — отдельная вики
(`/valorant/`, `/counterstrike/`, `/dota2/`).

У них **два разных API**.

#### 2.4.1 MediaWiki API — бесплатный, без ключа

Проверено живыми запросами:

```
GET https://liquipedia.net/counterstrike/api.php?action=query&...
GET https://liquipedia.net/valorant/api.php?...
GET https://liquipedia.net/dota2/api.php?...
```

Правила (цитаты из terms of use):

- «Rate limit all HTTP requests to no more than **1 request per 2 seconds**.
  API "action=parse" requests should not exceed **1 request per 30 seconds** as
  these are more resource intensive.»
- Обязателен кастомный `User-Agent` с названием проекта и контактом. Пример из их
  документации: `LiveScoresBot/1.0 (http://www.example.com/; email@example.com)`.
  Дженерик-агенты (`python-requests`, `Go-http-client`, `node-fetch`) блокируются.
- **Обязателен gzip.** Проверено: без `Accept-Encoding: gzip` возвращается
  `406 Gzip encoding is required for API requests`.
- Кэшировать результаты как можно дольше, не повторять одинаковые запросы.
- Контент под **CC-BY-SA 3.0** — обязательна атрибуция Liquipedia как источника.
- «Automated access to non-API endpoints (ie, generated HTML pages) is not
  permitted.»
- За нарушения — автоматические временные IP-баны, при рецидиве постоянные.

**Важный практический нюанс.** Данные матчей на Liquipedia лежат в LPDB и
рендерятся Lua-модулями. Если запросить викитекст страницы, матчей там не будет.
Проверено на `Team Vitality/Matches`:

```
{{Team matches table|team=Team Vitality|game=cs2|vod=true}}
```

Всё. Реальные матчи появляются только после рендера, то есть нужен
`action=parse&prop=text` и разбор HTML из ответа API. Формально это разрешено —
это API-эндпоинт, а не «generated HTML page», — но лимит 1 запрос в 30 секунд.

Что при этом реально приходит (проверено, `action=parse` на
`counterstrike/Team Vitality/Matches`):

> For matches between Oct 16, 2023 and Sep 04, 2026: **165W : 45L (78.57%) in
> matches**, **357W : 139L (71.98%) in games**, **6084W : 4652L (56.67%) in
> rounds**
>
> September 4, 2026 — S-Tier — Offline — BLAST Open Fall 2026 - Playoffs —
> 2 : 1 — FURIA
> August 31, 2026 — S-Tier — Offline — BLAST Open Fall 2026 - Group B —
> 2 : 0 — FUT
> …

То есть за один запрос — вся история матчей команды с турниром, тиром, форматом
(offline/online), счётом и соперником, плюс агрегированный W-L по матчам, картам
и раундам. Для «формы» и H2H этого более чем достаточно.

Аналогичные страницы есть на всех трёх вики (`/Matches`, `/Results`), а также
страницы турниров и трансферов (`Player Transfers/YYYY`) — последние закрывают
«изменения составов».

#### 2.4.2 LiquipediaDB API v3 — нужен ключ по заявке

- Лимит: **60 запросов в час.**
- Ключ выдаётся «upon approved request», документация доступна только после
  логина в LPDB Dashboard (проверено: `api.liquipedia.net/documentation` без
  логина возвращает «You are not allowed to use this page!»).
- Запрос без ключа: `{"error":["API key \"\" is not valid."]}`, HTTP 403.
- Отдаёт структурированные таблицы: `match2`, `match2game`, `match2player`,
  `tournament`, `squadplayer`, `placement`, `datapoint` и другие (всего ~16
  типов). Это именно то, что нужно для H2H, карт и составов, без парсинга HTML.
- По информации со страницы <https://liquipedia.net/api>, сейчас они «обслуживают
  преимущественно Enterprise-тариф», но бесплатный доступ сохраняется для
  образовательных, некоммерческих и community-проектов **при условии открытого
  исходного кода**, часто на ограниченный срок. Страница закрыта Turnstile, я
  читал её содержимое через поисковую выдачу — **проверьте формулировки сами**.
  Канал поддержки — `#api-help` в их Discord.

**Применительно к ставкам:** прямого запрета на использование в betting-контексте
в API terms of use нет. Требование одно — атрибуция CC-BY-SA.

---

### 2.5 GRID Open Access

<https://grid.gg/open-access/>
Лимиты: <https://grid.helpjuice.com/rate-limits-for-products>

**Покрытие:** **CS2 и Dota 2**. VALORANT в Open Access **нет** — он идёт через
отдельный VALORANT Data Portal (<https://grid.gg/get-valorant/>), тоже по заявке,
и это уже не бесплатная история.

Это **официальные** данные от организаторов турниров, а не скрейп.

**Ключ:** нужен, выдаётся по заявке. Условие допуска: pre-revenue стартапы,
академические институты, независимые разработчики, фанаты. Личный проект под это
описание подходит.

**Лимиты Open Access** (из их документации):

| Продукт | Open Access | Closed Platform (платно) |
|---|---|---|
| Central Data | 20 req/мин | 40 req/мин |
| Series State (overall) | 180 req/мин | 1200 req/мин |
| Series State (на серию) | 6 req/мин | 75 req/мин |
| Series Events | недоступен | 3 подключения на серию |
| Stats Feed | — | 10 req/мин |

**Что даёт:** GraphQL. Central Data — турниры, серии, команды, игроки,
организации, идентификаторы. Series State — состояние серии: счёт по картам,
статистика игроков и команд, игровые события. Для саммари матча по CS2 и Dota 2
это очень хороший материал.

**Ограничение:** Series Events (детальный поток событий) в Open Access исключён —
это платный продукт, и для betting-применения у них отдельная форма заявки. То
есть betting они не запрещают, но выделяют в отдельный коммерческий трек.

**Риск:** заявку могут не одобрить, и сроки рассмотрения неизвестны.

---

### 2.6 bo3.gg

Официального публичного API у них нет и документации нет. Но внутренний REST API
сайта открыт и работает без ключа — проверено живыми запросами 2026-09-05.

```
GET https://api.bo3.gg/api/v1/disciplines
GET https://api.bo3.gg/api/v1/matches?filter[matches.status][in]=finished&sort=-start_date
GET https://api.bo3.gg/api/v1/matches/{slug}
GET https://api.bo3.gg/api/v1/games?filter[games.match_id][eq]={id}
```

**Покрытие (эндпоинт `/disciplines`):** CS2 (`id=1`), VALORANT (`id=2`),
LoL (`id=3`), Dota 2 (`id=4`) и ещё 4 тайтла. Объём на 2026-09-05:
~79 900 матчей всего, из них VALORANT ~14 980, Dota 2 ~11 727. История с
декабря 2020 года.

**Что отдаёт объект матча (проверено):** `team1_id`/`team2_id`,
`winner_team_id`/`loser_team_id`, `team1_score`/`team2_score`, `bo_type`,
`status`, `start_date`/`end_date`, `tournament_id`, `stage_id`, `tier`
(`s`/`a`/`b`/`c`), `maps_score` (массив булевых — кто взял каждую карту),
`discipline_id`, и даже `bet_updates` с коэффициентами букмекера.

**Что отдаёт `/games` (карты):** `map_name` (`de_dust2`), `winner_clan_score` и
`loser_clan_score` (13:7), `rounds_count`, `demo_url`, длительность.
**Проверено: наполнено только для CS2.** Для матчей VALORANT (id 128692) и
Dota 2 (id 128781) `/games` вернул пустой список — они парсят демки только для CS.

Эндпоинт со статистикой игроков найти не удалось (перебор очевидных путей —
`player_stats`, `game_players`, `games/{id}/stats` и др. — везде 404). Не значит,
что его нет; значит, что без анализа сетевых запросов самого сайта я его не нашёл.

**Условия использования:** API не документирован, значит и не покрыт никакими
условиями явно. Страница <https://bo3.gg/wiki/terms-of-use> существует
(HTTP 200), но пунктов про scraping/автоматический доступ в её тексте я не нашёл.
Практический риск другой: **это внутренний API, его могут закрыть или сломать в
любой день без предупреждения**. Строить на нём единственный источник нельзя.

Забавная деталь: в `/disciplines` у каждой дисциплины есть поле `ps_code`
(`csgo`, `valorant`, `dota2`) — то есть bo3.gg сами частично сидят на PandaScore.

---

### 2.7 VALORANT: обёртки над vlr.gg

Самая известная — `vlrggapi` (<https://github.com/axsddlr/vlrggapi>), плюс
несколько форков. Отдают результаты матчей, детали матча, статы игроков,
рейтинги, ростеры, H2H, покарточные метрики (ACS, KAST, ADR, HS%).

**Состояние на 2026-09-05 — проверено запросами, все публичные инстансы лежат:**

| Инстанс | Ответ |
|---|---|
| `vlrggapi.vercel.app` | HTTP **402** (превышены лимиты бесплатного тира Vercel) |
| `vlr.orlandomm.net` | HTTP **503**, «no available server» |
| `vlresports.vercel.app` | HTTP 404 |
| `vlr.techeron.com` | не резолвится |

В самом репозитории написано, что хостинг лёг из-за превышения free-tier, и
предлагается self-host через Docker. Лимит в коде — 600 req/мин.

**Это скрейпер vlr.gg.** Официального разрешения на автоматический сбор у vlr.gg
нет. Как временное решение для личного проекта — работает; как основа
архитектуры — нет: ломается при каждом редизайне vlr.gg и требует своего хостинга.

Официального публичного esports-API у Riot для VALORANT нет — их VALORANT Data
Portal ведёт на форму заявки, которую обслуживает GRID.

---

### 2.8 Valve Steam Web API (Dota 2)

`https://api.steampowered.com/IDOTA2Match_570/...` —
`GetMatchHistory`, `GetMatchDetails`, `GetLeagueListing`.
Справочник: <https://steamapi.xpaw.me/IDOTA2Match_570>

Ключ бесплатный, карта не нужна. Лимит по Steam Web API ToS — **100 000 вызовов
в сутки**. Это первоисточник, на котором стоят и OpenDota, и Stratz.

Практически: смысла идти напрямую в Valve мало — OpenDota даёт то же самое плюс
распарсенные реплеи, агрегаты и SQL. Стоит держать в уме как запасной вариант,
если OpenDota будет недоступен. Из минусов — эндпоинты Valve исторически ломаются
после крупных патчей (например, известные 500-е на `GetMatchDetails` после 7.36).

---

### 2.9 Остальные, коротко

**Abios (Kambi)** — <https://abiosgaming.com/esports-data-api>. 15+ тайтлов,
включая все три нужные. Публичных цен нет, бесплатного тира нет, пакеты «Match»
и «Enterprise» по запросу. Ориентированы на букмекеров — betting-применение для
них норма, но это B2B-контракт, не для личного проекта.

**Tachio Sports** — <https://tachiosports.com/>. Заявляет бесплатный тир
300 req/мин и 15 конкурентных запросов, регистрация через GitHub, без карты.
Покрытие: CS2, Dota 2, LoL, VALORANT и др. REST + WebSocket, live-счёт,
коэффициенты, расписание. **Проект новый (основан в 2025, по schema.org — один
человек), глубину и качество данных проверить не удалось — сайт за Cloudflare.**
Как основной источник брать рискованно, посмотреть стоит.

**HLTV** — публичного API нет, сайт под Cloudflare, автоматический доступ против
их условий. Существующие питоновские обёртки (`hltv-async-api`,
`python-hltv-scraper`) работают через обход антибота. Для CS2 замена —
Liquipedia API и bo3.gg. **Рекомендация из SPEC не трогать HLTV остаётся в силе.**

**OddsPapi, esportsodds и подобные** — это коэффициенты букмекеров, а не
статистика матчей. Для ваших двух фич бесполезны.

**esport.is** — фигурирует в статьях 2026 года про «бесплатные esports API» с
лимитом 100 req/час. **Домен не резолвится (проверено 2026-09-05, connection
failed).** Считайте, что источника не существует.

---

## 3. Рекомендация

### Dota 2 — решено полностью и бесплатно

**Основной: OpenDota.** Без ключа, 60 req/мин и 3000/сутки, полная история,
H2H одним SQL-запросом через `/explorer`, покарточные счета, составы, детальная
статистика игроков в матче. Всё, что нужно и для предматча, и для саммари.

**Дополнительный: Stratz** — если понадобятся драфты и тайминги в удобной
GraphQL-форме. Требует бесплатный токен.

Через PandaScore Dota 2 брать смысла нет вообще.

### CS2 — собирается бесплатно, но из двух источников

**Основной: Liquipedia MediaWiki API** для предматча — H2H, форма, история
матчей, агрегаты W-L по матчам/картам/раундам, составы и трансферы. Легально,
задокументировано, бесплатно. Цена — 1 запрос в 30 секунд на `action=parse` и
необходимость разбирать HTML из ответа API. Для бэкенда с кроном раз в 15–30
минут это не проблема, надо только агрессивно кэшировать. Обязательна атрибуция
Liquipedia (CC-BY-SA 3.0) в интерфейсе приложения.

**Дополнительный: PandaScore Free** — для расписания предстоящих матчей и
привязки к турнирам, там это удобнее и структурированнее.

**Опционально: bo3.gg** — единственный найденный бесплатный источник счёта по
картам с названиями карт (`de_dust2 13:7`) для CS2. Хорош для саммари, но это
недокументированный внутренний API, держите его как «улучшение, если работает»,
а не как зависимость.

**Стоит подать заявку: GRID Open Access.** Если одобрят — это официальные данные
по CS2, с покарточной статистикой и событиями, легально и бесплатно. Лучший
исход из всех.

### VALORANT — самое слабое место

> **ПРОВЕРЕНО 2026-09-05 (перепроверка вручную): для VALORANT этот путь НЕ
> работает.** Утверждение ниже про «работает так же, как для CS2» — неверно.
> Живые запросы:
>
> | Запрос | Результат |
> |---|---|
> | `counterstrike/api.php?action=parse&page=Team_Vitality/Matches` | 809 059 символов, есть `in matches` / `in games` / `in rounds` ✅ |
> | `valorant/api.php?action=parse&page=Paper_Rex/Matches` | 2 510 символов, только навигация, агрегатов нет ❌ |
> | `valorant/api.php?action=parse&page=Paper_Rex/Results` | 169 030 символов, но это призовые и места на турнирах, ни карт, ни счётов ❌ |
> | Прямой вызов шаблона через `contentmodel=wikitext` с `game=valorant` | 1 659 символов, пусто ❌ |
>
> Викитекст страницы `Paper Rex/Matches` содержит ровно тот же шаблон
> `{{Team matches table|team=Paper Rex}}`, что и CS2-страница, но Lua-модуль на
> VALORANT-вики возвращает пустоту. То есть история матчей команд VALORANT через
> MediaWiki API недоступна — ни на странице команды, ни прямым вызовом шаблона.
>
> **Следствие:** на бесплатных источниках по VALORANT остаётся только
> уровень серии (PandaScore Free: счёт 2:1 и кто взял каждую карту, без названий
> карт и без раундов). Единственный легальный способ получить покарточные данные
> по VALORANT — **LPDB API v3** (таблицы `match2` / `match2game`), ключ по заявке,
> бесплатно для open-source community-проектов. Это делает заявку на LPDB не
> «желательным улучшением», а главным разблокирующим шагом для VALORANT.

**Основной (не подтвердилось): Liquipedia MediaWiki API** — H2H, форма, история,
агрегаты по картам и раундам, составы. Заявлено «то же, что и для CS2» — см.
блок выше, проверка это опровергла.

**Дополнительный: PandaScore Free** — расписание, итоговый счёт по картам (2:1),
кто взял какую карту (`games[].winner`), составы команд.

**Чего не будет:** названий карт по каждой игре, счёта в раундах по карте,
статистики игроков (ACS/KAST/ADR), пиков-банов карт. В GRID Open Access VALORANT
не входит. bo3.gg по VALORANT отдаёт только матч-уровень. Остаются два выхода:
self-hosted скрейпер vlr.gg (хрупко, серая зона) либо платный план PandaScore
Valorant Historical.

### Чего на бесплатных тирах не получится в принципе

1. **Статистика игроков в матче для VALORANT и CS2** через легальные
   задокументированные API. Для Dota 2 — есть полностью. Для CS2 частично
   вытягивается из Liquipedia (страницы игроков и турниров), для VALORANT — нет.
2. **Раунд за раундом / play-by-play** нигде: у PandaScore это Basic Live
   (от €1000/мес) и Pro Live, у GRID — платный Series Events.
3. **Пики и баны карт (map picks/bans)** — у PandaScore поле `map_picks` только
   на Valorant Historical. На Liquipedia пики карт есть в тексте страниц матчей,
   но их разбор нетривиален.
4. **Названия карт и счёт по раундам в VALORANT** — только платно или через
   скрейп vlr.gg.
5. **История изменений составов в структурированном виде** — только через
   Liquipedia (страницы `Player Transfers/YYYY`, требуют парсинга) или LPDB API
   с одобренным ключом. PandaScore на бесплатном плане отдаёт только текущий
   состав, без истории.
6. **Гарантия стабильности.** Бесплатные источники (bo3.gg, обёртки vlr.gg) могут
   отвалиться в любой момент — что уже наглядно продемонстрировали все публичные
   инстансы vlrggapi.

---

## 4. Что придётся отдать платному тиру, если хочется полноты

| Что | Где | Цена |
|---|---|---|
| Покарточная статистика и статы игроков (CS2, Dota 2, VALORANT) | PandaScore **Historical** | от **€400** за тайтл в месяц. Три дисциплины — от €1200/мес |
| Раунды CS2 (`/csgo/games/{id}/rounds`) | PandaScore **Live Basic** | от **€1000** за тайтл в месяц |
| Play-by-play CS2 и LoL (`/events`) | PandaScore **Pro Live** | по запросу |
| Раунды и события VALORANT | PandaScore **Valorant Historical Pro** | по запросу |
| Фреймы Dota 2 | PandaScore **Historical Pro** | по запросу |
| `map_picks` в VALORANT | PandaScore **Valorant Historical** | входит в Historical |
| Структурированные матчи/карты/составы без парсинга HTML | **Liquipedia LPDB API** | бесплатно по заявке для open-source community-проектов; иначе Enterprise по договору |
| Официальные данные CS2/Dota 2 с событиями | **GRID** (Series Events) | Open Access не покрывает, платно, для betting — отдельная форма |
| VALORANT официально | **GRID VALORANT Data Portal** | по заявке, не бесплатно |
| Всё и сразу под букмекерские задачи | **Abios / PandaScore Odds** | B2B-контракт, цены по запросу |

**Практический вывод по деньгам:** платные тарифы PandaScore начинаются от €400
за одну дисциплину в месяц — для личного трекера это неадекватно. Если чего-то
критически не хватает, порядок действий такой:

1. Подать заявку в **GRID Open Access** (CS2 + Dota 2, бесплатно, официальные
   данные) — самый выгодный из возможных апгрейдов.
2. Подать заявку на **Liquipedia LPDB API** — 60 req/час хватает при кэшировании,
   и это снимает всю боль с парсингом HTML. Условие — открытый исходный код
   проекта.
3. VALORANT оставить на связке Liquipedia + PandaScore Free и смириться с
   отсутствием статистики игроков, либо поднять self-hosted скрейпер vlr.gg,
   понимая риски.

---

## 5. Что не удалось выяснить

- **Требует ли PandaScore карту при регистрации** на бесплатном плане — на
  странице тарифов план €0/мес, но лично проверить регистрацию я не мог.
- **Глубина истории `/matches/past` на бесплатном плане PandaScore** — в
  документации не указана, проверяется только эмпирически после получения ключа.
- **Актуальность лимитов Stratz на 2026 год** — их страницы рендерятся на JS,
  первоисточник цифр датирован 2020 годом.
- **Условия Stratz по betting-применению** — публичного текста найти не удалось.
- **Эндпоинт статистики игроков в bo3.gg** — существует на сайте, но путь в их
  внутреннем API перебором не нашёлся.
- **Реальное качество и глубина данных Tachio Sports** — сайт за Cloudflare,
  документация не читается без регистрации.
- **Точные условия допуска к бесплатному тиру Liquipedia LPDB на сегодня** —
  страница `liquipedia.net/api` закрыта Cloudflare Turnstile, читал через
  поисковую выдачу.

---

## 6. Ссылки

**PandaScore**
- <https://developers.pandascore.co/docs/introduction>
- <https://developers.pandascore.co/docs/plan-reference> — таблица планов по эндпоинтам
- <https://developers.pandascore.co/docs/rate-and-connections-limits>
- <https://www.pandascore.co/pricing>
- <https://www.pandascore.co/stats>
- <https://www.pandascore.co/terms-and-condition>

**Dota 2**
- <https://docs.opendota.com>
- <https://www.opendota.com/api-keys>
- <https://blog.opendota.com/2018/04/17/changes-to-the-api/>
- <https://stratz.com/api>
- <https://stratz.com/knowledge-base/API>
- <https://github.com/STRATZ-Esports/knowledge-base/issues/15>
- <https://steamapi.xpaw.me/IDOTA2Match_570>

**Liquipedia**
- <https://liquipedia.net/api-terms-of-use>
- <https://liquipedia.net/api>
- <https://liquipedia.net/commons/Help:LiquipediaDB/Match>
- <https://api.liquipedia.net/documentation> (только после логина)

**GRID**
- <https://grid.gg/open-access/>
- <https://grid.helpjuice.com/rate-limits-for-products>
- <https://grid.gg/get-valorant/>

**Прочее**
- <https://github.com/axsddlr/vlrggapi>
- <https://abiosgaming.com/esports-data-api>
- <https://tachiosports.com/>
- <https://bo3.gg/wiki/terms-of-use>
