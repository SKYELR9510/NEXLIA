-- NEXLIA Chat · migración 001 (bajada). Borra solo tablas chat_*, en orden inverso
-- de claves foráneas. No toca spam_numeros ni spam_reportes.
DROP TABLE IF EXISTS chat_push_endpoints;
DROP TABLE IF EXISTS chat_message_receipts;
DROP TABLE IF EXISTS chat_messages;
DROP TABLE IF EXISTS chat_conversation_members;
DROP TABLE IF EXISTS chat_conversations;
DROP TABLE IF EXISTS chat_devices;
DROP TABLE IF EXISTS chat_users;
