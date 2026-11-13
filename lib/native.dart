import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'messaging/models.dart';

class Contact {
  Contact(this.id, this.name, this.numbers, this.starred, this.hasPhoto);
  final String id;
  final String name;
  final List<String> numbers;
  bool starred;
  final bool hasPhoto;
}

/// Cuenta telefónica (normalmente una SIM).
class SimInfo {
  SimInfo(this.key, this.label, this.number, this.slot);
  final String key;
  final String label;
  final String number;
  final int slot;

  static SimInfo fromMap(Map m) => SimInfo(
        (m['key'] ?? '').toString(),
        (m['label'] ?? '').toString(),
        (m['number'] ?? '').toString(),
        (m['slot'] as num?)?.toInt() ?? 0,
      );
}

class CallEntry {
  CallEntry(this.id, this.number, this.name, this.type, this.date, this.duration,
      {this.account = ''});
  final int id;
  final String number;
  final String name;

  /// 1 entrante, 2 saliente, 3 perdida, 5 rechazada, 6 bloqueada
  final int type;
  final DateTime date;
  final int duration;

  /// Cuenta telefónica con la que se hizo o recibió la llamada ('' si el sistema no la informa).
  final String account;

  bool get missed => type == 3 || type == 5 || type == 6;
}

String digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

/// Dos números son el mismo si coinciden sus últimos 9 dígitos.
bool sameNumber(String a, String b) {
  final x = digits(a), y = digits(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x.length >= 9 && y.length >= 9) {
    return x.substring(x.length - 9) == y.substring(y.length - 9);
  }
  return x == y;
}

/// Puente con la parte nativa (Kotlin).
class Native {
  static const _ch = MethodChannel('nexlia/phone');
  static const _ev = EventChannel('nexlia/phone/events');

  static final Stream<Map<dynamic, dynamic>> events =
      _ev.receiveBroadcastStream().map((e) => Map<dynamic, dynamic>.from(e as Map));

  static Future<bool> _bool(String m, [Map<String, dynamic>? a]) async {
    try {
      return (await _ch.invokeMethod<bool>(m, a)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isDefaultDialer() => _bool('isDefaultDialer');
  static Future<bool> requestDefaultDialer() => _bool('requestDefaultDialer');
  static Future<bool> requestPermissions() => _bool('requestPermissions');
  /// Inicia la llamada. Con [account] se fuerza esa SIM (EXTRA_PHONE_ACCOUNT_HANDLE);
  /// sin ella se llama exactamente como antes. Devuelve 'ok', 'sim_unavailable' o 'error'.
  static Future<String> placeCall(String number, {String account = ''}) async {
    try {
      final ok = await _ch.invokeMethod<bool>(
          'placeCall', {'number': number, if (account.isNotEmpty) 'account': account});
      return ok == true ? 'ok' : 'error';
    } on PlatformException catch (e) {
      return e.code == 'sim_unavailable' ? 'sim_unavailable' : 'error';
    } catch (_) {
      return 'error';
    }
  }
  static Future<bool> deleteCallLog(int id) => _bool('deleteCallLog', {'id': id});
  static Future<bool> addContact(String name, String number) =>
      _bool('addContact', {'name': name, 'number': number});
  static Future<bool> deleteContact(String id) => _bool('deleteContact', {'id': id});
  static Future<bool> setStarred(String id, bool starred) =>
      _bool('setStarred', {'id': id, 'starred': starred});

  static final Map<String, Future<Uint8List?>> _photos = {};

  /// Foto del contacto (miniatura, o grande si [big]). Se guarda en memoria.
  static Future<Uint8List?> contactPhoto(String id, {bool big = false}) {
    return _photos.putIfAbsent('$id/$big', () async {
      try {
        return await _ch.invokeMethod<Uint8List>('getContactPhoto', {'id': id, 'big': big});
      } catch (_) {
        return null;
      }
    });
  }

  static Future<bool> answer() => _bool('answer');
  static Future<bool> hangup() => _bool('hangup');
  static Future<bool> toggleHold() => _bool('toggleHold');
  static Future<bool> setMuted(bool on) => _bool('setMuted', {'on': on});
  static Future<bool> setSpeaker(bool on) => _bool('setSpeaker', {'on': on});
  static Future<bool> rejectWithMessage(String text) => _bool('rejectWithMessage', {'text': text});
  static Future<bool> sendSms(String number) => _bool('sendSms', {'number': number});
  static Future<bool> openWhatsApp(String number) => _bool('openWhatsApp', {'number': number});
  static Future<bool> selectPhoneAccount(String key) =>
      _bool('selectPhoneAccount', {'key': key});

  static Future<List<SimInfo>> getSimAccounts() async {
    try {
      final rows = await _ch.invokeMethod<List<dynamic>>('getSimAccounts') ?? [];
      return rows.map((r) => SimInfo.fromMap(r as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> swapCalls() => _bool('swapCalls');
  static Future<bool> mergeCalls() => _bool('mergeCalls');
  static Future<bool> setBluetooth(bool on) => _bool('setBluetooth', {'on': on});
  static Future<bool> dtmf(String digit) => _bool('dtmf', {'digit': digit});

  static Future<Map<dynamic, dynamic>> getCallState() async {
    try {
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('getCallState');
      return r ?? {'state': 'none'};
    } catch (_) {
      return {'state': 'none'};
    }
  }

  static Future<String?> takeDialNumber() async {
    try {
      return await _ch.invokeMethod<String>('takeDialNumber');
    } catch (_) {
      return null;
    }
  }

  static Future<List<Contact>> getContacts() async {
    final byId = <String, Contact>{};
    try {
      final rows = await _ch.invokeMethod<List<dynamic>>('getContacts') ?? [];
      for (final r in rows) {
        final m = r as Map;
        final id = m['id'] as String;
        final number = (m['number'] as String).trim();
        final c = byId.putIfAbsent(
            id, () => Contact(id, m['name'] as String, [], m['starred'] == true, m['photo'] == true));
        if (number.isNotEmpty && !c.numbers.any((n) => sameNumber(n, number))) {
          c.numbers.add(number);
        }
      }
    } catch (_) {}
    final list = byId.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  static Future<List<CallEntry>> getCallLog() async {
    final out = <CallEntry>[];
    try {
      final rows = await _ch.invokeMethod<List<dynamic>>('getCallLog') ?? [];
      for (final r in rows) {
        final m = r as Map;
        out.add(CallEntry(
          (m['id'] as num).toInt(),
          m['number'] as String,
          m['name'] as String,
          (m['callType'] as num).toInt(),
          DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),
          (m['duration'] as num).toInt(),
          account: (m['account'] ?? '').toString(),
        ));
      }
    } catch (_) {}
    return out;
  }

  static Future<String?> getPref(String key) async {
    try {
      return await _ch.invokeMethod<String>('getPref', {'key': key});
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setPref(String key, String value) =>
      _bool('setPref', {'key': key, 'value': value});
  static Future<bool> callVoicemail() => _bool('callVoicemail');
  static Future<bool> openSettings(String which) => _bool('openSettings', {'which': which});

  /// Abre la galería y devuelve la ruta de la copia guardada, o null si se canceló.
  static Future<String?> pickMedia(String kind) async {
    try {
      return await _ch.invokeMethod<String>('pickMedia', {'kind': kind});
    } catch (_) {
      return null;
    }
  }

  static Future<bool> removeMedia(String kind) => _bool('removeMedia', {'kind': kind});
  static Future<bool> ringerNormal() => _bool('ringerNormal');
  static Future<bool> silenceRinger() => _bool('silenceRinger');

  static Future<String> getVersion() async {
    try {
      return await _ch.invokeMethod<String>('getVersion') ?? '';
    } catch (_) {
      return '';
    }
  }

  // ---- SMS (solo lectura; la mensajería los usa a través de SmsRepository) ----

  static Future<SmsPermission> smsPermission() async {
    try {
      final s = await _ch.invokeMethod<String>('smsPermission');
      return s == 'granted' ? SmsPermission.granted : SmsPermission.denied;
    } catch (_) {
      return SmsPermission.unavailable;
    }
  }

  static Future<bool> requestSmsPermission() => _bool('requestSmsPermission');

  static Future<List<SmsThread>> getSmsThreads() async {
    try {
      final rows = await _ch.invokeMethod<List<dynamic>>('getSmsThreads') ?? [];
      return rows.whereType<Map>().map(SmsThread.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<SmsMessage>> getSmsMessages(String threadId) async {
    try {
      final rows =
          await _ch.invokeMethod<List<dynamic>>('getSmsMessages', {'threadId': threadId}) ?? [];
      return rows.whereType<Map>().map(SmsMessage.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<SimSubscription>> getSimSubscriptions() async {
    try {
      final rows = await _ch.invokeMethod<List<dynamic>>('getSimSubscriptions') ?? [];
      return rows.whereType<Map>().map(SimSubscription.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  // ---- Bloqueador de spam ----

  static Future<Map<String, dynamic>> getSpamData() async {
    try {
      final s = await _ch.invokeMethod<String>('getSpamData');
      return jsonDecode(s ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<bool> setSpamSettings(Map<String, dynamic> s) =>
      _bool('setSpamSettings', {'json': jsonEncode(s)});
  static Future<bool> setBlocked(List<String> list) =>
      _bool('setBlocked', {'json': jsonEncode(list)});
  static Future<bool> clearSpamLog() => _bool('clearSpamLog');
  static Future<bool> reportSpam(String number, String label) =>
      _bool('reportSpam', {'number': number, 'label': label});

  static Future<String> testServer() async {
    try {
      return await _ch.invokeMethod<String>('testServer') ?? '';
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<List<String>> getBlocked() async {
    final d = await getSpamData();
    return ((d['blocked'] as List?) ?? []).map((e) => e.toString()).toList();
  }

  static Future<void> blockNumber(String number) async {
    final list = await getBlocked();
    if (!list.any((n) => sameNumber(n, number))) list.insert(0, number);
    await setBlocked(list);
  }

  static Future<void> unblockNumber(String number) async {
    final list = await getBlocked();
    list.removeWhere((n) => sameNumber(n, number) || n == number);
    await setBlocked(list);
  }
}

/// Contactos y registro de llamadas cargados en memoria.
class AppData extends ChangeNotifier {
  AppData._();
  static final AppData i = AppData._();

  List<Contact> contacts = [];
  List<CallEntry> calls = [];
  List<SimInfo> sims = [];
  bool isDefault = true;

  Future<void> reload() async {
    isDefault = await Native.isDefaultDialer();
    sims = await Native.getSimAccounts();
    contacts = await Native.getContacts();
    calls = await Native.getCallLog();
    notifyListeners();
  }

  /// Etiqueta de la SIM de una llamada. Vacía con una sola SIM, para no cambiar esa vista.
  String simLabel(String account) {
    if (sims.length < 2 || account.isEmpty) return '';
    for (final s in sims) {
      if (s.key == account) return s.label;
    }
    return '';
  }

  Contact? contactFor(String number) {
    for (final c in contacts) {
      if (c.numbers.any((n) => sameNumber(n, number))) return c;
    }
    return null;
  }
}
