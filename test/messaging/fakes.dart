// Dobles de prueba de mensajería. Todos los datos son ficticios.
import 'package:phone/messaging/chat_api.dart';
import 'package:phone/messaging/models.dart';
import 'package:phone/messaging/sms_repository.dart';

/// API de Chat controlada por la prueba: cada envío consume la siguiente respuesta.
class FakeChatApi implements ChatApi {
  final List<Object> sendResults = [];
  final List<String> sentClientIds = [];
  final List<String> receipts = [];

  @override
  bool get isConfigured => true;

  @override
  Future<List<ChatConversation>> listConversations() async => [];

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId, {String? before, int limit = 50}) async => [];

  @override
  Future<ChatMessage> sendMessage(String conversationId, String clientId, String text) async {
    sentClientIds.add(clientId);
    final r = sendResults.isEmpty ? 'ok' : sendResults.removeAt(0);
    if (r is ChatError) throw r;
    return ChatMessage(
      clientId: clientId,
      serverId: 'srv-$clientId',
      conversationId: conversationId,
      fromMe: true,
      text: text,
      createdAt: DateTime.utc(2026, 1, 1),
      status: ChatMessageStatus.sent,
    );
  }

  @override
  Future<void> sendReceipt(String conversationId, String upToMessageId, String kind) async {
    receipts.add('$conversationId:$upToMessageId:$kind');
  }
}

class FakeSmsSource implements SmsSource {
  FakeSmsSource({this.perm = SmsPermission.denied, this.grantOnRequest = true});

  SmsPermission perm;
  bool grantOnRequest;
  int reads = 0;
  int requests = 0;
  final List<String> composed = [];
  List<SmsThread> data = [];
  Map<String, List<SmsMessage>> msgs = {};
  List<SimSubscription> sims = [];

  @override
  Future<SmsPermission> permission() async => perm;

  @override
  Future<bool> requestPermission() async {
    requests++;
    if (grantOnRequest) perm = SmsPermission.granted;
    return grantOnRequest;
  }

  @override
  Future<List<SmsThread>> threads() async {
    reads++;
    return data;
  }

  @override
  Future<List<SmsMessage>> messages(String threadId) async {
    reads++;
    return msgs[threadId] ?? const [];
  }

  @override
  Future<List<SimSubscription>> subscriptions() async => sims;

  @override
  Future<bool> openComposer(String address) async {
    composed.add(address);
    return true;
  }
}
