// Selector de SIM en la pantalla de llamada y etiqueta de SIM en el historial.
// Simula el canal nativo; no requiere teléfono.
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/call_screen.dart';
import 'package:phone/native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nexlia/phone');
  const events = EventChannel('nexlia/phone/events');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (args, sink) {}));
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockStreamHandler(events, null);
    AppData.i.sims = [];
  });

  Future<void> pumpCall(WidgetTester tester, Map<String, Object?> state) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(CupertinoApp(home: CallScreen(initial: state)));
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('con SELECT_PHONE_ACCOUNT se muestra el selector y se envía la SIM elegida',
      (tester) async {
    await pumpCall(tester, {
      'type': 'call',
      'state': 'selectAccount',
      'number': '981323499',
      'accounts': [
        {'key': 'tel|1', 'label': 'Claro', 'number': '', 'slot': 1},
        {'key': 'tel|2', 'label': 'Movistar', 'number': '987000111', 'slot': 2},
      ],
    });

    expect(find.text('Elige una SIM'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Movistar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Silenciar'), findsNothing);

    await tester.tap(find.text('Movistar'));
    await tester.pump();
    final sel = calls.where((c) => c.method == 'selectPhoneAccount').toList();
    expect(sel, hasLength(1));
    expect(sel.single.arguments, {'key': 'tel|2'});

    // El botón rojo (debajo dice "Cancelar") cuelga la llamada en espera de SIM.
    await tester.tap(find.byIcon(CupertinoIcons.phone_down_fill));
    await tester.pump();
    expect(calls.any((c) => c.method == 'hangup'), isTrue);
    await unmount(tester);
  });

  testWidgets('llamada normal (una SIM): sin selector y con los controles de siempre',
      (tester) async {
    await pumpCall(tester, {
      'type': 'call',
      'state': 'dialing',
      'number': '981323499',
      'sim': '',
      'accounts': <Object>[],
    });

    expect(find.text('Llamando…'), findsOneWidget);
    expect(find.text('¿Con qué SIM quieres llamar?'), findsNothing);
    expect(find.text('Silenciar'), findsOneWidget);
    expect(find.text('Finalizar'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('llamada en curso con doble SIM muestra la etiqueta de la SIM', (tester) async {
    await pumpCall(tester, {
      'type': 'call',
      'state': 'dialing',
      'number': '981323499',
      'sim': 'Movistar',
    });
    expect(find.text('Movistar'), findsOneWidget);
    await unmount(tester);
  });

  group('AppData.simLabel', () {
    test('con una SIM no se muestra etiqueta', () {
      AppData.i.sims = [SimInfo('a|1', 'Claro', '', 1)];
      expect(AppData.i.simLabel('a|1'), '');
    });

    test('con dos SIM se muestra la de la llamada', () {
      AppData.i.sims = [SimInfo('a|1', 'Claro', '', 1), SimInfo('a|2', 'Movistar', '', 2)];
      expect(AppData.i.simLabel('a|2'), 'Movistar');
      expect(AppData.i.simLabel('a|9'), '');
      expect(AppData.i.simLabel(''), '');
    });
  });

  test('CallEntry sin cuenta conserva el constructor anterior', () {
    final e = CallEntry(1, '1', '', 2, DateTime(2026), 0);
    expect(e.account, '');
  });
}
