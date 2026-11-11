# NEXLIA — marcador estilo iPhone con contactos y bloqueador de spam

App: **NEXLIA** (`com.nexlia.phone`). Flutter para la interfaz, Kotlin para llamadas y bloqueo.

## Instalar

1. Descomprime esta carpeta en tu PC.
2. Doble clic en `instalar.bat`. Crea el proyecto en `C:\proyectos\nexlia`, copia el código y fija Android 10 como mínimo.
3. Con el teléfono conectado por USB: `cd C:\proyectos\nexlia` y `flutter run --release`.
4. Al abrir la app, acepta los permisos y toca **Activar** para dejarla como Teléfono predeterminado. Sin ese paso no recibe llamadas ni bloquea spam.

### Xiaomi (HyperOS)
En Ajustes > Apps > NEXLIA > Otros permisos, activa **Mostrar en pantalla de bloqueo** y **Abrir ventanas nuevas en segundo plano**, y pon **Sin restricciones** en ahorro de batería. Si no, la pantalla de llamada entrante puede no aparecer con el teléfono bloqueado.

## Qué trae

- **Teclado**, **Recientes** (todas / perdidas), **Contactos** (buscar, crear, eliminar), **Favoritos**.
- **Pantalla de llamada** propia: contestar, rechazar, altavoz, silenciar, espera, teclado de tonos.
- **Spam** (pestaña): 
  - Desconocidos: permitir, silenciar o rechazar.
  - Serie 500 de Perú, números ocultos, internacionales.
  - Prefijos y números bloqueados por ti.
  - Base en línea propia.
  - Registro de llamadas filtradas.

Mantén presionada una llamada en Recientes para bloquear o reportar el número.

## Base de datos en línea (carpeta `servidor`)

1. En tu hosting crea una base MySQL y ejecuta `schema.sql`.
2. Edita los datos de conexión y la clave al inicio de `spam_api.php` y súbelo. Debe abrirse por **https**.
3. En la app: Spam > Servidor, escribe la dirección y la clave, y toca **Probar conexión**.

La base empieza vacía y se llena con los reportes hechos desde la app.

## Archivos

- `lib/` interfaz (Flutter).
- `android/kotlin/` llamadas, contactos y motor de spam (`Spam.kt` tiene las reglas, en orden).
- `android/AndroidManifest.xml` permisos y servicios.
