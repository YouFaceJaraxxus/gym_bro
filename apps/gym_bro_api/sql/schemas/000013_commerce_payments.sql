-- ── Commerce: shop items can sell out; payment renewal idempotency ───────────
-- 000006 required shop_item.quantity > 0, which made it impossible to sell the
-- last unit. Stock is now decremented by orders, so 0 means "out of stock".

ALTER TABLE shop_item DROP CONSTRAINT IF EXISTS shop_item_quantity_check;
ALTER TABLE shop_item ADD CONSTRAINT shop_item_quantity_check CHECK (quantity >= 0);

-- Speeds up "orders containing this item" lookups (restock notifications).
CREATE INDEX IF NOT EXISTS invoice_item_shop_item_idx ON invoice_item (shop_item_id);

-- ── Payments: idempotency for subscription renewals ───────────────────────────
-- Each `invoice.paid` webhook for a renewal becomes one payment row; the Stripe
-- invoice id makes redelivered webhooks a no-op.

ALTER TABLE payment ADD COLUMN IF NOT EXISTS stripe_invoice_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS payment_stripe_invoice_idx ON payment (stripe_invoice_id);
