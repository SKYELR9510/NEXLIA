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

/// Permiso de lectura de SMS. `unavailable`: el dispositivo no tiene mensajería
/// (por ejemplo, una tablet sin telefonía) o el puente nativo no responde.
enum SmsPermission { granted, denied, unavailable }

/// Por qué falló una lectura de SMS.
enum SmsReadErrorKind {
  /// Android retiró el permiso entre la comprobación y la consulta.
  permission,

  /// El proveedor de SMS falló (consulta rechazada, cursor nulo, base de datos ocupada...).
  provider,

  /// No hay proveedor de SMS en el dispositivo.
  unavailable,
}

class SmsReadException implements Exception {
  const SmsReadException(this.kind, [this.detail = '']);
  final SmsReadErrorKind kind;
  final String detail;
  @override
  String toString() => 'SmsReadException(${kind.name}: $detail)';
}

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

/// Lo que Android informa de las SIM para etiquetar SMS.
/// [slots]: ranuras del teléfono (0 si no se sabe). [active]: SIM activas legibles.
/// [readable]: false si Android no dejó leer las SIM (falta READ_PHONE_STATE).
class SmsSimInfo {
  const SmsSimInfo({this.slots = 0, this.active = const [], this.readable = true});
  final int slots;
  final List<SimSubscription> active;
  final bool readable;

  static const none = SmsSimInfo();

  /// Acepta el formato actual ({slots, subs, readable}) y la lista simple anterior.
  static SmsSimInfo fromNative(Object? raw) {
    if (raw is List) {
      return SmsSimInfo(active: raw.whereType<Map>().map(SimSubscription.fromMap).toList());
    }
    if (raw is Map) {
      return SmsSimInfo(
        slots: (raw['slots'] as num?)?.toInt() ?? 0,
        active: ((raw['subs'] as List?) ?? const []).whereType<Map>().map(SimSubscription.fromMap).toList(),
        readable: raw['readable'] != false,
      );
    }
    return none;
  }

  /// El teléfono admite dos o más SIM (aunque ahora tenga una sola o ninguna).
  bool get multiSim => (slots > 0 ? slots : active.length) >= 2;
}

const simUnknown = 'SIM no identificada';

/// Etiqueta de la SIM de un SMS.
/// - Teléfono de una sola ranura: '' (no se muestra, igual que en llamadas).
/// - Dos o más ranuras y la SIM del SMS está activa: "SIM n" o "SIM n · Operador".
/// - Dos o más ranuras y Android no da una SIM fiable (sub_id ausente, SIM retirada o
///   desactivada, o sin permiso para leer las SIM): "SIM no identificada".
String simLabelFor(SmsSimInfo sims, int subId) {
  if (!sims.multiSim) return '';
  if (subId < 0) return simUnknown;
  for (final s in sims.active) {
    if (s.subId != subId) continue;
    final base = s.slot > 0 ? 'SIM ${s.slot}' : '';
    final name = s.label.trim();
    final duplicated = sims.active.where((o) => o.label.trim() == name).length > 1;
    if (base.isEmpty) return name.isEmpty ? simUnknown : name;
    if (name.isEmpty || duplicated || name.toLowerCase() == base.toLowerCase()) return base;
    return '$base · $name';
  }
  return simUnknown;
}
