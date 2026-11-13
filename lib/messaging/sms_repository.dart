import 'package:flutter/foundation.dart';

import '../native.dart';
import 'models.dart';

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

/// Bandeja SMS de solo lectura. No guarda nada: el teléfono es la fuente de verdad.
class SmsRepository extends ChangeNotifier {
  SmsRepository(this.source);

  final SmsSource source;
  SmsPermission permission = SmsPermission.unavailable;
  List<SmsThread> threads = const [];
  List<SimSubscription> subscriptions = const [];
  bool loaded = false;

  /// Sin permiso no se llama a la lectura de SMS.
  Future<void> load() async {
    permission = await source.permission();
    if (permission == SmsPermission.granted) {
      subscriptions = await source.subscriptions();
      threads = await source.threads();
    } else {
      threads = const [];
    }
    loaded = true;
    notifyListeners();
  }

  /// Solo desde el botón "Permitir lectura de SMS".
  Future<bool> requestAccess() async {
    final ok = await source.requestPermission();
    await load();
    return ok && permission == SmsPermission.granted;
  }

  Future<List<SmsMessage>> messagesOf(String threadId) async {
    if (permission != SmsPermission.granted) return const [];
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
