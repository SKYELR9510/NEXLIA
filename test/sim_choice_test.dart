// Regla de decisión previa a la llamada (sin canal nativo).
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/native.dart';
import 'package:phone/sim_choice.dart';

void main() {
  final claro = SimInfo('tel|1', 'Claro', '', 1);
  final movistar = SimInfo('tel|2', 'Movistar', '', 2);

  test('sin cuentas legibles (p. ej. sin permiso): se llama como siempre', () {
    expect(decideSim([], simAsk).kind, SimDecisionKind.direct);
  });

  test('una SIM: nunca pregunta, aunque haya una preferencia guardada', () {
    expect(decideSim([claro], simAsk).kind, SimDecisionKind.direct);
    expect(decideSim([claro], 'tel|2').kind, SimDecisionKind.direct);
  });

  test('dos SIM sin preferencia o con "preguntar siempre": pregunta', () {
    expect(decideSim([claro, movistar], '').kind, SimDecisionKind.ask);
    final d = decideSim([claro, movistar], simAsk);
    expect(d.kind, SimDecisionKind.ask);
    expect(d.staleSaved, isFalse);
  });

  test('dos SIM con una guardada y disponible: usa esa', () {
    final d = decideSim([claro, movistar], 'tel|2');
    expect(d.kind, SimDecisionKind.useSaved);
    expect(d.account, 'tel|2');
  });

  test('SIM guardada desactivada o retirada: pregunta y avisa', () {
    final d = decideSim([claro, movistar], 'tel|3');
    expect(d.kind, SimDecisionKind.ask);
    expect(d.staleSaved, isTrue);
  });
}
