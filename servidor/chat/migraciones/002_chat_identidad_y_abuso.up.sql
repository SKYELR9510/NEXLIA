-- NEXLIA Chat · migración 002 (subida). Preparada, NO desplegada.
-- Identidad por teléfono verificado (OTP), sesiones por dispositivo con rotación,
-- cursores de lectura, límites de frecuencia, bloqueos y reportes.
-- Ningún campo guarda secretos en claro: códigos y tokens solo como hash.
-- Diseño: docs/CHAT_BACKEND.md.

-- Identidad: el número verificado identifica la cuenta (E.164, p. ej. +51987654321).
ALTER TABLE chat_users
  ADD COLUMN phone_e164        VARCHAR(16)  NULL AFTER public_id,
  ADD COLUMN phone_verified_at TIMESTAMP(3) NULL AFTER phone_e164,
  ADD COLUMN deleted_at        TIMESTAMP(3) NULL,
  ADD UNIQUE KEY uq_chat_users_phone (phone_e164);

-- Sesiones: token de acceso corto y token de renovación rotatorio (solo hashes).
-- refresh_family agrupa las rotaciones: si se reutiliza un token viejo, se revoca la familia.
ALTER TABLE chat_devices
  ADD COLUMN platform           ENUM('android') NOT NULL DEFAULT 'android' AFTER label,
  ADD COLUMN app_version        VARCHAR(20)  NOT NULL DEFAULT '' AFTER platform,
  ADD COLUMN access_expires_at  TIMESTAMP(3) NULL AFTER token_hash,
  ADD COLUMN refresh_hash       BINARY(32)   NULL AFTER access_expires_at,
  ADD COLUMN refresh_family     BINARY(16)   NULL AFTER refresh_hash,
  ADD COLUMN refresh_expires_at TIMESTAMP(3) NULL AFTER refresh_family,
  ADD UNIQUE KEY uq_chat_devices_refresh (refresh_hash),
  ADD KEY ix_chat_devices_family (refresh_family);

-- Retos OTP. El código nunca se guarda: solo HMAC-SHA256(código, pepper del servidor).
CREATE TABLE chat_otp_challenges (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  public_id     CHAR(26)        NOT NULL,
  phone_e164    VARCHAR(16)     NOT NULL,
  purpose       ENUM('login','change_phone') NOT NULL,
  code_hash     BINARY(32)      NOT NULL,
  attempts      TINYINT UNSIGNED NOT NULL DEFAULT 0,
  max_attempts  TINYINT UNSIGNED NOT NULL DEFAULT 5,
  ip_hash       BINARY(32)      NOT NULL,
  created_at    TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at    TIMESTAMP(3)    NOT NULL,
  consumed_at   TIMESTAMP(3)    NULL,
  UNIQUE KEY uq_chat_otp_public (public_id),
  KEY ix_chat_otp_phone (phone_e164, created_at),
  KEY ix_chat_otp_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Conversación directa única por par de usuarios: direct_key = SHA-256("menor:mayor").
ALTER TABLE chat_conversations
  ADD COLUMN direct_key BINARY(32) NULL AFTER kind,
  ADD UNIQUE KEY uq_chat_conversations_direct (direct_key);

-- Cursores por miembro: lectura y entrega hasta un mensaje (evita una fila por mensaje y lector).
ALTER TABLE chat_conversation_members
  ADD COLUMN last_delivered_message_id BIGINT UNSIGNED NULL,
  ADD COLUMN last_read_message_id      BIGINT UNSIGNED NULL,
  ADD COLUMN muted_until               TIMESTAMP(3)    NULL;

-- Borrado lógico de mensajes; la sincronización usa el id autoincremental como cursor.
ALTER TABLE chat_messages
  ADD COLUMN deleted_at TIMESTAMP(3) NULL,
  ADD KEY ix_chat_messages_created (created_at);

-- Límites de frecuencia por clave (p. ej. "otp:phone:+519...", "msg:user:42") y ventana.
CREATE TABLE chat_rate_limits (
  bucket        VARCHAR(120)  NOT NULL,
  window_start  TIMESTAMP     NOT NULL,
  hits          INT UNSIGNED  NOT NULL DEFAULT 0,
  PRIMARY KEY (bucket, window_start),
  KEY ix_chat_rate_window (window_start)
) ENGINE=InnoDB DEFAULT CHARSET=ascii COLLATE=ascii_bin;

CREATE TABLE chat_blocks (
  blocker_id  BIGINT UNSIGNED NOT NULL,
  blocked_id  BIGINT UNSIGNED NOT NULL,
  created_at  TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (blocker_id, blocked_id),
  KEY ix_chat_blocks_blocked (blocked_id),
  CONSTRAINT fk_chat_blocks_blocker FOREIGN KEY (blocker_id) REFERENCES chat_users (id) ON DELETE CASCADE,
  CONSTRAINT fk_chat_blocks_blocked FOREIGN KEY (blocked_id) REFERENCES chat_users (id) ON DELETE CASCADE
  -- "No bloquearse a sí mismo" se valida en la API: MySQL no admite CHECK sobre columnas con ON DELETE CASCADE.
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE chat_reports (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  reporter_id      BIGINT UNSIGNED NOT NULL,
  reported_id      BIGINT UNSIGNED NOT NULL,
  message_id       BIGINT UNSIGNED NULL,
  reason           ENUM('spam','fraud','harassment','other') NOT NULL,
  status           ENUM('open','reviewed','actioned','dismissed') NOT NULL DEFAULT 'open',
  created_at       TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_chat_reports_once (reporter_id, reported_id, message_id),
  KEY ix_chat_reports_reported (reported_id, status),
  CONSTRAINT fk_chat_reports_reporter FOREIGN KEY (reporter_id) REFERENCES chat_users (id) ON DELETE CASCADE,
  CONSTRAINT fk_chat_reports_reported FOREIGN KEY (reported_id) REFERENCES chat_users (id) ON DELETE CASCADE,
  CONSTRAINT fk_chat_reports_message FOREIGN KEY (message_id) REFERENCES chat_messages (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Eventos de seguridad (inicio de sesión, reutilización de token, recuperación). Sin contenido de mensajes.
CREATE TABLE chat_security_events (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT UNSIGNED NULL,
  device_id   BIGINT UNSIGNED NULL,
  kind        ENUM('otp_requested','otp_failed','login','refresh_reuse','logout','device_revoked','phone_changed','account_deleted') NOT NULL,
  ip_hash     BINARY(32)      NULL,
  created_at  TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY ix_chat_security_user (user_id, created_at),
  CONSTRAINT fk_chat_security_user FOREIGN KEY (user_id) REFERENCES chat_users (id) ON DELETE SET NULL,
  CONSTRAINT fk_chat_security_device FOREIGN KEY (device_id) REFERENCES chat_devices (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
