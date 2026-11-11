import 'package:flutter/cupertino.dart';

import 'common.dart';
import 'contacts_page.dart';
import 'native.dart';

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
        }).toList();
        const red = Color(0xFFFF3B30);
        const green = Color(0xFF12B83C);
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
                const SizedBox(height: 6),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Text('Sin llamadas',
                              style: TextStyle(color: secondaryColor(context), fontSize: 17)))
                      : ListView.builder(
                          padding: EdgeInsets.only(bottom: barSpace(context) + 70),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final e = list[i];
                            final contact =
                                e.number.isEmpty ? null : AppData.i.contactFor(e.number);
                            final name = contact?.name ??
                                (e.name.isNotEmpty
                                    ? e.name
                                    : (e.number.isEmpty ? 'Número oculto' : e.number));
                            final IconData icon = e.missed
                                ? CupertinoIcons.xmark
                                : (e.type == 2
                                    ? CupertinoIcons.arrow_up_right
                                    : CupertinoIcons.arrow_down_left);
                            final Color iconColor =
                                e.missed ? red : (e.type == 2 ? secondaryColor(context) : green);
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (contact != null) {
                                  openContact(context, contact);
                                } else {
                                  _actions(e, contact);
                                }
                              },
                              onLongPress: () => _actions(e, contact),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Row(
                                  children: [
                                    Avatar(contact?.name ?? e.name, size: 46),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                            border: Border(
                                                bottom: BorderSide(
                                                    color: separatorColor(context), width: 0.6))),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          fontSize: 17,
                                                          fontWeight: FontWeight.w600,
                                                          color: labelColor(context))),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      Icon(icon, size: 14, color: iconColor),
                                                      const SizedBox(width: 6),
                                                      Text(formatWhenLong(e.date),
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              color: secondaryColor(context))),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (e.number.isNotEmpty)
                                              CupertinoButton(
                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                minSize: 40,
                                                onPressed: () => callNumber(context, e.number),
                                                child: const Icon(CupertinoIcons.phone_fill, size: 24),
                                              ),
                                          ],
                                        ),
                                      ),
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
                    color: accentColor(context),
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
