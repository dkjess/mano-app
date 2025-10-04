-- Add started_working_together field to people table
ALTER TABLE people
ADD COLUMN started_working_together DATE;

-- Add comment for clarity
COMMENT ON COLUMN people.started_working_together IS 'Date when the user started working with this person';

-- Index for potential queries by relationship duration
CREATE INDEX people_started_working_together_idx ON people(started_working_together);