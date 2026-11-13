// SMS de solo lectura: sin permiso no se lee; el canal nativo se interpreta bien.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/messaging/models.dart';
import 'package:phone/messaging/sms_repository.dart';
import 'package:phone/native.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nexlia/phone');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sin permiso: no se leen SMS ni se pide permiso al cargar', () async {
    final src = FakeSmsSource(perm: SmsPermission.denied);
    final r = SmsRepository(src);
    await r.load();
    expect(r.threads, isEmpty);
    expect(src.reads, 0);
    expect(src.requests, 0);
    expect(await r.messagesOf('1'), isEmpty);
    expect(src.reads, 0);
  });

  test('el usuario concede el permiso: se leen los hilos', () async {
    final src = FakeSmsSource(perm: SmsPermission.denied)
      ..data = [SmsThread(threadId: '1', address: '+51900000001', snippet: 'x', date: DateTime(2026))];
    final r = SmsRepository(src);
    await r.load();
    expect(await r.requestAccess(), isTrue);
    expect(r.threads.length, 1);
  });

  test('el usuario lo deniega: sigue sin leer', () async {
    final src = FakeSmsSource(perm: SmsPermission.denied, grantOnRequest: false);
    final r = SmsRepository(src);
    expect(await r.requestAccess(), isFalse);
    expect(src.reads, 0);
  });

  test('responder abre la app de SMS del sistema (NEXLIA no envía)', () async {
    final src = FakeSmsSource(perm: SmsPermission.granted);
    final r = SmsRepository(src);
    await r.reply('+51900000001');
    expect(src.composed, ['+51900000001']);
  });

  test('etiqueta de SIM: vacía con una sola SIM', () async {
    final src = FakeSmsSource(perm: SmsPermission.granted)..sims = [const SimSubscription(1, 'Movistar', 1)];
    final r = SmsRepository(src);
    await r.load();
    expect(r.simLabel(1), '');
  });

  test('canal nativo: permiso, hilos, mensajes y SIM', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'smsPermission':
          return 'granted';
        case 'getSmsThreads':
          return [
            {'threadId': '5', 'address': '+51900000005', 'snippet': 'hola', 'date': 1700000000000, 'unreadCount': 2, 'subId': 3}
          ];
        case 'getSmsMessages':
          expect(call.arguments, {'threadId': '5'});
          return [
            {'id': '9', 'threadId': '5', 'address': '+51900000005', 'body': 'hola', 'date': 1700000000000, 'type': 2, 'read': true, 'subId': 3}
          ];
        case 'getSimSubscriptions':
          return [
            {'subId': 3, 'label': 'Claro', 'slot': 2}
          ];
      }
      return null;
    });
    expect(await Native.smsPermission(), SmsPermission.granted);
    final t = (await Native.getSmsThreads()).single;
    expect((t.threadId, t.unreadCount, t.subId), ('5', 2, 3));
    final m = (await Native.getSmsMessages('5')).single;
    expect(m.box, SmsBox.sent);
    expect(m.incoming, isFalse);
    expect((await Native.getSimSubscriptions()).single.label, 'Claro');
  });

  test('canal nativo con error: permiso "no disponible" y listas vacías', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'x'));
    expect(await Native.smsPermission(), SmsPermission.unavailable);
    expect(await Native.getSmsThreads(), isEmpty);
    expect(await Native.requestSmsPermission(), isFalse);
  });

  test('canal nativo: "denied" se respeta', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 'denied');
    expect(await Native.smsPermission(), SmsPermission.denied);
  });
}
