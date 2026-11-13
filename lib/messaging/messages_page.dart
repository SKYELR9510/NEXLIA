import 'package:flutter/cupertino.dart';

import '../common.dart';
import '../native.dart';
import 'chat_repository.dart';
import 'conversation_page.dart';
import 'inbox.dart';
import 'models.dart';
import 'sms_repository.dart';

/// Colores de canal: NEXLIA Chat usa el color de marca; SMS un verde propio.
Color chatColor(BuildContext c) => accentColor(c);
const smsColor = Color(0xFF12B886);

/// Pestaña "Mensajes": bandeja unificada de NEXLIA Chat y SMS.
/// Los canales se muestran juntos pero cada fila conserva su canal.
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, required this.chat, required this.sms, this.nameFor});

  final ChatRepository chat;
  final SmsRepository sms;

  /// Nombre para mostrar de un número (agenda). Por defecto, el propio número.
  final String Function(String address)? nameFor;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  InboxFilter filter = InboxFilter.all;
  String query = '';
  bool asking = false;

  @override
  void initState() {
    super.initState();
    // Al abrir se reintenta la cola de mensajes que el usuario ya envió (nunca se crean mensajes).
    if (!widget.chat.loaded) widget.chat.load().then((_) => widget.chat.flushOutbox());
    if (!widget.sms.loaded) widget.sms.load();
  }

  String _name(String address) => widget.nameFor?.call(address) ?? address;

  Future<void> _allowSms() async {
    if (asking) return;
    setState(() => asking = true);
    final ok = await widget.sms.requestAccess();
    if (mounted) setState(() => asking = false);
    if (!ok && mounted && widget.sms.permission == SmsPermission.denied) {
      final open = await confirm(context,
          'Sin permiso no se muestran tus SMS. Puedes activarlo en Ajustes > Permisos > SMS.',
          'Abrir ajustes');
      if (open) await Native.openSettings('app');
    }
  }

  void _open(InboxItem i) {
    Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute<void>(
      builder: (_) => i.channel == MessageChannel.chat
          ? ChatConversationPage(chat: widget.chat, conversationId: i.id)
          : SmsThreadPage(sms: widget.sms, threadId: i.id, title: i.title, address: i.address),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.chat, widget.sms]),
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final all = [...chatItems(widget.chat), ...smsItems(widget.sms, _name)];
    final items = buildInbox(all, filter, query);
    final showChat = filter != InboxFilter.sms;
    final showSms = filter != InboxFilter.chat;
    final smsBlocked = widget.sms.loaded && widget.sms.permission != SmsPermission.granted;
    final unread = unreadTotal(all);

    return ListView(
      padding: EdgeInsets.only(bottom: barSpace(context) + 12),
      children: [
        ScreenTitle('Mensajes',
            trailing: unread > 0
                ? Semantics(
                    label: '$unread sin leer',
                    child: ExcludeSemantics(child: _CountBadge(unread, color: accentColor(context))),
                  )
                : null),
        SearchPill(placeholder: 'Buscar en mensajes', onChanged: (v) => setState(() => query = v)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Pill('Todos', selected: filter == InboxFilter.all, onTap: () => setState(() => filter = InboxFilter.all)),
              const SizedBox(width: 8),
              Pill('NEXLIA Chat',
                  selected: filter == InboxFilter.chat, onTap: () => setState(() => filter = InboxFilter.chat)),
              const SizedBox(width: 8),
              Pill('SMS', selected: filter == InboxFilter.sms, onTap: () => setState(() => filter = InboxFilter.sms)),
            ],
          ),
        ),
        if (showChat && widget.chat.loaded && widget.chat.connection != ChatConnection.online)
          _ChatStatusBanner(connection: widget.chat.connection, hasDemo: widget.chat.hasDemo),
        if (showSms && smsBlocked)
          _SmsPermissionCard(
            unavailable: widget.sms.permission == SmsPermission.unavailable,
            busy: asking,
            onAllow: _allowSms,
          ),
        if (items.isEmpty)
          _EmptyState(filter: filter, searching: query.trim().isNotEmpty, smsBlocked: smsBlocked)
        else
          for (final i in items) _InboxRow(item: i, onTap: () => _open(i)),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count, {required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Etiqueta del canal en cada fila: nunca se confunde un SMS con un Chat.
class ChannelTag extends StatelessWidget {
  const ChannelTag(this.channel, {super.key});
  final MessageChannel channel;

  @override
  Widget build(BuildContext context) {
    final chat = channel == MessageChannel.chat;
    final color = chat ? chatColor(context) : smsColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chat ? CupertinoIcons.cloud_fill : CupertinoIcons.antenna_radiowaves_left_right,
              size: 11, color: color),
          const SizedBox(width: 3),
          Text(chat ? 'Chat' : 'SMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Marca visible de datos de prueba.
class DemoTag extends StatelessWidget {
  const DemoTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: CupertinoColors.systemOrange.resolveFrom(context).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('PRUEBA',
          style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w800,
              color: CupertinoColors.systemOrange.resolveFrom(context))),
    );
  }
}

String _when(DateTime t) {
  final now = DateTime.now();
  if (t.year == now.year && t.month == now.month && t.day == now.day) return formatTime(t);
  return formatDay(t);
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.item, required this.onTap});
  final InboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final bold = i.unread > 0;
    final channel = i.channel == MessageChannel.chat ? 'NEXLIA Chat' : 'SMS';
    final parts = [
      i.title,
      channel,
      if (i.isDemo) 'conversación de prueba',
      if (i.simLabel.isNotEmpty) i.simLabel,
      if (i.unread > 0) '${i.unread} sin leer',
      if (i.pending > 0) '${i.pending} pendiente${i.pending == 1 ? '' : 's'} de envío',
      if (i.failed) 'hay mensajes no enviados',
      i.preview,
    ];
    return Semantics(
      button: true,
      label: parts.where((p) => p.isNotEmpty).join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Sin el sufijo "(prueba)" para que las iniciales sean letras.
                  Avatar(i.title.replaceAll(RegExp(r'\s*\(.*?\)'), ''), size: 50),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: i.channel == MessageChannel.chat ? chatColor(context) : smsColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: bgColor(context), width: 2),
                      ),
                      child: Icon(
                          i.channel == MessageChannel.chat
                              ? CupertinoIcons.cloud_fill
                              : CupertinoIcons.chat_bubble_fill,
                          size: 10,
                          color: const Color(0xFFFFFFFF)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(i.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                                  color: labelColor(context))),
                        ),
                        const SizedBox(width: 8),
                        Text(_when(i.time),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                                color: bold ? accentColor(context) : secondaryColor(context))),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (i.pending > 0) ...[
                          Icon(CupertinoIcons.clock, size: 14, color: secondaryColor(context)),
                          const SizedBox(width: 4),
                        ],
                        if (i.failed) ...[
                          const Icon(CupertinoIcons.exclamationmark_circle_fill, size: 14, color: Color(0xFFFF3B30)),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(i.preview.isEmpty ? 'Sin mensajes' : i.preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 15,
                                  height: 1.25,
                                  color: bold ? labelColor(context) : secondaryColor(context))),
                        ),
                        if (i.unread > 0) ...[
                          const SizedBox(width: 8),
                          _CountBadge(i.unread, color: accentColor(context)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ChannelTag(i.channel),
                        if (i.isDemo) const DemoTag(),
                        if (i.simLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: fillColor(context), borderRadius: BorderRadius.circular(6)),
                            child: Text(i.simLabel,
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600, color: secondaryColor(context))),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.title, required this.text, this.action});
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: labelColor(context))),
                const SizedBox(height: 3),
                Text(text, style: TextStyle(fontSize: 13.5, height: 1.3, color: secondaryColor(context))),
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado real del canal Chat. No se simula una conexión que no existe.
class _ChatStatusBanner extends StatelessWidget {
  const _ChatStatusBanner({required this.connection, required this.hasDemo});
  final ChatConnection connection;
  final bool hasDemo;

  @override
  Widget build(BuildContext context) {
    if (connection == ChatConnection.offline) {
      return _Banner(
        icon: CupertinoIcons.wifi_slash,
        color: CupertinoColors.systemOrange.resolveFrom(context),
        title: 'Sin conexión con NEXLIA Chat',
        text: 'Tus mensajes quedan guardados en el teléfono como pendientes. Se reintentan al abrir Mensajes o al tocar Reintentar.',
      );
    }
    return _Banner(
      icon: CupertinoIcons.cloud,
      color: chatColor(context),
      title: 'NEXLIA Chat aún no está conectado',
      text: hasDemo
          ? 'Todavía no hay servidor de Chat. Las conversaciones marcadas PRUEBA son de demostración y no se envían a nadie.'
          : 'Todavía no hay servidor de Chat, así que no hay conversaciones por Internet.',
    );
  }
}

class _SmsPermissionCard extends StatelessWidget {
  const _SmsPermissionCard({required this.unavailable, required this.busy, required this.onAllow});
  final bool unavailable;
  final bool busy;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    if (unavailable) {
      return const _Banner(
        icon: CupertinoIcons.exclamationmark_triangle,
        color: smsColor,
        title: 'SMS no disponibles',
        text: 'Este teléfono no permite leer los SMS desde NEXLIA.',
      );
    }
    return _Banner(
      icon: CupertinoIcons.lock_shield,
      color: smsColor,
      title: 'Ver tus SMS en NEXLIA',
      text: 'NEXLIA necesita permiso para leer los SMS del teléfono. Solo se leen para mostrarlos aquí: '
          'no se copian a ningún servidor, no se analizan y NEXLIA no envía SMS por su cuenta.',
      action: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
        color: smsColor,
        borderRadius: BorderRadius.circular(18),
        onPressed: busy ? null : onAllow,
        child: const Text('Permitir lectura de SMS',
            style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, required this.searching, required this.smsBlocked});
  final InboxFilter filter;
  final bool searching;
  final bool smsBlocked;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String title;
    final String text;
    if (searching) {
      icon = CupertinoIcons.search;
      title = 'Sin resultados';
      text = 'No hay conversaciones que coincidan con tu búsqueda.';
    } else if (filter == InboxFilter.chat) {
      icon = CupertinoIcons.cloud;
      title = 'Sin conversaciones de Chat';
      text = 'Cuando NEXLIA Chat tenga servidor, tus conversaciones por Internet aparecerán aquí.';
    } else if (filter == InboxFilter.sms) {
      icon = CupertinoIcons.chat_bubble_2;
      title = smsBlocked ? 'SMS sin permiso' : 'Sin SMS';
      text = smsBlocked ? 'Permite la lectura de SMS para verlos aquí.' : 'No hay SMS en este teléfono.';
    } else {
      icon = CupertinoIcons.chat_bubble_2;
      title = 'Aún no hay mensajes';
      text = 'Aquí verás juntos tus SMS y tus conversaciones de NEXLIA Chat, cada uno con su canal.';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 24),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(24)),
            child: Icon(icon, size: 36, color: accentColor(context)),
          ),
          const SizedBox(height: 18),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: labelColor(context))),
          const SizedBox(height: 6),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.3, color: secondaryColor(context))),
        ],
      ),
    );
  }
}
