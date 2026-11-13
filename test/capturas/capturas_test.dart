// Capturas de la interfaz de mensajería para el PR (no es una prueba de regresión).
// Solo se ejecuta con CAPTURAS_DIR definido; en `flutter test` normal se omite.
// Datos ficticios: conversaciones marcadas PRUEBA y números +51 900 000 0xx.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/common.dart';
import 'package:phone/messaging/chat_api.dart';
import 'package:phone/messaging/chat_repository.dart';
import 'package:phone/messaging/messages_page.dart';
import 'package:phone/messaging/models.dart';
import 'package:phone/messaging/sms_repository.dart';

import '../messaging/fakes.dart';

final _dir = Platform.environment['CAPTURAS_DIR'] ?? '';

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final material = '$root/bin/cache/artifacts/material_fonts';
  ByteData read(String p) => ByteData.sublistView(File(p).readAsBytesSync());
  final weights = ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']
      .map((f) => '$material/$f')
      .where((p) => File(p).existsSync())
      .toList();
  if (weights.isEmpty) throw StateError('No se encontró Roboto en $material');
  for (final family in [
    'Roboto',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
  ]) {
    final l = FontLoader(family);
    for (final w in weights) {
      l.addFont(Future.value(read(w)));
    }
    await l.load();
  }
  final cfg = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map;
  final pkg = (cfg['packages'] as List).cast<Map>().firstWhere((p) => p['name'] == 'cupertino_icons');
  final base = Uri.parse(pkg['rootUri'] as String);
  final dir = base.isAbsolute ? base : Uri.file('${Directory.current.path}/.dart_tool/').resolveUri(base);
  final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')
    ..addFont(Future.value(read(dir.resolve('assets/CupertinoIcons.ttf').toFilePath())));
  await icons.load();
}

void main() {
  final key = GlobalKey();
  final now = DateTime.now();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pumpAndSettle();
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<(ChatRepository, SmsRepository)> repos({bool full = true}) async {
    final chat = ChatRepository(store: MemoryStore(), api: const UnconfiguredChatApi());
    await chat.load();
    if (!full) return (chat, SmsRepository(FakeSmsSource()));
    await chat.setDemo(true);
    final src = FakeSmsSource(perm: SmsPermission.granted)
      ..sims = [const SimSubscription(1, 'SIM 1', 1), const SimSubscription(2, 'SIM 2', 2)]
      ..data = [
        SmsThread(
            threadId: '1',
            address: '+51900000001',
            snippet: 'Tu código de verificación de prueba es 000000',
            date: now.subtract(const Duration(minutes: 12)),
            unreadCount: 1,
            subId: 2),
        SmsThread(
            threadId: '2',
            address: '+51900000002',
            snippet: 'Llego en 10 minutos',
            date: now.subtract(const Duration(days: 1)),
            subId: 1),
      ]
      ..msgs['1'] = [
        SmsMessage(
            id: '1',
            threadId: '1',
            address: '+51900000001',
            body: 'Hola, ¿recibiste el pedido?',
            date: now.subtract(const Duration(hours: 2)),
            box: SmsBox.sent,
            subId: 2),
        SmsMessage(
            id: '2',
            threadId: '1',
            address: '+51900000001',
            body: 'Tu código de verificación de prueba es 000000',
            date: now.subtract(const Duration(minutes: 12)),
            box: SmsBox.inbox,
            subId: 2),
      ];
    final sms = SmsRepository(src);
    await sms.load();
    return (chat, sms);
  }

  String name(String a) => switch (a) {
        '+51900000001' => 'Tienda (prueba)',
        '+51900000002' => 'Carlos (prueba)',
        _ => a,
      };

  Widget app(Widget home, Brightness b) => RepaintBoundary(
        key: key,
        child: CupertinoApp(
          debugShowCheckedModeBanner: false,
          theme: CupertinoThemeData(brightness: b, primaryColor: AppTheme.accents[0]),
          home: CupertinoPageScaffold(
            backgroundColor: b == Brightness.dark ? const Color(0xFF050A16) : const Color(0xFFFFFFFF),
            child: SafeArea(child: home),
          ),
        ),
      );

  setUpAll(() async {
    if (_dir.isNotEmpty) await _loadFonts();
  });

  void setSize(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  for (final b in [Brightness.light, Brightness.dark]) {
    final suffix = b == Brightness.dark ? 'oscuro' : 'claro';
    testWidgets('bandeja y conversaciones ($suffix)', (t) async {
      setSize(t);
      final (chat, sms) = await repos();
      await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms, nameFor: name), b));
      await shot(t, '1_bandeja_$suffix');
      await t.tap(find.text('Equipo NEXLIA (prueba)'));
      await shot(t, '2_chat_$suffix');
      t.state<NavigatorState>(find.byType(Navigator).first).pop();
      await t.pumpAndSettle();
      await t.tap(find.text('Tienda (prueba)'));
      await shot(t, '3_sms_$suffix');
    }, skip: _dir.isEmpty);

    testWidgets('primer uso: sin mensajes y permiso SMS ($suffix)', (t) async {
      setSize(t);
      final (chat, sms) = await repos(full: false);
      await t.pumpWidget(app(MessagesPage(chat: chat, sms: sms), b));
      await shot(t, '4_vacio_$suffix');
    }, skip: _dir.isEmpty);
  }
}
