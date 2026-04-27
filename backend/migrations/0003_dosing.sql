ALTER TABLE aspirations ADD COLUMN dosing_moment TEXT;
ALTER TABLE aspirations ADD COLUMN reminder_time INTEGER;  -- ms-of-day or full epoch ms; client uses HH:mm only
