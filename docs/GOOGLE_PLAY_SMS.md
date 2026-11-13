# NEXLIA y Google Play: permisos de SMS

**Fecha de consulta de las fuentes:** 13 de noviembre de 2026. Las políticas cambian: hay que revisarlas de nuevo antes de publicar.
**Este informe no es asesoría legal.** Resume las políticas públicas de Google y lo comprobado en esta rama.

## 1. Resumen

| Escenario | ¿Funciona la bandeja SMS de solo lectura? |
|---|---|
| **APK de pruebas** (GitHub Releases, instalación manual) | **Sí.** Es la distribución actual. Ver §2 para los avisos de Android 13 y posteriores |
| **Google Play, como app de Teléfono predeterminada** (lo que es NEXLIA hoy) | **No, tal como está.** La política de Google Play no permite `READ_SMS` a la app de Teléfono predeterminada (§3) |
| **Google Play, como app de SMS predeterminada** | Sí, pero hay que implementar la app de SMS completa (§4). Hoy no lo está |
| **Google Play, sin leer SMS** | Sí. Hay que quitar `READ_SMS` del manifiesto de esa versión (§6) |

**Conclusión:** la bandeja de SMS de la Fase 1 es válida para el APK de pruebas. **Antes de publicar en Google Play hay que elegir** entre convertir NEXLIA en la app de SMS completa o publicar una versión sin `READ_SMS`. Esa decisión es del producto; no se toma en esta rama.

## 2. APK de pruebas (instalación manual)

- **Rol de Teléfono y `READ_SMS`.** Al ser la app de Teléfono predeterminada, Android concede `READ_SMS` automáticamente (`GRANTED_BY_ROLE`, comprobado en los emuladores). Por eso NEXLIA exige además el consentimiento dentro de la app (`sms.consent.v1`) antes de leer.
- **Ajustes restringidos (Android 13 y posteriores).** Las apps instaladas desde un archivo (navegador, gestor de archivos, mensajería) quedan sujetas a "ajustes restringidos". Según la documentación de compatibilidad de Android 15 (CDD), esto incluye los roles de **Teléfono y SMS** y el permiso de **SMS**. Si Android bloquea el rol o el permiso, el usuario debe ir a *Ajustes > Apps > NEXLIA > ⋮ > Permitir ajustes restringidos*. El nombre del menú varía según el fabricante.
- **Lo que no se pudo comprobar.** En los emuladores de CI el APK se instala con `adb`, que Android trata como instalador exento. El comportamiento con una instalación desde el navegador **no se pudo verificar** sin un teléfono físico.
- **Verificación de desarrolladores para instalaciones manuales.** Google exige registrar al desarrollador también para las apps que se instalan desde un archivo en dispositivos certificados.
  - **Calendario:** el 30 de septiembre de 2026 empezó en Brasil, Indonesia, Singapur y Tailandia; la extensión global está anunciada para 2027. Perú no figura en la primera fase.
  - **Excepciones:** las apps no registradas se pueden seguir instalando con ADB o con el "flujo avanzado". Las cuentas de distribución limitada permiten compartir con hasta 20 dispositivos.
  - **Para NEXLIA:** antes de 2027 hay que registrar al desarrollador o usar una de esas vías para seguir distribuyendo el APK.

## 3. Por qué la app de Teléfono no puede usar `READ_SMS` en Google Play

La política "Use of SMS or Call Log permission groups" de Google Play:

- Cubre **`READ_SMS`**, `RECEIVE_SMS`, `SEND_SMS`, `WRITE_SMS`, `RECEIVE_MMS`, `RECEIVE_WAP_PUSH`, `READ_CALL_LOG`, `WRITE_CALL_LOG` y `PROCESS_OUTGOING_CALLS`.
- Exige que la app sea el **gestor predeterminado** (SMS, Teléfono o Asistente) antes de pedir esos permisos, y solo para su función principal.
- Para el **gestor de Teléfono predeterminado**, la tabla de usos permitidos incluye `READ_CALL_LOG`, `WRITE_CALL_LOG`, `PROCESS_OUTGOING_CALLS` y `SEND_SMS`, pero **no `READ_SMS`**.

**Para NEXLIA:**

| Permiso | Uso actual | En Google Play como app de Teléfono |
|---|---|---|
| `READ_CALL_LOG` y `WRITE_CALL_LOG` | Recientes | Permitido (gestor de Teléfono) |
| `READ_SMS` | Bandeja de solo lectura (Fase 1) | **No permitido** |
| `SEND_SMS`, `RECEIVE_SMS` | No se declaran | — |

**Uso de un permiso que el sistema ya concedió.** Aunque Android conceda `READ_SMS` al rol de Teléfono, Google Play valora **el uso** que la app hace del permiso, no solo el manifiesto. Declarar el permiso sin un uso permitido puede llevar al rechazo o a la retirada de la app.

## 4. Requisitos para ser la app de SMS predeterminada

Lo que exige la plataforma Android para recibir el rol SMS (`RoleManager.ROLE_SMS`):

| Componente | Para qué |
|---|---|
| Receptor `SMS_DELIVER` con `BROADCAST_SMS` | Recibir y **guardar** cada SMS (la app de SMS es la única que escribe en el proveedor) |
| Receptor `WAP_PUSH_DELIVER` con `BROADCAST_WAP_PUSH` | Recibir MMS |
| Actividad con `SENDTO` para `sms:`, `smsto:`, `mms:` y `mmsto:` | Redactar y enviar |
| Servicio `RESPOND_VIA_MESSAGE` con `SEND_RESPOND_VIA_MESSAGE` | "Responder con mensaje" al rechazar llamadas |
| Permisos `SEND_SMS`, `RECEIVE_SMS`, `RECEIVE_MMS`, `WRITE_SMS` y `READ_SMS` | Uso completo |

Lo que exige Google Play además:

- La app debe **hacer de verdad** la función de SMS.
- Debe pedir el rol **antes** que los permisos.
- Debe describirlo en la ficha de la tienda.
- Debe tener una política de privacidad.
- Debe enviar el **formulario de declaración de permisos** en Play Console, que Google revisa.

**Riesgo técnico.** Si NEXLIA pidiera el rol sin todo lo anterior, Android dejaría de entregar SMS a la app anterior y **se perderían SMS** y "Responder con mensaje". Por eso la Fase 1 no lo pide.

## 5. Excepciones de la política

Google concede excepciones **temporales y revisadas caso a caso** a apps que no son el gestor predeterminado, solo si el permiso es imprescindible para una función principal de la lista y **no hay otra forma** de hacerla. Algunas de la lista:

- identificación de llamadas, detección o bloqueo de spam;
- copia de seguridad y restauración;
- dispositivos complementarios;
- transacciones financieras por SMS;
- anti-*smishing*, con un historial demostrable de protección.

**Para NEXLIA:**

- **La bandeja de SMS no encaja en ninguna excepción.** Mostrar SMS es la función de la app de SMS predeterminada.
- **El antispam de llamadas de NEXLIA no usa SMS.** No justifica `READ_SMS`.
- **Las excepciones son para apps no predeterminadas.** NEXLIA ya es la app de Teléfono, así que conviene confirmar con Google si una excepción puede aplicarse a una app que sí es gestor predeterminado. La política publicada no lo aclara.

## 6. Alternativas técnicas

| Alternativa | Qué ofrece | Costo |
|---|---|---|
| **A. Variante de Play sin `READ_SMS`** (recomendada si se publica pronto) | Teléfono, contactos, antispam y NEXLIA Chat. La pestaña Mensajes muestra solo Chat, y "Abrir app de SMS" abre la app del sistema | Un *flavor* de Gradle o un manifiesto distinto para Play. El código ya trata "SMS no disponibles" |
| **B. NEXLIA como app de SMS completa** | Bandeja SMS y MMS con envío, como Google Mensajes | Fase grande: recepción y almacenamiento, envío con elección de SIM, MMS, notificaciones, "Responder con mensaje", copias. Revisión de Google |
| **C. Mantener la distribución por APK** | Todo lo actual | Sin la visibilidad de Play. Avisos de ajustes restringidos y verificación de desarrolladores |
| **D. Intents del sistema** (ya implementado) | "Responder en la app de SMS" abre la app de SMS con `ACTION_SENDTO`, sin ningún permiso | Ninguno |

Para verificar números o cuentas, Google recomienda la SMS Retriever API, la SMS User Consent API o la API de credenciales digitales, en lugar de leer SMS. NEXLIA Chat no lee SMS para verificar: el código OTP lo escribe el usuario.

## 7. Qué hay hoy en el manifiesto

- **Permisos.** Comprobados en el manifiesto final de CI: los de `main` más `READ_SMS`. No se declaran `SEND_SMS`, `RECEIVE_SMS`, `RECEIVE_MMS` ni `WRITE_SMS`.
- **Componentes.** No hay receptores `SMS_DELIVER` ni `WAP_PUSH_DELIVER`.
- **Rol.** No se pide el rol SMS (verificado en los emuladores: la app de SMS predeterminada no cambia).

## Fuentes

- [Google Play: Use of SMS or Call Log permission groups](https://support.google.com/googleplay/android-developer/answer/10208820?hl=en)
- [Google Play: Permissions and APIs that Access Sensitive Information](https://support.google.com/googleplay/android-developer/answer/9888170)
- [Android Developers: Permissions used only in default handlers](https://developer.android.com/guide/topics/permissions/default-handlers)
- [Android Authority: Android 15 restricted settings for sideloaded apps](https://androidauthority.com/android-15-restricted-settings-sideloading-3481098)
- [9to5Google: Android 15 sideloaded apps restrictions](https://9to5google.com/2024/09/12/android-15-sideloaded-apps-restrictions/)
- [Android Developers Blog: Android developer verification rolling out to all developers (marzo de 2026)](https://android-developers.googleblog.com/2026/03/android-developer-verification-rolling-out-to-all-developers.html)
