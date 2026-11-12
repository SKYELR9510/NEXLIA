// Contrato del puente Dart con Kotlin ante solicitudes simultáneas y cancelaciones.
// Simula el canal nativo: las respuestas llegan en otro orden y algunas fallan.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nexlia/phone');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('permisos y rol pedidos a la vez: ambos Future terminan con su propio resultado', () async {
    final perms = Completer<Object?>();
    final role = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (call) {
      if (call.method == 'requestPermissions') return perms.future;
      if (call.method == 'requestDefaultDialer') return role.future;
      return Future.value(null);
    });

    final a = Native.requestPermissions();
    final b = Native.requestDefaultDialer();
    // El sistema responde en el orden inverso.
    role.complete(true);
    perms.complete(false);

    expect(await b, isTrue);
    expect(await a, isFalse);
  });

  test('dos solicitudes iguales a la vez reciben la misma respuesta', () async {
    final perms = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (call) => perms.future);

    final a = Native.requestPermissions();
    final b = Native.requestPermissions();
    perms.complete(true);

    expect(await Future.wait([a, b]), [true, true]);
  });

  test('pantalla cerrada antes de responder ("cancelled"): devuelve false, no se queda esperando',
      () async {
    messenger.setMockMethodCallHandler(
        channel, (call) async => throw PlatformException(code: 'cancelled'));
    expect(await Native.requestDefaultDialer().timeout(const Duration(seconds: 1)), isFalse);
  });

  test('selector ya abierto ("busy"): pickMedia devuelve null', () async {
    messenger.setMockMethodCallHandler(
        channel, (call) async => throw PlatformException(code: 'busy'));
    expect(await Native.pickMedia('image').timeout(const Duration(seconds: 1)), isNull);
  });
}
