import 'package:flutter/cupertino.dart';

import '../common.dart';
import '../native.dart';
import 'a11y.dart';
import 'chat_repository.dart';
import 'conversation_page.dart';
import 'inbox.dart';
import 'models.dart';
import 'palette.dart';
import 'sms_repository.dart';

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

const _filterNames = {
  InboxFilter.all: 'Todos',
  InboxFilter.chat: 'NEXLIA Chat',
  InboxFilter.sms: 'SMS',
};

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
    final sms = widget.sms;
    final all = [...chatItems(widget.chat), ...smsItems(sms, _name)];
    final items = buildInbox(all, filter, query);
    final showChat = filter != InboxFilter.sms;
    final showSms = filter != InboxFilter.chat;
    final smsBlocked = sms.loaded && !sms.canRead;
    final unread = unreadTotal(all);

    return FocusTraversalGroup(
      child: ListView(
        padding: EdgeInsets.only(bottom: barSpace(context) + 12),
        children: [
          InfoBlock(
            header: true,
            label: unread > 0 ? 'Mensajes, $unread sin leer' : 'Mensajes',
            child: ScreenTitle('Mensajes',
                trailing: unread > 0 ? _CountBadge(unread, color: chatSolid(context)) : null),
          ),
          _SearchField(onChanged: (v) => setState(() => query = v)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(
              children: [
                for (final f in InboxFilter.values)
                  Tappable(
                    label: 'Filtro ${_filterNames[f]}',
                    hint: filter == f ? null : 'Mostrar solo ${f == InboxFilter.all ? 'todos los canales' : _filterNames[f]}',
                    selected: filter == f,
                    inGroup: true,
                    radius: 24,
                    onTap: () => setState(() => filter = f),
                    child: _FilterChip(_filterNames[f]!, selected: filter == f),
                  ),
              ],
            ),
          ),
          if (showChat && widget.chat.loaded && widget.chat.connection != ChatConnection.online)
            _ChatStatusBanner(connection: widget.chat.connection, hasDemo: widget.chat.hasDemo),
          if (showSms && sms.loaded && sms.canRead && sms.error != null)
            _SmsErrorBanner(onRetry: sms.load),
          if (showSms && smsBlocked)
            _SmsPermissionCard(
              unavailable: sms.permission == SmsPermission.unavailable,
              alreadyGranted: sms.permission == SmsPermission.granted,
              revoked: sms.permissionRevoked,
              busy: asking,
              onAllow: _allowSms,
            ),
          if (items.isEmpty)
            _EmptyState(filter: filter, searching: query.trim().isNotEmpty, smsBlocked: smsBlocked)
          else
            for (final i in items) _InboxRow(item: i, onTap: () => _open(i)),
        ],
      ),
    );
  }
}

/// Buscador de la bandeja: 48 de alto y etiqueta propia para el lector de pantalla.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Semantics(
        container: true,
        textField: true,
        label: 'Buscar en mensajes',
        child: CupertinoTextField(
          placeholder: 'Buscar en mensajes',
          onChanged: onChanged,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: ExcludeSemantics(child: Icon(CupertinoIcons.search, size: 20, color: labelColor(context))),
          ),
          placeholderStyle: TextStyle(color: secondaryColor(context), fontSize: 16),
          style: TextStyle(color: labelColor(context), fontSize: 16),
          decoration: BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}

/// Filtro con el mismo estilo de marca que las píldoras de la app, pero con
/// contraste AA: el degradado se oscurece si el texto blanco no se lee bien.
class _FilterChip extends StatelessWidget {
  const _FilterChip(this.text, {required this.selected});
  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final a = accentColor(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(colors: [solidFor(Color.lerp(a, const Color(0xFF19E3FF), 0.65)!), chatSolid(context)])
            : null,
        color: selected ? null : fillColor(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: selected ? onSolid : labelColor(context))),
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
          style: const TextStyle(color: onSolid, fontSize: 12, fontWeight: FontWeight.w700)),
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
    final ink = chat ? chatInk(context) : smsInk(context);
    final tint = chat ? accentColor(context) : smsSolid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chat ? CupertinoIcons.cloud_fill : CupertinoIcons.antenna_radiowaves_left_right, size: 11, color: ink),
          const SizedBox(width: 3),
          Text(chat ? 'Chat' : 'SMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink)),
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
      decoration: BoxDecoration(color: demoTint.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
      child: Text('PRUEBA',
          style: TextStyle(fontSize: 10, letterSpacing: 0.4, fontWeight: FontWeight.w800, color: demoInk(context))),
    );
  }
}

String _when(DateTime t) {
  final now = DateTime.now();
  if (t.year == now.year && t.month == now.month && t.day == now.day) return formatTime(t);
  return formatDay(t);
}

/// Texto que lee el lector de pantalla para una fila de la bandeja.
String inboxRowLabel(InboxItem i) => [
      i.title,
      i.channel == MessageChannel.chat ? 'NEXLIA Chat' : 'SMS',
      if (i.isDemo) 'conversación de prueba',
      if (i.simLabel.isNotEmpty) i.simLabel,
      if (i.unread > 0) '${i.unread} sin leer',
      if (i.pending > 0) '${i.pending} pendiente${i.pending == 1 ? '' : 's'} de envío',
      if (i.failed) 'hay mensajes no enviados',
      _when(i.time),
      i.preview,
    ].where((p) => p.isNotEmpty).join(', ');

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.item, required this.onTap});
  final InboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final bold = i.unread > 0;
    return Tappable(
      label: inboxRowLabel(i),
      hint: 'Abrir conversación',
      radius: 16,
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
                      color: i.channel == MessageChannel.chat ? chatSolid(context) : smsSolid,
                      shape: BoxShape.circle,
                      border: Border.all(color: bgColor(context), width: 2),
                    ),
                    child: Icon(
                        i.channel == MessageChannel.chat ? CupertinoIcons.cloud_fill : CupertinoIcons.chat_bubble_fill,
                        size: 10,
                        color: onSolid),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              color: bold ? chatInk(context) : secondaryColor(context))),
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
                        Icon(CupertinoIcons.exclamationmark_circle_fill, size: 14, color: failedInk(context)),
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
                        _CountBadge(i.unread, color: chatSolid(context)),
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
                          decoration:
                              BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(6)),
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
    );
  }
}

/// Aviso con un bloque informativo y, aparte, su acción: el lector de pantalla
/// lee el texto como texto y el botón como botón (nodos separados).
class _Banner extends StatelessWidget {
  const _Banner(
      {required this.icon, required this.tint, required this.ink, required this.title, required this.text, this.action});
  final IconData icon;
  final Color tint;

  /// Color del icono, con contraste suficiente sobre el fondo tintado.
  final Color ink;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final bg = over(tint, 0.12, bgColor(context));
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoBlock(
            label: '$title. $text',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: ink, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: labelColor(context))),
                      const SizedBox(height: 3),
                      Text(text, style: TextStyle(fontSize: 13.5, height: 1.3, color: secondaryColor(context))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 8),
              child: action!,
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
        tint: demoTint,
        ink: demoInk(context),
        title: 'Sin conexión con NEXLIA Chat',
        text: 'Tus mensajes quedan guardados en el teléfono como pendientes. Se reintentan al abrir Mensajes o al tocar Reintentar.',
      );
    }
    return _Banner(
      icon: CupertinoIcons.cloud,
      tint: accentColor(context),
      ink: chatInk(context),
      title: 'NEXLIA Chat aún no está conectado',
      text: hasDemo
          ? 'Todavía no hay servidor de Chat. Las conversaciones marcadas PRUEBA son de demostración y no se envían a nadie.'
          : 'Todavía no hay servidor de Chat, así que no hay conversaciones por Internet.',
    );
  }
}

class _SmsErrorBanner extends StatelessWidget {
  const _SmsErrorBanner({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      icon: CupertinoIcons.exclamationmark_triangle,
      tint: failedSolid,
      ink: failedInk(context),
      title: 'No se pudieron leer los SMS',
      text: 'El teléfono no respondió al pedir los SMS. Tus mensajes no se han tocado.',
      action: ActionButton(text: 'Reintentar', color: failedSolid, onPressed: onRetry),
    );
  }
}

class _SmsPermissionCard extends StatelessWidget {
  const _SmsPermissionCard({
    required this.unavailable,
    required this.alreadyGranted,
    required this.revoked,
    required this.busy,
    required this.onAllow,
  });
  final bool unavailable;

  /// Android ya dio READ_SMS (por ejemplo, por ser la app de Teléfono): falta el consentimiento en NEXLIA.
  final bool alreadyGranted;

  /// El usuario había aceptado, pero el permiso de Android se retiró en Ajustes.
  final bool revoked;
  final bool busy;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    if (unavailable) {
      return _Banner(
        icon: CupertinoIcons.exclamationmark_triangle,
        tint: smsSolid,
        ink: smsInk(context),
        title: 'SMS no disponibles',
        text: 'Este dispositivo no tiene SMS o no permite leerlos desde NEXLIA.',
      );
    }
    final String lead;
    if (revoked) {
      lead = 'Se retiró el permiso de SMS de NEXLIA en los ajustes de Android, así que ya no se muestran.';
    } else if (alreadyGranted) {
      lead = 'Android ya permite a NEXLIA leer SMS por ser tu app de Teléfono, pero no se mostrarán hasta que lo confirmes.';
    } else {
      lead = 'NEXLIA necesita permiso para leer los SMS del teléfono.';
    }
    return _Banner(
      icon: CupertinoIcons.lock_shield,
      tint: smsSolid,
      ink: smsInk(context),
      title: 'Ver tus SMS en NEXLIA',
      text: '$lead Solo se leen para mostrarlos aquí: no se copian a ningún servidor, '
          'no se analizan y NEXLIA no envía SMS por su cuenta.',
      action: ActionButton(
        text: alreadyGranted ? 'Mostrar mis SMS aquí' : 'Permitir lectura de SMS',
        color: smsSolid,
        onPressed: busy ? null : onAllow,
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
      text = smsBlocked ? 'Confirma la lectura de SMS para verlos aquí.' : 'No hay SMS en este teléfono.';
    } else {
      icon = CupertinoIcons.chat_bubble_2;
      title = 'Aún no hay mensajes';
      text = 'Aquí verás juntos tus SMS y tus conversaciones de NEXLIA Chat, cada uno con su canal.';
    }
    return InfoBlock(
      label: '$title. $text',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 48, 40, 24),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(24)),
              child: Icon(icon, size: 36, color: chatInk(context)),
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
      ),
    );
  }
}
