-- NEXLIA Chat · migración 001 (subida). Fase 1: preparada, NO desplegada.
-- Independiente de las tablas de spam. Nunca guarda SMS.
-- Sin contraseñas: el método de autenticación está pendiente (docs/FASE1_MENSAJERIA.md §5).

CREATE TABLE chat_users (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  public_id     CHAR(26)        NOT NULL,
  display_name  VARCHAR(80)     NOT NULL,
  status        ENUM('active','disabled') NOT NULL DEFAULT 'active',
  created_at    TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_chat_users_public (public_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sesiones por dispositivo. Solo se guarda el hash del token, nunca el token.
CREATE TABLE chat_devices (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id       BIGINT UNSIGNED NOT NULL,
  token_hash    BINARY(32)      NOT NULL,
  label         VARCHAR(80)     NOT NULL DEFAULT '',
  created_at    TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_seen_at  TIMESTAMP(3)    NULL,
  revoked_at    TIMESTAMP(3)    NULL,
  UNIQUE KEY uq_chat_devices_token (token_hash),
  KEY ix_chat_devices_user (user_id),
  CONSTRAINT fk_chat_devices_user FOREIGN KEY (user_id) REFERENCES chat_users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE chat_conversations (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  public_id     CHAR(26)        NOT NULL,
  kind          ENUM('direct')  NOT NULL DEFAULT 'direct',
  created_at    TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at    TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_chat_conversations_public (public_id),
  KEY ix_chat_conversations_updated (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Pertenencia: base de la autorización (solo los miembros leen o escriben).
CREATE TABLE chat_conversation_members (
  conversation_id BIGINT UNSIGNED NOT NULL,
  user_id         BIGINT UNSIGNED NOT NULL,
  joined_at       TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (conversation_id, user_id),
  KEY ix_chat_members_user (user_id),
  CONSTRAINT fk_chat_members_conv FOREIGN KEY (conversation_id) REFERENCES chat_conversations (id) ON DELETE CASCADE,
  CONSTRAINT fk_chat_members_user FOREIGN KEY (user_id) REFERENCES chat_users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- client_id: idempotencia del envío (el mismo mensaje reintentado no se duplica).
CREATE TABLE chat_messages (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  public_id       CHAR(26)        NOT NULL,
  conversation_id BIGINT UNSIGNED NOT NULL,
  sender_id       BIGINT UNSIGNED NOT NULL,
  client_id       VARCHAR(64)     NOT NULL,
  body            TEXT            NOT NULL,
  created_at      TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_chat_messages_public (public_id),
  UNIQUE KEY uq_chat_messages_idem (sender_id, client_id),
  KEY ix_chat_messages_conv (conversation_id, id),
  CONSTRAINT fk_chat_messages_conv FOREIGN KEY (conversation_id) REFERENCES chat_conversations (id) ON DELETE CASCADE,
  CONSTRAINT fk_chat_messages_sender FOREIGN KEY (sender_id) REFERENCES chat_users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE chat_message_receipts (
  message_id    BIGINT UNSIGNED NOT NULL,
  user_id       BIGINT UNSIGNED NOT NULL,
  kind          ENUM('delivered','read') NOT NULL,
  at            TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (message_id, user_id, kind),
  KEY ix_chat_receipts_user (user_id),
  CONSTRAINT fk_chat_receipts_msg FOREIGN KEY (message_id) REFERENCES chat_messages (id) ON DELETE CASCADE,
  CONSTRAINT fk_chat_receipts_user FOREIGN KEY (user_id) REFERENCES chat_users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE chat_push_endpoints (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  device_id     BIGINT UNSIGNED NOT NULL,
  provider      ENUM('fcm')     NOT NULL,
  token         VARCHAR(512)    NOT NULL,
  updated_at    TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_chat_push_device (device_id, provider),
  CONSTRAINT fk_chat_push_device FOREIGN KEY (device_id) REFERENCES chat_devices (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
