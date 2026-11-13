import 'package:flutter/foundation.dart';

import '../native.dart';
import 'models.dart';
import 'store.dart';

/// Origen de SMS: el proveedor de Android. NEXLIA solo lee.
abstract class SmsSource {
  Future<SmsPermission> permission();
  Future<bool> requestPermission();
  Future<List<SmsThread>> threads();
  Future<List<SmsMessage>> messages(String threadId);
  Future<List<SimSubscription>> subscriptions();

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
  Future<List<SimSubscription>> subscriptions() => Native.getSimSubscriptions();
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
  List<SimSubscription> subscriptions = const [];
  bool loaded = false;

  /// Solo se leen SMS con permiso de Android y consentimiento en la app.
  bool get canRead => consent && permission == SmsPermission.granted;

  Future<void> load() async {
    permission = await source.permission();
    consent = await store.read(consentKey) == '1';
    if (canRead) {
      subscriptions = await source.subscriptions();
      threads = await source.threads();
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

  Future<List<SmsMessage>> messagesOf(String threadId) async {
    if (!canRead) return const [];
    return source.messages(threadId);
  }

  /// Etiqueta de SIM solo con dos o más SIM (igual que en llamadas).
  String simLabel(int subId) {
    if (subscriptions.length < 2 || subId < 0) return '';
    for (final s in subscriptions) {
      if (s.subId == subId) return s.label.isEmpty ? 'SIM ${s.slot}' : s.label;
    }
    return '';
  }

  Future<bool> reply(String address) => source.openComposer(address);
}
