// Pruebas de caracterización (Fase 0): fijan el comportamiento ACTUAL de las
// funciones puras de números, para detectar regresiones en fases siguientes.
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/native.dart';

void main() {
  group('digits', () {
    test('deja solo los dígitos', () {
      expect(digits('+51 987-654 321'), '51987654321');
      expect(digits('(01) 234 5678'), '012345678');
      expect(digits(''), '');
    });
  });

  group('sameNumber', () {
    test('coincide por los últimos 9 dígitos', () {
      expect(sameNumber('+51 987 654 321', '987654321'), isTrue);
      expect(sameNumber('0051987654321', '987 654 321'), isTrue);
    });

    test('números cortos se comparan completos', () {
      expect(sameNumber('104', '104'), isTrue);
      expect(sameNumber('104', '1040'), isFalse);
    });

    test('vacíos nunca coinciden', () {
      expect(sameNumber('', ''), isFalse);
      expect(sameNumber('987654321', ''), isFalse);
    });

    test('limitación conocida: distinto país con los mismos 9 dígitos finales coincide', () {
      expect(sameNumber('+51 987654321', '+1 3987654321'), isTrue);
    });
  });

  group('CallEntry.missed', () {
    CallEntry e(int type) => CallEntry(1, '987654321', '', type, DateTime(2026), 0);

    test('perdida, rechazada y bloqueada cuentan como perdidas', () {
      expect(e(3).missed, isTrue);
      expect(e(5).missed, isTrue);
      expect(e(6).missed, isTrue);
    });

    test('entrante y saliente no', () {
      expect(e(1).missed, isFalse);
      expect(e(2).missed, isFalse);
    });
  });
}
