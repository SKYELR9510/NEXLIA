import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Errores de NEXLIA Chat, traducidos desde la red o el servidor.
sealed class ChatError implements Exception {
  const ChatError(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// No hay servidor configurado (Fase 1: no existe backend de Chat).
class ChatNotConfiguredError extends ChatError {
  const ChatNotConfiguredError() : super('NEXLIA Chat no tiene servidor configurado');
}

/// Sin red, tiempo agotado o conexión rechazada: se reintenta.
class ChatNetworkError extends ChatError {
  const ChatNetworkError(super.message);
}

/// Sin sesión o sesión no válida (401): requiere iniciar sesión.
class ChatAuthError extends ChatError {
  const ChatAuthError(super.message);
}

/// El servidor rechazó la petición de forma definitiva (400, 403, 404, 422).
class ChatRejectedError extends ChatError {
  const ChatRejectedError(this.status, String message) : super(message);
  final int status;
}

/// Error temporal del servidor (429, 5xx) o respuesta inválida: se reintenta.
class ChatServerError extends ChatError {
  const ChatServerError(this.status, String message) : super(message);
  final int status;
}

/// Contrato de API de NEXLIA Chat v1 (ver docs/FASE1_MENSAJERIA.md §5).
abstract class ChatApi {
  bool get isConfigured;
  Future<List<ChatConversation>> listConversations();
  Future<List<ChatMessage>> fetchMessages(String conversationId, {String? before, int limit = 50});
  Future<ChatMessage> sendMessage(String conversationId, String clientId, String text);
  Future<void> sendReceipt(String conversationId, String upToMessageId, String kind);
}

/// Sin servidor: cada operación lo dice. No simula respuestas.
class UnconfiguredChatApi implements ChatApi {
  const UnconfiguredChatApi();
  @override
  bool get isConfigured => false;
  @override
  Future<List<ChatConversation>> listConversations() async => throw const ChatNotConfiguredError();
  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId, {String? before, int limit = 50}) async =>
      throw const ChatNotConfiguredError();
  @override
  Future<ChatMessage> sendMessage(String conversationId, String clientId, String text) async =>
      throw const ChatNotConfiguredError();
  @override
  Future<void> sendReceipt(String conversationId, String upToMessageId, String kind) async =>
      throw const ChatNotConfiguredError();
}

/// Token de sesión. En la Fase 1 no hay autenticación: devuelve null.
typedef TokenProvider = Future<String?> Function();

/// Cliente HTTP del contrato v1 con `dart:io` (sin dependencias nuevas).
class HttpChatApi implements ChatApi {
  HttpChatApi({
    required this.baseUrl,
    required this.token,
    required this.myUserId,
    this.timeout = const Duration(seconds: 10),
    bool allowInsecureHttp = false,
    HttpClient? client,
  }) : _client = client ?? HttpClient() {
    if (baseUrl.scheme != 'https' && !allowInsecureHttp) {
      throw ArgumentError('NEXLIA Chat exige HTTPS: $baseUrl');
    }
  }

  final Uri baseUrl;
  final TokenProvider token;
  final String myUserId;
  final Duration timeout;
  final HttpClient _client;

  @override
  bool get isConfigured => true;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.path.endsWith('/') ? baseUrl : baseUrl.replace(path: '${baseUrl.path}/');
    final u = base.resolve(path);
    return query == null || query.isEmpty ? u : u.replace(queryParameters: query);
  }

  Future<Object?> _request(String method, String path,
      {Map<String, String>? query, Object? body, Map<String, String> headers = const {}}) async {
    final t = await token();
    if (t == null || t.isEmpty) throw const ChatAuthError('Sin sesión de NEXLIA Chat');
    late HttpClientResponse res;
    late String text;
    try {
      final req = await _client.openUrl(method, _uri(path, query)).timeout(timeout);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $t');
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      headers.forEach(req.headers.set);
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      res = await req.close().timeout(timeout);
      text = await res.transform(utf8.decoder).join().timeout(timeout);
    } on TimeoutException {
      throw const ChatNetworkError('Tiempo de espera agotado');
    } on SocketException catch (e) {
      throw ChatNetworkError('Sin conexión: ${e.message}');
    } on HandshakeException catch (e) {
      throw ChatNetworkError('Error TLS: ${e.message}');
    } on HttpException catch (e) {
      throw ChatNetworkError('Error HTTP: ${e.message}');
    }

    final s = res.statusCode;
    if (s == 401) throw const ChatAuthError('Sesión no válida');
    if (s == 429 || s >= 500) throw ChatServerError(s, 'Error temporal del servidor ($s)');
    if (s >= 400) throw ChatRejectedError(s, 'Petición rechazada ($s)');
    if (text.trim().isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      throw ChatServerError(s, 'Respuesta no válida del servidor');
    }
  }

  ChatMessage _message(Map m, String conversationId) {
    final status = ChatMessageStatus.values.firstWhere((x) => x.name == m['status'],
        orElse: () => ChatMessageStatus.sent);
    return ChatMessage(
      clientId: (m['clientId'] ?? m['id'] ?? '').toString(),
      serverId: m['id']?.toString(),
      conversationId: conversationId,
      fromMe: m['senderId']?.toString() == myUserId,
      text: (m['text'] ?? '').toString(),
      createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString())?.toUtc() ?? DateTime.now().toUtc(),
      status: status == ChatMessageStatus.pending ? ChatMessageStatus.sent : status,
    );
  }

  Map _object(Object? data) {
    if (data is Map) return data;
    throw const ChatServerError(200, 'Respuesta no válida del servidor');
  }

  @override
  Future<List<ChatConversation>> listConversations() async {
    final data = _object(await _request('GET', 'v1/conversations'));
    final list = (data['conversations'] as List?) ?? const [];
    return list.whereType<Map>().map(ChatConversation.fromJson).toList();
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId, {String? before, int limit = 50}) async {
    final data = _object(await _request('GET', 'v1/conversations/${Uri.encodeComponent(conversationId)}/messages',
        query: {'limit': '$limit', 'before': ?before}));
    final list = (data['messages'] as List?) ?? const [];
    return list.whereType<Map>().map((m) => _message(m, conversationId)).toList();
  }

  @override
  Future<ChatMessage> sendMessage(String conversationId, String clientId, String text) async {
    final data = _object(await _request(
      'POST',
      'v1/conversations/${Uri.encodeComponent(conversationId)}/messages',
      headers: {'Idempotency-Key': clientId},
      body: {'clientId': clientId, 'text': text},
    ));
    return _message(_object(data['message']), conversationId);
  }

  @override
  Future<void> sendReceipt(String conversationId, String upToMessageId, String kind) async {
    await _request('POST', 'v1/conversations/${Uri.encodeComponent(conversationId)}/receipts',
        body: {'upToMessageId': upToMessageId, 'kind': kind});
  }
}

/// Configuración de NEXLIA Chat. La URL se fija al compilar
/// (`--dart-define=NEXLIA_CHAT_URL=https://...`); hoy no existe servidor.
class ChatConfig {
  static const serverUrl = String.fromEnvironment('NEXLIA_CHAT_URL');

  static ChatApi api() {
    if (serverUrl.isEmpty) return const UnconfiguredChatApi();
    // Sin autenticación implementada todavía: el token es nulo y cada
    // petición responde ChatAuthError sin salir a la red.
    return HttpChatApi(baseUrl: Uri.parse(serverUrl), token: () async => null, myUserId: '');
  }
}
