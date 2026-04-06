-- ── Enums ─────────────────────────────────────────────────────────────────────

ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'super_user';

CREATE TYPE business_type AS ENUM ('gym', 'shop');

-- ── Business & subtypes ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS business (
  id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  name                VARCHAR(255)  NOT NULL,
  location            TEXT          NOT NULL,
  logo                TEXT,
  working_hours_from  TIME          NOT NULL,
  working_hours_to    TIME          NOT NULL,
  working_weekdays    SMALLINT[]    NOT NULL,  -- array of ISO weekday ints (1=Mon … 7=Sun)
  type                business_type NOT NULL
);

CREATE TABLE IF NOT EXISTS gym (
  id          UUID  PRIMARY KEY REFERENCES business(id) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS shop (
  id          UUID  PRIMARY KEY REFERENCES business(id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ── People roles ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS trainer (
  id        UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   UUID  NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  gym_id    UUID  NOT NULL REFERENCES gym(id)   ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE (user_id, gym_id)
);

CREATE TABLE IF NOT EXISTS member (
  id        UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   UUID  NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  gym_id    UUID  NOT NULL REFERENCES gym(id)   ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE (user_id, gym_id)
);

CREATE TABLE IF NOT EXISTS employee (
  id        UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   UUID  NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  gym_id    UUID  NOT NULL REFERENCES gym(id)   ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE (user_id, gym_id)
);

CREATE TABLE IF NOT EXISTS employee_trainer (
  id          UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID  NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  gym_id      UUID  NOT NULL REFERENCES gym(id)   ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE (user_id, gym_id)
);

CREATE TABLE IF NOT EXISTS gym_owner (
  id          UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID  NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  gym_id      UUID  NOT NULL REFERENCES gym(id)   ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE (user_id, gym_id)
);

CREATE TABLE IF NOT EXISTS shop_owner (
  id          UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID  NOT NULL REFERENCES users(id)  ON DELETE RESTRICT ON UPDATE CASCADE,
  shop_id     UUID  NOT NULL REFERENCES shop(id)   ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE (user_id, shop_id)
);

-- ── Memberships ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS gym_membership_type (
  id            UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  name          VARCHAR(255)   NOT NULL,
  monthly_cost  NUMERIC(10, 2) NOT NULL,
  gym_id        UUID           NOT NULL REFERENCES gym(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  is_active     BOOLEAN        NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS membership (
  id                          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                     UUID        NOT NULL REFERENCES users(id)               ON DELETE RESTRICT ON UPDATE CASCADE,
  current_membership_type_id  UUID        NOT NULL REFERENCES gym_membership_type(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  from_date                   DATE        NOT NULL,
  to_date                     DATE        NOT NULL,
  last_updated_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active                   BOOLEAN     NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS membership_invoice (
  id                    UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  membership_id         UUID           NOT NULL REFERENCES membership(id)            ON DELETE RESTRICT ON UPDATE CASCADE,
  membership_type_id    UUID           NOT NULL REFERENCES gym_membership_type(id)   ON DELETE RESTRICT ON UPDATE CASCADE,
  issued_at             TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  amount                NUMERIC(10, 2) NOT NULL
);
