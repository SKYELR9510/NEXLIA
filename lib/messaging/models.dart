// Modelos de mensajería. NEXLIA Chat (Internet) y SMS (operador) son canales
// separados: entidades, almacenamiento y repositorios distintos.

enum MessageChannel { chat, sms }

/// Estado de un mensaje propio de NEXLIA Chat.
enum ChatMessageStatus { pending, sent, delivered, read, failed }

/// Estado de la conexión con el servidor de NEXLIA Chat.
enum ChatConnection {
  /// No hay servidor configurado: los mensajes quedan pendientes en el teléfono.
  notConfigured,

  /// Hay servidor, pero el último intento falló por red.
  offline,

  /// El último intento con el servidor fue correcto.
  online,
}

DateTime _date(Object? v) =>
    DateTime.tryParse((v ?? '').toString())?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

class ChatUser {
  const ChatUser(this.id, this.displayName);
  final String id;
  final String displayName;

  Map<String, Object?> toJson() => {'id': id, 'displayName': displayName};
  static ChatUser fromJson(Map m) =>
      ChatUser((m['id'] ?? '').toString(), (m['displayName'] ?? '').toString());
}

class ChatConversation {
  ChatConversation({
    required this.id,
    required this.peer,
    required this.updatedAt,
    this.unreadCount = 0,
    this.isDemo = false,
  });

  final String id;
  final ChatUser peer;
  DateTime updatedAt;
  int unreadCount;

  /// Datos de prueba: nunca se envían al servidor y se marcan como PRUEBA.
  final bool isDemo;

  Map<String, Object?> toJson() => {
        'id': id,
        'peer': peer.toJson(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'unreadCount': unreadCount,
        'isDemo': isDemo,
      };

  static ChatConversation fromJson(Map m) => ChatConversation(
        id: (m['id'] ?? '').toString(),
        peer: ChatUser.fromJson((m['peer'] as Map?) ?? const {}),
        updatedAt: _date(m['updatedAt']),
        unreadCount: (m['unreadCount'] as num?)?.toInt() ?? 0,
        isDemo: m['isDemo'] == true,
      );
}

class ChatMessage {
  ChatMessage({
    required this.clientId,
    required this.conversationId,
    required this.fromMe,
    required this.text,
    required this.createdAt,
    this.serverId,
    this.status = ChatMessageStatus.pending,
    this.attempts = 0,
    this.lastError,
    this.isDemo = false,
  });

  /// Identificador generado en el teléfono: clave de idempotencia al enviar.
  final String clientId;
  String? serverId;
  final String conversationId;
  final bool fromMe;
  final String text;
  final DateTime createdAt;
  ChatMessageStatus status;
  int attempts;
  String? lastError;
  final bool isDemo;

  Map<String, Object?> toJson() => {
        'clientId': clientId,
        'serverId': serverId,
        'conversationId': conversationId,
        'fromMe': fromMe,
        'text': text,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'status': status.name,
        'attempts': attempts,
        'lastError': lastError,
        'isDemo': isDemo,
      };

  static ChatMessage fromJson(Map m) => ChatMessage(
        clientId: (m['clientId'] ?? '').toString(),
        serverId: m['serverId']?.toString(),
        conversationId: (m['conversationId'] ?? '').toString(),
        fromMe: m['fromMe'] == true,
        text: (m['text'] ?? '').toString(),
        createdAt: _date(m['createdAt']),
        status: ChatMessageStatus.values.firstWhere((s) => s.name == m['status'],
            orElse: () => ChatMessageStatus.pending),
        attempts: (m['attempts'] as num?)?.toInt() ?? 0,
        lastError: m['lastError']?.toString(),
        isDemo: m['isDemo'] == true,
      );
}

/// Permiso de lectura de SMS.
enum SmsPermission { granted, denied, unavailable }

/// Bandeja del proveedor de SMS de Android (Telephony.Sms.TYPE).
enum SmsBox { inbox, sent, draft, outbox, failed, queued, other }

SmsBox smsBoxFromType(int type) {
  switch (type) {
    case 1:
      return SmsBox.inbox;
    case 2:
      return SmsBox.sent;
    case 3:
      return SmsBox.draft;
    case 4:
      return SmsBox.outbox;
    case 5:
      return SmsBox.failed;
    case 6:
      return SmsBox.queued;
    default:
      return SmsBox.other;
  }
}

/// Hilo de SMS leído del teléfono. NEXLIA no lo guarda ni lo copia.
class SmsThread {
  const SmsThread({
    required this.threadId,
    required this.address,
    required this.snippet,
    required this.date,
    this.unreadCount = 0,
    this.subId = -1,
  });

  final String threadId;
  final String address;
  final String snippet;
  final DateTime date;
  final int unreadCount;
  final int subId;

  static SmsThread fromMap(Map m) => SmsThread(
        threadId: (m['threadId'] ?? '').toString(),
        address: (m['address'] ?? '').toString(),
        snippet: (m['snippet'] ?? '').toString(),
        date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num?)?.toInt() ?? 0),
        unreadCount: (m['unreadCount'] as num?)?.toInt() ?? 0,
        subId: (m['subId'] as num?)?.toInt() ?? -1,
      );
}

class SmsMessage {
  const SmsMessage({
    required this.id,
    required this.threadId,
    required this.address,
    required this.body,
    required this.date,
    required this.box,
    this.read = true,
    this.subId = -1,
    this.isMms = false,
  });

  final String id;
  final String threadId;
  final String address;
  final String body;
  final DateTime date;
  final SmsBox box;
  final bool read;
  final int subId;

  /// Preparado para MMS; en la Fase 1 solo se leen SMS (siempre false).
  final bool isMms;

  bool get incoming => box == SmsBox.inbox;

  static SmsMessage fromMap(Map m) => SmsMessage(
        id: (m['id'] ?? '').toString(),
        threadId: (m['threadId'] ?? '').toString(),
        address: (m['address'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num?)?.toInt() ?? 0),
        box: smsBoxFromType((m['type'] as num?)?.toInt() ?? 0),
        read: m['read'] != false,
        subId: (m['subId'] as num?)?.toInt() ?? -1,
      );
}

/// Suscripción (SIM) tal como la usa el proveedor de SMS (sub_id).
class SimSubscription {
  const SimSubscription(this.subId, this.label, this.slot);
  final int subId;
  final String label;
  final int slot;

  static SimSubscription fromMap(Map m) => SimSubscription(
        (m['subId'] as num?)?.toInt() ?? -1,
        (m['label'] ?? '').toString(),
        (m['slot'] as num?)?.toInt() ?? 0,
      );
}
