import 'package:flutter/cupertino.dart';

import '../common.dart';
import 'a11y.dart';
import 'chat_repository.dart';
import 'messages_page.dart';
import 'models.dart';
import 'palette.dart';
import 'sms_repository.dart';

CupertinoNavigationBar _bar(BuildContext context, String title) {
  return CupertinoNavigationBar(
    previousPageTitle: 'Mensajes',
    backgroundColor: bgColor(context),
    border: Border(bottom: BorderSide(color: separatorColor(context), width: 0.6)),
    middle: Semantics(
      header: true,
      child: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: labelColor(context))),
    ),
  );
}

/// Franja bajo la barra con el canal: fuera de la barra para que crezca con el texto grande.
class _ChannelStrip extends StatelessWidget {
  const _ChannelStrip(this.channel, this.text);
  final MessageChannel channel;
  final String text;

  @override
  Widget build(BuildContext context) {
    return InfoBlock(
      label: '${channel == MessageChannel.chat ? 'NEXLIA Chat' : 'SMS'}. $text',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Row(
          children: [
            ChannelTag(channel),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: secondaryColor(context)))),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.mine, required this.color, required this.text, required this.footer});
  final bool mine;
  final Color color;
  final String text;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
          decoration: BoxDecoration(
            color: mine ? color : fillColor(context),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 20 : 6),
              bottomRight: Radius.circular(mine ? 6 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: TextStyle(fontSize: 16, height: 1.3, color: mine ? onSolid : labelColor(context))),
              const SizedBox(height: 3),
              Align(alignment: Alignment.centerRight, widthFactor: 1, child: footer),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.icon = CupertinoIcons.info_circle});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InfoBlock(
      label: text,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: secondaryColor(context)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.3, color: secondaryColor(context)))),
          ],
        ),
      ),
    );
  }
}

String statusText(ChatMessageStatus s) => switch (s) {
      ChatMessageStatus.pending => 'Pendiente',
      ChatMessageStatus.sent => 'Enviado',
      ChatMessageStatus.delivered => 'Entregado',
      ChatMessageStatus.read => 'Leído',
      ChatMessageStatus.failed => 'No enviado',
    };

IconData _statusIcon(ChatMessageStatus s) => switch (s) {
      ChatMessageStatus.pending => CupertinoIcons.clock,
      ChatMessageStatus.sent => CupertinoIcons.checkmark_alt,
      ChatMessageStatus.delivered => CupertinoIcons.checkmark_alt_circle,
      ChatMessageStatus.read => CupertinoIcons.checkmark_alt_circle_fill,
      ChatMessageStatus.failed => CupertinoIcons.exclamationmark_circle_fill,
    };

/// Pie de burbuja: hora y estado. Wrap para que no se desborde con texto grande.
Widget _footer(String time, Color color, {IconData? icon, String? status}) => Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(time, style: TextStyle(fontSize: 11, color: color)),
        if (icon != null) Icon(icon, size: 13, color: color),
        if (status != null) Text(status, style: TextStyle(fontSize: 11, color: color)),
      ],
    );

/// Conversación de NEXLIA Chat (Internet). Solo envía cuando el usuario toca "Enviar".
class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({super.key, required this.chat, required this.conversationId});
  final ChatRepository chat;
  final String conversationId;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final text = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.chat.markRead(widget.conversationId);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = text.text;
    if (t.trim().isEmpty) return;
    text.clear();
    await widget.chat.send(widget.conversationId, t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.chat,
      builder: (context, _) {
        final conv = widget.chat.conversation(widget.conversationId);
        final msgs = widget.chat.messagesOf(widget.conversationId);
        return CupertinoPageScaffold(
          backgroundColor: bgColor(context),
          navigationBar: _bar(context, conv?.peer.displayName ?? 'Conversación'),
          child: SafeArea(
            child: Column(
              children: [
                const _ChannelStrip(MessageChannel.chat, 'Mensajes por Internet'),
                if (conv?.isDemo ?? false)
                  const _Note('Conversación de PRUEBA: los mensajes se quedan en este teléfono y no se envían a nadie.',
                      icon: CupertinoIcons.lab_flask)
                else if (!widget.chat.isConfigured)
                  const _Note('NEXLIA Chat aún no tiene servidor: lo que escribas queda pendiente en el teléfono.',
                      icon: CupertinoIcons.cloud)
                else if (widget.chat.connection == ChatConnection.offline)
                  const _Note('Sin conexión. Los mensajes pendientes se reintentarán.', icon: CupertinoIcons.wifi_slash),
                Expanded(
                  child: msgs.isEmpty
                      ? Center(
                          child: Text('Escribe el primer mensaje',
                              style: TextStyle(fontSize: 15, color: secondaryColor(context))))
                      : ListView(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          children: [for (final m in msgs.reversed) _message(context, m)],
                        ),
                ),
                _Composer(controller: text, color: chatSolid(context), onSend: _send, hint: 'Mensaje de NEXLIA Chat'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _message(BuildContext context, ChatMessage m) {
    final failed = m.status == ChatMessageStatus.failed;
    final footerColor = m.fromMe ? onSolid : secondaryColor(context);
    final time = formatTime(m.createdAt.toLocal());
    return Column(
      crossAxisAlignment: m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        InfoBlock(
          label: '${m.fromMe ? 'Tú' : 'Recibido'}, $time: ${m.text}${m.fromMe ? '. ${statusText(m.status)}' : ''}',
          child: _Bubble(
            mine: m.fromMe,
            color: failed ? failedSolid : chatSolid(context),
            text: m.text,
            footer: m.fromMe
                ? _footer(time, footerColor, icon: _statusIcon(m.status), status: statusText(m.status))
                : _footer(time, footerColor),
          ),
        ),
        if (failed && !m.isDemo)
          ActionButton(
            text: 'Reintentar',
            hint: 'Volver a enviar este mensaje',
            filled: false,
            color: failedInk(context),
            onPressed: () => widget.chat.retry(m.clientId),
          ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.color, required this.onSend, required this.hint});
  final TextEditingController controller;
  final Color color;
  final VoidCallback onSend;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: bgColor(context),
        border: Border(top: BorderSide(color: separatorColor(context), width: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              container: true,
              textField: true,
              label: hint,
              child: CupertinoTextField(
                controller: controller,
                placeholder: hint,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                style: TextStyle(color: labelColor(context), fontSize: 16),
                placeholderStyle: TextStyle(color: secondaryColor(context), fontSize: 16),
                decoration: BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ),
          Tappable(
            label: 'Enviar mensaje',
            radius: 24,
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.arrow_up, color: onSolid, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hilo SMS de solo lectura. Responder abre la app de SMS del sistema: NEXLIA no envía SMS.
class SmsThreadPage extends StatefulWidget {
  const SmsThreadPage(
      {super.key, required this.sms, required this.threadId, required this.title, required this.address});
  final SmsRepository sms;
  final String threadId;
  final String title;
  final String address;

  @override
  State<SmsThreadPage> createState() => _SmsThreadPageState();
}

class _SmsThreadPageState extends State<SmsThreadPage> {
  late Future<List<SmsMessage>> messages = widget.sms.messagesOf(widget.threadId);

  void _retry() => setState(() => messages = widget.sms.messagesOf(widget.threadId));

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: bgColor(context),
      navigationBar: _bar(context, widget.title),
      child: SafeArea(
        child: Column(
          children: [
            const _ChannelStrip(MessageChannel.sms, 'Solo lectura'),
            Expanded(
              child: FutureBuilder<List<SmsMessage>>(
                future: messages,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return Center(
                        child: Semantics(label: 'Cargando SMS', child: const CupertinoActivityIndicator()));
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const InfoBlock(
                              label: 'No se pudieron leer los SMS de esta conversación.',
                              child: Text('No se pudieron leer los SMS de esta conversación.',
                                  textAlign: TextAlign.center),
                            ),
                            const SizedBox(height: 12),
                            ActionButton(text: 'Reintentar', color: smsSolid, onPressed: _retry),
                          ],
                        ),
                      ),
                    );
                  }
                  final list = snap.data ?? const <SmsMessage>[];
                  if (list.isEmpty) {
                    return Center(
                        child: Text('No hay SMS para mostrar',
                            style: TextStyle(fontSize: 15, color: secondaryColor(context))));
                  }
                  return ListView(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    children: [for (final m in list.reversed) _message(context, m)],
                  );
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: separatorColor(context), width: 0.6)),
              ),
              child: Column(
                children: [
                  Text('Los SMS se envían desde la app de mensajes del teléfono.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: secondaryColor(context))),
                  const SizedBox(height: 8),
                  ActionButton(
                    text: 'Responder en la app de SMS',
                    hint: 'Abre la app de mensajes del teléfono',
                    color: smsSolid,
                    onPressed: widget.address.trim().isEmpty ? null : () => widget.sms.reply(widget.address),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(BuildContext context, SmsMessage m) {
    final mine = !m.incoming;
    final sim = widget.sms.simLabel(m.subId);
    final footerColor = mine ? onSolid : secondaryColor(context);
    final box = switch (m.box) {
      SmsBox.failed => 'No enviado',
      SmsBox.outbox || SmsBox.queued => 'En cola',
      SmsBox.draft => 'Borrador',
      _ => '',
    };
    final when = '${formatDay(m.date)} ${formatTime(m.date)}';
    final parts = [when, if (sim.isNotEmpty) sim, if (box.isNotEmpty) box];
    return InfoBlock(
      label: '${mine ? 'Enviado' : 'Recibido'}, ${parts.join(', ')}: ${m.body}',
      child: _Bubble(
        mine: mine,
        color: m.box == SmsBox.failed ? failedSolid : smsSolid,
        text: m.body,
        footer: Text(parts.join(' · '), style: TextStyle(fontSize: 11, color: footerColor)),
      ),
    );
  }
}
