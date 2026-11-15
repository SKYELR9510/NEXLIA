# Revisión incremental de seguridad de NEXLIA Chat (PR #9)

## Alcance
Esta rama deriva de `feature/fase-1-mensajeria`. No habilita un backend real, no cambia llamadas/SIM, no fusiona PRs ni publica versiones.

## Implementado
- Límite de respuesta HTTP de 1 MiB, con error explícito ante exceso.
- Desactivación de redirecciones automáticas del cliente que adjunta `Authorization: Bearer`.
- HTTPS obligatorio; HTTP de pruebas solo en loopback (`localhost`, `127.0.0.1`, `::1`).
- Carga de estado de Chat mediante instantánea temporal: JSON corrupto no elimina conversaciones ya cargadas.
- Escrituras de Chat serializadas, con espera antes de recargar y prueba de almacenamiento lento.
- Errores de `Native.setPref` propagados al repositorio; Kotlin usa `commit()` para confirmar el resultado del guardado y lo ejecuta en el `io` executor fuera del hilo principal; falta prueba en dispositivo con conversaciones grandes.
- Confirmado en `MainActivity.kt`: `getPref`/`setPref` usan `SharedPreferences("ui")`, sin cifrado de mensajes.
- Pruebas unitarias para los casos anteriores.
- Lectura de respuestas con tiempo máximo total (no renovado por fragmento) y manejo explícito de UTF-8 inválido.

## Pendiente de verificar
- Ejecutar CI completa y revisar los resultados; no se declara aprobación de pruebas.
- Confirmar en CI las nuevas pruebas de timeout total y UTF-8 inválido; cambios implementados, sin ejecución local de Flutter.
- Se añadió control de revisión para evitar que una carga antigua reemplace mutaciones concurrentes, con prueba de lectura lenta; falta ejecutar pruebas y revisar intercalaciones adicionales.
- Confirmar almacenamiento nativo: `NativePrefsStore` utiliza `Native.setPref`; no asumir cifrado.
- Diseñar cifrado en reposo mediante Android Keystore y migración de datos antes de permitir mensajes reales.
- Cola persistente de recibos de lectura implementada, con prueba de reinicio y reintento; falta validación en CI y política de reintento al recuperar conectividad.
- Probar en dispositivo físico con dos SIM.

## Riesgos y criterios de integración
No fusionar sin CI aprobada. No habilitar producción ni almacenar conversaciones reales hasta revisar privacidad, autenticación, gestión de sesiones, cifrado local y recuperación ante fallos.

## Evidencia de CI
El workflow `verificacion.yml` se ejecuta al hacer push en ramas distintas de `main`. La consulta de estados del conector no ha confirmado todavía los resultados de esta rama. No considerar las pruebas aprobadas hasta revisar GitHub Actions.

## Límite de seguridad actual
`SharedPreferences("ui")` guarda mensajes sin cifrado. No se ha implementado Android Keystore ni migración de datos cifrados. **No conectar una cuenta real ni habilitar Chat en producción** hasta reemplazar esta persistencia y probar recuperación, copia de seguridad y cierre de sesión. La escritura `commit()` ya se despacha al ejecutor de E/S; verificar latencia y consumo de memoria con conversaciones grandes.

## Ajustes posteriores
- La recarga conserva el estado actual si la última escritura falló.
- `flushOutbox()` intenta procesar los recibos pendientes al completar la cola de mensajes.
- **Bloqueantes de producción:** cifrado en reposo con Android Keystore y migración segura, backend/autenticación funcional, CI aprobada y pruebas en dispositivo. Estos elementos no se consideran implementados ni validados.

## Cifrado local incorporado (pendiente de validación Android)
- `android/kotlin/ChatSecurePrefs.kt` cifra `chat.store.v1` con AES-256-GCM y una clave no exportable de Android Keystore. El nombre de la preferencia se autentica como AAD.
- La lectura migra el JSON heredado desde `SharedPreferences("ui")` a `chat_secure_v1`; solo elimina el original tras confirmar el nuevo guardado.
- La interfaz de Flutter mantiene el mismo contrato; lectura y escritura cifradas se despachan al ejecutor de E/S.
- **Sin validar:** compilación Kotlin, migración en dispositivos, pérdida de clave tras restauración de copias de seguridad, resistencia a fallos durante migración, rendimiento y compatibilidad con versiones Android.
- **Antes de producción:** excluir `chat_secure_v1.xml` de Auto Backup / device transfer o implementar una estrategia de restauración que no pierda mensajes. No habilitar Chat real hasta comprobar esta política.
