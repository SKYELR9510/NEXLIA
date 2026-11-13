import 'package:flutter/cupertino.dart';

import '../common.dart';
import 'chat_repository.dart';
import 'messages_page.dart';
import 'models.dart';
import 'sms_repository.dart';

CupertinoNavigationBar _bar(BuildContext context, String title, MessageChannel channel) {
  return CupertinoNavigationBar(
    previousPageTitle: 'Mensajes',
    backgroundColor: bgColor(context),
    border: Border(bottom: BorderSide(color: separatorColor(context), width: 0.6)),
    middle: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: labelColor(context))),
        const SizedBox(height: 2),
        ChannelTag(channel),
      ],
    ),
  );
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
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
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(text,
                  style: TextStyle(
                      fontSize: 16, height: 1.3, color: mine ? const Color(0xFFFFFFFF) : labelColor(context))),
              const SizedBox(height: 3),
              footer,
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
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: secondaryColor(context)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: TextStyle(fontSize: 13, height: 1.3, color: secondaryColor(context)))),
        ],
      ),
    );
  }
}

String _statusText(ChatMessageStatus s) => switch (s) {
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
        final color = chatColor(context);
        return CupertinoPageScaffold(
          backgroundColor: bgColor(context),
          navigationBar: _bar(context, conv?.peer.displayName ?? 'Conversación', MessageChannel.chat),
          child: SafeArea(
            child: Column(
              children: [
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
                          children: [
                            for (final m in msgs.reversed) _message(context, m, color),
                          ],
                        ),
                ),
                _Composer(controller: text, color: color, onSend: _send, hint: 'Mensaje de NEXLIA Chat'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _message(BuildContext context, ChatMessage m, Color color) {
    final footerColor = m.fromMe ? const Color(0xDDFFFFFF) : secondaryColor(context);
    final failed = m.status == ChatMessageStatus.failed;
    final footer = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatTime(m.createdAt.toLocal()), style: TextStyle(fontSize: 11, color: footerColor)),
        if (m.fromMe) ...[
          const SizedBox(width: 5),
          Icon(_statusIcon(m.status), size: 13, color: failed ? const Color(0xFFFFD1CC) : footerColor),
          const SizedBox(width: 3),
          Text(_statusText(m.status), style: TextStyle(fontSize: 11, color: footerColor)),
        ],
      ],
    );
    return Semantics(
      label: '${m.fromMe ? 'Tú' : 'Recibido'}: ${m.text}. ${m.fromMe ? _statusText(m.status) : ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _Bubble(
              mine: m.fromMe,
              color: failed ? const Color(0xFFE5484D) : color,
              text: m.text,
              footer: footer),
          if (failed && !m.isDemo)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: Size.zero,
              onPressed: () => widget.chat.retry(m.clientId),
              child: const Text('Reintentar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: bgColor(context),
        border: Border(top: BorderSide(color: separatorColor(context), width: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: hint,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              style: TextStyle(color: labelColor(context), fontSize: 16),
              placeholderStyle: TextStyle(color: secondaryColor(context), fontSize: 16),
              decoration: BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(22)),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'Enviar',
            child: GestureDetector(
              onTap: onSend,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.arrow_up, color: Color(0xFFFFFFFF), size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hilo SMS de solo lectura. Responder abre la app de SMS del sistema: NEXLIA no envía SMS.
class SmsThreadPage extends StatefulWidget {
  const SmsThreadPage({super.key, required this.sms, required this.threadId, required this.title, required this.address});
  final SmsRepository sms;
  final String threadId;
  final String title;
  final String address;

  @override
  State<SmsThreadPage> createState() => _SmsThreadPageState();
}

class _SmsThreadPageState extends State<SmsThreadPage> {
  late Future<List<SmsMessage>> messages = widget.sms.messagesOf(widget.threadId);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: bgColor(context),
      navigationBar: _bar(context, widget.title, MessageChannel.sms),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<SmsMessage>>(
                future: messages,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CupertinoActivityIndicator());
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
                  CupertinoButton(
                    color: smsColor,
                    borderRadius: BorderRadius.circular(22),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                    onPressed: widget.address.isEmpty ? null : () => widget.sms.reply(widget.address),
                    child: const Text('Responder en la app de SMS',
                        style: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w700)),
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
    final footerColor = mine ? const Color(0xDDFFFFFF) : secondaryColor(context);
    final box = switch (m.box) {
      SmsBox.failed => ' · No enviado',
      SmsBox.outbox || SmsBox.queued => ' · En cola',
      SmsBox.draft => ' · Borrador',
      _ => '',
    };
    return Semantics(
      label: '${mine ? 'Enviado' : 'Recibido'}${sim.isEmpty ? '' : ' por $sim'}: ${m.body}',
      excludeSemantics: true,
      child: _Bubble(
        mine: mine,
        color: smsColor,
        text: m.body,
        footer: Text('${formatDay(m.date)} ${formatTime(m.date)}${sim.isEmpty ? '' : ' · $sim'}$box',
            style: TextStyle(fontSize: 11, color: footerColor)),
      ),
    );
  }
}
