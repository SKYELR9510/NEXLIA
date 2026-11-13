import 'package:flutter/foundation.dart';

import '../native.dart';
import 'models.dart';
import 'store.dart';

/// Origen de SMS: el proveedor de Android. NEXLIA solo lee.
/// [threads] y [messages] lanzan [SmsReadException] si la lectura falla.
abstract class SmsSource {
  Future<SmsPermission> permission();
  Future<bool> requestPermission();
  Future<List<SmsThread>> threads();
  Future<List<SmsMessage>> messages(String threadId);
  Future<SmsSimInfo> sims();

  /// Abre la app de SMS del sistema con el destinatario (acción del usuario).
  Future<bool> openComposer(String address);
}

class NativeSmsSource implements SmsSource {
  const NativeSmsSource();
  @override
  Future<SmsPermission> permission() => Native.smsPermission();
  @override
  Future<bool> requestPermission() => Native.requestSmsPermission();
  @override
  Future<List<SmsThread>> threads() => Native.getSmsThreads();
  @override
  Future<List<SmsMessage>> messages(String threadId) => Native.getSmsMessages(threadId);
  @override
  Future<SmsSimInfo> sims() => Native.getSimSubscriptions();
  @override
  Future<bool> openComposer(String address) => Native.sendSms(address);
}

/// Bandeja SMS de solo lectura. No guarda SMS: el teléfono es la fuente de verdad.
///
/// Leer exige dos cosas: el permiso READ_SMS de Android y el consentimiento dado
/// dentro de NEXLIA. El permiso solo no basta: Android lo concede automáticamente
/// a la app de Teléfono predeterminada (rol DIALER), sin que el usuario lo pida.
class SmsRepository extends ChangeNotifier {
  SmsRepository(this.source, {KeyValueStore? store}) : store = store ?? MemoryStore();

  /// Única clave que guarda este repositorio: "1" si el usuario aceptó ver sus SMS.
  static const consentKey = 'sms.consent.v1';

  final SmsSource source;
  final KeyValueStore store;
  SmsPermission permission = SmsPermission.unavailable;
  bool consent = false;
  List<SmsThread> threads = const [];
  SmsSimInfo sims = SmsSimInfo.none;
  bool loaded = false;

  /// Último error de lectura (null si la última lectura fue bien o no se leyó).
  SmsReadErrorKind? error;

  Future<void>? _loading;
  bool _again = false;

  /// Solo se leen SMS con permiso de Android y consentimiento en la app.
  bool get canRead => consent && permission == SmsPermission.granted;

  /// El usuario aceptó en NEXLIA, pero el permiso de Android ya no está (retirado en Ajustes).
  bool get permissionRevoked => consent && permission == SmsPermission.denied;

  /// Carga permiso, consentimiento, SIM e hilos. Si ya hay una carga en curso, no
  /// lanza otra en paralelo: la repite al terminar, para no pisar datos más nuevos.
  Future<void> load() {
    if (_loading != null) {
      _again = true;
      return _loading!;
    }
    return _loading = _run();
  }

  Future<void> _run() async {
    try {
      do {
        _again = false;
        await _loadOnce();
      } while (_again);
    } finally {
      _loading = null;
    }
  }

  Future<void> _loadOnce() async {
    permission = await source.permission();
    consent = await store.read(consentKey) == '1';
    error = null;
    if (canRead) {
      sims = await source.sims();
      try {
        threads = await source.threads();
      } on SmsReadException catch (e) {
        threads = const [];
        error = e.kind;
        if (e.kind == SmsReadErrorKind.permission) permission = SmsPermission.denied;
        if (e.kind == SmsReadErrorKind.unavailable) permission = SmsPermission.unavailable;
      }
    } else {
      threads = const [];
    }
    loaded = true;
    notifyListeners();
  }

  /// Solo desde el botón de la tarjeta de SMS o el interruptor de Más > Mensajes.
  /// Registra el consentimiento y, si Android aún no dio el permiso, lo pide.
  Future<bool> requestAccess() async {
    await store.write(consentKey, '1');
    if (await source.permission() != SmsPermission.granted) {
      await source.requestPermission();
    }
    await load();
    return canRead;
  }

  /// Deja de mostrar SMS en NEXLIA (el permiso de Android se quita en Ajustes).
  Future<void> revoke() async {
    await store.write(consentKey, '0');
    await load();
  }

  /// Mensajes de un hilo. Lanza [SmsReadException] si la lectura falla.
  Future<List<SmsMessage>> messagesOf(String threadId) async {
    if (!canRead) return const [];
    return source.messages(threadId);
  }

  /// Etiqueta de la SIM de un SMS (ver [simLabelFor]).
  String simLabel(int subId) => simLabelFor(sims, subId);

  Future<bool> reply(String address) => source.openComposer(address);
}
