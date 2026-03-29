CREATE TYPE user_role AS ENUM (
  'admin',
  'trainer',
  'employee',
  'employee_trainer',
  'member'
);

ALTER TABLE users
  ADD COLUMN role     user_role NOT NULL DEFAULT 'member',
  ADD COLUMN auth_id  UUID      UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  ALTER COLUMN password DROP NOT NULL,
  ALTER COLUMN password SET DEFAULT '';
