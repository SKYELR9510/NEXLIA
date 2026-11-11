import 'package:flutter/cupertino.dart';

import 'common.dart';
import 'native.dart';

const Map<String, dynamic> _defaults = {
  'unknownMode': 0, // 0 permitir, 1 silenciar, 2 rechazar
  'blockHidden': false,
  'peru500': true,
  'blockInternational': false,
  'prefixes': <dynamic>[],
  'spamAction': 2, // 1 silenciar, 2 rechazar
  'onlineEnabled': false,
  'serverUrl': '',
  'apiKey': '',
  'threshold': 3,
};

class SpamPage extends StatefulWidget {
  const SpamPage({super.key, required this.active});
  final bool active;

  @override
  State<SpamPage> createState() => _SpamPageState();
}

class _SpamPageState extends State<SpamPage> {
  Map<String, dynamic> s = Map<String, dynamic>.from(_defaults);
  List<String> blocked = [];
  List<dynamic> log = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SpamPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  Future<void> _load() async {
    final d = await Native.getSpamData();
    if (!mounted) return;
    setState(() {
      s = {..._defaults, ...((d['settings'] as Map?)?.cast<String, dynamic>() ?? {})};
      blocked = ((d['blocked'] as List?) ?? []).map((e) => e.toString()).toList();
      log = (d['log'] as List?) ?? [];
    });
  }

  void _set(String key, dynamic value) {
    setState(() => s[key] = value);
    Native.setSpamSettings(s);
  }

  List<String> get prefixes => ((s['prefixes'] as List?) ?? []).map((e) => e.toString()).toList();

  Future<void> _addPrefix() async {
    final r = await askText(context, 'Bloquear prefijo',
        hints: ['Primeros dígitos (ej. 500, 0800)'], types: [TextInputType.phone]);
    if (r == null) return;
    final p = digits(r[0]);
    if (p.length < 2) {
      if (mounted) await showMessage(context, 'Prefijo muy corto', 'Escribe al menos 2 dígitos.');
      return;
    }
    final list = prefixes;
    if (!list.contains(p)) list.add(p);
    _set('prefixes', list);
  }

  Future<void> _addBlocked() async {
    final r = await askText(context, 'Bloquear número', hints: ['Número'], types: [TextInputType.phone]);
    if (r == null || digits(r[0]).isEmpty) return;
    await Native.blockNumber(r[0]);
    await _load();
  }

  Future<void> _editServer() async {
    final r = await askText(context, 'Servidor de spam',
        hints: ['https://tudominio.com/spam_api.php', 'Clave'],
        initial: [s['serverUrl'].toString(), s['apiKey'].toString()],
        types: [TextInputType.url, TextInputType.text]);
    if (r == null) return;
    setState(() {
      s['serverUrl'] = r[0];
      s['apiKey'] = r[1];
    });
    await Native.setSpamSettings(s);
  }

  Future<void> _test() async {
    final msg = await Native.testServer();
    if (mounted) await showMessage(context, 'Base en línea', msg);
  }

  Widget _segmented(String key, Map<int, String> options) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: (s[key] as num).toInt(),
          children: {
            for (final e in options.entries)
              e.key: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(e.value)),
          },
          onValueChanged: (v) {
            if (v != null) _set(key, v);
          },
        ),
      ),
    );
  }

  Widget _switch(String title, String subtitle, String key) {
    return CupertinoListTile(
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2),
      trailing: CupertinoSwitch(value: s[key] == true, onChanged: (v) => _set(key, v)),
    );
  }

  Widget _removeButton(VoidCallback onTap) => CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 30,
        onPressed: onTap,
        child: Icon(CupertinoIcons.minus_circle_fill,
            color: CupertinoColors.systemRed.resolveFrom(context), size: 22),
      );

  @override
  Widget build(BuildContext context) {
    final blue = CupertinoColors.systemBlue.resolveFrom(context);
    final online = s['onlineEnabled'] == true;
    final url = s['serverUrl'].toString();
    return Container(
      color: groupedBg(context),
      child: ListView(
        padding: const EdgeInsets.only(bottom: barSpace),
        children: [
          const LargeTitle('Spam'),
          CupertinoListSection.insetGrouped(
            header: const Text('NÚMEROS QUE NO ESTÁN EN TUS CONTACTOS'),
            footer: const Text(
                'Silenciar: la llamada entra sin sonar y queda en Recientes. Rechazar: se corta sola.'),
            children: [
              _segmented('unknownMode', const {0: 'Permitir', 1: 'Silenciar', 2: 'Rechazar'}),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('PATRONES DE SPAM'),
            children: [
              _switch('Serie 500 (Perú)', 'Numeración oficial para llamadas comerciales', 'peru500'),
              _switch('Números ocultos', 'Llamadas privadas o sin número', 'blockHidden'),
              _switch('Internacionales', 'Llamadas de fuera del Perú (+51)', 'blockInternational'),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('QUÉ HACER CON EL SPAM DETECTADO'),
            children: [
              _segmented('spamAction', const {1: 'Silenciar', 2: 'Rechazar'}),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('PREFIJOS BLOQUEADOS'),
            children: [
              for (final p in prefixes)
                CupertinoListTile(
                  title: Text('Empieza con $p'),
                  trailing: _removeButton(() {
                    final list = prefixes..remove(p);
                    _set('prefixes', list);
                  }),
                ),
              CupertinoListTile(
                title: Text('Añadir prefijo…', style: TextStyle(color: blue)),
                onTap: _addPrefix,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('NÚMEROS BLOQUEADOS'),
            children: [
              for (final n in blocked)
                CupertinoListTile(
                  title: Text(AppData.i.contactFor(n)?.name ?? n),
                  subtitle: AppData.i.contactFor(n) != null ? Text(n) : null,
                  trailing: _removeButton(() async {
                    await Native.unblockNumber(n);
                    await _load();
                  }),
                ),
              CupertinoListTile(
                title: Text('Añadir número…', style: TextStyle(color: blue)),
                onTap: _addBlocked,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('BASE DE DATOS EN LÍNEA'),
            footer: const Text(
                'Consulta tu servidor antes de que suene cada llamada de un desconocido. '
                'Se bloquea cuando el número tiene al menos los reportes indicados.'),
            children: [
              CupertinoListTile(
                title: const Text('Consultar en línea'),
                trailing: CupertinoSwitch(value: online, onChanged: (v) => _set('onlineEnabled', v)),
              ),
              CupertinoListTile(
                title: const Text('Servidor'),
                additionalInfo: SizedBox(
                  width: 170,
                  child: Text(url.isEmpty ? 'Sin configurar' : url,
                      maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: _editServer,
              ),
              CupertinoListTile(
                title: const Text('Reportes mínimos'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 30,
                      onPressed: () {
                        final t = (s['threshold'] as num).toInt();
                        if (t > 1) _set('threshold', t - 1);
                      },
                      child: const Icon(CupertinoIcons.minus_circle, size: 24),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text('${s['threshold']}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, color: labelColor(context))),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 30,
                      onPressed: () => _set('threshold', (s['threshold'] as num).toInt() + 1),
                      child: const Icon(CupertinoIcons.plus_circle, size: 24),
                    ),
                  ],
                ),
              ),
              CupertinoListTile(
                title: Text('Probar conexión', style: TextStyle(color: blue)),
                onTap: _test,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('LLAMADAS FILTRADAS'),
            children: [
              if (log.isEmpty) const CupertinoListTile(title: Text('Aún no se ha filtrado ninguna')),
              for (final e in log.take(50))
                CupertinoListTile(
                  title: Text((e['number'] ?? '').toString().isEmpty
                      ? 'Número oculto'
                      : e['number'].toString()),
                  subtitle: Text(
                      '${e['reason']} · ${e['action'] == 1 ? 'silenciada' : 'rechazada'}'),
                  additionalInfo: Text(formatWhen(
                      DateTime.fromMillisecondsSinceEpoch((e['time'] as num).toInt()))),
                ),
              if (log.isNotEmpty)
                CupertinoListTile(
                  title: Text('Borrar registro',
                      style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context))),
                  onTap: () async {
                    await Native.clearSpamLog();
                    await _load();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
