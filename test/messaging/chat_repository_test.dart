// Repositorio de NEXLIA Chat: cola de pendientes, errores de red, persistencia y prueba.
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/messaging/chat_api.dart';
import 'package:phone/messaging/chat_repository.dart';
import 'package:phone/messaging/models.dart';

import 'fakes.dart';

void main() {
  var ids = 0;
  ChatRepository repo(ChatApi api, MemoryStore store) => ChatRepository(
        store: store,
        api: api,
        now: () => DateTime.utc(2026, 5, 1, 10, 0, ids),
        newId: () => 'c${++ids}',
      );

  ChatConversation conv(String id, {bool demo = false}) =>
      ChatConversation(id: id, peer: ChatUser('u-$id', 'Persona $id'), updatedAt: DateTime.utc(2026), isDemo: demo);

  Future<ChatRepository> withConversation(ChatApi api, MemoryStore store, {bool demo = false}) async {
    // Se siembra el almacén como lo dejaría el servidor (prueba, no datos reales).
    store.data[ChatRepository.storeKey] =
        '{"version":1,"conversations":[${_json(conv('k1', demo: demo))}],"messages":{}}';
    final r = repo(api, store);
    await r.load();
    return r;
  }

  setUp(() => ids = 0);

  test('sin servidor: el mensaje queda pendiente, guardado y el estado es "sin servidor"', () async {
    final store = MemoryStore();
    final r = await withConversation(const UnconfiguredChatApi(), store);
    final m = await r.send('k1', '  hola  ');
    expect(m!.text, 'hola');
    expect(m.status, ChatMessageStatus.pending);
    expect(r.connection, ChatConnection.notConfigured);
    expect(r.pendingCount('k1'), 1);

    final again = repo(const UnconfiguredChatApi(), store);
    await again.load();
    expect(again.messagesOf('k1').single.status, ChatMessageStatus.pending);
    expect(again.messagesOf('k1').single.clientId, m.clientId);
  });

  test('texto vacío o conversación inexistente: no se crea nada', () async {
    final r = await withConversation(FakeChatApi(), MemoryStore());
    expect(await r.send('k1', '   '), isNull);
    expect(await r.send('no-existe', 'hola'), isNull);
    expect(r.messagesOf('k1'), isEmpty);
  });

  test('con servidor: pasa a enviado con id del servidor y conexión en línea', () async {
    final api = FakeChatApi();
    final r = await withConversation(api, MemoryStore());
    final m = await r.send('k1', 'hola');
    expect(m!.status, ChatMessageStatus.sent);
    expect(m.serverId, 'srv-${m.clientId}');
    expect(r.connection, ChatConnection.online);
    expect(api.sentClientIds, [m.clientId]);
  });

  test('error de red: sigue pendiente, cuenta el intento y no adelanta los siguientes', () async {
    final api = FakeChatApi()
      ..sendResults.addAll([const ChatNetworkError('x'), const ChatNetworkError('x')]);
    final r = await withConversation(api, MemoryStore());
    final a = await r.send('k1', 'uno');
    final b = await r.send('k1', 'dos');
    expect(a!.status, ChatMessageStatus.pending);
    expect(b!.status, ChatMessageStatus.pending);
    expect(r.connection, ChatConnection.offline);
    // Al reintentar, el orden se respeta y se reutiliza el mismo clientId (idempotencia).
    await r.flushOutbox();
    expect(api.sentClientIds, [a.clientId, a.clientId, a.clientId, b.clientId]);
    expect(a.status, ChatMessageStatus.sent);
    expect(b.status, ChatMessageStatus.sent);
    expect(a.attempts, 2);
  });

  test('rechazo definitivo: solo ese mensaje queda fallido y "Reintentar" lo reenvía', () async {
    final api = FakeChatApi()..sendResults.add(const ChatRejectedError(422, 'no'));
    final r = await withConversation(api, MemoryStore());
    final m = await r.send('k1', 'hola');
    expect(m!.status, ChatMessageStatus.failed);
    await r.retry(m.clientId);
    expect(m.status, ChatMessageStatus.sent);
  });

  test('error 5xx o sin sesión: queda pendiente', () async {
    final api = FakeChatApi()..sendResults.addAll([const ChatServerError(503, 'x'), const ChatAuthError('x')]);
    final r = await withConversation(api, MemoryStore());
    final m = await r.send('k1', 'hola');
    expect(m!.status, ChatMessageStatus.pending);
    await r.flushOutbox();
    expect(m.status, ChatMessageStatus.pending);
    expect(m.lastError, isNotNull);
  });

  test('conversación de prueba: nunca se envía al servidor', () async {
    final api = FakeChatApi();
    final r = await withConversation(api, MemoryStore(), demo: true);
    final m = await r.send('k1', 'hola');
    expect(m!.isDemo, isTrue);
    expect(m.status, ChatMessageStatus.pending);
    expect(api.sentClientIds, isEmpty);
  });

  test('datos de prueba: se activan marcados y se retiran sin tocar lo demás', () async {
    final api = FakeChatApi();
    final r = await withConversation(api, MemoryStore());
    await r.setDemo(true);
    expect(r.hasDemo, isTrue);
    expect(r.conversations.where((c) => c.isDemo).length, 2);
    for (final c in r.conversations.where((c) => c.isDemo)) {
      expect(r.messagesOf(c.id).every((m) => m.isDemo), isTrue);
    }
    await r.flushOutbox();
    expect(api.sentClientIds, isEmpty, reason: 'los pendientes de prueba no salen');
    await r.setDemo(false);
    expect(r.hasDemo, isFalse);
    expect(r.conversation('k1'), isNotNull);
  });

  test('abrir la conversación pone no leídos a cero y envía recibo solo con servidor', () async {
    final api = FakeChatApi();
    final store = MemoryStore();
    store.data[ChatRepository.storeKey] = '{"version":1,"conversations":[{"id":"k1","peer":{"id":"u","displayName":"P"},'
        '"updatedAt":"2026-01-01T00:00:00.000Z","unreadCount":2,"isDemo":false}],"messages":{"k1":['
        '{"clientId":"r1","serverId":"s9","conversationId":"k1","fromMe":false,"text":"hola",'
        '"createdAt":"2026-01-01T00:00:00.000Z","status":"read","attempts":0,"isDemo":false}]}}';
    final r = repo(api, store);
    await r.load();
    await r.markRead('k1');
    expect(r.conversation('k1')!.unreadCount, 0);
    expect(api.receipts, ['k1:s9:read']);
  });

  test('almacén dañado: la app arranca con la bandeja vacía', () async {
    final store = MemoryStore()..data[ChatRepository.storeKey] = '{no es json';
    final r = repo(const UnconfiguredChatApi(), store);
    await r.load();
    expect(r.loaded, isTrue);
    expect(r.conversations, isEmpty);
  });
}

String _json(ChatConversation c) =>
    '{"id":"${c.id}","peer":{"id":"${c.peer.id}","displayName":"${c.peer.displayName}"},'
    '"updatedAt":"${c.updatedAt.toIso8601String()}","unreadCount":0,"isDemo":${c.isDemo}}';
