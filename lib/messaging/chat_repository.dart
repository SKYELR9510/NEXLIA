import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'chat_api.dart';
import 'models.dart';
import 'store.dart';

export 'store.dart';

String _randomId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Conversaciones y mensajes de NEXLIA Chat: local primero, con cola de pendientes.
class ChatRepository extends ChangeNotifier {
  ChatRepository({
    required this.store,
    required ChatApi api,
    DateTime Function()? now,
    String Function()? newId,
  })  : _api = api,
        _now = now ?? (() => DateTime.now().toUtc()),
        _newId = newId ?? _randomId,
        connection = api.isConfigured ? ChatConnection.offline : ChatConnection.notConfigured;

  static const storeKey = 'chat.store.v1';

  final KeyValueStore store;
  final ChatApi _api;
  final DateTime Function() _now;
  final String Function() _newId;

  final List<ChatConversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messages = {};
  ChatConnection connection;
  bool loaded = false;
  bool _flushing = false;
  Future<void> _pendingWrite = Future<void>.value();
  final Map<String, String> _pendingReceipts = {};
  bool _flushingReceipts = false;

  int get pendingReceiptCount => _pendingReceipts.length;

  bool get isConfigured => _api.isConfigured;

  List<ChatConversation> get conversations =>
      List.of(_conversations)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  bool get hasDemo => _conversations.any((c) => c.isDemo);

  ChatConversation? conversation(String id) {
    for (final c in _conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<ChatMessage> messagesOf(String conversationId) =>
      List.of(_messages[conversationId] ?? const <ChatMessage>[])
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  ChatMessage? lastMessage(String conversationId) {
    final list = messagesOf(conversationId);
    return list.isEmpty ? null : list.last;
  }

  int pendingCount(String conversationId) =>
      (_messages[conversationId] ?? const <ChatMessage>[])
          .where((m) => m.fromMe && m.status == ChatMessageStatus.pending)
          .length;

  /// Lee una instantánea completa antes de sustituir el estado en memoria.
  /// Un fallo de lectura o JSON inválido no destruye los mensajes ya cargados.
  Future<void> load() async {
    await _pendingWrite;
    final raw = await store.read(storeKey);
    final nextConversations = <ChatConversation>[];
    final nextMessages = <String, List<ChatMessage>>{};
    final nextReceipts = <String, String>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = jsonDecode(raw) as Map;
        for (final c in (data['conversations'] as List? ?? const [])) {
          if (c is Map) nextConversations.add(ChatConversation.fromJson(c));
        }
        final receipts = (data['pendingReceipts'] as Map?) ?? const {};
        receipts.forEach((k, v) {
          if (v is String && v.isNotEmpty) nextReceipts[k.toString()] = v;
        });
        final msgs = (data['messages'] as Map?) ?? const {};
        msgs.forEach((k, v) {
          nextMessages[k.toString()] =
              (v as List? ?? const []).whereType<Map>().map(ChatMessage.fromJson).toList();
        });
      } catch (_) {
        // Mantener la instantánea anterior; no reemplazarla por datos parciales.
        loaded = true;
        notifyListeners();
        return;
      }
    }
    _conversations
      ..clear()
      ..addAll(nextConversations);
    _messages
      ..clear()
      ..addAll(nextMessages);
    _pendingReceipts
      ..clear()
      ..addAll(nextReceipts);
    loaded = true;
    notifyListeners();
  }

  /// Serializa instantáneas: una escritura lenta nunca sobrescribe otra posterior.
  Future<void> _save() {
    final snapshot = jsonEncode({
      'version': 1,
      'conversations': _conversations.map((c) => c.toJson()).toList(),
      'messages': _messages.map((k, v) => MapEntry(k, v.map((m) => m.toJson()).toList())),
      'pendingReceipts': Map<String, String>.of(_pendingReceipts),
    });
    final write = _pendingWrite.catchError((Object _) {}).then((_) => store.write(storeKey, snapshot));
    _pendingWrite = write;
    return write;
  }

  /// Guarda el mensaje como pendiente y luego intenta enviar la cola.
  /// Solo se llama por acción del usuario: no hay envíos automáticos de texto.
  Future<ChatMessage?> send(String conversationId, String text) async {
    final body = text.trim();
    final conv = conversation(conversationId);
    if (body.isEmpty || conv == null) return null;
    final m = ChatMessage(
      clientId: _newId(),
      conversationId: conversationId,
      fromMe: true,
      text: body,
      createdAt: _now(),
      isDemo: conv.isDemo,
    );
    _messages.putIfAbsent(conversationId, () => []).add(m);
    conv.updatedAt = m.createdAt;
    await _save();
    notifyListeners();
    await flushOutbox();
    return m;
  }

  /// Envía los pendientes en orden. Se detiene ante un error temporal para no
  /// adelantar mensajes; un rechazo definitivo marca solo ese mensaje como fallido.
  Future<void> flushOutbox() async {
    if (_flushing) return;
    if (!_api.isConfigured) {
      connection = ChatConnection.notConfigured;
      notifyListeners();
      return;
    }
    _flushing = true;
    try {
      final pending = _messages.values
          .expand((l) => l)
          .where((m) => m.fromMe && !m.isDemo && m.status == ChatMessageStatus.pending)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final m in pending) {
        try {
          final sent = await _api.sendMessage(m.conversationId, m.clientId, m.text);
          m.serverId = sent.serverId;
          m.status = sent.status == ChatMessageStatus.pending ? ChatMessageStatus.sent : sent.status;
          m.lastError = null;
          connection = ChatConnection.online;
        } on ChatRejectedError catch (e) {
          m.status = ChatMessageStatus.failed;
          m.attempts++;
          m.lastError = e.message;
          connection = ChatConnection.online;
        } on ChatNetworkError catch (e) {
          m.attempts++;
          m.lastError = e.message;
          connection = ChatConnection.offline;
          break;
        } on ChatServerError catch (e) {
          m.attempts++;
          m.lastError = e.message;
          break;
        } on ChatAuthError catch (e) {
          m.lastError = e.message;
          break;
        } on ChatNotConfiguredError {
          connection = ChatConnection.notConfigured;
          break;
        }
      }
      await _save();
    } finally {
      _flushing = false;
      notifyListeners();
    }
  }

  /// "Reintentar" en un mensaje fallido.
  Future<void> retry(String clientId) async {
    for (final m in _messages.values.expand((l) => l)) {
      if (m.clientId == clientId && m.status == ChatMessageStatus.failed) {
        m.status = ChatMessageStatus.pending;
        m.lastError = null;
      }
    }
    await _save();
    notifyListeners();
    await flushOutbox();
  }

  /// Reintenta recibos de lectura persistidos sin afectar a los mensajes.
  Future<void> flushReceipts() async {
    if (_flushingReceipts || !_api.isConfigured || _pendingReceipts.isEmpty) return;
    _flushingReceipts = true;
    try {
      for (final entry in Map<String, String>.of(_pendingReceipts).entries) {
        try {
          await _api.sendReceipt(entry.key, entry.value, 'read');
          if (_pendingReceipts[entry.key] == entry.value) {
            _pendingReceipts.remove(entry.key);
            await _save();
          }
        } on ChatError {
          break;
        }
      }
    } finally {
      _flushingReceipts = false;
      notifyListeners();
    }
  }

  /// Al abrir la conversación: guardar el recibo antes de intentar enviarlo.
  Future<void> markRead(String conversationId) async {
    final conv = conversation(conversationId);
    if (conv == null || conv.unreadCount == 0) return;
    conv.unreadCount = 0;
    if (!conv.isDemo && _api.isConfigured) {
      for (final m in messagesOf(conversationId).reversed) {
        if (!m.fromMe && m.serverId != null) {
          _pendingReceipts[conversationId] = m.serverId!;
          break;
        }
      }
    }
    await _save();
    notifyListeners();
    await flushReceipts();
  }

  /// Datos de prueba, claramente marcados. Nunca se envían al servidor.
  Future<void> setDemo(bool on) async {
    final demoIds = {for (final c in _conversations) if (c.isDemo) c.id};
    _conversations.removeWhere((c) => c.isDemo);
    _messages.removeWhere((k, _) => demoIds.contains(k));
    if (on) {
      final now = _now();
      for (final c in demoConversations(now)) {
        _conversations.add(c.$1);
        _messages[c.$1.id] = c.$2;
      }
    }
    await _save();
    notifyListeners();
  }
}

/// Conversaciones de demostración. Todo va marcado con isDemo = true.
List<(ChatConversation, List<ChatMessage>)> demoConversations(DateTime now) {
  ChatMessage msg(String conv, int i, bool me, String text, Duration ago, ChatMessageStatus s) =>
      ChatMessage(
        clientId: 'demo-$conv-$i',
        conversationId: conv,
        fromMe: me,
        text: text,
        createdAt: now.subtract(ago),
        status: me ? s : ChatMessageStatus.read,
        isDemo: true,
      );
  return [
    (
      ChatConversation(
          id: 'demo-ana',
          peer: const ChatUser('demo-u1', 'Ana (prueba)'),
          updatedAt: now.subtract(const Duration(minutes: 4)),
          unreadCount: 2,
          isDemo: true),
      [
        msg('demo-ana', 1, true, 'Hola Ana, ¿confirmamos el pedido de mañana?',
            const Duration(minutes: 40), ChatMessageStatus.read),
        msg('demo-ana', 2, false, 'Sí, 20 cajas de mandarina.', const Duration(minutes: 9),
            ChatMessageStatus.read),
        msg('demo-ana', 3, false, '¿Me envías la guía cuando salga?', const Duration(minutes: 4),
            ChatMessageStatus.read),
      ],
    ),
    (
      ChatConversation(
          id: 'demo-equipo',
          peer: const ChatUser('demo-u2', 'Equipo NEXLIA (prueba)'),
          updatedAt: now.subtract(const Duration(hours: 3)),
          isDemo: true),
      [
        msg('demo-equipo', 1, false, 'Esta es una conversación de prueba de NEXLIA Chat.',
            const Duration(hours: 5), ChatMessageStatus.read),
        msg('demo-equipo', 2, true, 'Te paso el resumen de la reunión.', const Duration(hours: 4), ChatMessageStatus.delivered),
        msg('demo-equipo', 3, true, '¿Revisaste la propuesta?', const Duration(hours: 3, minutes: 30), ChatMessageStatus.sent),
        msg('demo-equipo', 4, true, 'Este mensaje de prueba muestra un fallo.', const Duration(hours: 3, minutes: 10),
            ChatMessageStatus.failed),
        msg('demo-equipo', 5, true, 'Y este, uno pendiente.', const Duration(hours: 3), ChatMessageStatus.pending),
      ],
    ),
  ];
}
