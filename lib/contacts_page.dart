import 'package:flutter/cupertino.dart';

import 'common.dart';
import 'native.dart';

void openContact(BuildContext context, Contact c) {
  Navigator.of(context, rootNavigator: true)
      .push(CupertinoPageRoute<void>(builder: (_) => ContactDetail(contact: c)));
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  String query = '';

  Future<void> _add() async {
    final r = await askText(context, 'Nuevo contacto',
        hints: ['Nombre', 'Número'], types: [TextInputType.name, TextInputType.phone]);
    if (r == null || r[0].isEmpty || r[1].isEmpty) return;
    await Native.addContact(r[0], r[1]);
    await AppData.i.reload();
  }

  String _letter(String name) {
    if (name.trim().isEmpty) return '#';
    final ch = name.trim().characters.first.toUpperCase();
    return RegExp(r'[A-ZÁÉÍÓÚÑ]').hasMatch(ch) ? ch : '#';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.i,
      builder: (context, _) {
        final q = query.toLowerCase();
        final qd = digits(query);
        final list = AppData.i.contacts.where((c) {
          if (q.isEmpty) return true;
          if (c.name.toLowerCase().contains(q)) return true;
          return qd.isNotEmpty && c.numbers.any((n) => digits(n).contains(qd));
        }).toList();

        final rows = <Widget>[];
        String? last;
        for (final c in list) {
          final l = _letter(c.name);
          if (l != last) {
            last = l;
            rows.add(Container(
              width: double.infinity,
              color: groupedBg(context),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(l,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: secondaryColor(context))),
            ));
          }
          rows.add(GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openContact(context, c),
            child: Container(
              margin: const EdgeInsets.only(left: 20),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: separatorColor(context), width: 0.4))),
              child: Row(
                children: [
                  Expanded(
                    child: Text(c.name.isEmpty ? (c.numbers.isEmpty ? 'Sin nombre' : c.numbers.first) : c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 17, color: labelColor(context))),
                  ),
                  if (c.starred)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(CupertinoIcons.star_fill,
                          size: 14, color: CupertinoColors.systemYellow.resolveFrom(context)),
                    ),
                ],
              ),
            ),
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LargeTitle('Contactos',
                trailing: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: _add,
                  child: const Icon(CupertinoIcons.add, size: 26),
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: CupertinoSearchTextField(
                placeholder: 'Buscar',
                onChanged: (v) => setState(() => query = v.trim()),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(query.isEmpty ? 'Sin contactos' : 'Sin resultados',
                          style: TextStyle(color: secondaryColor(context), fontSize: 17)))
                  : ListView(
                      padding: EdgeInsets.only(bottom: barSpace(context)),
                      children: rows,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.i,
      builder: (context, _) {
        final favs = AppData.i.contacts.where((c) => c.starred).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LargeTitle('Favoritos'),
            Expanded(
              child: favs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                            'Abre un contacto y toca la estrella para tenerlo aquí.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: secondaryColor(context), fontSize: 17)),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: barSpace(context)),
                      itemCount: favs.length,
                      itemBuilder: (context, i) {
                        final c = favs[i];
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: c.numbers.isEmpty ? null : () => callNumber(context, c.numbers.first),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Row(
                              children: [
                                Avatar(c.name, size: 46),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                                              Text(c.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w600,
                                                      color: labelColor(context))),
                                              Text(c.numbers.isEmpty ? '' : c.numbers.first,
                                                  style: TextStyle(
                                                      fontSize: 14, color: secondaryColor(context))),
                                            ],
                                          ),
                                        ),
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          minSize: 36,
                                          onPressed: () => openContact(context, c),
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

class ContactDetail extends StatefulWidget {
  const ContactDetail({super.key, required this.contact});
  final Contact contact;

  @override
  State<ContactDetail> createState() => _ContactDetailState();
}

class _ContactDetailState extends State<ContactDetail> {
  List<String> blocked = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await Native.getBlocked();
    if (mounted) setState(() => blocked = b);
  }

  bool get isBlocked =>
      widget.contact.numbers.isNotEmpty &&
      widget.contact.numbers.every((n) => blocked.any((b) => sameNumber(b, n)));

  Future<void> _toggleBlock() async {
    final was = isBlocked;
    for (final n in widget.contact.numbers) {
      if (was) {
        await Native.unblockNumber(n);
      } else {
        await Native.blockNumber(n);
      }
    }
    await _load();
  }

  Future<void> _toggleStar() async {
    final c = widget.contact;
    setState(() => c.starred = !c.starred);
    await Native.setStarred(c.id, c.starred);
    await AppData.i.reload();
  }

  Future<void> _delete() async {
    if (!await confirm(context, '¿Eliminar a ${widget.contact.name}?', 'Eliminar')) return;
    await Native.deleteContact(widget.contact.id);
    await AppData.i.reload();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    return CupertinoPageScaffold(
      backgroundColor: groupedBg(context),
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Atrás',
        backgroundColor: groupedBg(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _toggleStar,
          child: Icon(c.starred ? CupertinoIcons.star_fill : CupertinoIcons.star, size: 24),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 12),
            Center(child: Avatar(c.name, size: 104)),
            const SizedBox(height: 12),
            Text(c.name,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: labelColor(context))),
            const SizedBox(height: 16),
            if (c.numbers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CupertinoButton(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(16),
                  onPressed: () => callNumber(context, c.numbers.first),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.phone_fill, color: CupertinoColors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Llamar',
                          style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            CupertinoListSection.insetGrouped(
              children: [
                for (final n in c.numbers)
                  CupertinoListTile(
                    title: Text('móvil', style: TextStyle(fontSize: 14, color: labelColor(context))),
                    subtitle: Text(n,
                        style: TextStyle(
                            fontSize: 17, color: CupertinoColors.systemBlue.resolveFrom(context))),
                    onTap: () => callNumber(context, n),
                  ),
                if (c.numbers.isEmpty) const CupertinoListTile(title: Text('Sin número')),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: Text(c.starred ? 'Quitar de favoritos' : 'Añadir a favoritos',
                      style: TextStyle(color: CupertinoColors.systemBlue.resolveFrom(context))),
                  onTap: _toggleStar,
                ),
                if (c.numbers.isNotEmpty)
                  CupertinoListTile(
                    title: Text(isBlocked ? 'Desbloquear contacto' : 'Bloquear contacto',
                        style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context))),
                    onTap: _toggleBlock,
                  ),
                CupertinoListTile(
                  title: Text('Eliminar contacto',
                      style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context))),
                  onTap: _delete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
