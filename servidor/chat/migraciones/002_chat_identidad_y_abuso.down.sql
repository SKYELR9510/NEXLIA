-- NEXLIA Chat · migración 002 (bajada). Deja el esquema exactamente como tras la 001.
DROP TABLE IF EXISTS chat_security_events;
DROP TABLE IF EXISTS chat_reports;
DROP TABLE IF EXISTS chat_blocks;
DROP TABLE IF EXISTS chat_rate_limits;
DROP TABLE IF EXISTS chat_otp_challenges;

ALTER TABLE chat_messages
  DROP KEY ix_chat_messages_created,
  DROP COLUMN deleted_at;

ALTER TABLE chat_conversation_members
  DROP COLUMN muted_until,
  DROP COLUMN last_read_message_id,
  DROP COLUMN last_delivered_message_id;

ALTER TABLE chat_conversations
  DROP KEY uq_chat_conversations_direct,
  DROP COLUMN direct_key;

ALTER TABLE chat_devices
  DROP KEY ix_chat_devices_family,
  DROP KEY uq_chat_devices_refresh,
  DROP COLUMN refresh_expires_at,
  DROP COLUMN refresh_family,
  DROP COLUMN refresh_hash,
  DROP COLUMN access_expires_at,
  DROP COLUMN app_version,
  DROP COLUMN platform;

ALTER TABLE chat_users
  DROP KEY uq_chat_users_phone,
  DROP COLUMN deleted_at,
  DROP COLUMN phone_verified_at,
  DROP COLUMN phone_e164;
