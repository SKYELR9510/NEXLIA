import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Contact {
  Contact(this.id, this.name, this.numbers, this.starred);
  final String id;
  final String name;
  final List<String> numbers;
  bool starred;
}

class CallEntry {
  CallEntry(this.id, this.number, this.name, this.type, this.date, this.duration);
  final int id;
  final String number;
  final String name;

  /// 1 entrante, 2 saliente, 3 perdida, 5 rechazada, 6 bloqueada
  final int type;
  final DateTime date;
  final int duration;

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
  static const _ch = MethodChannel('livak/phone');
  static const _ev = EventChannel('livak/phone/events');

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
  static Future<bool> placeCall(String number) => _bool('placeCall', {'number': number});
  static Future<bool> deleteCallLog(int id) => _bool('deleteCallLog', {'id': id});
  static Future<bool> addContact(String name, String number) =>
      _bool('addContact', {'name': name, 'number': number});
  static Future<bool> deleteContact(String id) => _bool('deleteContact', {'id': id});
  static Future<bool> setStarred(String id, bool starred) =>
      _bool('setStarred', {'id': id, 'starred': starred});

  static Future<bool> answer() => _bool('answer');
  static Future<bool> hangup() => _bool('hangup');
  static Future<bool> toggleHold() => _bool('toggleHold');
  static Future<bool> setMuted(bool on) => _bool('setMuted', {'on': on});
  static Future<bool> setSpeaker(bool on) => _bool('setSpeaker', {'on': on});
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
            id, () => Contact(id, m['name'] as String, [], m['starred'] == true));
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
        ));
      }
    } catch (_) {}
    return out;
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
  bool isDefault = true;

  Future<void> reload() async {
    isDefault = await Native.isDefaultDialer();
    contacts = await Native.getContacts();
    calls = await Native.getCallLog();
    notifyListeners();
  }

  Contact? contactFor(String number) {
    for (final c in contacts) {
      if (c.numbers.any((n) => sameNumber(n, number))) return c;
    }
    return null;
  }
}
