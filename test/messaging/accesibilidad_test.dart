// Accesibilidad de la mensajería: nodos separados para texto y acciones, etiquetas,
// teclado, tamaños táctiles, contraste y texto grande, en claro y oscuro.
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/common.dart';
import 'package:phone/messaging/a11y.dart';
import 'package:phone/messaging/chat_api.dart';
import 'package:phone/messaging/chat_repository.dart';
import 'package:phone/messaging/conversation_page.dart';
import 'package:phone/messaging/messages_page.dart';
import 'package:phone/messaging/messaging_settings_page.dart';
import 'package:phone/messaging/models.dart';
import 'package:phone/messaging/sms_repository.dart';

import 'fakes.dart';

Widget app(Widget home, {Brightness b = Brightness.light, double scale = 1}) => CupertinoApp(
      theme: CupertinoThemeData(brightness: b, primaryColor: AppTheme.accents[0]),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: CupertinoPageScaffold(child: home),
    );

void main() {
  final now = DateTime.now();

  Future<(ChatRepository, SmsRepository, FakeSmsSource)> repos(
      {bool demo = true, SmsPermission perm = SmsPermission.granted, bool consent = true, bool sms = true}) async {
    final chat = ChatRepository(store: MemoryStore(), api: const UnconfiguredChatApi());
    await chat.load();
    if (demo) await chat.setDemo(true);
    final src = FakeSmsSource(perm: perm)
      ..simInfo = const SmsSimInfo(slots: 2, active: [SimSubscription(1, 'Claro', 1)]);
    if (sms) {
      src.data = [
        SmsThread(threadId: '1', address: '+51900000001', snippet: 'Código de prueba 0000', date: now, unreadCount: 1, subId: 1),
        SmsThread(threadId: '2', address: '+51900000002', snippet: 'Hola', date: now, subId: 9),
      ];
      src.msgs['1'] = [
        SmsMessage(id: '1', threadId: '1', address: '+51900000001', body: 'Código de prueba 0000', date: now, box: SmsBox.inbox, subId: 1),
        SmsMessage(id: '2', threadId: '1', address: '+51900000001', body: 'Gracias', date: now, box: SmsBox.sent, subId: -1),
      ];
    }
    return (chat, SmsRepository(src, store: consent ? consented() : MemoryStore()), src);
  }

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  group('lector de pantalla', () {
    testWidgets('tarjeta de SMS: el texto y el botón son nodos distintos', (t) async {
      final h = t.ensureSemantics();
      final (chat, sms, _) = await repos(consent: false);
      await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
      await t.pumpAndSettle();
      final button = find.bySemanticsLabel('Mostrar mis SMS aquí');
      expect(button, findsOneWidget);
      expect(t.getSemantics(button), containsSemantics(isButton: true, hasTapAction: true, isEnabled: true));
      final info = find.bySemanticsLabel(RegExp(r'^Ver tus SMS en NEXLIA\. Android ya permite'));
      expect(info, findsOneWidget);
      expect(t.getSemantics(info), containsSemantics(isButton: false, hasTapAction: false));
      expect(t.getSemantics(info).label.contains('Mostrar mis SMS aquí'), isFalse);
      h.dispose();
    });

    testWidgets('filtros: botones con estado seleccionado en grupo excluyente', (t) async {
      final h = t.ensureSemantics();
      final (chat, sms, _) = await repos();
      await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
      await t.pumpAndSettle();
      expect(t.getSemantics(find.bySemanticsLabel('Filtro Todos')),
          containsSemantics(isButton: true, isSelected: true, isInMutuallyExclusiveGroup: true, hasTapAction: true));
      expect(t.getSemantics(find.bySemanticsLabel('Filtro SMS')),
          containsSemantics(isButton: true, isSelected: false, hasTapAction: true));
      await t.tap(find.text('SMS').first);
      await t.pumpAndSettle();
      expect(t.getSemantics(find.bySemanticsLabel('Filtro SMS')), containsSemantics(isSelected: true));
      h.dispose();
    });

    testWidgets('filas: canal, prueba, SIM, no leídos y estado en la etiqueta', (t) async {
      final h = t.ensureSemantics();
      final (chat, sms, _) = await repos();
      await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
      await t.pumpAndSettle();
      expect(t.getSemantics(find.bySemanticsLabel(RegExp(r'^Ana \(prueba\), NEXLIA Chat, conversación de prueba, 2 sin leer'))),
          containsSemantics(isButton: true, hasTapAction: true));
      expect(find.bySemanticsLabel(RegExp(r'^\+51900000001, SMS, SIM 1 · Claro, 1 sin leer')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^\+51900000002, SMS, SIM no identificada')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Equipo NEXLIA \(prueba\).*1 pendiente de envío, hay mensajes no enviados')),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Mensajes, 3 sin leer')), findsOneWidget);
      h.dispose();
    });

    testWidgets('conversación: cada mensaje es un nodo con remitente y estado; enviar es un botón', (t) async {
      final h = t.ensureSemantics();
      final (chat, _, _) = await repos();
      await t.pumpWidget(app(ChatConversationPage(chat: chat, conversationId: 'demo-equipo')));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(r'^Tú, .*: Te paso el resumen de la reunión\.\. Entregado$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Recibido, ')), findsOneWidget);
      expect(t.getSemantics(find.bySemanticsLabel('Enviar mensaje')), containsSemantics(isButton: true, hasTapAction: true));
      expect(find.bySemanticsLabel(RegExp(r'^NEXLIA Chat\. Mensajes por Internet')), findsOneWidget);
      h.dispose();
    });

    testWidgets('hilo SMS: SIM no identificada y botón de responder', (t) async {
      final h = t.ensureSemantics();
      final (_, sms, _) = await repos();
      await sms.load();
      await t.pumpWidget(app(SmsThreadPage(sms: sms, threadId: '1', title: '+51900000001', address: '+51900000001')));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(r'^Recibido, .*SIM 1 · Claro: Código de prueba 0000$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Enviado, .*SIM no identificada: Gracias$')), findsOneWidget);
      expect(t.getSemantics(find.bySemanticsLabel('Responder en la app de SMS')), containsSemantics(isButton: true));
      h.dispose();
    });

    testWidgets('Más > Mensajes: cada interruptor se lee con su texto', (t) async {
      final h = t.ensureSemantics();
      final (chat, sms, _) = await repos();
      await sms.load();
      await t.pumpWidget(app(MessagingSettingsPage(chat: chat, sms: sms)));
      await t.pumpAndSettle();
      expect(t.getSemantics(find.bySemanticsLabel(RegExp('Mostrar mis SMS en NEXLIA'))),
          containsSemantics(hasToggledState: true, isToggled: true));
      expect(t.getSemantics(find.bySemanticsLabel(RegExp('Conversaciones de prueba'))),
          containsSemantics(hasToggledState: true, isToggled: true));
      expect(find.bySemanticsLabel(RegExp(r'SIM[\s\S]*2 ranuras · 1 activa')), findsOneWidget);
      h.dispose();
    });
  });

  group('teclado', () {
    String? focusedLabel() =>
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Tappable>()?.label;

    Future<bool> tabTo(WidgetTester t, bool Function(String) match) async {
      for (var i = 0; i < 25; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pumpAndSettle();
        final l = focusedLabel();
        if (l != null && match(l)) return true;
      }
      return false;
    }

    testWidgets('Tab llega a los filtros y Espacio los activa', (t) async {
      final (chat, sms, _) = await repos();
      await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
      await t.pumpAndSettle();
      expect(await tabTo(t, (l) => l == 'Filtro SMS'), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      expect(find.text('Ana (prueba)'), findsNothing);
      expect(find.text('+51900000001'), findsOneWidget);
    });

    testWidgets('Tab llega a una conversación e Intro la abre; el foco se ve', (t) async {
      final (chat, sms, _) = await repos();
      await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
      await t.pumpAndSettle();
      expect(await tabTo(t, (l) => l.startsWith('Ana (prueba)')), isTrue);
      final ring = find.descendant(
          of: find.byWidgetPredicate((w) => w is Tappable && w.label.startsWith('Ana (prueba)')),
          matching: find.byWidgetPredicate((w) => w is Container && w.foregroundDecoration != null));
      expect(ring, findsOneWidget, reason: 'borde de foco visible');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.byType(ChatConversationPage), findsOneWidget);
    });

    testWidgets('el botón de la tarjeta de SMS se activa con teclado', (t) async {
      final (chat, sms, src) = await repos(consent: false);
      await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
      await t.pumpAndSettle();
      expect(await tabTo(t, (l) => l == 'Mostrar mis SMS aquí'), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(sms.canRead, isTrue);
      expect(src.requests, 0);
      expect(find.text('Código de prueba 0000'), findsOneWidget);
    });
  });

  group('tamaños táctiles y contraste', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      testWidgets('bandeja (${b.name}): áreas táctiles, etiquetas y contraste de texto', (t) async {
        phone(t);
        final h = t.ensureSemantics();
        final (chat, sms, _) = await repos(consent: false);
        await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms), b: b));
        await t.pumpAndSettle();
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        h.dispose();
      });

      testWidgets('conversación de Chat (${b.name})', (t) async {
        phone(t);
        final h = t.ensureSemantics();
        final (chat, _, _) = await repos();
        await t.pumpWidget(app(ChatConversationPage(chat: chat, conversationId: 'demo-equipo'), b: b));
        await t.pumpAndSettle();
        await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        h.dispose();
      });

      testWidgets('hilo SMS (${b.name})', (t) async {
        phone(t);
        final h = t.ensureSemantics();
        final (_, sms, _) = await repos();
        await sms.load();
        await t.pumpWidget(
            app(SmsThreadPage(sms: sms, threadId: '1', title: '+51900000001', address: '+51900000001'), b: b));
        await t.pumpAndSettle();
        await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    }

    testWidgets('controles propios: al menos 48 × 48', (t) async {
      phone(t);
      final (chat, sms, _) = await repos(consent: false);
      await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
      await t.pumpAndSettle();
      for (final f in [find.byType(Tappable), find.byType(ActionButton)]) {
        for (final e in f.evaluate()) {
          final s = t.getSize(find.byWidget(e.widget));
          expect(s.height >= minTouch && s.width >= minTouch, isTrue, reason: '${e.widget} mide $s');
        }
      }
    });
  });

  group('texto grande (200 %)', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      testWidgets('bandeja, conversación, hilo SMS y ajustes sin desbordes (${b.name})', (t) async {
        phone(t);
        final (chat, sms, _) = await repos(consent: false);
        await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms), b: b, scale: 2));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        // Con texto al 200 % la tarjeta queda más abajo: se desplaza hasta ella.
        await t.scrollUntilVisible(find.text('Mostrar mis SMS aquí'), 200);
        expect(t.takeException(), isNull);
        await t.scrollUntilVisible(find.text('Ana (prueba)'), 300);
        expect(t.takeException(), isNull);

        await t.pumpWidget(app(ChatConversationPage(chat: chat, conversationId: 'demo-equipo'), b: b, scale: 2));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);

        await sms.requestAccess();
        await t.pumpWidget(app(
            SmsThreadPage(sms: sms, threadId: '1', title: '+51900000001', address: '+51900000001'),
            b: b,
            scale: 2));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);

        await t.pumpWidget(app(MessagingSettingsPage(chat: chat, sms: sms), b: b, scale: 2));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  });
}
