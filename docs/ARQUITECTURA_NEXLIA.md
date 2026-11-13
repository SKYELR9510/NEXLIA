# NEXLIA — Arquitectura maestra y hoja de ruta

**Estado:** documento de arquitectura objetivo\
**Producto:** plataforma personal de comunicación para Android\
**Repositorio:** `SKYELR9510/NEXLIA`\
**Rama de trabajo:** `docs/arquitectura-plataforma`\
**Idioma del producto:** español inicialmente; preparado para internacionalización

> Este documento define el destino del producto y las reglas de integración. No autoriza reescrituras ni presupone que una función está implementada. Antes de modificar código, Claude debe inspeccionar la versión actual de cada archivo, verificar dependencias y registrar la situación real.

---

## 1. Visión del producto

NEXLIA evolucionará desde la aplicación telefónica existente hacia una plataforma personal de comunicación que reúna:

1. **PHONE:** llamadas celulares mediante SIM.
2. **MESSAGES:** mensajería NEXLIA por Internet y SMS/MMS del operador.
3. **CONTACTS:** agenda, favoritos, perfiles y búsqueda.
4. **CONNECT:** identidad NEXLIA, invitaciones y dispositivos vinculados.
5. **SHIELD:** bloqueo, reportes y protección contra spam.
6. **LIFE:** recordatorios y seguimiento de comunicaciones.
7. **AI:** asistencia opcional para resumir, organizar o traducir contenido autorizado.

El público inicial es personal/general. La experiencia debe ser sencilla, accesible y útil sin exigir que todos los contactos tengan una cuenta NEXLIA.

### Principios no negociables

- Preservar las llamadas que ya funcionan.
- Evolucionar incrementalmente; no reescribir por preferencia tecnológica.
- Diferenciar claramente llamadas celulares, SMS/MMS y chat por Internet.
- Solicitar permisos solo cuando una función los necesite y explicar el motivo.
- Privacidad y seguridad desde el diseño.
- No enviar contenido de conversaciones a servicios de IA sin acción y consentimiento claros.
- Toda función visible debe estar implementada o identificada honestamente como próxima función.
- Mantener compatibilidad con los dispositivos y versiones Android que el proyecto soporte realmente.

---

## 2. Identidad visual

La identidad se basa en el icono proporcionado por el propietario del producto:

- Azul marino como superficie principal.
- Azul eléctrico para acciones y selección.
- Cian/turquesa para señal, estados y acentos.
- Blanco y grises neutros para legibilidad.
- **Prohibido introducir morado o rosado como colores de marca.**

La aplicación tendrá tema claro, oscuro y opción de seguir el sistema. Los colores deben centralizarse en tokens del sistema de diseño; no codificar colores dispersos en cada pantalla.

### Navegación propuesta

- Inicio
- Llamadas
- Mensajes
- Contactos
- Perfil / Más

La navegación final debe respetar los flujos existentes y validarse con prototipos antes de sustituir rutas actuales.

### Componentes compartidos

- Encabezados, barras de navegación y buscador global.
- Tarjetas de contacto y avatar.
- Estados vacíos, carga, error y sin conexión.
- Indicadores de tipo de conversación: Chat, SMS/MMS.
- Botones de llamada, mensaje, favorito y opciones.
- Selectores de SIM cuando aplique.
- Diálogos de permisos y confirmación.
- Componentes accesibles: contraste, tamaño de texto y objetivos táctiles.

---

## 3. Arquitectura lógica

Adoptar arquitectura modular por funcionalidades, conservando la tecnología existente cuando sea viable. El repositorio ha sido identificado previamente como una solución con Flutter/Dart para la interfaz, código Android/Kotlin para integración telefónica y un backend PHP/MySQL relacionado con reportes de spam. Estas observaciones son una línea de partida y deben volver a verificarse contra la rama y archivos actuales antes de cada cambio.

### Capas

**Presentación**
- Pantallas y componentes.
- Navegación.
- Gestión de estado.
- Temas y accesibilidad.

**Dominio**
- Casos de uso.
- Entidades y reglas de negocio.
- Contratos/repositorios.
- Validaciones.

**Datos**
- Repositorios concretos.
- Persistencia local.
- API remota.
- Sincronización y caché.

**Integración de plataforma**
- Telecom/llamadas.
- SMS/MMS.
- Contactos del dispositivo.
- Permisos y roles Android.
- Notificaciones y tareas en segundo plano.

La interfaz no debe acceder directamente a la base de datos, a la red o a APIs nativas desde widgets. Encapsular esas operaciones en servicios/repositorios testeables.

### Módulos objetivo

| Módulo | Responsabilidad |
|---|---|
| app | Arranque, composición y navegación |
| core/design | Tokens, temas y componentes compartidos |
| core/network | Cliente API, errores y conectividad |
| core/storage | Persistencia local y migraciones |
| core/security | Sesiones, cifrado y almacenamiento seguro |
| core/notifications | Registro y presentación de notificaciones |
| feature/home | Panel de comunicaciones |
| feature/phone | Marcador y experiencia de llamada |
| feature/recents | Historial de llamadas |
| feature/contacts | Contactos, favoritos y perfiles |
| feature/messaging | Bandeja y conversaciones |
| feature/sms | Integración SMS/MMS del sistema |
| feature/groups | Grupos de chat NEXLIA |
| feature/connect | Cuenta, invitaciones y dispositivos |
| feature/shield | Bloqueo, reportes y antispam |
| feature/life | Recordatorios y seguimiento |
| feature/assistant | Funciones de IA consentidas |
| feature/settings | Preferencias, privacidad y permisos |

No crear carpetas vacías por adelantado. Introducir cada módulo cuando exista una funcionalidad concreta que lo justifique y siguiendo las convenciones reales del repositorio.

---

## 4. Canales de comunicación: separación obligatoria

### 4.1 Chat NEXLIA (Internet)

Mensajes entre cuentas NEXLIA:
- Conversaciones individuales.
- Grupos.
- Texto, imágenes, documentos y notas de voz.
- Estados de envío, entrega y lectura.
- Indicador de escritura y presencia, configurables.
- Notificaciones push.
- Cifrado de extremo a extremo antes de anunciarlo como disponible.

### 4.2 SMS/MMS del operador

Mensajes gestionados por Android y la red móvil:
- Bandeja SMS/MMS.
- Envío y recepción con los permisos y rol requeridos.
- Selección de SIM cuando el dispositivo admita varias.
- Adjuntos MMS sujetos a operador y dispositivo.
- Historial local y búsqueda.

No asumir que SMS admite confirmación universal de lectura ni cifrado de extremo a extremo. La aplicación debe explicar las diferencias.

### 4.3 Bandeja unificada

Puede mostrar conversaciones de ambos canales en una experiencia común, pero debe conservar el origen y las reglas de cada canal. Cada hilo debe indicar inequívocamente si es Chat NEXLIA o SMS/MMS.

No convertir silenciosamente un mensaje de Internet en SMS ni enviar contenido por un canal alternativo sin informar y obtener confirmación del usuario.

---

## 5. Modelo de datos objetivo

El modelo definitivo depende del backend existente y debe diseñarse con migraciones reversibles. Entidades conceptuales:

- User: cuenta NEXLIA.
- UserProfile: nombre visible, foto y preferencias.
- Device: dispositivos vinculados y sesiones.
- Contact: relación local o sincronizada.
- Conversation: conversación y tipo de canal.
- ConversationMember: participantes y roles.
- Message: contenido, autor, canal, timestamps y estado.
- Attachment: metadatos y ubicación protegida del archivo.
- MessageReceipt: estados de entrega/lectura cuando el canal lo soporte.
- Group: nombre, imagen y configuración.
- BlockEntry: bloqueos locales y de cuenta.
- AbuseReport: reportes de abuso/spam.
- Reminder: recordatorios creados por el usuario.
- PushEndpoint: tokens de notificación asociados a dispositivos.

Los SMS/MMS del operador deben seguir siendo gestionados según el modelo de almacenamiento y las reglas de Android. No copiar automáticamente todo el contenido SMS a la nube.

### Reglas de consistencia

- Identificadores estables y claves foráneas.
- Timestamps en UTC; presentación en zona local.
- Paginación para conversaciones e historial.
- Idempotencia para operaciones de envío/reintento.
- Estados explícitos para pendiente, enviado, entregado, leído y fallido, solo cuando apliquen.
- Migraciones versionadas y respaldos antes de cambios destructivos.

---

## 6. Backend y comunicación en tiempo real

Mantener y evaluar el backend PHP/MySQL existente antes de decidir si se amplía o se separa. No introducir una segunda API o base de datos sin una necesidad demostrada.

Capacidades del servidor objetivo:
- Autenticación y gestión de sesiones.
- Perfiles y dispositivos.
- Conversaciones y miembros.
- Envío, recepción y sincronización de mensajes.
- Gestión de archivos con límites y validación.
- Notificaciones push.
- Bloqueos y reportes.
- Registro de auditoría sin almacenar contenido sensible innecesario.
- Límites de frecuencia y protección contra abuso.

Para tiempo real, evaluar WebSocket o un mecanismo equivalente compatible con la infraestructura actual. Las notificaciones push deben avisar de eventos; no deben ser el único almacenamiento ni la única fuente de verdad de los mensajes.

No guardar contraseñas en texto plano. Usar TLS, controles de autorización por conversación, límites de frecuencia, validación del lado servidor y gestión segura de secretos fuera del repositorio.

---

## 7. Seguridad y privacidad

### Requisitos mínimos

- TLS para todo tráfico remoto.
- Almacenamiento seguro de credenciales y claves en el dispositivo.
- Autorización por usuario y conversación en cada operación del backend.
- Cifrado en reposo donde corresponda.
- Cifrado de extremo a extremo para chat privado antes de comercializarlo como tal.
- Verificación de dispositivos y gestión de sesiones.
- Bloquear, reportar y eliminar usuarios.
- Controles de privacidad para presencia, última conexión y confirmaciones.
- Política de retención y eliminación de datos.
- Protección de adjuntos, tipos MIME y tamaño máximo.
- No incluir secretos, tokens ni datos personales en logs.

### Inteligencia artificial

- Desactivada por defecto para el análisis del contenido de mensajes o llamadas.
- Acción explícita del usuario para resumir o traducir.
- Informar qué contenido se procesa y con qué proveedor.
- No usar contenido privado para entrenar modelos sin consentimiento separado.
- Permitir borrar los resultados generados.
- No prometer grabación o transcripción de llamadas hasta verificar API, restricciones del sistema, fabricante y legislación aplicable.

### Antispam

La reputación de números debe basarse en señales justificables, controles contra reportes maliciosos y mecanismos de apelación. No etiquetar a una persona como estafadora solo por un reporte aislado.

---

## 8. Integración Android: roles y permisos

Las funciones telefónicas y SMS están sujetas a roles y restricciones de Android y de distribución.

Antes de implementar:
- Verificar el rol de aplicación de teléfono predeterminada y los componentes requeridos.
- Verificar por separado el rol SMS predeterminado y los componentes exigidos para SMS/MMS.
- Revisar las políticas vigentes de Google Play para permisos de llamadas y SMS.
- Solicitar permisos en contexto, después de explicar su beneficio.
- Probar doble SIM en dispositivos reales de distintos fabricantes.
- Mantener una experiencia limitada pero funcional si el usuario no concede un permiso.

No asumir que tener el rol de marcador concede automáticamente el rol SMS, ni que todos los fabricantes exponen las mismas capacidades.

---

## 9. Roadmap de implementación

### Fase 0 — Auditoría y línea base
1. Confirmar rama, commit y estructura actual.
2. Inspeccionar manifiesto, dependencias y canales nativos.
3. Documentar flujos actuales de llamadas y spam.
4. Ejecutar las pruebas y compilación disponibles.
5. Crear inventario de permisos y capacidades.
6. Registrar riesgos y deuda técnica.

**Salida:** informe de auditoría y pruebas reproducibles.

### Fase 1 — Sistema visual y navegación
1. Crear tokens de color basados en el icono.
2. Implementar temas claro/oscuro/sistema.
3. Diseñar navegación y componentes comunes.
4. Adaptar pantallas existentes una a una.
5. Validar accesibilidad y tamaños de pantalla.

**Salida:** rediseño sin regresiones telefónicas.

### Fase 2 — SMS/MMS
1. Verificar viabilidad y políticas del rol SMS.
2. Implementar el flujo de solicitud del rol.
3. Crear bandeja y conversaciones SMS.
4. Implementar envío/recepción y selección SIM.
5. Implementar MMS según compatibilidad.
6. Probar permisos denegados, SIM ausente y errores del operador.

**Salida:** SMS/MMS propio si se cumplen requisitos de plataforma y distribución.

### Fase 3 — Chat NEXLIA
1. Diseñar protocolo y API.
2. Crear cuentas y sesiones.
3. Implementar conversaciones individuales.
4. Añadir sincronización y reintentos.
5. Añadir adjuntos y notificaciones.
6. Añadir grupos.
7. Diseñar e implementar cifrado de extremo a extremo.
8. Realizar pruebas de seguridad.

**Salida:** mensajería de Internet lista para pruebas cerradas.

### Fase 4 — Connect
Perfiles, invitaciones, descubrimiento con consentimiento y dispositivos vinculados.

### Fase 5 — Shield y Life
Protección antispam, bloqueo, reportes, recordatorios y seguimiento.

### Fase 6 — AI
Resúmenes, traducción y organización con consentimiento explícito.

### Fase 7 — Estabilización y publicación
Pruebas de compatibilidad, seguridad, rendimiento, batería, accesibilidad y políticas de tienda.

Cada fase debe terminar con revisión, pruebas y documentación antes de iniciar la siguiente.

---

## 10. Estrategia de ramas y entregas

- No trabajar directamente sobre `main`.
- Usar ramas cortas por funcionalidad, por ejemplo `feature/ui-refresh`, `feature/sms-inbox`, `feature/nexlia-chat`.
- Commits pequeños con mensajes descriptivos.
- Abrir Pull Request hacia `main`.
- No fusionar si falla compilación, pruebas o revisión.
- No incluir secretos ni archivos generados.
- Conservar una forma de volver a la versión estable anterior.

La rama `docs/arquitectura-plataforma` contiene este documento y no debe usarse como rama de desarrollo funcional.

---

## 11. Estrategia de pruebas y criterios de aceptación

### Pruebas automatizadas
- Unitarias para dominio, validaciones y repositorios.
- Widget/UI para navegación, estados vacíos y temas.
- Integración para API y persistencia.
- Pruebas de migraciones de base de datos.
- Pruebas de permisos y roles Android donde sea posible.
- Pruebas de seguridad de autorización y acceso entre conversaciones.

### Pruebas manuales en dispositivos
- Llamadas entrantes y salientes.
- SIM única y doble SIM.
- Cambio de SIM predeterminada.
- SMS/MMS con operador real.
- Sin Internet, conexión intermitente y reconexión.
- Notificaciones en segundo plano.
- Batería y restricciones de fabricantes.
- Tema claro/oscuro y accesibilidad.

### Criterio de aceptación de cada entrega
1. Compila en el entorno documentado.
2. Pruebas automatizadas relevantes pasan.
3. No hay regresiones en llamadas existentes.
4. Permisos justificados y probados.
5. Errores y estados de carga están cubiertos.
6. Cambios de base de datos tienen migración.
7. Documentación actualizada.
8. Pull Request revisable y con alcance acotado.

---

## 12. Instrucciones de trabajo para Claude

Claude debe seguir estas reglas en cada tarea:

1. Leer este documento y revisar el estado actual del repositorio antes de proponer cambios.
2. No asumir que las rutas, clases o dependencias mencionadas en conversaciones anteriores siguen existiendo; verificarlas en el código actual.
3. Informar qué archivos modificará y por qué antes de un cambio amplio.
4. No reemplazar el motor telefónico ni alterar roles/permisos sin análisis de impacto.
5. Mantener Flutter/Dart y Kotlin donde ya resuelven necesidades; no migrar de stack sin una justificación técnica comparativa.
6. No agregar backend, proveedor, SDK o dependencia sin explicar costo, privacidad, mantenimiento y alternativa.
7. Implementar una funcionalidad vertical completa y pequeña por vez.
8. Añadir pruebas para la lógica nueva y actualizar las existentes.
9. Ejecutar formato, análisis estático, pruebas y compilación que permita el entorno; reportar literalmente qué se ejecutó y qué no.
10. No declarar una función terminada si solo existe su interfaz o un mock.
11. No subir secretos, claves privadas, archivos de firma ni datos reales.
12. No fusionar a `main` sin revisión explícita.
13. Si encuentra una contradicción entre este documento y el código real, detener el cambio afectado, explicar la evidencia y proponer la actualización de arquitectura.
14. Al finalizar cada tarea, entregar resumen, archivos modificados, pruebas ejecutadas, limitaciones y siguiente paso.

### Formato de reporte de Claude

- Objetivo.
- Estado previo verificado.
- Archivos modificados.
- Decisiones técnicas.
- Pruebas ejecutadas y resultado.
- Riesgos o limitaciones.
- Pasos manuales pendientes.
- Commit y rama.

---

## 13. Primer trabajo autorizado por esta arquitectura

La primera tarea funcional después de esta documentación debe ser **Fase 0: auditoría técnica reproducible**, no implementar chat inmediatamente.

Entregables:
- Inventario real de módulos y dependencias.
- Diagrama de navegación actual.
- Flujo nativo de llamadas y permisos.
- Estado real del envío SMS actual.
- Estado del backend y API de spam.
- Comandos de compilación y pruebas.
- Lista de regresiones conocidas.
- Propuesta de Fase 1 con archivos concretos.

**No modificar todavía el motor de llamadas ni los flujos SMS durante la auditoría.**

---

## 14. Decisiones pendientes que requieren evidencia

No fijar una tecnología definitiva para estos puntos hasta evaluar el repositorio y requisitos:
- Protocolo y proveedor de tiempo real.
- Proveedor de almacenamiento multimedia.
- Diseño criptográfico y biblioteca E2EE mantenida.
- Estrategia de sincronización y respaldo.
- Proveedor de IA y tratamiento de datos.
- Soporte mínimo de Android y fabricantes objetivo.
- Costos operativos y límites de uso.

La prioridad es una plataforma mantenible, segura y realista, no acumular tecnologías.

---

**Visión de producto:** NEXLIA debe hacer que llamadas, SMS, chat, contactos y organización personal se sientan como una sola experiencia, sin ocultar las diferencias técnicas y de privacidad entre cada canal.
