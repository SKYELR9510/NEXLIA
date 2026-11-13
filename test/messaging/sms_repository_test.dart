// SMS de solo lectura: sin permiso no se lee; el canal nativo se interpreta bien.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/messaging/models.dart';
import 'package:phone/messaging/sms_repository.dart';
import 'package:phone/messaging/store.dart';
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

  test('el usuario concede el permiso: se guarda el consentimiento y se leen los hilos', () async {
    final src = FakeSmsSource(perm: SmsPermission.denied)
      ..data = [SmsThread(threadId: '1', address: '+51900000001', snippet: 'x', date: DateTime(2026))];
    final store = MemoryStore();
    final r = SmsRepository(src, store: store);
    await r.load();
    expect(await r.requestAccess(), isTrue);
    expect(src.requests, 1);
    expect(r.threads.length, 1);
    expect(store.data[SmsRepository.consentKey], '1');
  });

  test('permiso dado por el rol de Teléfono sin consentimiento en la app: no se lee nada', () async {
    final src = FakeSmsSource(perm: SmsPermission.granted)
      ..data = [SmsThread(threadId: '1', address: '+51900000001', snippet: 'x', date: DateTime(2026))];
    final r = SmsRepository(src, store: MemoryStore());
    await r.load();
    expect(r.canRead, isFalse);
    expect(r.threads, isEmpty);
    expect(await r.messagesOf('1'), isEmpty);
    expect(src.reads, 0);
  });

  test('con el permiso ya concedido, confirmar en la app no vuelve a pedirlo', () async {
    final src = FakeSmsSource(perm: SmsPermission.granted)
      ..data = [SmsThread(threadId: '1', address: '+51900000001', snippet: 'x', date: DateTime(2026))];
    final r = SmsRepository(src, store: MemoryStore());
    expect(await r.requestAccess(), isTrue);
    expect(src.requests, 0);
    expect(r.threads.length, 1);
  });

  test('desactivar: deja de leer y lo recuerda', () async {
    final src = FakeSmsSource(perm: SmsPermission.granted)
      ..data = [SmsThread(threadId: '1', address: '+51900000001', snippet: 'x', date: DateTime(2026))];
    final store = consented();
    final r = SmsRepository(src, store: store);
    await r.load();
    expect(r.threads.length, 1);
    await r.revoke();
    expect(r.threads, isEmpty);
    final again = SmsRepository(src, store: store);
    await again.load();
    expect(again.canRead, isFalse);
  });

  test('consentimiento sin permiso de Android (quitado en Ajustes): no se lee', () async {
    final src = FakeSmsSource(perm: SmsPermission.denied);
    final r = SmsRepository(src, store: consented());
    await r.load();
    expect(r.canRead, isFalse);
    expect(src.reads, 0);
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

  test('etiqueta de SIM: vacía en un teléfono de una sola ranura', () async {
    final src = FakeSmsSource(perm: SmsPermission.granted)
      ..simInfo = const SmsSimInfo(slots: 1, active: [SimSubscription(1, 'Movistar', 1)]);
    final r = SmsRepository(src, store: consented());
    await r.load();
    expect(r.simLabel(1), '');
    expect(r.simLabel(-1), '');
  });

  group('SIM no identificada (Android no da información fiable)', () {
    const two = SmsSimInfo(slots: 2, active: [SimSubscription(4, 'Claro', 1), SimSubscription(7, 'Bitel', 2)]);
    test('SIM activa: ranura y operador', () {
      expect(simLabelFor(two, 4), 'SIM 1 · Claro');
      expect(simLabelFor(two, 7), 'SIM 2 · Bitel');
    });
    test('sin sub_id (fabricante sin la columna o valor inválido)', () {
      expect(simLabelFor(two, -1), simUnknown);
    });
    test('SIM retirada o desactivada: su sub_id ya no está activo', () {
      expect(simLabelFor(two, 99), simUnknown);
    });
    test('teléfono de dos ranuras sin ninguna SIM activa', () {
      expect(simLabelFor(const SmsSimInfo(slots: 2), 4), simUnknown);
    });
    test('sin permiso para leer las SIM', () {
      expect(simLabelFor(const SmsSimInfo(slots: 2, readable: false), 4), simUnknown);
    });
    test('mismo operador en las dos SIM: solo la ranura', () {
      const same = SmsSimInfo(slots: 2, active: [SimSubscription(1, 'Claro', 1), SimSubscription(2, 'Claro', 2)]);
      expect(simLabelFor(same, 1), 'SIM 1');
      expect(simLabelFor(same, 2), 'SIM 2');
    });
    test('operador vacío o igual al nombre de la ranura', () {
      const s = SmsSimInfo(slots: 2, active: [SimSubscription(1, '', 1), SimSubscription(2, 'SIM 2', 2)]);
      expect(simLabelFor(s, 1), 'SIM 1');
      expect(simLabelFor(s, 2), 'SIM 2');
    });
    test('ranura desconocida (slots 0) pero dos SIM activas: se trata como doble SIM', () {
      const s = SmsSimInfo(active: [SimSubscription(1, 'A', 1), SimSubscription(2, 'B', 2)]);
      expect(simLabelFor(s, 2), 'SIM 2 · B');
      expect(simLabelFor(s, 5), simUnknown);
    });
    test('formato nativo anterior (lista) y actual (mapa)', () {
      expect(SmsSimInfo.fromNative([{'subId': 1, 'label': 'A', 'slot': 1}]).active.single.subId, 1);
      final m = SmsSimInfo.fromNative({
        'slots': 2,
        'readable': false,
        'subs': [{'subId': 3, 'label': 'B', 'slot': 2}]
      });
      expect((m.slots, m.readable, m.active.single.slot), (2, false, 2));
      expect(SmsSimInfo.fromNative(null).multiSim, isFalse);
    });
  });

  group('errores de lectura', () {
    SmsThread t(String id) => SmsThread(threadId: id, address: '+5190000000$id', snippet: 'x', date: DateTime(2026));

    test('el proveedor falla: error visible y sin hilos; al reintentar se recupera', () async {
      final src = FakeSmsSource(perm: SmsPermission.granted)
        ..data = [t('1')]
        ..failWith = const SmsReadException(SmsReadErrorKind.provider, 'cursor nulo');
      final r = SmsRepository(src, store: consented());
      await r.load();
      expect(r.error, SmsReadErrorKind.provider);
      expect(r.threads, isEmpty);
      expect(r.canRead, isTrue, reason: 'no se confunde con falta de permiso');
      src.failWith = null;
      await r.load();
      expect(r.error, isNull);
      expect(r.threads.length, 1);
    });

    test('permiso retirado durante la lectura: pasa a "sin permiso" y no reintenta solo', () async {
      final src = FakeSmsSource(perm: SmsPermission.granted)
        ..failWith = const SmsReadException(SmsReadErrorKind.permission);
      final r = SmsRepository(src, store: consented());
      await r.load();
      expect(r.permission, SmsPermission.denied);
      expect(r.permissionRevoked, isTrue);
      expect(r.canRead, isFalse);
      expect(src.requests, 0);
    });

    test('permiso retirado en Ajustes: al volver a la app no se lee y se explica', () async {
      final src = FakeSmsSource(perm: SmsPermission.granted)..data = [t('1')];
      final r = SmsRepository(src, store: consented());
      await r.load();
      expect(r.threads.length, 1);
      src.perm = SmsPermission.denied;
      final before = src.reads;
      await r.load();
      expect(r.threads, isEmpty);
      expect(r.permissionRevoked, isTrue);
      expect(src.reads, before);
    });

    test('sin proveedor de SMS: "no disponible"', () async {
      final src = FakeSmsSource(perm: SmsPermission.granted)
        ..failWith = const SmsReadException(SmsReadErrorKind.unavailable);
      final r = SmsRepository(src, store: consented());
      await r.load();
      expect(r.permission, SmsPermission.unavailable);
    });

    test('dispositivo sin mensajería: no se intenta leer', () async {
      final src = FakeSmsSource(perm: SmsPermission.unavailable);
      final r = SmsRepository(src, store: consented());
      await r.load();
      expect(src.reads, 0);
      expect(r.canRead, isFalse);
    });

    test('mensajes de un hilo: el error llega a la pantalla', () async {
      final src = FakeSmsSource(perm: SmsPermission.granted)
        ..failWith = const SmsReadException(SmsReadErrorKind.provider);
      final r = SmsRepository(src, store: consented());
      await r.load();
      await expectLater(r.messagesOf('1'), throwsA(isA<SmsReadException>()));
    });

    test('cargas simultáneas: no se leen en paralelo y la última ve el consentimiento nuevo', () async {
      final src = FakeSmsSource(perm: SmsPermission.granted)
        ..data = [t('1')]
        ..delay = const Duration(milliseconds: 30);
      final store = MemoryStore();
      final r = SmsRepository(src, store: store);
      final a = r.load(); // sin consentimiento todavía
      final b = r.requestAccess(); // el usuario acepta mientras carga
      await Future.wait([a, b]);
      expect(r.canRead, isTrue);
      expect(r.threads.length, 1);
      expect(src.maxActive, 1, reason: 'nunca dos lecturas del proveedor a la vez');
    });
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
          return {
            'slots': 2,
            'readable': true,
            'subs': [
              {'subId': 3, 'label': 'Claro', 'slot': 2}
            ]
          };
      }
      return null;
    });
    expect(await Native.smsPermission(), SmsPermission.granted);
    final t = (await Native.getSmsThreads()).single;
    expect((t.threadId, t.unreadCount, t.subId), ('5', 2, 3));
    final m = (await Native.getSmsMessages('5')).single;
    expect(m.box, SmsBox.sent);
    expect(m.incoming, isFalse);
    final sims = await Native.getSimSubscriptions();
    expect(sims.active.single.label, 'Claro');
    expect(sims.multiSim, isTrue);
  });

  test('canal nativo con error: "no disponible" y la lectura informa el tipo de error', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'x'));
    expect(await Native.smsPermission(), SmsPermission.unavailable);
    await expectLater(Native.getSmsThreads(),
        throwsA(isA<SmsReadException>().having((e) => e.kind, 'kind', SmsReadErrorKind.provider)));
    expect(await Native.requestSmsPermission(), isFalse);
    expect((await Native.getSimSubscriptions()).readable, isFalse, reason: 'las SIM fallan sin bloquear los SMS');
  });

  test('canal nativo: códigos "permission" y "unavailable"', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'permission'));
    await expectLater(Native.getSmsMessages('1'),
        throwsA(isA<SmsReadException>().having((e) => e.kind, 'kind', SmsReadErrorKind.permission)));
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'unavailable'));
    await expectLater(Native.getSmsThreads(),
        throwsA(isA<SmsReadException>().having((e) => e.kind, 'kind', SmsReadErrorKind.unavailable)));
  });

  test('canal nativo: "unavailable" en el permiso (dispositivo sin mensajería)', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 'unavailable');
    expect(await Native.smsPermission(), SmsPermission.unavailable);
  });

  test('canal nativo: "denied" se respeta', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 'denied');
    expect(await Native.smsPermission(), SmsPermission.denied);
  });
}
