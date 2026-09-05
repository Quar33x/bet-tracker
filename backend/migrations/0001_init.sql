-- Зеркало данных о матчах. Ничего вычисляемого здесь не хранится:
-- профит, ROI и винрейт по-прежнему считаются в приложении.

CREATE TABLE teams (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  discipline     TEXT    NOT NULL,   -- valorant | cs2 | dota2
  name           TEXT    NOT NULL,
  short_name     TEXT,
  opendota_id    INTEGER,
  pandascore_id  INTEGER,
  liquipedia_page TEXT,
  updated_at     INTEGER NOT NULL
);
CREATE UNIQUE INDEX idx_teams_discipline_name ON teams (discipline, name);
CREATE INDEX idx_teams_opendota ON teams (opendota_id) WHERE opendota_id IS NOT NULL;

CREATE TABLE matches (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  discipline      TEXT    NOT NULL,
  source          TEXT    NOT NULL,  -- opendota | pandascore | liquipedia | lpdb
  external_id     TEXT    NOT NULL,
  tournament_name TEXT,
  team_a_id       INTEGER REFERENCES teams (id),
  team_b_id       INTEGER REFERENCES teams (id),
  best_of         INTEGER,
  scheduled_at    INTEGER,           -- unix seconds
  status          TEXT    NOT NULL,  -- scheduled | running | finished
  score_a         INTEGER,
  score_b         INTEGER,
  updated_at      INTEGER NOT NULL
);
CREATE UNIQUE INDEX idx_matches_source_external ON matches (source, external_id);
CREATE INDEX idx_matches_schedule ON matches (discipline, scheduled_at);
CREATE INDEX idx_matches_status ON matches (status, scheduled_at);

-- Карты внутри матча — заполняются только теми источниками, которые их отдают.
--
-- score_a/score_b — это счёт В РАУНДАХ (13:7). Источники, которые раундов не
-- дают (PandaScore на бесплатном плане знает только победителя карты),
-- заполняют winner и оставляют счёт пустым. Складывать в одну колонку «1:0 по
-- картам» и «13:7 по раундам» нельзя: на этих числах потом строится анализ
-- фор, и смесь двух шкал молча его испортит.
CREATE TABLE match_maps (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  match_id  INTEGER NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
  position  INTEGER NOT NULL,
  map_name  TEXT,
  score_a   INTEGER,
  score_b   INTEGER,
  winner    TEXT CHECK (winner IN ('a', 'b'))
);
CREATE UNIQUE INDEX idx_match_maps_position ON match_maps (match_id, position);

-- Кэш сырых ответов источников: бережёт их лимиты и наши деньги.
CREATE TABLE source_cache (
  key        TEXT    PRIMARY KEY,
  payload    TEXT    NOT NULL,
  fetched_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX idx_source_cache_expiry ON source_cache (expires_at);

-- Тексты от модели. Кэш по (матч, вид, версия промпта): переспрашивать
-- одно и то же по тому же матчу — значит платить дважды.
CREATE TABLE analyses (
  match_id       INTEGER NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
  kind           TEXT    NOT NULL,  -- preview | summary
  prompt_version TEXT    NOT NULL,
  model          TEXT    NOT NULL,
  body           TEXT    NOT NULL,
  input_tokens   INTEGER,
  output_tokens  INTEGER,
  cost_usd       REAL,
  created_at     INTEGER NOT NULL,
  PRIMARY KEY (match_id, kind, prompt_version)
);

-- Отправленные батчи саммари: крон забирает результаты следующим заходом.
CREATE TABLE llm_batches (
  id         TEXT    PRIMARY KEY,   -- id батча на стороне Anthropic
  kind       TEXT    NOT NULL,      -- summary
  status     TEXT    NOT NULL,      -- pending | done | failed
  created_at INTEGER NOT NULL,
  closed_at  INTEGER
);
CREATE INDEX idx_llm_batches_status ON llm_batches (status, created_at);

-- Журнал запусков крона: чтобы было видно, что происходило ночью.
CREATE TABLE job_runs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  job         TEXT    NOT NULL,
  started_at  INTEGER NOT NULL,
  finished_at INTEGER,
  ok          INTEGER,
  detail      TEXT
);
CREATE INDEX idx_job_runs_started ON job_runs (started_at);
