# NEXLIA — Informe de integración P0

**Rama:** `integracion/p0` (creada desde `main` @ `808f61e`)\
**Fecha:** 12–13 de noviembre de 2026\
**Estado:** lista para revisión final. **No fusionada.**

---

## Resumen

- Los seis PR (#1–#6) se integraron en orden de dependencias, sin conflictos de texto. Ningún archivo arrastra una versión antigua: 52 de 54 son idénticos a la última versión de su PR, y los 2 combinados conservan íntegros los cambios de ambos lados.
- **Verificación automática:**
  - dependencias exactas desde `pubspec.lock`;
  - 35 pruebas Dart y 23 Kotlin sin fallos ni omisiones;
  - compilación debug y release correctas;
  - firma con la clave de producción;
  - permisos idénticos a la v1.0.13;
  - `php -l` y `git diff --check` limpios.
- **Avisos que quedan** (no bloquean, pero no se ocultan):
  - 38 avisos informativos del análisis estático; `flutter analyze` sin opciones termina con código 1 por ellos;
  - 15 de 17 archivos Dart no siguen el formato estándar.
- **Emuladores Android 10 y 14:** el APK se instala como actualización de la v1.0.13 conservando datos, queda como marcador, arranca, recibe llamadas y muestra llamadas iniciadas desde otras apps, sin cierres inesperados. Detalle y diferencias con el control en la sección 5.3.
- **Doble SIM:** validada por el propietario en teléfono físico sobre los PR #4 y #6. El emulador solo tiene una SIM, así que esa parte no se repitió aquí.

---

## 1. PR incorporados

| PR | Rama | Commit de cabeza | Base del PR | Depende de |
|---|---|---|---|---|
| #1 Arquitectura y hoja de ruta | `docs/arquitectura-plataforma` | `4f41302` | `main` | — |
| #2 Auditoría técnica y CI | `audit/fase-0` | `590de4e` | `docs/arquitectura-plataforma` | #1 |
| #3 Compilación reproducible | `chore/build-reproducible` | `8190b2c` | `audit/fase-0` | #2 |
| #4 Selector de SIM para Telecom | `fix/seleccion-sim` | `3c3eda8` | `audit/fase-0` | #2 |
| #5 Concurrencia y resultados nativos | `fix/resultados-nativos` | `dbbd10f` | `audit/fase-0` | #2 |
| #6 Selector previo de SIM y preferencias | `fix/selector-sim-previo` | `9fd0b12` | `fix/seleccion-sim` | #4 |

Comprobaciones previas:
- Las cabezas, bases y ancestros se leyeron de GitHub y de `git` antes de integrar.
- `main` no había cambiado desde que se crearon las ramas.
- Todas las ramas descienden de `main` @ `808f61e`.

## 2. Commits integrados

**Orden de integración:** #1 → #2 → #3 → #4 → #6 → #5. Cada PR entra con un merge propio (`--no-ff`) para que se pueda rastrear.

| Merge | Integra |
|---|---|
| `3280919` | PR #1 |
| `4e3a971` | PR #2 |
| `f75361b` | PR #3 |
| `88af9de` | PR #4 |
| `54594af` | PR #6 |
| `da63a46` | PR #5 |
| `e8adc9d` | Corrección de `git diff --check` (sección 6) |

**Commits de los PR** (8, cada uno una sola vez; se verificó que no hay mensajes ni contenidos duplicados):

| Commit | Mensaje |
|---|---|
| `4f41302` | docs: add NEXLIA platform architecture and integration roadmap |
| `61a2987` | Fase 0: pruebas de caracterización y verificación de CI sin publicar |
| `590de4e` | docs: informe de auditoría técnica de la Fase 0 |
| `e6188d1` | chore: proyecto Flutter versionado y compilación reproducible |
| `8190b2c` | ci: resumen de pruebas Kotlin en la verificación |
| `3c3eda8` | fix: selección de SIM cuando Telecom pide elegir cuenta |
| `9fd0b12` | fix: selector de SIM antes de iniciar la llamada |
| `dbbd10f` | fix: respuestas nativas por solicitud y estado concurrente del bloqueador |

## 3. Conflictos resueltos

**Conflictos de texto: ninguno.** Git combinó automáticamente dos archivos que tocaban dos PR paralelos. Se revisaron a mano y por comparación de cambios:

| Archivo | PR | Verificación |
|---|---|---|
| `android/kotlin/MainActivity.kt` | #6 (`placeCall` con `EXTRA_PHONE_ACCOUNT_HANDLE`, `selectPhoneAccount`, `getSimAccounts`, cuenta en el historial) y #5 (`PendingRequests` para rol, permisos y selector de archivos; `cancelled` al destruirse; permisos interrumpidos = `false`) | Las líneas añadidas y quitadas por cada PR están íntegras en el resultado. No se cruzan: #6 solo toca la rama `placeCall` y el historial; #5 solo las respuestas pendientes |
| `android/kotlin/CallService.kt` | #4 (texto de notificación "Elige una SIM para llamar") y #5 (`SpamEngine.screened.wasScreened`) | Igual: cambios íntegros, en zonas distintas |

Los archivos que pidió revisar expresamente quedan así:

| Archivo | PR que lo modificó | Estado en la integración |
|---|---|---|
| `CallManager.kt`, `SimAccounts.kt`, `lib/common.dart`, `lib/native.dart`, `lib/sim_choice.dart`, `lib/call_screen.dart`, `lib/more_page.dart` | #4 y #6 (cadena) | Idénticos a #6 |
| `Spam.kt`, `PendingRequests.kt`, `ScreenedRegistry.kt` | #5 | Idénticos a #5 |
| `android/app/build.gradle.kts`, `.github/workflows/apk.yml`, `.github/workflows/verificacion.yml` | #2 y #3 | Idénticos a #3 |

Los flujos temporales usados para los APK de prueba (`apk-pruebas.yml`, `prueba-firma.yml`, `validacion-p0.yml`) **no** están en la integración: solo existen en ramas `tmp/*`.

## 4. Archivos modificados

54 archivos: 36 añadidos, 12 modificados y 6 movidos sin cambios. En total, 3 449 líneas añadidas y 179 eliminadas, más este informe.

| Área | Archivos |
|---|---|
| Proyecto Flutter y Gradle (#3) | `pubspec.yaml`, `pubspec.lock`, `.metadata`, `analysis_options.yaml`, `.gitignore`, `android/.gitignore`, `android/build.gradle.kts`, `android/settings.gradle.kts`, `android/gradle.properties`, `android/gradle/wrapper/gradle-wrapper.properties`, `android/app/build.gradle.kts`, manifiestos `debug`/`profile`, temas y fondos de arranque |
| Movidos sin cambios (#3) | `android/AndroidManifest.xml` → `android/app/src/main/AndroidManifest.xml`; `android/res/mipmap-*` → `android/app/src/main/res/` |
| CI (#2, #3) | `.github/workflows/apk.yml` (publica solo si pasa la verificación), `.github/workflows/verificacion.yml` |
| Motor nativo (#4, #5, #6) | Modificados: `CallManager.kt`, `CallService.kt`, `MainActivity.kt`, `Spam.kt`. Nuevos: `SimAccounts.kt`, `PendingRequests.kt`, `ScreenedRegistry.kt` |
| Interfaz (#4, #6) | `lib/call_screen.dart`, `lib/common.dart`, `lib/more_page.dart`, `lib/native.dart`, `lib/recents_page.dart`, `lib/sim_choice.dart` (nuevo) |
| Pruebas | Dart: `test/canal_nativo_test.dart`, `formatos_test.dart`, `marcador_test.dart`, `numeros_test.dart`, `seleccion_sim_test.dart`, `selector_previo_test.dart`, `sim_choice_test.dart`. Kotlin: `android/test/` (5 clases) |
| Documentación | `docs/ARQUITECTURA_NEXLIA.md`, `docs/AUDITORIA_FASE0.md`, `docs/INFORME_INTEGRACION_P0.md`, `LEEME.md`, `instalar.ps1` |

- **Permisos Android:** sin cambios. El manifiesto fuente es el mismo, movido de ubicación, y el APK final tiene exactamente los permisos de la v1.0.13 (sección 5.2).
- **Llamadas entrantes:** no se modificó su gestión.

## 5. Pruebas ejecutadas y resultados

### 5.1 Verificación estándar — [ejecución 43353765651](https://github.com/SKYELR9510/NEXLIA/actions/runs/43353765651) sobre `e8adc9d`

| Comprobación | Resultado |
|---|---|
| Entorno | Flutter 3.50.0 stable, Dart 3.14.0, JDK 17, Gradle 9.5.0, PHP 8.5 |
| `flutter pub get --enforce-lockfile` | Correcto: dependencias exactas del lock |
| `dart format --set-exit-if-changed` (informativo) | **Aviso:** 15 de 17 archivos cambiarían. Código heredado con formato no estándar; no afecta a la compilación |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **0 errores, 0 advertencias, 38 avisos informativos**: 28 `deprecated_member_use` (`flutter/cupertino.dart`, `withOpacity`, `minSize`), 8 `unnecessary_underscores`, 1 `use_null_aware_elements`, 1 `unnecessary_import` |
| Pruebas Dart (`flutter test`) | **35 de 35** pasan, 0 omitidas |
| Pruebas Kotlin (`:app:testDebugUnitTest`) | **23 de 23**, 0 fallos y 0 omitidas: `PendingRequestsTest` 6, `SimAccountsTest` 5, `SimSelectionTest` 3, `SpamConcurrencyTest` 5, `SpamEngineTest` 4 |
| Compilación debug | `app-debug.apk` compila |
| Manifiesto final | minSdk 29, targetSdk 36; permisos en la sección 5.2 |
| `php -l servidor/*.php` | Sin errores |

### 5.2 Validación ampliada — [ejecución 43356527657](https://github.com/SKYELR9510/NEXLIA/actions/runs/43356527657) (rama temporal `tmp/validacion-p0`)

| Comprobación | Resultado |
|---|---|
| `flutter analyze` **sin opciones** | **Termina con código 1:** sin opciones trata como fatales los 38 avisos informativos. 0 errores y 0 advertencias reales |
| `git diff --check origin/main...HEAD` | Sin problemas, tras la corrección de la sección 6 |
| Compilación release | Correcta: `app-release.apk` de 49,4 MB, firmada |
| Firma | SHA-256 del certificado `e0735399159692c453a3ffbdd4c695a9bafc289cc1f19c89743cb298942d6394` (CN=NEXLIA, O=NEXLIA, C=PE), firma v2: **idéntico** al de la v1.0.13 publicada |
| Paquete y versión | `com.nexlia.phone`, versionCode `13`, versionName `1.0.13-validacion-p0`, minSdk 29, targetSdk 36 (v1.0.13: `com.nexlia.phone`, versionCode `13`) |
| Permisos frente a v1.0.13 | **Idénticos** (`aapt2 dump permissions`): `CALL_PHONE`, `READ_CALL_LOG`, `WRITE_CALL_LOG`, `READ_CONTACTS`, `WRITE_CONTACTS`, `READ_PHONE_STATE`, `INTERNET`, `POST_NOTIFICATIONS`, `USE_FULL_SCREEN_INTENT`, `VIBRATE`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. Ninguno SMS |
| SHA-256 tras descargar el artefacto | `NEXLIA-validacion-P0.apk: OK` (comprobado en los trabajos de emulador) |

### 5.3 Auditoría funcional

**Automatizada en emulador.** El emulador no tiene SIM real; su red simula una línea. Junto al APK de validación se ejecuta un **control** con la v1.0.13 publicada sola, para separar regresiones de limitaciones del emulador.

Resultados por emulador ([ejecución 43356527657](https://github.com/SKYELR9510/NEXLIA/actions/runs/43356527657)). "Validación" = APK P0 instalado encima de la v1.0.13; "Control" = v1.0.13 sola.

| Comprobación | Android 10 · validación | Android 10 · control | Android 14 · validación | Android 14 · control |
|---|---|---|---|---|
| Instala la v1.0.13 publicada | PASS | PASS | PASS | PASS |
| Se instala **como actualización** encima de la v1.0.13 (`adb install -r` → `Success`) | PASS | — | PASS | — |
| Conserva la instalación (`firstInstallTime` igual) | PASS | — | PASS | — |
| Queda como marcador predeterminado (rol DIALER) | PASS | PASS | PASS | PASS |
| Arranca | PASS | PASS | PASS | PASS |
| Entrante simulada: se abre la pantalla de llamada de NEXLIA | PASS | PASS | PASS | PASS |
| Entrante: Telecom enlaza `com.nexlia.phone.CallService` | PASS | PASS | PASS | PASS |
| Entrante: notificación en `dumpsys notification` | N/V | N/V | N/V | N/V |
| Entrante: la app sigue estable tras colgar | PASS | PASS | PASS | PASS |
| Saliente desde otra app (`ACTION_CALL`): se muestra en NEXLIA | PASS | PASS | PASS | PASS |
| Saliente desde otra app: aparece en la consola `gsm list` del emulador | PASS | PASS | FAIL¹ | FAIL¹ |
| Historial: entrante registrada | N/V² | N/V² | PASS | PASS |
| Historial: saliente registrada | N/V² | N/V² | FAIL¹ | FAIL¹ |
| Historial: guarda la cuenta (`subscription_id`) | N/V² | N/V² | PASS | PASS |
| Sin cierres inesperados de NEXLIA (logcat) | PASS | PASS | PASS | PASS |
| Selector de SIM, SIM retirada, antispam real, audio y Bluetooth | N/V³ | N/V³ | N/V³ | N/V³ |

1. **No es una regresión:** el control con la v1.0.13 da exactamente el mismo resultado. `dumpsys telecom` muestra la llamada saliente `state=ACTIVE` en `TelephonyConnectionService`, es decir, Telecom sí la colocó. Pero la consola `gsm list` del emulador de Android 14 no la lista, así que la prueba no puede colgarla desde la consola, y la llamada aún no estaba en el historial al consultarlo (Android lo escribe al terminar la llamada). En Android 10 la misma prueba pasa con ambos APK.
2. En Android 10, el usuario `shell` del emulador no tiene permiso para leer el registro de llamadas (`SecurityException`).
3. Requieren teléfono físico (el emulador tiene una SIM simulada).

**Incidencias de infraestructura** (no del código):
- En el primer intento, el emulador de Android 10 con el APK de validación se quedó colgado al arrancar. Se canceló y se relanzó solo ese trabajo, con el **mismo** APK; el trabajo `apk` no se volvió a ejecutar y existe un único artefacto.
- En el relanzamiento, el control de Android 14 volvió a colgarse y se canceló; vale su resultado completo del primer intento.
- Por esas cancelaciones, la ejecución aparece como "cancelled" en GitHub.

**Cubierto por pruebas automáticas** (sin teléfono):

| Función | Pruebas |
|---|---|
| Selector de SIM previo (dos SIM) | `selector_previo_test.dart`: aparece **antes** de llamar y usa la SIM elegida |
| Preferencia predeterminada | `selector_previo_test.dart`: "Usar siempre" se guarda y la siguiente llamada no pregunta; ajustes Más > SIM para llamar |
| SIM retirada o desactivada | `sim_choice_test.dart`, `selector_previo_test.dart` (preferencia inválida y `sim_unavailable` al llamar), `SimSelectionTest.resolve` |
| Una sola SIM | `sim_choice_test.dart`, `selector_previo_test.dart` (`placeCall` sin cuenta), `seleccion_sim_test.dart` |
| Cancelación del selector | `selector_previo_test.dart` (no llama), `seleccion_sim_test.dart` ("Cancelar" cuelga en SELECT_PHONE_ACCOUNT) |
| Sin segundo selector | `SimSelectionTest.sinSegundoSelectorSiYaSeEligio` |
| Historial | `numeros_test.dart`, `seleccion_sim_test.dart` (etiqueta de SIM solo con 2+ cuentas) |
| Filtrado antispam | `SpamEngineTest` (normalización), `SpamConcurrencyTest` (estado concurrente) |
| Solicitudes nativas concurrentes | `PendingRequestsTest` (8 hilos × 1 000; altas y respuestas simultáneas), `canal_nativo_test.dart` |

**Requiere teléfono físico** (lista también en `INSTRUCCIONES.txt` del artefacto):

| Función | Estado |
|---|---|
| Doble SIM: selector previo, SIM 1/SIM 2, "Preguntar siempre", preferencia | **Probado por el propietario** sobre #4/#6 (12-nov). Pendiente repetirlo con el APK de validación |
| SIM retirada o desactivada con la preferencia guardada | Pendiente |
| Llamada iniciada desde otra app con dos SIM (como máximo un selector) | Pendiente |
| Entrante con pantalla bloqueada; contestar/rechazar desde la notificación | Pendiente |
| Filtrado antispam con números reales y "Llamadas filtradas" | Pendiente |
| Arranque con permisos pendientes + "Activar" inmediato; giro o cierre con un diálogo abierto | Pendiente |
| Audio, altavoz, Bluetooth, unir llamadas | Pendiente |

## 6. Problemas encontrados

| # | Problema | Tratamiento |
|---|---|---|
| P1 | `git diff --check` fallaba en 4 líneas de `docs/ARQUITECTURA_NEXLIA.md` (PR #1): espacios finales usados como salto de línea Markdown | Corregido en `e8adc9d`: se usa la barra invertida, que GitHub muestra igual. Sin cambio de contenido |
| P2 | `flutter analyze` sin opciones termina con código 1 por 38 avisos informativos (APIs obsoletas, guiones bajos) | Documentado. CI usa `--no-fatal-infos --no-fatal-warnings`, que solo falla por errores. Limpieza propuesta como tarea aparte |
| P3 | 15 de 17 archivos Dart sin formato estándar | Documentado. Aplicar `dart format` en un PR propio, sin cambios funcionales, para no mezclarlo con lógica |
| P4 | Mientras preparaba la validación hubo fallos de mis propios scripts (descarga superficial sin historial para `git diff --check`, formato distinto de `dumpsys` en Android 14, permisos del usuario `shell` en Android 10) | Corregidos en el flujo temporal; no afectan al código de la app |
| P5 | En el emulador de Android 14 la consola `gsm list` no muestra las llamadas salientes, aunque Telecom las tiene activas | Limitación de la prueba: idéntica con la v1.0.13 (control). Documentado como FAIL¹ en la sección 5.3, no como regresión |
| P6 | Dos arranques de emulador colgados en GitHub Actions | Infraestructura; se relanzaron con el mismo APK |

## 7. Riesgos pendientes

| Riesgo | Mitigación |
|---|---|
| Doble SIM solo se validó en los equipos del propietario; los fabricantes difieren (Xiaomi/HyperOS, Samsung/One UI) | Repetir la lista física con el APK de validación en ambos equipos |
| `package:flutter/cupertino.dart` obsoleto desde Flutter 3.47 | Flutter fijado en 3.50.0; la migración a `cupertino_ui` es una tarea aparte |
| `material_ui` aparece como dependencia de la plantilla y no se usa | Quitarla regenerando el lock en un PR aparte |
| La publicación real (`apk.yml` en `main`) aún no se ejecutó con la nueva estructura | Se probó la compilación release firmada y la verificación previa; la primera publicación ocurrirá al fusionar en `main` |
| El APK de validación usa la clave de producción y es descargable por cualquier usuario con sesión en GitHub mientras exista (30 días) | Borrar el artefacto tras validar, si se prefiere |
| Backend de spam sin cambios (hallazgos B1–B8 de la auditoría) | Fuera del alcance de P0 |
| Buzón de voz usa la SIM predeterminada de Android | Fuera del alcance de P0 |
| Ramas temporales `tmp/*` sin borrar (esta sesión no tiene permiso para borrar ramas) | Borrarlas manualmente: `tmp/scaffold-3.50.0`, `tmp/integracion-p0`, `tmp/integracion-p0-sim`, `tmp/validacion-p0` |

## 8. Resultado de compilación

| Tipo | Resultado |
|---|---|
| Debug (`flutter build apk --debug`) | Correcto |
| Release firmada (`flutter build apk --release`) | Correcta: `app-release.apk` de 49,4 MB, firmada |
| Pruebas Dart / Kotlin | 35/35 y 23/23 |
| Análisis | 0 errores, 0 advertencias, 38 avisos informativos |

## 9. APK de validación

| Dato | Valor |
|---|---|
| Artefacto | [NEXLIA-validacion-P0](https://github.com/SKYELR9510/NEXLIA/actions/runs/43356527657/artifacts/14006617863), zip de 23,8 MB, **disponible hasta el 13-dic-2026**. Requiere iniciar sesión en GitHub; sin sesión, GitHub responde 404 |
| APK | `NEXLIA-validacion-P0.apk`, 49 432 752 bytes |
| **SHA-256** | `f21c17346ebc9753ec3b2e9abbe781f79734b596f3bc9d7d30987ca17cd51939` |
| Paquete | `com.nexlia.phone` |
| Versión | `1.0.13-validacion-p0`, versionCode `13` |
| Certificado | `e0735399…942d6394`: la misma clave de producción que la v1.0.13 |
| Android | Desde Android 10 (API 29); target API 36 |
| Contenido del zip | APK, `.sha256`, `firma.txt`, `version.txt`, `permisos.txt`, `INSTRUCCIONES.txt` (instalación y lista de validación física) |
| Origen | Commit `6cbcd4c` de `tmp/validacion-p0` = `integracion/p0` @ `e8adc9d` + un commit que solo añade el flujo y los scripts de validación (`.github/workflows/validacion-p0.yml`, `ci/`). El código de la app es idéntico al de la integración; después, la integración solo añade este informe |
| Publicación | **No** se creó ninguna Release. El APK de producción vigente sigue siendo la v1.0.13 |

**Compatibilidad de actualización:** mismo paquete, mismo certificado y versionCode 13 (igual al de la v1.0.13). Se comprobó en los emuladores de Android 10 y 14: `adb install -r` → `Success` y `firstInstallTime` sin cambios, es decir, una actualización con los datos conservados. La siguiente versión oficial (versionCode 14 o mayor) se instalará encima de esta.

**Instalación:** con la sesión de GitHub iniciada, descarga el zip, descomprímelo, comprueba el SHA-256 (en Windows: `certutil -hashfile NEXLIA-validacion-P0.apk SHA256`), abre el APK en el teléfono y elige **Actualizar**. La lista de validación física está en `INSTRUCCIONES.txt` y en la sección 5.3.

## 10. Estado de la rama `main`

- `main` sigue en `808f61e` ("Rediseno: marcador con sugerencias, recientes por dia, ficha de contacto y llamada con foto de fondo"). No se modificó.
- Ningún PR se fusionó: #1–#6 siguen abiertos.
- No se creó ninguna Release; la última sigue siendo `v1.0.13`.
- Integrar esta rama en `main` equivale a fusionar los seis PR. Al hacerlo, `apk.yml` ejecutará la verificación y, si pasa, publicará la siguiente versión oficial (`1.0.<n>`, con versionCode mayor que 13).
