-- ── Notification type enum ────────────────────────────────────────────────────

CREATE TYPE notification_type AS ENUM (
  -- invite flows
  'employee_gym_invite',
  'vendor_shop_invite',
  'member_invite',
  -- business events
  'news',
  'events',
  -- training
  'training',
  'training_update',
  'class_reminder',
  -- shop
  'shop_item_update',
  'purchase_made',
  -- membership
  'membership_expiring',
  'invoice_issued',
  'member_subscription_extended',
  -- join confirmations
  'member_join',
  'employee_join',
  'vendor_join'
);

-- ── Notification table ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS notification (
  id          UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID              NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type        notification_type NOT NULL,
  title       TEXT              NOT NULL,
  body        TEXT,
  -- Type-specific payload.
  -- Invite notifications include: invite_status ('pending'|'accepted'|'declined'),
  -- inviter_id, entity_name, and one of: gym_id+employee_type or shop_id.
  metadata    JSONB,
  is_read     BOOLEAN           NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS notification_user_id_created_at_idx
  ON notification(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notification_user_id_unread_idx
  ON notification(user_id) WHERE is_read = FALSE;

-- ── Extend employee_trainer with trainer_id ───────────────────────────────────

ALTER TABLE employee_trainer
  ADD COLUMN IF NOT EXISTS trainer_id UUID REFERENCES trainer(id) ON DELETE SET NULL;
