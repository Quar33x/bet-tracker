const now = () => Math.floor(Date.now() / 1000);

export class SourceCache {
  constructor(private db: D1Database) {}

  async get(key: string): Promise<string | null> {
    const row = await this.db
      .prepare("SELECT payload FROM source_cache WHERE key = ? AND expires_at > ?")
      .bind(key, now())
      .first<{ payload: string }>();
    return row?.payload ?? null;
  }

  async set(key: string, payload: string, ttlSeconds: number): Promise<void> {
    const fetchedAt = now();
    const expiresAt = fetchedAt + ttlSeconds;
    await this.db
      .prepare(
        `INSERT INTO source_cache (key, payload, fetched_at, expires_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT (key) DO UPDATE SET
           payload    = excluded.payload,
           fetched_at = excluded.fetched_at,
           expires_at = excluded.expires_at`,
      )
      .bind(key, payload, fetchedAt, expiresAt)
      .run();
  }

  async prune(): Promise<number> {
    const result = await this.db
      .prepare("DELETE FROM source_cache WHERE expires_at <= ?")
      .bind(now())
      .run();
    return result.meta.changes;
  }
}
