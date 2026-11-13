import '../native.dart';

/// Almacenamiento clave-valor. Cada canal usa sus propias claves.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Preferencias nativas de la app (las mismas que usa el resto de NEXLIA).
class NativePrefsStore implements KeyValueStore {
  const NativePrefsStore();
  @override
  Future<String?> read(String key) => Native.getPref(key);
  @override
  Future<void> write(String key, String value) => Native.setPref(key, value);
}

/// En memoria (pruebas).
class MemoryStore implements KeyValueStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
}
