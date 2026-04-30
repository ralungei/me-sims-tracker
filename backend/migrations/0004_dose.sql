ALTER TABLE aspirations ADD COLUMN unit TEXT;
ALTER TABLE aspirations ADD COLUMN default_dose INTEGER NOT NULL DEFAULT 1;
ALTER TABLE aspirations ADD COLUMN schedule_raw TEXT;  -- JSON: [{"fromWeek":1,"toWeek":2,"count":1}, ...]
