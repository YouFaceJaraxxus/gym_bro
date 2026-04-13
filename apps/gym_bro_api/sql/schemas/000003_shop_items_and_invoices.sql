-- ── Enums ─────────────────────────────────────────────────────────────────────

CREATE TYPE shop_item_type AS ENUM ('equipment', 'supplement', 'gift_card');

-- ── Shop items ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS shop_item (
  id            UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id       UUID            NOT NULL REFERENCES shop(id) ON DELETE CASCADE ON UPDATE CASCADE,
  type          shop_item_type  NOT NULL,
  name          VARCHAR(255)    NOT NULL,
  description   TEXT,
  price         NUMERIC(10, 2)  NOT NULL,
  is_active     BOOLEAN         NOT NULL DEFAULT TRUE,
  active_until  TIMESTAMPTZ
);

-- ── Invoices ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS invoice (
  id     UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  date   DATE           NOT NULL DEFAULT CURRENT_DATE,
  -- Maintained automatically by the trigger below; do not set manually.
  total  NUMERIC(10, 2) NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS invoice_item (
  id            UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id    UUID     NOT NULL REFERENCES invoice(id)    ON DELETE CASCADE ON UPDATE CASCADE,
  shop_item_id  UUID     NOT NULL REFERENCES shop_item(id)  ON DELETE RESTRICT ON UPDATE CASCADE,
  quantity      INTEGER  NOT NULL CHECK (quantity > 0),
  UNIQUE (invoice_id, shop_item_id)
);

-- ── Trigger: keep invoice.total in sync with invoice_items ────────────────────

CREATE OR REPLACE FUNCTION recalc_invoice_total()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  target_invoice_id UUID := COALESCE(NEW.invoice_id, OLD.invoice_id);
BEGIN
  UPDATE invoice
  SET total = COALESCE((
    SELECT SUM(ii.quantity * si.price)
    FROM   invoice_item ii
    JOIN   shop_item    si ON si.id = ii.shop_item_id
    WHERE  ii.invoice_id = target_invoice_id
  ), 0)
  WHERE id = target_invoice_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER invoice_item_total_sync
AFTER INSERT OR UPDATE OR DELETE ON invoice_item
FOR EACH ROW EXECUTE FUNCTION recalc_invoice_total();
