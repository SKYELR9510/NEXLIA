import 'package:flutter/cupertino.dart';

import '../common.dart';
import 'a11y.dart';
import 'chat_api.dart';
import 'chat_repository.dart';
import 'models.dart';
import 'sms_repository.dart';

/// Más > Mensajes: estado real de cada canal y conversaciones de prueba.
class MessagingSettingsPage extends StatelessWidget {
  const MessagingSettingsPage({super.key, required this.chat, required this.sms});
  final ChatRepository chat;
  final SmsRepository sms;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([chat, sms]),
      builder: (context, _) => CupertinoPageScaffold(
        backgroundColor: groupedBg(context),
        navigationBar: CupertinoNavigationBar(
          middle: Text('Mensajes', style: TextStyle(color: labelColor(context))),
          previousPageTitle: 'Más',
          backgroundColor: groupedBg(context),
          border: null,
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _section(context, 'NEXLIA CHAT', [
                _info(context, 'Servidor',
                    ChatConfig.serverUrl.isEmpty ? 'No configurado' : Uri.parse(ChatConfig.serverUrl).host),
                _info(context, 'Estado', switch (chat.connection) {
                  ChatConnection.notConfigured => 'Sin servidor',
                  ChatConnection.offline => 'Sin conexión',
                  ChatConnection.online => 'Conectado',
                }),
                _info(context, 'Cifrado de extremo a extremo', 'No disponible todavía'),
              ]),
              _footer(context,
                  'NEXLIA Chat todavía no tiene servidor ni cuentas de usuario. No se envía nada por Internet hasta que existan.'),
              _section(context, 'SMS', [
                _toggle(context, 'Mostrar mis SMS en NEXLIA', sms.consent,
                    (on) => on ? sms.requestAccess() : sms.revoke()),
                _info(context, 'Permiso de Android', switch (sms.permission) {
                  SmsPermission.granted => 'Concedido',
                  SmsPermission.denied => 'Sin permiso',
                  SmsPermission.unavailable => 'No disponible',
                }),
                _info(context, 'SIM', _simText(sms.sims, sms.canRead)),
                _info(context, 'Enviar SMS', 'Desde la app de SMS del teléfono'),
              ]),
              _footer(context,
                  'NEXLIA solo muestra tus SMS si lo activas; no los copia a ningún servidor, no los analiza y no envía SMS por su cuenta. '
                  'Al desactivarlo deja de leerlos; el permiso de Android se quita en Ajustes > Apps > NEXLIA > Permisos.'),
              _section(context, 'PRUEBAS', [
                _toggle(context, 'Conversaciones de prueba', chat.hasDemo, (on) => chat.setDemo(on)),
              ]),
              _footer(context,
                  'Muestra conversaciones de Chat inventadas, marcadas PRUEBA, para ver cómo se verá la bandeja. No se envían a nadie.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondaryColor(context))),
        ),
        Container(
          decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Container(height: 0.6, margin: const EdgeInsets.only(left: 16), color: separatorColor(context)),
              rows[i],
            ],
          ]),
        ),
      ],
    );
  }

  /// Estado de las SIM según lo que Android informa (puede ser incompleto).
  static String _simText(SmsSimInfo s, bool read) {
    if (!read) return 'Se muestra al ver los SMS';
    if (!s.readable) return 'Android no permite leerlas';
    final n = s.active.length;
    final active = n == 0 ? 'ninguna activa' : (n == 1 ? '1 activa' : '$n activas');
    return s.slots > 0 ? '${s.slots} ranura${s.slots == 1 ? '' : 's'} · $active' : active;
  }

  /// Interruptor con su texto: un solo nodo para el lector ("Etiqueta, activado").
  Widget _toggle(BuildContext context, String label, bool value, ValueChanged<bool> onChanged) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minTouch),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: labelColor(context)))),
              CupertinoSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value) {
    return MergeSemantics(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: labelColor(context)))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 15, color: secondaryColor(context))),
          ),
        ],
      ),
    ));
  }

  Widget _footer(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        child: Text(text, style: TextStyle(fontSize: 13, height: 1.3, color: secondaryColor(context))),
      );
}
