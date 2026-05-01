-- ── Shop vendor ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS shop_vendor (
  id        UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   UUID  NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  shop_id   UUID  NOT NULL REFERENCES shop(id)  ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE (user_id, shop_id)
);
