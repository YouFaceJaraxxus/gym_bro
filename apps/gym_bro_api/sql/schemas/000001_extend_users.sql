CREATE TYPE user_role AS ENUM (
  'admin',
  'trainer',
  'employee',
  'employee_trainer',
  'member'
);

ALTER TABLE users
  ADD COLUMN role user_role NOT NULL DEFAULT 'member';
