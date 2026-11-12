import 'package:flutter/cupertino.dart';

import 'common.dart';
import 'contacts_page.dart';
import 'native.dart';

/// Llamadas seguidas del mismo número y tipo, juntas en una fila.
class _Group {
  _Group(this.first);
  final CallEntry first;
  int count = 1;
}

class RecentsPage extends StatefulWidget {
  const RecentsPage({super.key});

  @override
  State<RecentsPage> createState() => _RecentsPageState();
}

class _RecentsPageState extends State<RecentsPage> {
  int filter = 0;
  String query = '';

  Future<void> _actions(CallEntry e, Contact? contact) async {
    final number = e.number;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(contact?.name ?? (number.isEmpty ? 'Número oculto' : number)),
        actions: [
          if (number.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                callNumber(context, number);
              },
              child: const Text('Llamar'),
            ),
          if (number.isNotEmpty && contact == null)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(ctx);
                final r = await askText(context, 'Nuevo contacto', hints: ['Nombre']);
                if (r == null || r[0].isEmpty) return;
                await Native.addContact(r[0], number);
                await AppData.i.reload();
              },
              child: const Text('Añadir a contactos'),
            ),
          if (number.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                blockFlow(context, number);
              },
              child: const Text('Bloquear número'),
            ),
          if (number.isNotEmpty && contact == null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                reportFlow(context, number);
              },
              child: const Text('Reportar como spam'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await Native.deleteCallLog(e.id);
              await AppData.i.reload();
            },
            child: const Text('Eliminar del registro'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
      ),
    );
  }

  bool _match(CallEntry e) {
    switch (filter) {
      case 1:
        return e.missed;
      case 2:
        return e.type == 1;
      case 3:
        return e.type == 2;
      default:
        return true;
    }
  }

  bool _same(CallEntry a, CallEntry b) {
    if (a.type != b.type) return false;
    if (a.number.isEmpty || b.number.isEmpty) return a.number == b.number;
    return sameNumber(a.number, b.number);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.i,
      builder: (context, _) {
        final q = query.toLowerCase();
        final qd = digits(query);
        final list = AppData.i.calls.where((e) {
          if (!_match(e)) return false;
          if (q.isEmpty) return true;
          final name = (AppData.i.contactFor(e.number)?.name ?? e.name).toLowerCase();
          return name.contains(q) || (qd.isNotEmpty && digits(e.number).contains(qd));
        });

        // Encabezado por día y llamadas repetidas agrupadas.
        final items = <Object>[];
        String? lastDay;
        _Group? prev;
        for (final e in list) {
          final day = formatDay(e.date);
          if (day != lastDay) {
            items.add(day);
            lastDay = day;
            prev = null;
          }
          if (prev != null && _same(prev.first, e)) {
            prev.count++;
          } else {
            prev = _Group(e);
            items.add(prev);
          }
        }

        const labels = ['Todas', 'Perdidas', 'Entrantes', 'Salientes'];
        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ScreenTitle('Recientes'),
                SearchPill(
                    placeholder: 'Buscar en historial…',
                    onChanged: (v) => setState(() => query = v.trim())),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: labels.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => Center(
                      child: Pill(labels[i],
                          selected: filter == i, onTap: () => setState(() => filter = i)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text('Sin llamadas',
                              style: TextStyle(color: secondaryColor(context), fontSize: 17)))
                      : ListView.builder(
                          padding: EdgeInsets.only(bottom: barSpace(context) + 76),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final item = items[i];
                            if (item is String) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                                child: Text(item,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: secondaryColor(context))),
                              );
                            }
                            final g = item as _Group;
                            final e = g.first;
                            final contact =
                                e.number.isEmpty ? null : AppData.i.contactFor(e.number);
                            final name = contact?.name ??
                                (e.name.isNotEmpty
                                    ? e.name
                                    : (e.number.isEmpty ? 'Número oculto' : e.number));
                            final extra = e.duration > 0 ? ' · ${formatDuration(e.duration)}' : '';
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => openDetail(context, contact: contact, number: e.number),
                              onLongPress: () => _actions(e, contact),
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(14, 3, 14, 3),
                                padding: const EdgeInsets.fromLTRB(12, 9, 2, 9),
                                decoration: BoxDecoration(
                                    color: cardColor(context),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: separatorColor(context), width: 0.6)),
                                child: Row(
                                  children: [
                                    Avatar(contact?.name ?? e.name, size: 44, contact: contact),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        fontSize: 17,
                                                        fontWeight: FontWeight.w600,
                                                        color: e.missed
                                                            ? const Color(0xFFFF3B30)
                                                            : labelColor(context))),
                                              ),
                                              if (g.count > 1)
                                                Text('  (${g.count})',
                                                    style: TextStyle(
                                                        fontSize: 15,
                                                        color: secondaryColor(context))),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Icon(callIcon(e), size: 14, color: callColor(context, e)),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                    '${callKind(e)} · ${formatTime(e.date)}$extra',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: secondaryColor(context))),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (e.number.isNotEmpty)
                                      CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        minSize: 40,
                                        onPressed: () => callNumber(context, e.number),
                                        child: const Icon(CupertinoIcons.phone_fill, size: 23),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              right: 18,
              bottom: barSpace(context) + 14,
              child: GestureDetector(
                onTap: () => homeTab.value = 0,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: brandGradient(context),
                    boxShadow: [
                      BoxShadow(
                          color: accentColor(context).withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(CupertinoIcons.circle_grid_3x3_fill,
                      color: Color(0xFFFFFFFF), size: 24),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
