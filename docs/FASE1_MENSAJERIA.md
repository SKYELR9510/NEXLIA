# NEXLIA — Fase 1: base de mensajería

**Rama:** `feature/fase-1-mensajeria` (desde `main` @ `6cca168`)\
**Referencia:** `docs/ARQUITECTURA_NEXLIA.md` §4 (canales separados), §5 (modelo), §7 (seguridad), §8 (roles)

Este documento define el diseño **antes** de implementar. Se actualizó al cerrar la fase y en la ronda de correcciones del PR #8 (accesibilidad, compatibilidad SMS y backend). Lo que está implementado y verificado se detalla en `docs/INFORME_FASE1.md`.

Documentos relacionados:

- `docs/CHAT_BACKEND.md`: arquitectura del servidor de NEXLIA Chat.
- `docs/GOOGLE_PLAY_SMS.md`: permisos SMS y Google Play.

---

## 1. Auditoría previa (estado de `main`)

| Área | Estado encontrado | Consecuencia para la Fase 1 |
|---|---|---|
| Navegación | `Home` con `IndexedStack` de 5 pestañas fijas (`main.dart`): Teléfono 0, Contactos 1, Recientes 2, Buzón 3, Más 4. Otros archivos usan los índices 0, 1, 2 y 4 | Mensajes ocupa el índice 3. **Buzón de voz** pasa a Más (misma pantalla `VoicemailPage`): no se pierde ninguna función ni cambia ningún otro índice |
| Widgets y tema | Tokens en `common.dart` (`bgColor`, `cardColor`, `fillColor`, `labelColor`, `secondaryColor`, `accentColor`, `brandGradient`) con claro y oscuro; componentes `Pill`, `ScreenTitle`, `SearchPill` y `Avatar` | La mensajería reutiliza esos tokens y componentes: hereda tema, color de acento y accesibilidad |
| Modelos | `Contact`, `CallEntry`, `SimInfo` en `native.dart`; `AppData` como estado global | Los modelos de mensajería van en `lib/messaging/`, separados de los de llamadas |
| Almacenamiento | Preferencias nativas (`getPref`/`setPref` → `SharedPreferences "ui"`); sin base de datos local | Chat local sobre una interfaz `KeyValueStore`, con la implementación nativa existente. Sin dependencias nuevas |
| Puente nativo | `MethodChannel('nexlia/phone')`; `PendingRequests` por código de solicitud (P0) | Lectura de SMS y su permiso por el mismo canal, con un código de solicitud propio |
| SIM | `SimAccounts` (Telecom) para llamadas | Los SMS usan `subscription_id`; la etiqueta sale de `SubscriptionManager` (necesita `READ_PHONE_STATE`, ya concedido) |
| Backend | Solo `servidor/spam_api.php` + `schema.sql`. Clave compartida, sin cuentas, sin sesiones, sin TLS propio | **No hay base segura para Chat.** Falta identidad (registro y verificación), sesiones, despliegue con TLS y push |
| Permisos | Llamadas, contactos e internet. Ningún permiso SMS | Se añade solo `READ_SMS`, pedido en contexto |

## 2. Canales y separación (no negociable)

```
            ┌──────────────── Interfaz ─────────────────┐
            │  Bandeja unificada (solo vista)           │
            │  InboxItem { channel: chat | sms, ... }   │
            └───────────────┬───────────────┬───────────┘
                            │               │
            ┌───────────────▼──┐        ┌───▼──────────────────┐
            │ ChatRepository   │        │ SmsRepository        │
            │ (NEXLIA Chat)    │        │ (solo lectura)       │
            ├──────────────────┤        ├──────────────────────┤
            │ ChatStore local  │        │ SmsSource nativo     │
            │ (clave propia)   │        │ Telephony.Sms (Android)│
            │ ChatApi (HTTPS)  │        │ NEXLIA no copia SMS  │
            └──────────────────┘        └──────────────────────┘
```

- **Almacenamiento:** Chat guarda en la clave `chat.store.v1`. Los SMS **no se guardan** en NEXLIA: se leen del proveedor de Android cada vez.
- **Backend:** las tablas de Chat (`chat_*`) son independientes de las de spam y nunca contienen SMS.
- **Bandeja unificada:** solo combina vistas (`InboxItem`). Cada fila conserva su canal y lo muestra con una insignia y un color.
- **Sin cambio de canal oculto:** no hay paso de Chat a SMS. Desde un hilo SMS, "Responder" abre la app de SMS del sistema con una acción explícita del usuario. Desde Chat nunca se envía un SMS.

## 3. Entidades (cliente)

### NEXLIA Chat (`lib/messaging/models.dart`)
| Entidad | Campos |
|---|---|
| `ChatUser` | `id`, `displayName` |
| `ChatConversation` | `id`, `peer: ChatUser`, `updatedAt` (UTC), `unreadCount`, `isDemo` |
| `ChatMessage` | `clientId` (idempotencia), `serverId?`, `conversationId`, `fromMe`, `text`, `createdAt` (UTC), `status`, `attempts`, `lastError?` |
| `ChatMessageStatus` | `pending`, `sent`, `delivered`, `read`, `failed` |
| `ChatConnection` | `notConfigured`, `offline`, `online` |

Transiciones de estado de un mensaje propio:

```
pending ──envío OK──▶ sent ──recibo──▶ delivered ──recibo──▶ read
   │  ▲
   │  └─ error de red / 5xx / 429: sigue pending (attempts+1), se reintenta
   └──── 4xx definitivo (400/403/404/422): failed ──"Reintentar"──▶ pending
```

`delivered` y `read` están modelados y se pintan en la interfaz. Solo cambiarán cuando el servidor envíe recibos (sección 6).

### SMS (`lib/messaging/models.dart`)
| Entidad | Campos |
|---|---|
| `SmsThread` | `threadId`, `address`, `snippet`, `date`, `unreadCount`, `subId` |
| `SmsMessage` | `id`, `threadId`, `address`, `body`, `date`, `box` (recibido, enviado, borrador, pendiente, fallido), `read`, `subId` |
| `SmsPermission` | `granted`, `denied`, `unavailable` |

MMS: el modelo está preparado (`SmsMessage.isMms`), pero la Fase 1 **no lee** MMS (otro proveedor, `content://mms`).

## 4. Repositorios

| Repositorio | Responsabilidad | Depende de |
|---|---|---|
| `ChatRepository` | Conversaciones y mensajes, cola de pendientes (*outbox*), reintentos, estado de conexión, no leídos, datos de prueba | `ChatStore` (persistencia), `ChatApi` (red), reloj e ids inyectables |
| `ChatApi` | Contrato HTTP. Implementaciones: `HttpChatApi` (`dart:io`, sin dependencias nuevas) y `UnconfiguredChatApi` (sin servidor) | `ChatConfig` (URL), `TokenProvider` (sesión) |
| `SmsRepository` | Permiso, hilos y mensajes **de solo lectura**; etiquetas de SIM | `SmsSource` (nativo: `SmsReader.kt`) |
| `buildInbox()` | Función pura: combina, filtra (Todos, NEXLIA Chat, SMS), busca y ordena | Las dos listas anteriores |

La interfaz no llama a `Native` directamente desde la mensajería: todo pasa por repositorios testeables (§3 de la arquitectura).

## 5. Contrato de API (NEXLIA Chat v1)

JSON sobre HTTPS. Autenticación `Authorization: Bearer <token de sesión>`. Fechas en ISO-8601 UTC.

| Método y ruta | Cuerpo | Respuesta | Cliente |
|---|---|---|---|
| `GET /v1/conversations` | — | `200 {conversations:[{id, peer:{id,displayName}, updatedAt, unreadCount}]}` | Implementado |
| `GET /v1/conversations/{id}/messages?before=&limit=` | — | `200 {messages:[{id, clientId, senderId, text, createdAt, status}]}` | Implementado |
| `POST /v1/conversations/{id}/messages` + cabecera `Idempotency-Key: <clientId>` | `{clientId, text}` | `201 {message}`; si el `clientId` ya existía, `200` con el mismo mensaje (idempotente) | Implementado |
| `POST /v1/conversations/{id}/receipts` | `{upToMessageId, kind: delivered\|read}` | `204` | Implementado |
| `POST /v1/conversations` | `{peerUserId}` | `201 {conversation}` | Pendiente (requiere directorio de usuarios) |
| `POST /v1/devices/push` | `{platform:"android", token}` | `204` | Pendiente (requiere proveedor push) |
| `POST /v1/auth/*` | Por definir | — | **Decisión pendiente** (§7) |

Errores (los traduce `HttpChatApi`):

| Respuesta | Error en el cliente | Efecto |
|---|---|---|
| Sin red, *timeout*, conexión rechazada | `ChatNetworkError` | El mensaje sigue pendiente; estado `offline` |
| 401 | `ChatAuthError` | Pendiente; requiere iniciar sesión |
| 400, 403, 404, 422 | `ChatRejectedError` | `failed` |
| 429, 5xx | `ChatServerError` | Pendiente y se reintenta |

**Autorización en el servidor** (obligatoria al implementarlo): cada operación debe comprobar que el usuario es miembro de la conversación. Nunca se confía en ids enviados por el cliente para decidir permisos.

## 6. Sincronización y funcionamiento sin conexión

- **Local primero:** escribir un mensaje lo guarda al instante como `pending`, con un `clientId` único, y lo pinta con un reloj.
- **Cola de pendientes:** `flushOutbox()` envía los pendientes en orden de creación, con `Idempotency-Key = clientId`. Si un envío se repite, el servidor devuelve el mismo mensaje y no se duplica.
- **Reintentos:** ante un error de red o 5xx se detiene la cola (no se adelantan mensajes) y queda `attempts+1`. Se reintenta al abrir la pestaña Mensajes por primera vez en la sesión, al enviar otro mensaje o al tocar "Reintentar" en un mensaje fallido. Sin servidor configurado, la cola no intenta nada y lo dice en la interfaz.
- **Persistencia:** la conversación, los mensajes y la cola se guardan tras cada cambio y se restauran al abrir la app.
- **Recibos:** al abrir una conversación se ponen a 0 los no leídos y, con servidor, se envía `read` hasta el último mensaje.
- **Tiempo real:** fuera de esta fase. Opciones a evaluar: WebSocket o *long-polling* compatibles con el hosting PHP. Las notificaciones push solo avisarán; no serán la fuente de los mensajes.
- **SMS:** el proveedor de Android es la fuente de verdad. NEXLIA solo lee, sin caché propia.

## 7. Seguridad y privacidad

| Requisito | Fase 1 |
|---|---|
| Cifrado de extremo a extremo | **No implementado y no se anuncia.** Más > Mensajes lo muestra como "No disponible todavía" |
| Contraseñas y secretos en el cliente | Ninguno. `TokenProvider` devuelve `null` porque no hay sesiones. El futuro token de sesión deberá guardarse en almacenamiento seguro (Keystore), no en preferencias |
| Leer SMS | Hacen falta **dos** condiciones: el permiso `READ_SMS` de Android **y** el consentimiento dado en NEXLIA (botón de la tarjeta de SMS en la pestaña Mensajes, o el interruptor de Más > Mensajes), guardado en `sms.consent.v1`. El permiso solo no basta: la validación en emulador mostró que Android concede `READ_SMS` automáticamente a la app de Teléfono predeterminada (`GRANTED_BY_ROLE`). Sin las dos condiciones no se llama a la lectura. Se puede desactivar en Más > Mensajes |
| Leer contactos | Se reutilizan los nombres ya cargados por la app (permiso existente); nada se envía a un servidor |
| Enviar mensajes | Siempre por acción del usuario. Sin envíos automáticos. Sin paso de Chat a SMS |
| IA | No se analiza ninguna conversación |
| Datos de prueba | Activables en Más > Mensajes; se marcan con la etiqueta **PRUEBA** en cada fila y conversación y no se mezclan con datos reales |
| Backend | Pendiente de decidir: verificación de identidad (OTP por SMS, con proveedor externo y su costo), sesiones revocables, TLS, límites de frecuencia, retención y borrado |

## 8. Migraciones MySQL (preparadas, no desplegadas)

`servidor/chat/migraciones/001_chat_base.up.sql` y `.down.sql`, independientes de las tablas de spam:

| Tabla | Propósito |
|---|---|
| `chat_users` | Cuenta NEXLIA (nombre visible, estado). Sin contraseñas: el método de autenticación está pendiente |
| `chat_devices` | Dispositivos y sesiones (`token_hash`, nunca el token en claro), revocables |
| `chat_conversations` | Conversación (`kind = 'direct'`; grupos más adelante) |
| `chat_conversation_members` | Pertenencia: base de la autorización |
| `chat_messages` | Mensajes; `UNIQUE (sender_id, client_id)` para la idempotencia |
| `chat_message_receipts` | Recibos de entrega y lectura por miembro |
| `chat_push_endpoints` | Tokens push por dispositivo |

`servidor/chat/migraciones/002_chat_identidad_y_abuso.up.sql` y `.down.sql` añaden:

- **Identidad por teléfono verificado:** `chat_users.phone_e164`, único.
- **Sesiones con token de renovación rotatorio:** en `chat_devices`, solo hashes y con familia de rotación.
- **Retos OTP:** `chat_otp_challenges`, con el código como HMAC.
- **Conversación directa única por par:** `direct_key`.
- **Cursores de entrega y lectura por miembro.**
- **Protección contra abuso:** `chat_rate_limits`, `chat_blocks` y `chat_reports`.
- **Eventos de seguridad:** `chat_security_events`.

Reglas:

- **Reversible:** cada `down` deshace solo su migración. En CI (MySQL 8), tras bajar la 002 el esquema queda idéntico al de la 001 (se comparan los `SHOW CREATE TABLE`). Se prueban 8 restricciones y, al final, el esquema de spam queda intacto.
- **Contrato:** `servidor/chat/openapi.yaml` (OpenAPI 3.0.3), validado en CI.
- **Fuera de alcance:** los endpoints PHP de Chat no se implementan. Sin proveedor de OTP ni dominio con TLS no habría un backend real, y simularlo está excluido. El diseño completo está en `docs/CHAT_BACKEND.md`.

## 9. Permisos y roles Android

| Cambio | Justificación |
|---|---|
| `READ_SMS` (nuevo) | Bandeja SMS de solo lectura. Se pide en contexto si falta. Al ser NEXLIA la app de Teléfono predeterminada, Android lo concede con el rol (verificado en API 29 y 34); por eso la lectura además exige el consentimiento dentro de la app (§7) |
| Rol SMS predeterminado | **No se solicita.** Exige `SMS_DELIVER`, `WAP_PUSH_DELIVER`, `RESPOND_VIA_MESSAGE` y escribir cada SMS recibido; pedirlo sin implementarlo completo rompería la recepción de SMS y "Responder con mensaje" (auditoría P0, §5) |
| `SEND_SMS`, `RECEIVE_SMS`, `RECEIVE_MMS` | No se añaden en esta fase |

Política de Google Play: el gestor de Teléfono predeterminado **no** puede usar `READ_SMS`. La distribución actual es por APK. Antes de publicar en Play hay que completar el rol SMS o publicar una variante sin `READ_SMS`. Análisis completo en `docs/GOOGLE_PLAY_SMS.md`.

**Disponibilidad de SMS:** se considera que el dispositivo tiene SMS si declara `FEATURE_TELEPHONY` o `FEATURE_TELEPHONY_MESSAGING`. Exigir solo la segunda (API 33+) dejaba sin SMS al emulador de Android 13 y 14, que no la declara; lo detectó la matriz de emuladores y está corregido.

## 10. Interfaz

- **Pestaña Mensajes (índice 3):** título con el total de no leídos, buscador, filtros **Todos · NEXLIA Chat · SMS**, aviso del estado real de Chat, tarjeta de permiso SMS y lista de conversaciones.
- **Fila:** avatar con un distintivo de canal, nombre, hora, fragmento, contador de no leídos, reloj si hay pendientes, aviso rojo si hay un mensaje no enviado, y etiquetas **Chat** (color de marca) o **SMS** (verde), **PRUEBA** y la SIM cuando hay dos.
- **Conversación de Chat:** burbujas, estado de cada mensaje propio con icono y texto (Pendiente, Enviado, Entregado, Leído, No enviado), botón "Reintentar" en los fallidos reales y caja de redacción. Encima, un aviso si la conversación es de prueba, si no hay servidor o si no hay conexión.
- **Hilo SMS:** solo lectura, SIM por mensaje, estado de bandeja (borrador, en cola, no enviado) y botón "Responder en la app de SMS". No hay caja de redacción.
- **Más > Mensajes:** estado de cada canal (servidor, conexión, cifrado "No disponible todavía", permiso SMS) e interruptor de conversaciones de prueba.
- **Más > Buzón de voz:** la misma pantalla que antes estaba en la pestaña 3.
- **Estados vacíos** por filtro, permiso SMS denegado, Chat sin servidor y búsqueda sin resultados.
- Tema claro y oscuro con los tokens existentes, más una paleta de mensajería con contraste AA (§11).

## 11. Accesibilidad

| Requisito | Implementación (`lib/messaging/a11y.dart`, `palette.dart`) | Verificación |
|---|---|---|
| Texto y acciones separados | `InfoBlock` (nodo de texto, nunca botón) y `ActionButton`/`Tappable` (nodo de botón con su etiqueta exacta). Antes la tarjeta de SMS completa se leía como un único botón | Pruebas de semántica y `uiautomator` en API 29 a 35 |
| Etiquetas y estado | Filtros: botón, seleccionado, grupo excluyente y pista. Filas: nombre, canal, prueba, SIM, no leídos, pendientes, hora y fragmento. Mensajes: remitente, hora, texto y estado. Interruptores unidos a su texto (`MergeSemantics`) | Pruebas `accesibilidad_test.dart` y `uiautomator` |
| Teclado | `FocusableActionDetector`: Tab para moverse, Intro o Espacio para activar, borde de foco visible | Pruebas con eventos de teclado |
| Tamaño táctil | Mínimo 48 × 48 en filas, filtros, botones y buscador | `androidTapTargetGuideline` en la bandeja; `iOSTapTargetGuideline` (44) en las pantallas con la barra de Cupertino |
| Contraste | Fondos sólidos que se oscurecen hasta 4,5:1 con texto blanco para cualquier acento (`solidFor`), tintas propias para etiquetas y tintes de aviso al 8 % | `paleta_test.dart`: 4 acentos × 2 temas. `textContrastGuideline` en la bandeja, la conversación y el hilo, en claro y oscuro |
| Texto grande | El canal sale de la barra de navegación (no cabía al 200 %). El pie de las burbujas usa `Wrap` | Pantallas al 200 % sin desbordes, en claro y oscuro |

## 12. Matriz de compatibilidad Android

minSdk 29, targetSdk 36. Emuladores x86_64 `default` en CI, con una SIM simulada, NEXLIA como marcador predeterminado y 21 SMS de prueba.

| Comportamiento | Android 10 (29) | 12 (31) | 13 (33) | 14 (34) | 15 (35) | 16 (36) |
|---|---|---|---|---|---|---|
| `READ_SMS` concedido por el rol de Teléfono (`GRANTED_BY_ROLE`) | Sí | Sí | Sí | Sí | Sí | No probado |
| Sin consentimiento en la app no se lee nada | PASS | PASS | PASS | PASS | PASS | — |
| Tarjeta: texto y botón como nodos separados | PASS | PASS | PASS | PASS | PASS | — |
| SMS visibles tras confirmar | PASS | PASS | PASS | PASS | PASS | — |
| Hilo SMS y botón Responder accesibles | PASS | PASS | PASS | PASS | PASS | — |
| Permiso retirado (`pm revoke`): no se leen SMS y se explica | PASS | PASS | PASS | PASS | PASS | — |
| `FEATURE_TELEPHONY_MESSAGING` declarada (*) | — (existe desde API 33) | — | No | No | Sí | — |
| Sin cierres inesperados ni ANR | PASS | PASS | PASS | PASS | PASS | — |
| Regresión: llamada entrante con la pantalla de NEXLIA | PASS | PASS | PASS | PASS | PASS | — |
| Regresión: llamada saliente desde otra app | PASS | PASS | PASS | PASS | PASS | — |
| Ajustes restringidos para APK instalado desde archivo (API 33+) | — | — | No verificable (CI instala con `adb`) | Igual | Igual | Igual |
| Dos SIM, SIM retirada, fabricantes sin `sub_id` | No verificable en emulador (lógica cubierta por pruebas unitarias) | | | | | |

(*) Deducido de la ejecución con la comprobación anterior, que solo aceptaba esta característica: en API 33 y 34 la app mostraba «SMS no disponibles» y en API 35 no. Que esa característica varíe así de una versión a otra es el motivo de la corrección.

Resultados por versión y evidencias en `docs/INFORME_FASE1.md` §8.

## 13. Limitaciones conocidas

- **Solo SMS, solo lectura.** No hay MMS, envío desde NEXLIA ni rol SMS (§9).
- **Hilos.** Se forman con los 3000 SMS más recientes (`SCAN_LIMIT`), y cada hilo muestra sus 300 más recientes. Un hilo cuyo último SMS es más antiguo que esos 3000 no aparece. Se eligió así frente a `content://mms-sms/conversations`, que se comporta distinto según el fabricante.
- **SIM.** Android solo informa las SIM **activas**. Un SMS de una SIM retirada o desactivada, sin `sub_id` o de un teléfono sin `READ_PHONE_STATE` se muestra como «SIM no identificada» en teléfonos de dos ranuras. En teléfonos de una ranura no se muestra etiqueta. No se ha probado con dos SIM reales.
- **Google Play.** Esta versión no es publicable en Play con `READ_SMS` (`docs/GOOGLE_PLAY_SMS.md`).
- **NEXLIA Chat.** No hay servidor, cuentas, sincronización ni push (`docs/CHAT_BACKEND.md`). Tampoco hay cifrado de extremo a extremo.
- **Lector de pantalla del buscador.** En `uiautomator` el campo no expone su etiqueta como texto o descripción (las pruebas de Flutter sí la ven). Falta comprobarlo con TalkBack en un teléfono.
- **Android 16 (API 36)** no está en la matriz de emuladores.
