# NEXLIA Chat: arquitectura del backend

**Estado:** diseño. **No hay servidor desplegado ni endpoints PHP de Chat implementados.**

Este documento define qué hay que construir para que NEXLIA Chat funcione de verdad, y con qué reglas. Las piezas que ya existen y están probadas:

| Pieza | Archivo | Verificación |
|---|---|---|
| Contrato de la API (OpenAPI 3.0) | `servidor/chat/openapi.yaml` | Validado en CI con `openapi-spec-validator`. Una prueba Dart comprueba que el cliente usa rutas del contrato |
| Migración 001: usuarios, dispositivos, conversaciones, miembros, mensajes, recibos y push | `servidor/chat/migraciones/001_chat_base.*.sql` | MySQL 8 en CI: se sube, se baja y se vuelve a subir |
| Migración 002: identidad por teléfono, sesiones con rotación, OTP, conversación directa única, cursores, límites, bloqueos, reportes y eventos de seguridad | `servidor/chat/migraciones/002_chat_identidad_y_abuso.*.sql` | MySQL 8 en CI: tras bajar, el esquema queda idéntico al de la 001 (comparación de `SHOW CREATE TABLE`), y se prueban 8 restricciones |
| Cliente del contrato en la app | `lib/messaging/chat_api.dart` | Contra un servidor HTTP local en las pruebas. Sin servidor real, la app muestra "sin servidor" |

---

## 1. Auditoría de lo que existe

| Componente | Estado | Consecuencia para Chat |
|---|---|---|
| `servidor/spam_api.php` | Un solo archivo PHP con PDO y sentencias preparadas | Sirve como referencia de estilo, pero **no se reutiliza su autenticación** (ver la fila siguiente) |
| Autenticación del antispam | Clave compartida (`API_CLAVE`) que viaja en cada petición y está incluida en la app | Cualquiera que extraiga la clave del APK puede llamar al API. **No vale para Chat**: Chat necesita una identidad por usuario y sesiones por dispositivo |
| Secretos | Constantes en el propio PHP (`DB_PASS`, `API_CLAVE`) | En Chat los secretos van fuera del directorio público y del repositorio (§9) |
| Hosting | PHP + MySQL compartido, sin WebSocket garantizado | La sincronización usa *long-polling* (≤ 25 s) en lugar de WebSocket (§6) |
| Cliente Chat en la app | Contrato v1 parcial (conversaciones, mensajes, recibos), cola de pendientes, idempotencia | Faltan el inicio de sesión, el almacenamiento seguro del token, `/v1/sync` y el registro push |

## 2. Componentes

```
App NEXLIA ──HTTPS──▶ API PHP /v1/* ──PDO──▶ MySQL (tablas chat_*)
     ▲                     │
     │                     ├──▶ Proveedor de SMS para OTP (externo, de pago)
     └── aviso push ◀──────┴──▶ Firebase Cloud Messaging (externo, cuenta de servicio)
```

- **API:** PHP 8.2 o superior, sin framework obligatorio. Un enrutador mínimo, PDO con sentencias preparadas y respuestas JSON.
- **Base de datos:** MySQL 8 con las migraciones 001 y 002.
- **Tareas programadas** (cron): limpieza de retos OTP caducados y de ventanas de límites, y caducidad de sesiones.
- **Dependencias externas** (no se pueden implementar sin cuenta ni credenciales):
  - proveedor de OTP por SMS;
  - Firebase (FCM);
  - dominio con TLS.

## 3. Identidad y autenticación

### 3.1 Registro e inicio de sesión (el mismo flujo)

1. **Pedir código.** La app envía `POST /v1/auth/otp/request {phone, purpose: "login"}`.
   - El servidor valida el formato E.164, aplica los límites (§8) y crea un registro en `chat_otp_challenges`. Guarda `code_hash = HMAC-SHA256(código, OTP_PEPPER)`, con caducidad de 5 minutos y un máximo de 5 intentos.
   - Envía el código por el proveedor de SMS.
   - Responde siempre `202`, para no revelar qué números tienen cuenta.
2. **Verificar.** La app envía `POST /v1/auth/otp/verify {challengeId, code, device}`.
   - El servidor compara en tiempo constante (`hash_equals`) y suma un intento.
   - Si el código es correcto, marca `consumed_at`, crea la cuenta si no existía (`isNew: true`) y abre una sesión en `chat_devices`.
3. **Respuesta:**
   - `accessToken`: 256 bits aleatorios, base64url, válido 1 hora.
   - `refreshToken`: 256 bits, válido 60 días, rota en cada uso.
   - El servidor guarda **solo** `SHA-256(token)`, nunca el token.

### 3.2 Sesiones y rotación

- **Renovar.** `POST /v1/auth/refresh` invalida el token de renovación usado y entrega uno nuevo de la misma `refresh_family`.
- **Reutilización = posible robo.** Si llega un token ya rotado, se revoca toda la familia y se registra `refresh_reuse` en `chat_security_events`.
- **Cerrar sesiones.** `POST /v1/auth/logout` cierra la sesión del dispositivo actual. `DELETE /v1/devices/{id}` cierra otra sesión propia.

### 3.3 Recuperación segura de la cuenta

- **Teléfono perdido o app reinstalada:** basta con iniciar sesión con OTP en el mismo número. Desde el dispositivo nuevo se pueden cerrar las demás sesiones (`GET /v1/devices` y `DELETE`).
- **Cambio de número:** con una sesión abierta, se pide OTP al número nuevo (`purpose: "change_phone"`) y se confirma con `POST /v1/me/phone`. Las demás sesiones se cierran.
- **Número reciclado por el operador:** riesgo propio de cualquier identidad por teléfono. Quien reciba el número podría entrar en la cuenta. **Decisión pendiente:** añadir un PIN opcional de cuenta, que pediría `otp/verify` cuando exista. Se documenta y no se implementa todavía.

### 3.4 En la app

- **Guardar los tokens con cifrado.** Hoy la app guarda sus preferencias en texto plano y no hay sesiones. Los tokens se guardarán cifrados con una clave AES-GCM del **Android Keystore**, en Kotlin, a través del canal nativo. No necesita dependencias Dart nuevas.
- **No incluir secretos en el APK.** La app solo conoce la URL del servidor (`NEXLIA_CHAT_URL`).

## 4. Conversaciones individuales

- **Iniciar una conversación.** El usuario **escribe el número** de la otra persona: `POST /v1/conversations {peerPhone}`.
  - No se sube la agenda.
  - Hacer "descubrimiento de contactos" exigiría consentimiento expreso y una protección real: los hashes de números se pueden revertir por fuerza bruta.
- **Una sola conversación directa por par.** `direct_key = SHA-256("idMenor:idMayor")` es único. Si ya existe, la API responde `200` con la existente.
- **Respuesta `404` sin distinguir casos.** No existe, no tiene cuenta o te bloqueó dan la misma respuesta, para no revelar datos.

## 5. Envío, recepción, estados y reintentos

| Paso | Regla |
|---|---|
| Enviar | `POST /v1/conversations/{id}/messages` con `Idempotency-Key = clientId` y cuerpo `{clientId, text}` |
| Idempotencia | `UNIQUE (sender_id, client_id)`. Si se repite, responde `200` con el mensaje ya guardado y no lo duplica (probado en CI) |
| Autorización | El remitente debe ser miembro de la conversación y no estar bloqueado por el otro miembro (`403`) |
| Validación | Texto UTF-8 de 1 a 4000 caracteres, sin caracteres de control salvo `\n`, recortado en los extremos. `clientId` con el formato `^[A-Za-z0-9_-]{8,64}$` e igual a la cabecera (`422` si no) |
| Entregado | El dispositivo receptor, al recibir por `/v1/sync`, envía `receipts {kind: delivered}`. El servidor solo **avanza** `last_delivered_message_id` |
| Leído | Al abrir la conversación, `receipts {kind: read}` hasta el último mensaje recibido. Solo avanza `last_read_message_id` |
| Estado de un mensaje propio | Se calcula con los cursores del otro miembro: `sent`, `delivered` o `read` |
| Pendientes y reintentos | Ya implementados en la app (`ChatRepository`). Un error de red, `5xx` o `429` deja el mensaje pendiente y no adelanta los siguientes. `400`, `403`, `404` o `422` lo marcan como fallido y aparece "Reintentar". `401` renueva la sesión |
| Orden | Por `chat_messages.id` (autoincremental). La app ordena por fecha de creación local hasta recibir el id del servidor |

## 6. Sincronización

- `GET /v1/sync?since=<cursor>&wait=25` devuelve mensajes, recibos y conversaciones cambiados desde el cursor. Si no hay cambios, mantiene la petición abierta hasta 25 s (*long-polling*, compatible con PHP compartido).
- El cursor es opaco: codifica los últimos ids vistos.
- `410` significa que el cursor es demasiado antiguo: la app recarga las conversaciones y el historial reciente.
- La app sincroniza:
  - al abrir;
  - en primer plano, con *long-polling*;
  - al recibir un aviso push.

  No sincroniza en segundo plano continuo.

## 7. Notificaciones push

- El dispositivo registra su token: `PUT /v1/devices/current/push {provider: "fcm", token}`.
- Los avisos son **solo de datos**, `{"t":"sync"}`, **sin el texto del mensaje** ni el remitente. La app sincroniza y genera la notificación local.
- **Requisitos externos:**
  - proyecto de Firebase y su archivo de configuración en la app;
  - cuenta de servicio en el servidor, como secreto;
  - dependencia `firebase_messaging` en Flutter. Será **la primera dependencia nueva de Chat**, y se decidirá en su fase.
- Si el token es inválido (FCM `UNREGISTERED`), se borra de `chat_push_endpoints`.

## 8. Protección contra abuso y spam

| Control | Límite inicial | Dónde |
|---|---|---|
| Pedir OTP | 3 por número cada 15 min y 10 por IP cada hora | `chat_rate_limits` |
| Verificar OTP | 5 intentos por reto, y bloqueo del número 1 h tras 3 retos agotados | `chat_otp_challenges` |
| Enviar mensajes | 30 por minuto y 1000 por día por usuario | `chat_rate_limits` |
| Conversaciones nuevas | 20 al día; 5 si la cuenta tiene menos de 24 h | `chat_rate_limits` y `chat_users.created_at` |
| Bloquear | Inmediato. La persona bloqueada no puede escribir (`403`) ni abrir conversación (`404`) | `chat_blocks` |
| Reportar | Un reporte por mensaje y usuario. Al reportar se bloquea por defecto | `chat_reports` |
| Revisión | Si una cuenta acumula reportes de 3 usuarios distintos en 24 h, queda limitada a sus conversaciones existentes hasta que alguien la revise | Tarea programada |
| Registro | Inicio de sesión, OTP fallidos, reutilización de tokens y cambios de número, sin contenido de mensajes y con la IP como hash | `chat_security_events` |

- **Sin analizar contenido.** No se analizan los mensajes con IA ni de ninguna otra forma. El antispam de Chat se basa en frecuencia, antigüedad y reportes.
- **Separado del antispam de llamadas.** No se mezcla con la base de spam de llamadas (`spam_*`).

## 9. Seguridad del servidor

- **Transporte:** solo HTTPS, con HSTS. La app rechaza `http://` (`HttpChatApi` lo exige).
- **Secretos fuera del repositorio:** `DB_*`, `OTP_PEPPER`, `IP_PEPPER`, la clave del proveedor de SMS y la cuenta de FCM van en variables de entorno o en un archivo fuera de la raíz pública. Nunca en Git ni en la app.
- **Identificadores públicos opacos** (ULID). Los ids internos nunca salen de la API.
- **Autorización en cada operación:**
  - pertenencia comprobada con `chat_conversation_members`;
  - nunca se confía en un id enviado por el cliente para decidir permisos;
  - "no existe" y "no autorizado" se responden igual (`404`).
- **Registros:** sin cuerpos de mensaje, sin tokens y sin códigos.
- **Borrado de cuenta:** borrado lógico (`deleted_at`), cierre de todas las sesiones y anonimización del nombre. Una cuenta con mensajes no se puede borrar físicamente; CI lo comprueba con la clave foránea. La retención concreta de mensajes **está pendiente de decidir** y debe constar en la política de privacidad.

## 10. Cifrado de extremo a extremo

**No está implementado y no se anuncia.** El servidor puede leer los mensajes, protegidos con TLS en tránsito y con los controles de acceso de la base de datos. Hacer E2EE de verdad exige:

- claves de identidad por dispositivo;
- prellaves publicadas;
- un protocolo auditado (por ejemplo, X3DH o PQXDH con Double Ratchet, mediante una biblioteca revisada y no implementación propia);
- verificación de claves entre usuarios;
- sesiones con varios dispositivos;
- pruebas criptográficas.

Es una fase propia. Hasta entonces, la app muestra "No disponible todavía".

## 11. Plan de implementación (Fase 2 propuesta)

1. **Requisitos externos.** Decidir el proveedor de OTP (costo por SMS en Perú) y el dominio con TLS.
2. **API base:** enrutador, configuración por entorno, migraciones 001 y 002, `/v1/auth/*` y `/v1/me`. Pruebas de integración en CI contra MySQL, con el proveedor de OTP simulado **solo en pruebas**.
3. **Mensajería:** conversaciones, mensajes, recibos y `/v1/sync`. Pruebas de autorización (no miembro, bloqueado) e idempotencia.
4. **App:**
   - pantalla de inicio de sesión con OTP;
   - tokens en Keystore;
   - `TokenProvider` real;
   - nueva conversación por número;
   - sincronización.
5. **Push** (FCM), cuando se decida la dependencia.
6. **Antiabuso:** límites, bloqueo y reporte en la interfaz, y tarea de revisión.
