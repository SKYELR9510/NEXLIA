// Cliente HTTP del contrato v1 contra un servidor local de prueba (no hay servidor real).
// Sin TestWidgetsFlutterBinding: así dart:io usa sockets reales en 127.0.0.1.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone/messaging/chat_api.dart';
import 'package:phone/messaging/models.dart';

void main() {
  late HttpServer server;
  late List<HttpRequest> seen;
  late List<String> bodies;
  late FutureOr<void> Function(HttpRequest r) handler;

  setUp(() async {
    seen = [];
    bodies = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      seen.add(r);
      bodies.add(await utf8.decoder.bind(r).join());
      await handler(r);
    });
  });

  tearDown(() => server.close(force: true));

  HttpChatApi api({String? token = 'tok-prueba', Duration timeout = const Duration(seconds: 3)}) => HttpChatApi(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}/api'),
        token: () async => token,
        myUserId: 'yo',
        timeout: timeout,
        allowInsecureHttp: true,
      );

  void reply(int status, [Object? json]) {
    handler = (r) async {
      r.response.statusCode = status;
      if (json != null) {
        r.response.headers.contentType = ContentType.json;
        r.response.write(jsonEncode(json));
      }
      await r.response.close();
    };
  }

  test('exige HTTPS salvo en pruebas locales', () {
    expect(() => HttpChatApi(baseUrl: Uri.parse('http://ejemplo.invalid'), token: () async => 't', myUserId: 'x'),
        throwsArgumentError);
    expect(HttpChatApi(baseUrl: Uri.parse('https://ejemplo.invalid'), token: () async => 't', myUserId: 'x').isConfigured,
        isTrue);
  });

  test('sin servidor configurado no hay red: error "sin configurar"', () async {
    expect(ChatConfig.serverUrl, isEmpty);
    expect(ChatConfig.api().isConfigured, isFalse);
    expect(() => ChatConfig.api().sendMessage('c', 'id', 't'), throwsA(isA<ChatNotConfiguredError>()));
  });

  test('envío: ruta, Bearer, Idempotency-Key y cuerpo; 201 devuelve el mensaje', () async {
    reply(201, {
      'message': {'id': 'm1', 'clientId': 'c-1', 'senderId': 'yo', 'text': 'hola', 'createdAt': '2026-05-01T10:00:00Z', 'status': 'sent'}
    });
    final m = await api().sendMessage('conv 1', 'c-1', 'hola');
    final r = seen.single;
    expect(r.method, 'POST');
    expect(r.uri.path, '/api/v1/conversations/conv%201/messages');
    expect(r.headers.value('authorization'), 'Bearer tok-prueba');
    expect(r.headers.value('idempotency-key'), 'c-1');
    expect(jsonDecode(bodies.single), {'clientId': 'c-1', 'text': 'hola'});
    expect(m.serverId, 'm1');
    expect(m.fromMe, isTrue);
    expect(m.status, ChatMessageStatus.sent);
  });

  test('lista de mensajes: paginación por consulta y remitente ajeno', () async {
    reply(200, {
      'messages': [
        {'id': 'm2', 'senderId': 'otra', 'text': 'hey', 'createdAt': '2026-05-01T10:00:00Z', 'status': 'delivered'}
      ]
    });
    final list = await api().fetchMessages('c1', before: 'm9', limit: 20);
    expect(seen.single.uri.queryParameters, {'limit': '20', 'before': 'm9'});
    expect(list.single.fromMe, isFalse);
    expect(list.single.status, ChatMessageStatus.delivered);
  });

  test('códigos HTTP: 401 sesión, 422 rechazo, 429 y 500 temporales', () async {
    reply(401);
    await expectLater(api().sendMessage('c', 'x', 't'), throwsA(isA<ChatAuthError>()));
    reply(422, {'error': 'texto'});
    await expectLater(api().sendMessage('c', 'x', 't'), throwsA(isA<ChatRejectedError>()));
    reply(429);
    await expectLater(api().sendMessage('c', 'x', 't'), throwsA(isA<ChatServerError>()));
    reply(500);
    await expectLater(api().sendMessage('c', 'x', 't'), throwsA(isA<ChatServerError>()));
  });

  test('respuesta que no es JSON: error de servidor', () async {
    handler = (r) async {
      r.response.write('<html>');
      await r.response.close();
    };
    await expectLater(api().listConversations(), throwsA(isA<ChatServerError>()));
  });

  test('sin sesión: falla antes de salir a la red', () async {
    reply(200, {});
    await expectLater(api(token: null).listConversations(), throwsA(isA<ChatAuthError>()));
    expect(seen, isEmpty);
  });

  test('puerto cerrado: error de red', () async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = s.port;
    await s.close();
    final a = HttpChatApi(
        baseUrl: Uri.parse('http://127.0.0.1:$port'), token: () async => 't', myUserId: 'x', allowInsecureHttp: true);
    await expectLater(a.listConversations(), throwsA(isA<ChatNetworkError>()));
  });

  test('servidor que no responde: tiempo agotado como error de red', () async {
    handler = (r) => Completer<void>().future; // nunca responde
    await expectLater(api(timeout: const Duration(milliseconds: 300)).listConversations(),
        throwsA(isA<ChatNetworkError>()));
  });
}
