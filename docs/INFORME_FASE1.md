# Informe de la Fase 1: base de mensajería

**Rama:** `feature/fase-1-mensajeria`, creada desde `main` en `6cca168` ("Merge PR #7: integración P0").
**Diseño:** `docs/FASE1_MENSAJERIA.md`.
**Backend de Chat:** `docs/CHAT_BACKEND.md`.
**Google Play:** `docs/GOOGLE_PLAY_SMS.md`.
**Estado:** PR #8 en borrador hacia `main`. No se ha fusionado ni se ha publicado ninguna Release.

Este informe separa tres cosas: lo implementado y verificado, lo preparado pero no activo, y lo que no existe todavía. Cubre la entrega inicial y la ronda de correcciones pedida en la revisión del PR #8 (§2).

---

## 1. Resumen

| Canal | Qué funciona hoy | Qué no existe todavía |
|---|---|---|
| **SMS** | Bandeja de solo lectura con los SMS reales del teléfono: hilos, no leídos, búsqueda y la SIM cuando el teléfono tiene dos ranuras («SIM no identificada» si Android no da un dato fiable). Responder abre la app de SMS del sistema. Verificado en Android 10, 12, 13, 14 y 15 (emulador) | Envío desde NEXLIA, MMS, rol de app de SMS y publicación en Google Play con `READ_SMS` |
| **NEXLIA Chat** | Interfaz, almacenamiento local, cola de pendientes, estados de mensaje y cliente HTTP del contrato v1 (probado contra un servidor local). Contrato completo en OpenAPI y migraciones 001 y 002 probadas en MySQL 8 | **No hay servidor ni cuentas.** No se envía nada por Internet. La app lo dice en pantalla y no simula conexión |

Las conversaciones de demostración se activan en **Más > Mensajes**, llevan la etiqueta **PRUEBA** y nunca salen del teléfono.

## 2. Ronda de correcciones del PR #8

| Pedido de la revisión | Qué se hizo | Evidencia |
|---|---|---|
| **1. Accesibilidad** | Texto y acciones en nodos separados (la tarjeta de SMS completa se leía antes como un solo botón). Etiquetas y estados en filtros, filas, mensajes, botones e interruptores. Teclado: Tab, Intro y Espacio, con borde de foco visible. Mínimo 48 × 48. Paleta de mensajería con contraste AA para los 4 acentos y los 2 temas. Pantallas que soportan texto al 200 % | 18 pruebas de accesibilidad, 10 de contraste, `uiautomator` en 5 versiones de Android y capturas (§7) |
| **2. Compatibilidad SMS y Android** | Errores del proveedor separados de "sin SMS", con aviso y "Reintentar". Permiso retirado en Ajustes detectado y explicado. «SIM no identificada» cuando el `sub_id` falta o no corresponde a una SIM activa. Ranuras leídas sin permisos. Dispositivos sin mensajería. Cargas que nunca leen en paralelo. Borradores sin número. Fragmentos limitados. Lectura siempre en segundo plano | 30 pruebas Dart del repositorio SMS, 11 pruebas Kotlin y matriz de emuladores con API 29, 31, 33, 34 y 35 (§6.3) |
| **3. Google Play** | Informe `docs/GOOGLE_PLAY_SMS.md`: la política de Google Play no permite `READ_SMS` a la app de Teléfono predeterminada. Requisitos del rol SMS, excepciones, ajustes restringidos de Android 13 y posteriores, verificación de desarrolladores y alternativas | Fuentes oficiales enlazadas |
| **4. Backend de Chat** | Auditoría del backend existente. Arquitectura completa en `docs/CHAT_BACKEND.md`: identidad por OTP, sesiones con rotación, recuperación, conversaciones, sincronización, recibos, push y antiabuso. Contrato `servidor/chat/openapi.yaml` (15 rutas, 21 operaciones). Migración 002 | OpenAPI validado en CI. Migración 002 subida y bajada con el esquema idéntico, y 8 restricciones probadas en MySQL 8 (§6.2) |
| **5. Pruebas** | `flutter analyze` con y sin opciones, Dart, Kotlin, compilación debug y **release**, permisos del manifiesto, `php -l`, `git diff --check`, migraciones y emuladores | §6 |
| **6. Documentación** | Diseño con accesibilidad, matriz de compatibilidad Android y limitaciones conocidas (§11 a §13 de `FASE1_MENSAJERIA.md`). Este informe | — |

### Fallos encontrados por las pruebas de esta ronda (ya corregidos)

1. **"SMS no disponibles" en Android 13 y 14.** Al endurecer la detección de dispositivos sin mensajería se exigió `FEATURE_TELEPHONY_MESSAGING`. Los emuladores de API 33 y 34 no la declaran aunque reciben SMS, así que la app ocultaba los SMS. Lo detectó la matriz de emuladores. **Corrección** (`ec7cb9b`): basta con `FEATURE_TELEPHONY` o con `FEATURE_TELEPHONY_MESSAGING`; si de verdad no hay proveedor, la consulta lo informa. Hay una prueba Kotlin.
2. **Contraste insuficiente.** Las pruebas de contraste detectaron:
   - el verde de SMS con texto blanco (2,6:1);
   - la etiqueta PRUEBA (1,9:1);
   - el rojo de "no enviado" (3,9:1);
   - el texto secundario sobre los avisos tintados (4,4:1).

   Se corrigieron con la paleta `palette.dart`.
3. **Buscador de 44 px y desbordes con texto grande.** El buscador no llegaba al mínimo de 48, y con texto al 200 % la etiqueta de canal no cabía en la barra de navegación. **Corrección:** buscador propio de 48 y canal en una franja bajo la barra.

### Hallazgo de la entrega inicial

Android concede `READ_SMS` automáticamente a la app de Teléfono predeterminada (`GRANTED_BY_ROLE`), como se confirma ahora en las 5 versiones probadas. Por eso la lectura exige además el consentimiento dentro de NEXLIA (`sms.consent.v1`, commit `ecccb54`).

## 3. Cambios en la app

- **Navegación:**
  - La pestaña 3 pasa de Buzón a **Mensajes**.
  - El Buzón de voz sigue en **Más > Buzón de voz**, con la misma pantalla y una prueba de regresión.
  - Las pestañas 0, 1, 2 y 4 no cambian.
- **Mensajes:**
  - Título con el total de no leídos.
  - Buscador.
  - Filtros Todos, NEXLIA Chat y SMS.
  - Aviso del estado real de Chat.
  - Tarjeta de SMS con tres textos: permiso pendiente, permiso ya dado por el rol o permiso retirado.
  - Aviso de error de lectura con "Reintentar".
  - Filas con canal, PRUEBA, SIM, no leídos, pendientes y fallidos.
- **Conversación de Chat:**
  - Franja de canal.
  - Estados de cada mensaje.
  - "Reintentar" en los fallidos reales.
  - Botón Enviar de 48.
- **Hilo SMS:**
  - Solo lectura.
  - SIM o «SIM no identificada» en cada mensaje.
  - Estado de bandeja.
  - Error de lectura con "Reintentar".
  - "Responder en la app de SMS".
- **Más > Mensajes:**
  - Estado del servidor de Chat.
  - Cifrado de extremo a extremo: "No disponible todavía".
  - Interruptor para mostrar los SMS.
  - Permiso de Android.
  - SIM detectadas (ranuras y activas).
  - Conversaciones de prueba.

## 4. Arquitectura

```
lib/messaging/
  models.dart            Entidades por canal; SmsSimInfo y simLabelFor (SIM no identificada); SmsReadException
  store.dart             KeyValueStore (preferencias nativas o memoria en pruebas)
  chat_api.dart          Contrato v1: HttpChatApi (dart:io, HTTPS obligatorio) y UnconfiguredChatApi
  chat_repository.dart   Chat local primero: cola de pendientes, idempotencia, reintentos, recibos
  sms_repository.dart    SMS de solo lectura: permiso + consentimiento, errores, cargas sin solaparse
  inbox.dart             Bandeja unificada (solo vistas)
  a11y.dart              Tappable, InfoBlock y ActionButton: nodos, teclado, foco y área táctil
  palette.dart           Colores con contraste comprobado (WCAG 2.1 AA)
  messages_page.dart, conversation_page.dart, messaging_settings_page.dart, messaging.dart
android/kotlin/SmsReader.kt   Telephony.Sms en segundo plano; códigos permission/provider/unavailable;
                              sub_id normalizado; ranuras sin permisos; disponibilidad de SMS
servidor/chat/openapi.yaml    Contrato completo de NEXLIA Chat (borrador, validado)
servidor/chat/migraciones/    001 (base) y 002 (identidad, sesiones, antiabuso), no desplegadas
```

- **Sin dependencias nuevas.** `pubspec.yaml` y `pubspec.lock` no cambian.
- **Permisos.** Los mismos que en la entrega inicial: los de `main` más `READ_SMS`. En esta ronda no se añadió ninguno.
- **Motor de llamadas y doble SIM sin cambios.** Esta ronda no modificó `call_screen`, `sim_choice`, `SimAccounts`, `placeCall` ni el selector. Las pruebas de regresión siguen pasando (§6).

## 5. Seguridad y privacidad

| Requisito | Cómo se cumple |
|---|---|
| No anunciar cifrado de extremo a extremo | No se anuncia. Más > Mensajes lo muestra como "No disponible todavía". `CHAT_BACKEND.md` §10 explica qué haría falta |
| No guardar contraseñas ni secretos en el cliente | No hay ninguno. La app solo conoce la URL (`NEXLIA_CHAT_URL`, vacía). El diseño guarda los tokens futuros cifrados con una clave del Android Keystore y en el servidor solo sus hashes |
| No leer contactos ni SMS sin permiso y consentimiento | SMS: permiso de Android y consentimiento en la app. Si el permiso se retira, no se lee (probado en el emulador con `pm revoke`). Contactos: solo los nombres que la app ya cargaba. El diseño de Chat **no sube la agenda** |
| No analizar conversaciones con IA | Sin análisis de ningún tipo. El antispam de Chat se basa en frecuencia, antigüedad y reportes |
| No enviar mensajes automáticamente | Chat solo envía al tocar Enviar. La cola reintenta solo mensajes que el usuario ya escribió. NEXLIA no envía SMS |
| No pasar de Chat a SMS sin confirmación | No existe ese paso |
| No usar datos reales en pruebas | Números ficticios (+51 900 000 0xx y 555xxxx del emulador) y textos "prueba". Las credenciales de MySQL en CI son de un contenedor efímero (`solo-ci`) |
| Sin secretos en el repositorio | El backend de Chat los define como variables de entorno fuera del directorio público (`CHAT_BACKEND.md` §9). La auditoría señala que el antispam actual guarda una clave compartida en la app y no se reutiliza para Chat |

## 6. Pruebas y resultados

### 6.1 Verificación de la rama (`verificacion.yml`)

Ejecución [43508116305](https://github.com/SKYELR9510/NEXLIA/actions/runs/43508116305), commit `76151f4`, el último que toca código o pruebas; los posteriores solo cambian documentos y capturas. Los mismos resultados se obtuvieron en `2d4da4c` (ejecución [43504208729](https://github.com/SKYELR9510/NEXLIA/actions/runs/43504208729)), que es el código validado en el emulador. Flutter 3.50.0 y Dart 3.14.0.

| Paso | Resultado |
|---|---|
| `flutter pub get --enforce-lockfile` | OK, sin cambios de dependencias |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | OK: **0 errores y 0 advertencias** |
| `flutter analyze` sin opciones | Código 1 por **57 avisos informativos**: 38 vienen de `main` y 19 son nuevos. De los nuevos, 9 se deben a importar `package:flutter/cupertino.dart`, que la app entera usa y cuyo reemplazo (`cupertino_ui`) sería una dependencia nueva; los otros 10, a usar en las pruebas `containsSemantics`, que funciona pero está marcado como obsoleto |
| `flutter test` | **129 correctas**: 35 de `main` y 94 nuevas. 7 omitidas, que son las de capturas y se ejecutan en su propio job |
| `flutter build apk --debug` | OK |
| `flutter build apk --release` | OK, 50,0 MB. `minSdk` 29 y `targetSdk` 36. **Firmado con la clave de depuración** porque CI no tiene la de producción, así que no es distribuible. No se publica |
| Kotlin `testDebugUnitTest` | **34 pruebas, 0 fallos**: `SmsReaderTest` 11, `PendingRequestsTest` 6, `SimAccountsTest` 5, `SimSelectionTest` 3, `SpamConcurrencyTest` 5 y `SpamEngineTest` 4 |
| Permisos del manifiesto final (debug y release) | `ACCESS_NETWORK_STATE`, `CALL_PHONE`, `INTERNET`, `POST_NOTIFICATIONS`, `READ_CALL_LOG`, `READ_CONTACTS`, `READ_PHONE_STATE`, **`READ_SMS`**, `USE_FULL_SCREEN_INTENT`, `VIBRATE`, `WAKE_LOCK`, `WRITE_CALL_LOG` y `WRITE_CONTACTS`. No hay `SEND_SMS`, `RECEIVE_SMS` ni `RECEIVE_MMS` |
| `php -l servidor/*.php` | Sin errores. `spam_api.php` no cambia |
| `git diff --check origin/main...HEAD` | Sin problemas |

### 6.2 Backend (job `migraciones-chat`, MySQL 8.0)

- **Pasos de la migración:**
  1. Se carga el esquema de spam existente.
  2. Subida de la **001**: 7 tablas `chat_*`.
  3. Subida de la **002**: 12 tablas.
  4. Bajada de la **002**: el esquema queda **idéntico** al de la 001 (comparando `SHOW CREATE TABLE`).
  5. Nueva subida de la 002: 12 tablas.
- **Restricciones probadas (8):**
  - un teléfono no puede tener dos cuentas;
  - no hay dos conversaciones directas del mismo par;
  - no se repite un `client_id` del mismo remitente;
  - no hay bloqueos duplicados;
  - no se repite el mismo reporte;
  - no se repite un token de renovación;
  - el contador de frecuencia funciona;
  - una cuenta con mensajes no se borra físicamente.
- **Bajada final:** se bajan la 002 y la 001; quedan 0 tablas `chat_*` y **las 2 tablas de spam intactas**.
- **Contrato:** `openapi-spec-validator` da `servidor/chat/openapi.yaml: OK` (15 rutas y 21 operaciones). Una prueba Dart comprueba que el cliente usa rutas del contrato.

### 6.3 Emulador (rama temporal `tmp/validacion-fase1`, APK debug de la rama)

Ejecución [43504205040](https://github.com/SKYELR9510/NEXLIA/actions/runs/43504205040), commit `d7550ac`, que es `2d4da4c` más el script de validación. El job de API 29 se repitió: en el primer intento uiautomator no pudo volcar la pantalla (archivo vacío) y todas las comprobaciones de interfaz fallaron a la vez. En el segundo intento pasó completo. Las dos salidas están en la ejecución.

Cada versión ejecutó 31 comprobaciones.

| Versión | PASS | FAIL | N/V | Detalle de N/V |
|---|---|---|---|---|
| Android 10 (API 29) | 25 | 0 | 6 | 4 de teléfono físico, buscador en uiautomator (\*) y recuento de SMS en el proveedor (16 de 21 al consultarlo; la app los mostró) |
| Android 12 (API 31) | 25 | 0 | 6 | 4 de teléfono físico, buscador (\*) y saliente en `gsm list` (\*\*) |
| Android 13 (API 33) | 25 | 0 | 6 | Igual que API 31 |
| Android 14 (API 34) | 25 | 0 | 6 | Igual que API 31 |
| Android 15 (API 35) | 25 | 0 | 6 | Igual que API 31 |

Comprobaciones que pasaron en las 5 versiones:

- **Instalación y SMS:**
  - instalación y rol de marcador;
  - `READ_SMS` por el rol (`GRANTED_BY_ROLE`, como información);
  - sin `SEND_SMS` ni `RECEIVE_SMS`;
  - sin consentimiento no se ve ningún SMS.
- **Accesibilidad:**
  - en la tarjeta, el botón es un nodo propio con su texto exacto y el texto informativo es otro nodo sin la acción;
  - filtros como botones con su estado de selección.
- **Uso:**
  - toque sobre el botón **localizado en el árbol de accesibilidad**, sin coordenadas fijas;
  - SMS visibles, el más reciente arriba;
  - fila SMS como botón con el canal en su etiqueta;
  - sin etiqueta de SIM con una sola ranura;
  - hilo con el botón Responder accesible y mensajes leídos como "Recibido, …".
- **Permiso retirado:** sin SMS visibles, tarjeta con la explicación y app estable.
- **Regresión de llamadas:** la entrante abre la pantalla de NEXLIA y la app sigue estable al colgar; la saliente desde otra app se muestra en NEXLIA.
- **Estabilidad:** sin cierres inesperados ni ANR.

(\*) En uiautomator el buscador no expone su etiqueta como texto ni como descripción. Las pruebas de Flutter sí ven la etiqueta. Falta comprobarlo con TalkBack en un teléfono.
(\*\*) En API 31 y posteriores, `gsm list` no muestra la llamada saliente. Con v1.0.13 ocurre igual (documentado en la P0).

### 6.4 Qué cubren las pruebas

| Requisito | Pruebas |
|---|---|
| Accesibilidad | `accesibilidad_test.dart`: nodos separados, etiquetas, estados, teclado (Tab, Intro, Espacio y foco visible), tamaños táctiles (`androidTapTargetGuideline`, `iOSTapTargetGuideline` y `labeledTapTargetGuideline`), contraste (`textContrastGuideline`) y texto al 200 %, en claro y oscuro |
| Contraste | `paleta_test.dart`: 4 acentos × 2 temas × 19 combinaciones de texto y fondo |
| SMS y Android | `sms_repository_test.dart`: etiquetas de SIM y «SIM no identificada» (9 pruebas), errores del proveedor, permiso retirado, dispositivo sin SMS, lecturas sin solaparse y canal nativo con sus códigos de error. `SmsReaderTest.kt`: agrupación, borradores sin número, fragmento, `sub_id`, clasificación de errores y disponibilidad de SMS |
| Chat | `chat_repository_test.dart` y `http_chat_api_test.dart` (servidor local: 401, 422, 429, 500, JSON inválido, puerto cerrado, tiempo agotado y contrato) |
| Regresión de llamadas y doble SIM | Las 35 pruebas Dart y 23 Kotlin de `main` siguen pasando. Emulador: llamada entrante y saliente en 5 versiones |

## 7. Capturas

En `docs/capturas/fase1/`.

**Interfaz.** Generadas en CI con fuentes reales y datos de prueba:

- `1_bandeja_*`: bandeja.
- `2_chat_*`: conversación de prueba.
- `3_sms_*`: hilo SMS.
- `4_vacio_*`: primer uso.
- `5_texto_grande_*`: texto al 160 %.
- `6_foco_teclado_*`: foco del teclado sobre una conversación.
- `7_lector_de_pantalla`: depurador de semántica de Flutter, con un recuadro por nodo. Se ve que la tarjeta de SMS tiene un nodo de texto y otro de botón (recuadro amarillo), separados. Las etiquetas salen como bloques porque el depurador usa la fuente de pruebas de Flutter; los textos exactos de cada nodo están en las pruebas de semántica y en las salidas de uiautomator del emulador (§6.3).

**Emulador Android 14:**

- `emulador_api34_1_sin_consentimiento`
- `emulador_api34_2_sms_visibles`
- `emulador_api34_3_hilo_sms`
- `emulador_api34_4_permiso_retirado`
- `emulador_api34_5_llamada_entrante`

Las imágenes salen del registro de cada job en base64, con su SHA-256 comprobado al extraerlas.

## 8. Limitaciones y dependencias externas

| Tema | Estado |
|---|---|
| Servidor de Chat | **No existe.** Diseño, contrato y migraciones listos. Faltan un proveedor de OTP (de pago), un dominio con TLS y la implementación PHP (`CHAT_BACKEND.md` §11) |
| Push | Requiere un proyecto de Firebase y la dependencia `firebase_messaging`, que sería la primera dependencia nueva. Pendiente de decisión |
| Cifrado de extremo a extremo | No implementado ni anunciado |
| SMS | Solo lectura. Sin MMS, sin envío y sin rol SMS. Hilos limitados a los 3000 SMS más recientes |
| Google Play | No publicable con `READ_SMS` como app de Teléfono. Hay que decidir entre una variante sin `READ_SMS` o la app de SMS completa (`GOOGLE_PLAY_SMS.md` §6) |
| Instalación desde archivo en Android 13 y posteriores | Los ajustes restringidos pueden pedir "Permitir ajustes restringidos" para los roles de Teléfono y SMS. **No verificable** en CI (instala con `adb`) |
| Dos SIM reales, SIM retirada o desactivada, fabricantes sin `sub_id` | **No verificable** en emulador. La lógica está cubierta por pruebas unitarias |
| TalkBack en un teléfono | No verificado. Sí lo están el árbol de accesibilidad (uiautomator) y las pruebas de semántica |
| Android 16 (API 36) | No está en la matriz de emuladores |

## 9. Plan de la siguiente fase (propuesta)

1. **Decisiones del producto:**
   - Google Play o APK, y con ello variante sin `READ_SMS` o app de SMS completa;
   - proveedor de OTP y su costo;
   - dominio con TLS;
   - retención de mensajes;
   - PIN opcional de cuenta.
2. **Backend de Chat (Fase 2):**
   - API PHP sobre las migraciones 001 y 002: `/v1/auth/*`, `/v1/me`, conversaciones, mensajes, recibos y `/v1/sync`;
   - pruebas de integración en CI contra MySQL, con OTP simulado solo en pruebas;
   - pruebas de autorización (no miembro, bloqueado) e idempotencia.
3. **App:**
   - inicio de sesión con OTP;
   - tokens cifrados con una clave del Android Keystore;
   - nueva conversación escribiendo el número;
   - sincronización con *long-polling*;
   - bloqueo y reporte en la interfaz.
4. **Push** con FCM, cuando se decida la dependencia.
5. **Validación en teléfonos físicos:**
   - dos SIM;
   - instalación desde archivo en Android 13 a 15;
   - TalkBack;
   - fabricantes (Samsung, Xiaomi, Motorola).
6. **Limpieza aparte de avisos del analizador** (migración a `cupertino_ui` y a `isSemantics`) en toda la app.
