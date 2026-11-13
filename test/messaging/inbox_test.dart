// Bandeja unificada: separación de canales, filtros, búsqueda y no leídos.
import 'package:flutter_test/flutter_test.dart';
import 'package:phone/messaging/chat_api.dart';
import 'package:phone/messaging/chat_repository.dart';
import 'package:phone/messaging/inbox.dart';
import 'package:phone/messaging/models.dart';
import 'package:phone/messaging/sms_repository.dart';

import 'fakes.dart';

void main() {
  final t0 = DateTime(2026, 5, 1, 12);
  InboxItem chat(String id, int min, {int unread = 0}) => InboxItem(
      channel: MessageChannel.chat, id: id, title: 'Chat $id', preview: 'hola chat', time: t0.add(Duration(minutes: min)), unread: unread);
  InboxItem sms(String id, int min, {int unread = 0}) => InboxItem(
      channel: MessageChannel.sms,
      id: id,
      title: 'SMS $id',
      preview: 'código 1234',
      time: t0.add(Duration(minutes: min)),
      unread: unread,
      address: '+51900000$id');

  final items = [chat('a', 1, unread: 2), sms('1', 3, unread: 1), chat('b', 5), sms('2', 0)];

  test('Todos: ambos canales, del más reciente al más antiguo', () {
    expect(buildInbox(items, InboxFilter.all, '').map((i) => i.id), ['b', '1', 'a', '2']);
  });

  test('filtros: cada uno muestra solo su canal', () {
    expect(buildInbox(items, InboxFilter.chat, '').every((i) => i.channel == MessageChannel.chat), isTrue);
    expect(buildInbox(items, InboxFilter.sms, '').every((i) => i.channel == MessageChannel.sms), isTrue);
    expect(buildInbox(items, InboxFilter.chat, '').length, 2);
    expect(buildInbox(items, InboxFilter.sms, '').length, 2);
  });

  test('búsqueda por nombre, texto y número, sin distinguir mayúsculas', () {
    expect(buildInbox(items, InboxFilter.all, 'CHAT A').map((i) => i.id), ['a']);
    expect(buildInbox(items, InboxFilter.all, 'código').length, 2);
    expect(buildInbox(items, InboxFilter.all, '9000002').map((i) => i.id), ['2']);
    expect(buildInbox(items, InboxFilter.chat, 'código'), isEmpty);
  });

  test('no leídos: suma de ambos canales', () {
    expect(unreadTotal(items), 3);
  });

  test('desde los repositorios: Chat y SMS conservan su canal y la SIM solo con dos SIM', () async {
    final c = ChatRepository(store: MemoryStore(), api: const UnconfiguredChatApi());
    await c.load();
    await c.setDemo(true);
    final src = FakeSmsSource(perm: SmsPermission.granted)
      ..data = [SmsThread(threadId: '7', address: '+51900000007', snippet: 'hola', date: t0, subId: 2)]
      ..simInfo = const SmsSimInfo(slots: 2, active: [SimSubscription(1, 'Claro', 1), SimSubscription(2, '', 2)]);
    final s = SmsRepository(src, store: consented());
    await s.load();

    final ci = chatItems(c);
    final si = smsItems(s, (a) => a == '+51900000007' ? 'Contacto prueba' : a);
    expect(ci.every((i) => i.channel == MessageChannel.chat && i.isDemo), isTrue);
    expect(ci.any((i) => i.pending > 0 && i.failed), isTrue);
    expect(si.single.channel, MessageChannel.sms);
    expect(si.single.title, 'Contacto prueba');
    expect(si.single.simLabel, 'SIM 2');
    expect(si.single.isDemo, isFalse);
  });
}
