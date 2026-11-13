// Pruebas de caracterización (Fase 0) de los formatos que se muestran en pantalla.
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/common.dart';
import 'package:phone/native.dart';

void main() {
  test('initials', () {
    expect(initials('Ana María López'), 'AL');
    expect(initials('  sintia  '), 'S');
    expect(initials(''), '#');
    expect(initials('ñandú'), 'Ñ');
  });

  test('formatDuration', () {
    expect(formatDuration(0), '00:00');
    expect(formatDuration(65), '01:05');
    expect(formatDuration(3661), '1:01:01');
  });

  test('formatTime en 12 horas', () {
    expect(formatTime(DateTime(2026, 11, 12, 0, 5)), '12:05 a. m.');
    expect(formatTime(DateTime(2026, 11, 12, 9, 7)), '9:07 a. m.');
    expect(formatTime(DateTime(2026, 11, 12, 13, 0)), '1:00 p. m.');
  });

  test('callKind', () {
    CallEntry e(int type) => CallEntry(1, '1', '', type, DateTime(2026), 0);
    expect(callKind(e(1)), 'Entrante');
    expect(callKind(e(2)), 'Saliente');
    expect(callKind(e(3)), 'Perdida');
    expect(callKind(e(5)), 'Rechazada');
    expect(callKind(e(6)), 'Bloqueada');
    expect(callKind(e(4)), 'Llamada');
  });
}
