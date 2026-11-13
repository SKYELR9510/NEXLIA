// Prueba de humo (Fase 0): el marcador se dibuja y las teclas escriben el número.
// No llama a la parte nativa: los canales no existen en el entorno de pruebas
// y Native.* devuelve valores por defecto.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/common.dart';
import 'package:phone/keypad_page.dart';

void main() {
  testWidgets('las teclas escriben en el marcador y borrar quita el último dígito',
      (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    dialText.value = '';

    await tester.pumpWidget(const CupertinoApp(home: CupertinoPageScaffold(child: KeypadPage())));

    await tester.tap(find.text('9'));
    await tester.tap(find.text('8'));
    await tester.tap(find.text('1'));
    await tester.pump();
    expect(dialText.value, '981');
    expect(find.text('981'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.delete_left));
    await tester.pump();
    expect(dialText.value, '98');
  });
}
