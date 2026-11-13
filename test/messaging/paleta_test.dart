// Contraste (WCAG 2.1 AA, 4,5:1) de los colores de mensajería con cada acento y tema.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/common.dart';
import 'package:phone/messaging/palette.dart';

void main() {
  test('fórmula de contraste: blanco/negro 21:1 y mismo color 1:1', () {
    expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)), closeTo(21, 0.01));
    expect(contrastRatio(const Color(0xFF777777), const Color(0xFF777777)), closeTo(1, 0.001));
  });

  test('solidFor oscurece hasta 4,5:1 con texto blanco', () {
    final c = solidFor(const Color(0xFF7C8DB5));
    expect(contrastRatio(onSolid, c), greaterThanOrEqualTo(4.5));
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    for (var a = 0; a < AppTheme.accents.length; a++) {
      testWidgets('tema ${b.name}, acento $a: textos y fondos sólidos', (t) async {
        late BuildContext ctx;
        await t.pumpWidget(CupertinoApp(
          theme: CupertinoThemeData(brightness: b, primaryColor: AppTheme.accents[a]),
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ));
        final bg = bgColor(ctx);
        void aa(Color fg, Color back, String what) =>
            expect(contrastRatio(fg, back), greaterThanOrEqualTo(4.5), reason: '$what: ${contrastRatio(fg, back)}');

        aa(onSolid, chatSolid(ctx), 'texto blanco sobre Chat sólido');
        aa(onSolid, smsSolid, 'texto blanco sobre SMS sólido');
        aa(onSolid, failedSolid, 'texto blanco sobre no enviado');
        aa(chatInk(ctx), bg, 'tinta Chat sobre fondo');
        aa(chatInk(ctx), over(accentColor(ctx), 0.14, bg), 'etiqueta Chat');
        aa(smsInk(ctx), over(smsSolid, 0.14, bg), 'etiqueta SMS');
        aa(demoInk(ctx), over(demoTint, 0.18, bg), 'etiqueta PRUEBA');
        aa(failedInk(ctx), bg, 'aviso de no enviado');
        aa(secondaryColor(ctx), bg, 'texto secundario');
        aa(secondaryColor(ctx), fillColor(ctx), 'texto secundario sobre relleno');
        aa(labelColor(ctx), fillColor(ctx), 'burbuja recibida');
        for (final tint in [accentColor(ctx), smsSolid, failedSolid, demoTint]) {
          aa(secondaryColor(ctx), over(tint, 0.12, bg), 'texto de aviso sobre tinte $tint');
          aa(labelColor(ctx), over(tint, 0.12, bg), 'título de aviso sobre tinte $tint');
        }
      });
    }
  }
}
