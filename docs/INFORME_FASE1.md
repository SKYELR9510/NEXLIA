# Informe de la Fase 1: base de mensajería

**Rama:** `feature/fase-1-mensajeria`, creada desde `main` en `6cca168` ("Merge PR #7: integración P0").
**Diseño:** `docs/FASE1_MENSAJERIA.md`.
**Estado:** PR en borrador hacia `main`. No se ha fusionado ni se ha publicado ninguna Release.

Este informe separa tres cosas: lo implementado y verificado, lo preparado pero no activo, y lo que no existe todavía.

---

## 1. Resumen

| Canal | Qué funciona hoy | Qué no existe todavía |
|---|---|---|
| **SMS** | Bandeja de solo lectura con los SMS reales del teléfono, por hilos, con no leídos, búsqueda y SIM cuando hay dos. Responder abre la app de SMS del sistema | Envío desde NEXLIA, MMS y el rol de app de SMS predeterminada |
| **NEXLIA Chat** | Interfaz completa, almacenamiento local, cola de pendientes, estados de mensaje y cliente HTTP del contrato v1 (probado contra un servidor local) | **No hay servidor ni cuentas.** Sin ellos no se envía nada por Internet. La app lo dice en pantalla y no simula conexión |

Las conversaciones de demostración se activan en **Más > Mensajes**, llevan la etiqueta **PRUEBA** y nunca salen del teléfono.

## 2. Cambios en la app

**Navegación**
- La pestaña 3 pasa de **Buzón** a **Mensajes**. Las pestañas 0, 1, 2 y 4 no cambian.
- El **Buzón de voz** sigue disponible en **Más > Buzón de voz**, con la misma pantalla. Hay una prueba de regresión para ello.

**Pestaña Mensajes**
- Título con el total de no leídos.
- Buscador por nombre, texto o número.
- Filtros **Todos**, **NEXLIA Chat** y **SMS**.
- Aviso con el estado real de Chat: sin servidor o sin conexión.
- Tarjeta de SMS que explica para qué se piden y qué no se hace con ellos.

**Filas de la bandeja**
- Distintivo de canal en el avatar.
- Etiquetas **Chat** o **SMS**, **PRUEBA**, y la SIM cuando hay dos.
- Reloj si hay mensajes pendientes y aviso rojo si alguno no se envió.

**Conversación de Chat**
- Burbujas con el estado de cada mensaje: Pendiente, Enviado, Entregado, Leído o No enviado.
- "Reintentar" en los mensajes fallidos que no son de prueba.
- Caja de redacción.

**Hilo SMS**
- Solo lectura, con la SIM y el estado de bandeja de cada mensaje.
- Botón "Responder en la app de SMS".
- No hay caja de redacción.

**Más > Mensajes**
- Servidor de Chat: "No configurado".
- Cifrado de extremo a extremo: "No disponible todavía".
- Interruptor para mostrar o dejar de mostrar los SMS.
- Interruptor para las conversaciones de prueba.

**Otros**
- Tema claro y oscuro con los colores existentes.
- Etiquetas de accesibilidad en filas, mensajes y botones.

## 3. Arquitectura

```
lib/messaging/
  models.dart          Entidades separadas: ChatConversation/ChatMessage y SmsThread/SmsMessage
  store.dart           KeyValueStore (preferencias nativas o memoria en pruebas)
  chat_api.dart        Contrato v1: ChatApi, HttpChatApi (dart:io, HTTPS obligatorio), UnconfiguredChatApi
  chat_repository.dart Chat local primero: cola de pendientes, idempotencia por clientId, reintentos, recibos
  sms_repository.dart  SMS de solo lectura: permiso de Android + consentimiento en la app
  inbox.dart           Bandeja unificada: solo combina vistas; cada fila conserva su canal
  messages_page.dart, conversation_page.dart, messaging_settings_page.dart, messaging.dart
android/kotlin/SmsReader.kt      Lectura de Telephony.Sms (sub_id con alternativa si falta) y SIM activas
servidor/chat/migraciones/       001_chat_base.up.sql / .down.sql (tablas chat_*, no desplegadas)
```

- **Almacenamiento separado.** Chat guarda en la clave `chat.store.v1`. Los SMS no se copian; solo se guarda la clave `sms.consent.v1`, con el valor 1 o 0. En el servidor, las tablas `chat_*` son independientes de las de spam y no tienen ningún campo de SMS.
- **Sin dependencias nuevas.** `pubspec.yaml` y `pubspec.lock` no cambian. El cliente HTTP usa `dart:io`.
- **Puente nativo.** Mismo `MethodChannel`, con un código de solicitud propio para pedir el permiso (`REQ_SMS 1004`, gestionado por `PendingRequests` de la P0). Métodos nuevos:
  - `smsPermission`
  - `requestSmsPermission`
  - `getSmsThreads`
  - `getSmsMessages`
  - `getSimSubscriptions`
  - `openSettings('app')`

## 4. Hallazgo durante la validación y corrección

La primera validación en emulador mostró que **Android concede `READ_SMS` automáticamente a la app de Teléfono predeterminada**. `dumpsys` lo marca con el flag `GRANTED_BY_ROLE`, en API 29 y en API 34. La primera versión de la bandeja mostraba entonces los SMS sin que el usuario lo hubiera aceptado dentro de NEXLIA. Captura de esa versión: el SMS de prueba aparecía en la bandeja sin la tarjeta de consentimiento.

**Corrección (commit `ecccb54`).** La lectura exige dos condiciones:

1. El permiso de Android.
2. El consentimiento dado en NEXLIA, guardado en `sms.consent.v1`.

Si Android ya dio el permiso, la tarjeta lo explica ("Android ya permite a NEXLIA leer SMS por ser tu app de Teléfono, pero no se mostrarán hasta que lo confirmes") y el botón cambia a **"Mostrar mis SMS aquí"**. El usuario puede desactivarlo en Más > Mensajes.

Cubierto por cinco pruebas nuevas y verificado en los dos emuladores (§6.3).

## 5. Seguridad y privacidad

| Requisito | Cómo se cumple |
|---|---|
| No anunciar cifrado de extremo a extremo | No se anuncia. Más > Mensajes lo muestra como "No disponible todavía" |
| No guardar contraseñas ni secretos en el cliente | No hay ninguno. `ChatConfig` lee solo una URL de compilación (`NEXLIA_CHAT_URL`, vacía hoy). El proveedor de token devuelve `null`, y `HttpChatApi` falla con `ChatAuthError` antes de salir a la red |
| No leer contactos ni SMS sin permiso y consentimiento | SMS: permiso de Android y consentimiento en la app (§4). Contactos: solo se reutilizan los nombres que la app ya cargaba |
| No analizar conversaciones con IA | No hay análisis de ningún tipo |
| No enviar mensajes automáticamente | Chat solo crea mensajes al tocar Enviar. La cola reintenta únicamente mensajes que el usuario ya escribió. Las conversaciones de prueba nunca se envían |
| No pasar de Chat a SMS sin confirmación | No existe ese paso. NEXLIA no envía SMS: "Responder" abre la app de SMS del sistema |
| No usar datos reales en pruebas | Pruebas, capturas y emulador usan números ficticios (+51 900 000 0xx y 555xxxx del emulador) y textos marcados "prueba" |
| Permisos Android | Solo se añade `READ_SMS`. No se declaran `SEND_SMS`, `RECEIVE_SMS` ni `RECEIVE_MMS`, y no se pide el rol de SMS. Comprobado en el manifiesto final y en los emuladores |

## 6. Pruebas y resultados

Todas las ejecuciones son de GitHub Actions sobre esta rama. Flutter 3.50.0 y Dart 3.14.0.

### 6.1 Verificación de la rama (`verificacion.yml`)

| Paso | Resultado |
|---|---|
| `flutter pub get --enforce-lockfile` | OK (sin cambios de dependencias) |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **0 errores y 0 advertencias.** Avisos informativos: 38 en `main` y 43 en esta rama. Los 5 nuevos son `deprecated_member_use` por importar `package:flutter/cupertino.dart` en los archivos nuevos, igual que el resto de la app |
| `flutter test` | **82 pruebas correctas** y 4 omitidas (las de capturas, que solo corren en su job). En `main` había 35; esta rama añade 47 |
| `flutter build apk --debug` | OK |
| `./gradlew :app:testDebugUnitTest` | **28 pruebas, 0 fallos.** Las 23 existentes y 5 nuevas de `SmsReaderTest` |
| Permisos del manifiesto final | Los de `main` más `READ_SMS`. Nada más |
| `php -l servidor/*.php` | Sin errores (el PHP no cambia) |

### 6.2 Migraciones MySQL (job `migraciones-chat`, MySQL 8.0)

1. Se carga primero `servidor/schema.sql`, el esquema de spam existente.
2. **Subida:** se crean las 7 tablas `chat_*`.
3. **Idempotencia:** un segundo mensaje con el mismo `(sender_id, client_id)` se rechaza por `uq_chat_messages_idem`.
4. **Bajada:** quedan 0 tablas `chat_*` y siguen `spam_numeros` y `spam_reportes`.
5. **Nueva subida:** se vuelven a crear las 7 tablas.

### 6.3 Emulador (rama temporal `tmp/validacion-fase1`, APK debug de esta rama)

| Comprobación | API 29 (Android 10) | API 34 (Android 14) |
|---|---|---|
| Instala, NEXLIA queda como marcador predeterminado y la app arranca | PASS | PASS |
| No declara `SEND_SMS` ni `RECEIVE_SMS` | PASS | PASS |
| Sin consentimiento en la app no se muestra ningún SMS, aunque Android haya dado `READ_SMS` por el rol | PASS | PASS |
| Sin consentimiento se muestran la tarjeta y su botón | PASS | PASS |
| Tras tocar "Mostrar mis SMS aquí", el SMS de prueba aparece en la bandeja | PASS | PASS |
| La app de SMS predeterminada no cambia y NEXLIA no toma el rol SMS | PASS | PASS |
| **Regresión:** una llamada entrante abre la pantalla de NEXLIA, y la app sigue estable tras colgar | PASS | PASS |
| **Regresión:** una llamada saliente desde otra app se muestra en NEXLIA | PASS | PASS |
| La llamada saliente llega a la red del emulador | PASS | N/V (*) |
| Sin cierres inesperados en logcat | PASS | PASS |

(*) En API 34, `gsm list` no muestra las llamadas salientes. Ocurre igual con v1.0.13, como se documentó en la P0.

Las capturas del emulador están en `docs/capturas/fase1/emulador_api34_*.png`.

El script no pudo leer las coordenadas del botón desde el árbol de accesibilidad: la tarjeta completa se expone como un único nodo. El toque se hizo por posición y la captura confirma el resultado. Queda como mejora de accesibilidad separar el botón del texto de la tarjeta (§7).

### 6.4 Qué cubren las pruebas nuevas

| Requisito | Pruebas |
|---|---|
| Separación Chat/SMS | `inbox_test` (canal conservado y filtros), almacenamiento por claves distintas, tablas `chat_*` independientes |
| Bandeja y filtros | `inbox_test`, `messages_page_test` |
| Conversaciones | `messages_page_test`: abrir Chat y SMS, estados, envío de prueba que se queda local, no leídos a cero |
| Estados vacíos | `messages_page_test`: general, por filtro y búsqueda sin resultados |
| Mensajes pendientes | `chat_repository_test`: sin servidor, orden de la cola, `clientId` reutilizado al reintentar |
| Errores de red | `http_chat_api_test`: servidor local con 401, 422, 429, 500, JSON inválido, puerto cerrado y tiempo agotado. `chat_repository_test`: efecto de cada error en el mensaje |
| Persistencia | `chat_repository_test`: recarga desde el almacén y almacén dañado |
| Temas claro y oscuro | `messages_page_test`, y capturas en ambos temas |
| SMS y permisos | `sms_repository_test`: sin permiso, permiso por rol sin consentimiento, desactivar, canal nativo y errores. `SmsReaderTest`: agrupación, no leídos y SIM |
| Regresión de llamadas y doble SIM | Las 35 pruebas Dart y 23 Kotlin previas siguen pasando (selector de SIM, `placeCall`, `PendingRequests`, spam). Emulador: llamada entrante y saliente |

### 6.5 Capturas

Generadas por el job `capturas` con fuentes reales (Roboto y CupertinoIcons) y datos de prueba. Están en `docs/capturas/fase1/`:

- `1_bandeja_*`: bandeja con Chat de prueba y dos SMS ficticios en dos SIM.
- `2_chat_*`: conversación de prueba con todos los estados.
- `3_sms_*`: hilo SMS de solo lectura.
- `4_vacio_*`: primer uso sin mensajes y tarjeta de SMS.

Cada una existe en tema claro y oscuro. Las imágenes salen del registro del job en base64 con su SHA-256.

## 7. Limitaciones y dependencias externas

| Tema | Estado | Qué hace falta |
|---|---|---|
| Servidor de Chat | **No existe.** Solo están el contrato v1 y la migración, probada en CI | Endpoints PHP `/v1/*` con autorización por pertenencia (`chat_conversation_members`), TLS y límites de frecuencia |
| Identidad y sesiones | **Sin decidir** | Elegir el método: OTP por SMS (proveedor externo y su costo) u otro. Sesiones revocables y token guardado en Keystore, no en preferencias |
| Crear una conversación nueva | No disponible | Directorio de usuarios y `POST /v1/conversations` |
| Recibir mensajes y tiempo real | No disponible | WebSocket o *long-polling* compatible con el hosting, y push (FCM) para avisos. `chat_push_endpoints` está preparada |
| Cifrado de extremo a extremo | **No implementado** | Diseño de claves por dispositivo. No se anuncia |
| Envío de SMS y MMS, y rol SMS | No implementado | Implementar `SMS_DELIVER`, `WAP_PUSH_DELIVER` y `RESPOND_VIA_MESSAGE` completos antes de pedir el rol. Pedirlo antes rompería la recepción de SMS |
| Google Play | Riesgo | `READ_SMS` es un permiso restringido para apps que no son de SMS predeterminadas. Hoy se distribuye por APK. Antes de Play hay que completar el rol SMS o retirar la lectura |
| Doble SIM real | No verificable en emulador | Comprobar en un teléfono con dos SIM las etiquetas de SIM en SMS y el `sub_id` de cada fabricante |
| Accesibilidad de la tarjeta de SMS | Mejora pendiente | El lector de pantalla trata la tarjeta como un solo botón. Separar el texto del botón |
| Avisos del analizador | 38 heredados y 5 nuevos del mismo tipo | Migración a `package:cupertino_ui` y `withValues`, como tarea aparte para toda la app |

## 8. Ejecuciones de CI

Los identificadores de las ejecuciones finales y sus enlaces están en la descripción del PR. La rama temporal `tmp/validacion-fase1` solo contiene el flujo y el script del emulador sobre esta misma rama, y no se integra.
