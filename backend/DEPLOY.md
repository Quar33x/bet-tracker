# Как поднять бэкенд

Пошагово, с нуля. Всё бесплатное: Cloudflare Workers, D1 и PandaScore
Fixtures укладываются в бесплатные тарифы. Платный только Claude — по факту
потребления, с потолком расходов внутри самого воркера.

Время: минут 20.

---

## Шаг 1. Аккаунт Cloudflare

Зарегистрируйся на <https://dash.cloudflare.com/sign-up>. Карта не нужна.

## Шаг 2. Ключ PandaScore

Зарегистрируйся на <https://www.pandascore.co/pricing>, выбери бесплатный
план **Fixtures** (€0/мес). Ключ появится в личном кабинете.

Заодно проверь два вопроса, которые не удалось выяснить со стороны:
просят ли карту при регистрации и насколько глубокую историю отдаёт
`/matches/past`.

## Шаг 3. Ключ Claude

<https://console.anthropic.com> → Get API key. Он уже есть, если ты
заводил его раньше.

## Шаг 4. Вход в Cloudflare из терминала

Из папки `backend`:

```bash
npx wrangler login
```

Откроется браузер, подтверди доступ.

## Шаг 5. Создать базу

```bash
npx wrangler d1 create bet-tracker
```

Команда напечатает `database_id`. **Скопируй его в `wrangler.toml`** вместо
`REPLACE_AFTER_D1_CREATE`.

Затем накатить схему:

```bash
npx wrangler d1 migrations apply bet-tracker --remote
```

## Шаг 6. Секреты

Придумай токен приложения — это пароль, которым телефон авторизуется в
твоём API. Подойдёт любая длинная случайная строка.

```bash
npx wrangler secret put APP_TOKEN
npx wrangler secret put PANDASCORE_KEY
npx wrangler secret put ANTHROPIC_API_KEY
```

Каждая команда спросит значение. Секреты не попадают ни в git, ни в
приложение — они живут только в Cloudflare.

Дневной потолок расходов на модель по умолчанию $5. Поменять:

```bash
npx wrangler secret put DAILY_BUDGET_USD
```

## Шаг 7. Выкатить

```bash
npx wrangler deploy
```

В конце напечатает адрес вида `https://bet-tracker-api.<логин>.workers.dev`.

Проверить:

```bash
curl https://bet-tracker-api.<логин>.workers.dev/health
```

Должно ответить `{"ok": true, ...}`.

## Шаг 8. Наполнить данными

Крон запускается раз в 20 минут сам, но первый заход можно не ждать:

```bash
curl -X POST -H "Authorization: Bearer ТВОЙ_APP_TOKEN" \
  https://bet-tracker-api.<логин>.workers.dev/admin/ingest
```

Ответ покажет, сколько команд обработано и сколько матчей записано.

## Шаг 9. Подключить приложение

В приложении вкладка **Ещё** → адрес воркера и `APP_TOKEN` → «Проверить
связь». Дальше на вкладке **Матчи** появятся матчи, а по кнопке
«Разобрать матч» — предматчевый анализ.

---

## Что происходит дальше само

Каждые 20 минут воркер:

1. тянет свежие матчи (OpenDota по Dota 2, PandaScore по трём дисциплинам);
2. забирает готовые саммари из очереди Batch API и раскладывает по матчам;
3. ставит в очередь саммари для матчей, которые завершились и текста ещё
   не имеют.

Предматчевый разбор так не считается: он делается только по кнопке в
приложении, потому что это самый дорогой вызов.

## Сколько это стоит

- Cloudflare Workers + D1 — бесплатно на таких объёмах.
- PandaScore Fixtures — бесплатно, 1000 запросов в час.
- OpenDota и Liquipedia — бесплатно.
- Claude — по факту: предматчевый разбор около $0.18, саммари около $0.01.
  При 10 разборах и 30 саммари в день выходит примерно $60-65 в месяц.

Потолок держат две вещи: `DAILY_BUDGET_USD` в воркере и месячный лимит в
консоли Anthropic. Первый останавливает запросы, второй — последний рубеж.

Посмотреть расходы: вкладка «Ещё» в приложении или

```bash
curl -H "Authorization: Bearer ТВОЙ_APP_TOKEN" \
  https://bet-tracker-api.<логин>.workers.dev/spend
```

## Полезные команды

```bash
npx wrangler tail                                   # живой лог воркера
npx wrangler d1 execute bet-tracker --remote --command "SELECT COUNT(*) FROM matches"
```

Журнал запусков крона также виден через `/jobs`.
