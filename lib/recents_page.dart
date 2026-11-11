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

  String _kind(CallEntry e) {
    switch (e.type) {
      case 1:
        return 'Entrante';
      case 2:
        return 'Saliente';
      case 3:
        return 'Perdida';
      case 5:
        return 'Rechazada';
      case 6:
        return 'Bloqueada';
      default:
        return 'Llamada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.i,
      builder: (context, _) {
        final all = AppData.i.calls;
        final list = filter == 0 ? all : all.where((c) => c.missed).toList();
        final red = CupertinoColors.systemRed.resolveFrom(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LargeTitle('Recientes'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: filter,
                children: const {
                  0: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Todas')),
                  1: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Perdidas')),
                },
                onValueChanged: (v) => setState(() => filter = v ?? 0),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text('Sin llamadas recientes',
                          style: TextStyle(color: secondaryColor(context), fontSize: 17)))
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 6, bottom: barSpace),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final e = list[i];
                        final contact = e.number.isEmpty ? null : AppData.i.contactFor(e.number);
                        final name = contact?.name ??
                            (e.name.isNotEmpty
                                ? e.name
                                : (e.number.isEmpty ? 'Número oculto' : e.number));
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: e.number.isEmpty ? null : () => callNumber(context, e.number),
                          onLongPress: () => _actions(e, contact),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Row(
                              children: [
                                Avatar(contact?.name ?? e.name, size: 42),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                        border: Border(
                                            bottom: BorderSide(
                                                color: separatorColor(context), width: 0.4))),
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
                                                      color: e.missed ? red : labelColor(context))),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Icon(
                                                      e.type == 2
                                                          ? CupertinoIcons.phone_fill_arrow_up_right
                                                          : CupertinoIcons.phone_fill_arrow_down_left,
                                                      size: 13,
                                                      color: secondaryColor(context)),
                                                  const SizedBox(width: 4),
                                                  Text(_kind(e),
                                                      style: TextStyle(
                                                          fontSize: 14, color: secondaryColor(context))),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(formatWhen(e.date),
                                            style: TextStyle(fontSize: 15, color: secondaryColor(context))),
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          minSize: 36,
                                          onPressed: () {
                                            if (contact != null) {
                                              Navigator.of(context, rootNavigator: true).push(
                                                  CupertinoPageRoute<void>(
                                                      builder: (_) => ContactDetail(contact: contact)));
                                            } else {
                                              _actions(e, contact);
                                            }
                                          },
                                          child: const Icon(CupertinoIcons.info_circle, size: 23),
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
        );
      },
    );
  }
}
