-- Aspirations: user-defined recurring challenges
CREATE TABLE IF NOT EXISTS aspirations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL DEFAULT '✨',
  kind TEXT NOT NULL CHECK (kind IN ('dailySimple','dailyTimed','treatment','weekly')),
  hue REAL NOT NULL,
  xp INTEGER NOT NULL,
  duration_minutes INTEGER,
  total_days INTEGER,
  started_at INTEGER,
  last_completed_at INTEGER,
  completions_log TEXT NOT NULL DEFAULT '[]',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

-- Tasks: one-off agenda items
CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  notes TEXT,
  due_date INTEGER,
  is_done INTEGER NOT NULL DEFAULT 0,
  completed_at INTEGER,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

-- Activity log: every need-action ever logged
CREATE TABLE IF NOT EXISTS activity_log (
  id TEXT PRIMARY KEY,
  need_type TEXT NOT NULL,
  action_name TEXT NOT NULL,
  action_icon TEXT NOT NULL DEFAULT 'circle',
  boost_amount REAL NOT NULL,
  notes TEXT,
  timestamp INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_log_timestamp ON activity_log(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_log_need ON activity_log(need_type);

-- Needs state: live values for each need + enabled flag
CREATE TABLE IF NOT EXISTS needs_state (
  need_type TEXT PRIMARY KEY,
  value REAL NOT NULL,
  last_updated INTEGER NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL
);
