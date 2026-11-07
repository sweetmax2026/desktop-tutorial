CREATE TABLE IF NOT EXISTS feedback (
  id TEXT PRIMARY KEY, payload_hash TEXT NOT NULL, category TEXT NOT NULL,
  content TEXT NOT NULL, contact TEXT NOT NULL, app_version TEXT,
  system_version TEXT, created_at INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'new' CHECK(status IN ('new','done'))
);
CREATE INDEX IF NOT EXISTS feedback_created ON feedback(created_at DESC);
CREATE TABLE IF NOT EXISTS sessions (token_hash TEXT PRIMARY KEY, expires_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS sessions_expiry ON sessions(expires_at);
CREATE TABLE IF NOT EXISTS rate_limits (key TEXT PRIMARY KEY, count INTEGER NOT NULL, expires_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS rate_expiry ON rate_limits(expires_at);
