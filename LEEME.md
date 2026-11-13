# NEXLIA — marcador estilo iPhone con contactos y bloqueador de spam

App: **NEXLIA** (`com.nexlia.phone`). Flutter para la interfaz, Kotlin para llamadas y bloqueo.

## Instalar

**Recomendado:** descarga `NEXLIA.apk` de la última versión en [Releases](https://github.com/SKYELR9510/NEXLIA/releases). Las versiones publicadas se instalan encima de la anterior.

Al abrir la app, acepta los permisos y toca **Activar** para dejarla como Teléfono predeterminado. Sin ese paso no recibe llamadas ni bloquea spam.

## Compilar

El repositorio es un proyecto Flutter completo con versiones fijas:

- Flutter **3.50.0** (Dart 3.14.0), JDK 17.
- Dependencias exactas en `pubspec.lock`; Gradle 9.5.0, Android Gradle Plugin 9.3.1 y Kotlin 2.4.20 en `android/`.

```
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --debug
cd android && ./gradlew :app:testDebugUnitTest
```

En Windows, `instalar.bat` comprueba la versión de Flutter y descarga las dependencias.

Un APK compilado en la PC se firma con la clave debug local y **no** se instala encima de las releases oficiales.

### CI

- `Verificación` (`.github/workflows/verificacion.yml`): análisis, pruebas Dart y Kotlin, compilación debug y sintaxis PHP en cada rama y Pull Request.
- `Compilar APK` (`.github/workflows/apk.yml`): en cada push a `main` ejecuta primero la verificación; solo si pasa, compila la release firmada, comprueba el certificado y la publica.

### Xiaomi (HyperOS)
En Ajustes > Apps > NEXLIA > Otros permisos, activa **Mostrar en pantalla de bloqueo** y **Abrir ventanas nuevas en segundo plano**, y pon **Sin restricciones** en ahorro de batería. Si no, la pantalla de llamada entrante puede no aparecer con el teléfono bloqueado.

## Qué trae

- Pestañas **Teléfono** (marcador con sugerencias), **Contactos** (favoritos, índice A–Z), **Recientes** (agrupadas por día), **Buzón** y **Más**.
- **Pantalla de llamada** propia: contestar, rechazar, rechazar con mensaje, silenciar, teclado, altavoz, agregar, espera, Bluetooth; fondo, video y tono propios.
- **Bloqueo de llamadas** (Más > Bloqueo de llamadas): desconocidos, serie 500, ocultos, internacionales, prefijos, lista propia, base en línea y registro.

## Base de datos en línea (carpeta `servidor`)

1. En tu hosting crea una base MySQL y ejecuta `schema.sql`.
2. Edita los datos de conexión y la clave al inicio de `spam_api.php` y súbelo. Debe abrirse por **https**.
3. En la app: Spam > Servidor, escribe la dirección y la clave, y toca **Probar conexión**.

La base empieza vacía y se llena con los reportes hechos desde la app.

## Archivos

- `lib/`: interfaz (Flutter). `test/`: pruebas Dart.
- `android/kotlin/`: llamadas, contactos y motor de spam (`Spam.kt` tiene las reglas, en orden). `android/test/`: pruebas Kotlin.
- `android/app/src/main/AndroidManifest.xml`: permisos y servicios.
- `servidor/`: API de spam (PHP + MySQL).
- `docs/`: arquitectura y auditorías.
