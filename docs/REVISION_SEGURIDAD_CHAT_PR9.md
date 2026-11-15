# Revisión incremental de seguridad de NEXLIA Chat (PR #9)

## Alcance
Esta rama deriva de `feature/fase-1-mensajeria`. No habilita un backend real, no cambia llamadas/SIM, no fusiona PRs ni publica versiones.

## Implementado
- Límite de respuesta HTTP de 1 MiB, con error explícito ante exceso.
- Desactivación de redirecciones automáticas del cliente que adjunta `Authorization: Bearer`.
- HTTPS obligatorio; HTTP de pruebas solo en loopback (`localhost`, `127.0.0.1`, `::1`).
- Carga de estado de Chat mediante instantánea temporal: JSON corrupto no elimina conversaciones ya cargadas.
- Escrituras de Chat serializadas, con espera antes de recargar y prueba de almacenamiento lento.
- Errores de `Native.setPref` propagados al repositorio, sin declarar éxito cuando falla el guardado.
- Confirmado en `MainActivity.kt`: `getPref`/`setPref` usan `SharedPreferences("ui")`, sin cifrado de mensajes.
- Pruebas unitarias para los casos anteriores.

## Pendiente de verificar
- Ejecutar CI completa y revisar los resultados; no se declara aprobación de pruebas.
- Revisar el tratamiento de tiempos agotados durante respuestas parciales y errores de decodificación UTF-8.
- Completar protección contra carreras entre cargas y mutaciones concurrentes (las escrituras ya están serializadas).
- Confirmar almacenamiento nativo: `NativePrefsStore` utiliza `Native.setPref`; no asumir cifrado.
- Diseñar cifrado en reposo mediante Android Keystore y migración de datos antes de permitir mensajes reales.
- Implementar cola persistente de recibos de lectura y reintentos.
- Probar en dispositivo físico con dos SIM.

## Riesgos y criterios de integración
No fusionar sin CI aprobada. No habilitar producción ni almacenar conversaciones reales hasta revisar privacidad, autenticación, gestión de sesiones, cifrado local y recuperación ante fallos.
