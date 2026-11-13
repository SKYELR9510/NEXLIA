import 'chat_repository.dart';
import 'models.dart';
import 'sms_repository.dart';

enum InboxFilter { all, chat, sms }

/// Fila de la bandeja unificada. Es solo una vista: conserva su canal y no se guarda.
class InboxItem {
  const InboxItem({
    required this.channel,
    required this.id,
    required this.title,
    required this.preview,
    required this.time,
    this.unread = 0,
    this.pending = 0,
    this.failed = false,
    this.isDemo = false,
    this.simLabel = '',
    this.address = '',
  });

  final MessageChannel channel;
  final String id;
  final String title;
  final String preview;
  final DateTime time;
  final int unread;
  final int pending;
  final bool failed;
  final bool isDemo;
  final String simLabel;
  final String address;
}

List<InboxItem> chatItems(ChatRepository chat) => [
      for (final c in chat.conversations)
        () {
          final last = chat.lastMessage(c.id);
          final msgs = chat.messagesOf(c.id);
          return InboxItem(
            channel: MessageChannel.chat,
            id: c.id,
            title: c.peer.displayName,
            preview: last == null ? '' : (last.fromMe ? 'Tú: ${last.text}' : last.text),
            time: (last?.createdAt ?? c.updatedAt).toLocal(),
            unread: c.unreadCount,
            pending: chat.pendingCount(c.id),
            failed: msgs.any((m) => m.fromMe && m.status == ChatMessageStatus.failed),
            isDemo: c.isDemo,
          );
        }(),
    ];

List<InboxItem> smsItems(SmsRepository sms, String Function(String address) nameFor) => [
      for (final t in sms.threads)
        InboxItem(
          channel: MessageChannel.sms,
          id: t.threadId,
          // Borradores o remitentes sin número: el proveedor puede dar la dirección vacía.
          title: t.address.trim().isEmpty ? 'Sin número' : nameFor(t.address),
          preview: t.snippet,
          time: t.date,
          unread: t.unreadCount,
          simLabel: sms.simLabel(t.subId),
          address: t.address,
        ),
    ];

/// Combina, filtra, busca y ordena (más reciente primero). Función pura.
List<InboxItem> buildInbox(List<InboxItem> items, InboxFilter filter, String query) {
  final q = query.trim().toLowerCase();
  final out = items.where((i) {
    if (filter == InboxFilter.chat && i.channel != MessageChannel.chat) return false;
    if (filter == InboxFilter.sms && i.channel != MessageChannel.sms) return false;
    if (q.isEmpty) return true;
    return i.title.toLowerCase().contains(q) ||
        i.preview.toLowerCase().contains(q) ||
        i.address.toLowerCase().contains(q);
  }).toList()
    ..sort((a, b) => b.time.compareTo(a.time));
  return out;
}

int unreadTotal(List<InboxItem> items) => items.fold(0, (n, i) => n + i.unread);
