// Selector de SIM ANTES de iniciar la llamada (callNumber) y su preferencia.
// Simula el canal nativo: cuentas, preferencias y placeCall.
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/common.dart';
import 'package:phone/native.dart';
import 'package:phone/sim_choice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nexlia/phone');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const number = '981323499';
  const claro = {'key': 'tel|1', 'label': 'Claro', 'number': '', 'slot': 1};
  const movistar = {'key': 'tel|2', 'label': 'Movistar', 'number': '987000111', 'slot': 2};

  late List<Map<String, Object>> sims;
  late Map<String, String> prefs;
  late List<Map> placed;
  late String unavailableOnce;

  setUp(() {
    sims = [claro, movistar];
    prefs = {};
    placed = [];
    unavailableOnce = '';
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?) ?? {};
      switch (call.method) {
        case 'getSimAccounts':
          return sims;
        case 'getPref':
          return prefs[args['key']];
        case 'setPref':
          prefs[args['key'] as String] = args['value'] as String;
          return true;
        case 'placeCall':
          placed.add(Map.of(args));
          if (unavailableOnce.isNotEmpty && args['account'] == unavailableOnce) {
            unavailableOnce = '';
            throw PlatformException(code: 'sim_unavailable');
          }
          return true;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    AppData.i.sims = [];
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(CupertinoApp(
      home: CupertinoPageScaffold(
        child: Builder(
          builder: (ctx) => Center(
            child: CupertinoButton(
                onPressed: () => callNumber(ctx, number), child: const Text('Llamar')),
          ),
        ),
      ),
    ));
  }

  Future<void> tapCall(WidgetTester tester) async {
    await tester.tap(find.text('Llamar'));
    await tester.pumpAndSettle();
  }

  final picker = find.text('¿Con qué SIM llamas?');

  testWidgets('una SIM: llama directo, sin selector y sin cuenta (igual que antes)',
      (tester) async {
    sims = [claro];
    await pumpApp(tester);
    await tapCall(tester);
    expect(picker, findsNothing);
    expect(placed, [
      {'number': number}
    ]);
  });

  testWidgets('dos SIM: el selector aparece ANTES de llamar y se usa la SIM elegida',
      (tester) async {
    await pumpApp(tester);
    await tapCall(tester);
    expect(picker, findsOneWidget);
    expect(placed, isEmpty, reason: 'no debe llamar antes de elegir');
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Movistar'), findsOneWidget);

    await tester.tap(find.text('Movistar'));
    await tester.pumpAndSettle();
    expect(placed, [
      {'number': number, 'account': 'tel|2'}
    ]);
    expect(prefs[simPrefKey], isNull, reason: 'sin "usar siempre" no se guarda');
  });

  testWidgets('cancelar el selector no llama', (tester) async {
    await pumpApp(tester);
    await tapCall(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(placed, isEmpty);
  });

  testWidgets('"Usar siempre esta SIM" se guarda y la siguiente llamada no pregunta',
      (tester) async {
    await pumpApp(tester);
    await tapCall(tester);
    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pump();
    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(prefs[simPrefKey], 'tel|1');

    await tapCall(tester);
    expect(picker, findsNothing);
    expect(placed, [
      {'number': number, 'account': 'tel|1'},
      {'number': number, 'account': 'tel|1'},
    ]);
  });

  testWidgets('SIM guardada desactivada: no se usa, se olvida y se vuelve a preguntar',
      (tester) async {
    prefs[simPrefKey] = 'tel|3';
    await pumpApp(tester);
    await tapCall(tester);
    expect(picker, findsOneWidget);
    expect(find.textContaining('ya no está disponible'), findsOneWidget);
    expect(prefs[simPrefKey], simAsk);

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(placed, [
      {'number': number, 'account': 'tel|1'}
    ]);
  });

  testWidgets('la SIM desaparece justo al llamar: se pregunta otra vez una sola vez',
      (tester) async {
    prefs[simPrefKey] = 'tel|2';
    unavailableOnce = 'tel|2';
    await pumpApp(tester);
    await tapCall(tester);
    expect(placed, [
      {'number': number, 'account': 'tel|2'}
    ]);
    expect(picker, findsOneWidget);
    expect(prefs[simPrefKey], simAsk);

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(placed.last, {'number': number, 'account': 'tel|1'});
    expect(placed, hasLength(2));
  });

  testWidgets('ajustes: elegir SIM 2 la guarda; "Preguntar siempre" la quita', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const CupertinoApp(home: SimSettingsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Preguntar siempre'), findsOneWidget);

    await tester.tap(find.text('Movistar'));
    await tester.pumpAndSettle();
    expect(prefs[simPrefKey], 'tel|2');

    await tester.tap(find.text('Preguntar siempre'));
    await tester.pumpAndSettle();
    expect(prefs[simPrefKey], simAsk);
  });

  testWidgets('ajustes con una SIM: lo explica y no ofrece opciones', (tester) async {
    sims = [claro];
    await tester.pumpWidget(const CupertinoApp(home: SimSettingsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('una sola SIM'), findsOneWidget);
    expect(find.text('Preguntar siempre'), findsNothing);
  });
}
