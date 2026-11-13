// Pantallas de mensajería: bandeja, filtros, estados vacíos, permiso SMS, temas y Buzón en Más.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/common.dart';
import 'package:phone/messaging/chat_api.dart';
import 'package:phone/messaging/chat_repository.dart';
import 'package:phone/messaging/conversation_page.dart';
import 'package:phone/messaging/messages_page.dart';
import 'package:phone/messaging/models.dart';
import 'package:phone/messaging/sms_repository.dart';
import 'package:phone/more_page.dart';

import 'fakes.dart';

Widget app(Widget home, {Brightness brightness = Brightness.light}) => CupertinoApp(
      theme: CupertinoThemeData(brightness: brightness, primaryColor: AppTheme.accents[0]),
      home: CupertinoPageScaffold(child: home),
    );

void main() {
  final now = DateTime.now();

  Future<(ChatRepository, SmsRepository, FakeSmsSource)> repos(
      {bool demo = false, SmsPermission perm = SmsPermission.denied, bool smsData = false}) async {
    final chat = ChatRepository(store: MemoryStore(), api: const UnconfiguredChatApi());
    await chat.load();
    if (demo) await chat.setDemo(true);
    final src = FakeSmsSource(perm: perm);
    if (smsData) {
      src.data = [
        SmsThread(threadId: '1', address: '+51900000001', snippet: 'Tu código de prueba es 0000', date: now, unreadCount: 1),
      ];
      src.msgs['1'] = [
        SmsMessage(id: '1', threadId: '1', address: '+51900000001', body: 'Tu código de prueba es 0000', date: now, box: SmsBox.inbox),
        SmsMessage(id: '2', threadId: '1', address: '+51900000001', body: 'Gracias', date: now, box: SmsBox.sent),
      ];
    }
    return (chat, SmsRepository(src), src);
  }

  testWidgets('bandeja vacía: estado vacío, aviso de Chat sin servidor y tarjeta de permiso SMS', (t) async {
    final (chat, sms, src) = await repos();
    await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
    await t.pumpAndSettle();
    expect(find.text('Mensajes'), findsOneWidget);
    expect(find.text('Aún no hay mensajes'), findsOneWidget);
    expect(find.text('NEXLIA Chat aún no está conectado'), findsOneWidget);
    expect(find.text('Permitir lectura de SMS'), findsOneWidget);
    expect(src.requests, 0, reason: 'no se pide permiso sin acción del usuario');
    expect(src.reads, 0);
  });

  testWidgets('estados vacíos por filtro', (t) async {
    final (chat, sms, _) = await repos(perm: SmsPermission.granted);
    await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
    await t.pumpAndSettle();
    await t.tap(find.text('NEXLIA Chat'));
    await t.pumpAndSettle();
    expect(find.text('Sin conversaciones de Chat'), findsOneWidget);
    expect(find.text('Permitir lectura de SMS'), findsNothing);
    await t.tap(find.text('SMS'));
    await t.pumpAndSettle();
    expect(find.text('Sin SMS'), findsOneWidget);
    expect(find.text('NEXLIA Chat aún no está conectado'), findsNothing);
  });

  testWidgets('pedir permiso SMS solo al tocar el botón; luego se muestran los SMS', (t) async {
    final (chat, sms, src) = await repos(smsData: true);
    await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
    await t.pumpAndSettle();
    expect(find.text('Tu código de prueba es 0000'), findsNothing);
    await t.tap(find.text('Permitir lectura de SMS'));
    await t.pumpAndSettle();
    expect(src.requests, 1);
    expect(find.text('Tu código de prueba es 0000'), findsOneWidget);
    expect(find.text('Permitir lectura de SMS'), findsNothing);
  });

  testWidgets('bandeja con ambos canales: insignias, PRUEBA, no leídos y filtros', (t) async {
    final (chat, sms, _) = await repos(demo: true, perm: SmsPermission.granted, smsData: true);
    await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
    await t.pumpAndSettle();
    expect(find.text('Ana (prueba)'), findsOneWidget);
    expect(find.text('Equipo NEXLIA (prueba)'), findsOneWidget);
    expect(find.text('+51900000001'), findsOneWidget);
    expect(find.text('PRUEBA'), findsNWidgets(2));
    expect(find.text('Chat'), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget, reason: 'total de no leídos: 2 de Chat + 1 de SMS');

    await t.tap(find.text('SMS').first);
    await t.pumpAndSettle();
    expect(find.text('Ana (prueba)'), findsNothing);
    expect(find.text('+51900000001'), findsOneWidget);

    await t.tap(find.text('NEXLIA Chat'));
    await t.pumpAndSettle();
    expect(find.text('+51900000001'), findsNothing);
    expect(find.text('Ana (prueba)'), findsOneWidget);
  });

  testWidgets('búsqueda sin resultados', (t) async {
    final (chat, sms, _) = await repos(demo: true);
    await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
    await t.pumpAndSettle();
    await t.enterText(find.byType(CupertinoTextField), 'zzz');
    await t.pumpAndSettle();
    expect(find.text('Sin resultados'), findsOneWidget);
    await t.enterText(find.byType(CupertinoTextField), 'ana');
    await t.pumpAndSettle();
    expect(find.text('Ana (prueba)'), findsOneWidget);
    expect(find.text('Equipo NEXLIA (prueba)'), findsNothing);
  });

  testWidgets('conversación de prueba: aviso, estados y un envío queda en el teléfono', (t) async {
    final (chat, sms, _) = await repos(demo: true);
    await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
    await t.pumpAndSettle();
    await t.tap(find.text('Equipo NEXLIA (prueba)'));
    await t.pumpAndSettle();
    expect(find.byType(ChatConversationPage), findsOneWidget);
    expect(find.textContaining('Conversación de PRUEBA'), findsOneWidget);
    expect(find.text('Entregado'), findsWidgets);
    expect(find.text('No enviado'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing, reason: 'los mensajes de prueba no se reintentan');
    await t.enterText(find.byType(CupertinoTextField), 'nuevo mensaje');
    await t.tap(find.byIcon(CupertinoIcons.arrow_up));
    await t.pumpAndSettle();
    expect(find.text('nuevo mensaje'), findsOneWidget);
    final m = chat.messagesOf('demo-equipo').last;
    expect((m.text, m.status, m.isDemo), ('nuevo mensaje', ChatMessageStatus.pending, true));
  });

  testWidgets('abrir la conversación pone a cero los no leídos', (t) async {
    final (chat, sms, _) = await repos(demo: true);
    await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
    await t.pumpAndSettle();
    expect(chat.conversation('demo-ana')!.unreadCount, 2);
    await t.tap(find.text('Ana (prueba)'));
    await t.pumpAndSettle();
    expect(chat.conversation('demo-ana')!.unreadCount, 0);
  });

  testWidgets('hilo SMS: solo lectura y responder abre la app de SMS', (t) async {
    final (chat, sms, src) = await repos(perm: SmsPermission.granted, smsData: true);
    await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms)));
    await t.pumpAndSettle();
    await t.tap(find.text('+51900000001'));
    await t.pumpAndSettle();
    expect(find.byType(SmsThreadPage), findsOneWidget);
    expect(find.text('Gracias'), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsNothing, reason: 'no hay redacción de SMS en NEXLIA');
    await t.tap(find.text('Responder en la app de SMS'));
    expect(src.composed, ['+51900000001']);
  });

  testWidgets('tema oscuro: fondo oscuro y texto claro', (t) async {
    final (chat, sms, _) = await repos(demo: true);
    await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms), brightness: Brightness.dark));
    await t.pumpAndSettle();
    final title = t.widget<Text>(find.text('Ana (prueba)'));
    expect(title.style!.color, const Color(0xFFFFFFFF));
    final light = await repos(demo: true);
    await t.pumpWidget(app(MessagesPage(chat: light.$1, sms: light.$2)));
    await t.pumpAndSettle();
    expect(t.widget<Text>(find.text('Ana (prueba)')).style!.color, const Color(0xFF0B1B3A));
  });

  testWidgets('regresión: el Buzón de voz sigue disponible desde Más', (t) async {
    await t.pumpWidget(app(const MorePage()));
    await t.pumpAndSettle();
    expect(find.text('Buzón de voz'), findsOneWidget);
    expect(find.text('Mensajes'), findsOneWidget);
    await t.tap(find.text('Buzón de voz'));
    await t.pumpAndSettle();
    expect(find.text('Llamar al buzón'), findsOneWidget);
    expect(find.text('Más'), findsWidgets, reason: 'tiene botón para volver');
  });
}
