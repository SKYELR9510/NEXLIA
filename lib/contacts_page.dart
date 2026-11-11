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
  static const double rowH = 58;
  static const double favH = 150;
  static const double titleH = 40;
  static const letters = 'ABCDEFGHIJKLMNÑOPQRSTUVWXYZ#';

  final ScrollController scroll = ScrollController();
  String query = '';

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final r = await askText(context, 'Nuevo contacto',
        hints: ['Nombre', 'Número'], types: [TextInputType.name, TextInputType.phone]);
    if (r == null || r[0].isEmpty || r[1].isEmpty) return;
    await Native.addContact(r[0], r[1]);
    await AppData.i.reload();
  }

  String _letter(String name) {
    if (name.trim().isEmpty) return '#';
    var ch = name.trim().characters.first.toUpperCase();
    const map = {'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U'};
    ch = map[ch] ?? ch;
    return RegExp(r'[A-ZÑ]').hasMatch(ch) ? ch : '#';
  }

  void _jump(String letter, List<Contact> list, double header) {
    final i = list.indexWhere((c) => _letter(c.name) == letter);
    if (i < 0 || !scroll.hasClients) return;
    final target = header + i * rowH;
    scroll.jumpTo(target.clamp(0.0, scroll.position.maxScrollExtent).toDouble());
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
        final favs = q.isEmpty ? AppData.i.contacts.where((c) => c.starred).toList() : <Contact>[];
        final header = (favs.isEmpty ? 0.0 : favH) + titleH;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenTitle('Contactos',
                trailing: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: _add,
                  child: const Icon(CupertinoIcons.add, size: 28),
                )),
            SearchPill(
                placeholder: 'Buscar contactos…',
                onChanged: (v) => setState(() => query = v.trim())),
            Expanded(
              child: Stack(
                children: [
                  CustomScrollView(
                    controller: scroll,
                    slivers: [
                      if (favs.isNotEmpty)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: favH,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                                  child: Text('Favoritos',
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: labelColor(context))),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    itemCount: favs.length,
                                    itemBuilder: (context, i) {
                                      final c = favs[i];
                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => openContact(context, c),
                                        child: SizedBox(
                                          width: 74,
                                          child: Column(
                                            children: [
                                              Avatar(c.name, size: 58, contact: c),
                                              const SizedBox(height: 6),
                                              Text(c.name.split(' ').first,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 13, color: labelColor(context))),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: titleH,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                            child: Text(
                                list.isEmpty
                                    ? (query.isEmpty ? 'Sin contactos' : 'Sin resultados')
                                    : 'Todos los contactos',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: labelColor(context))),
                          ),
                        ),
                      ),
                      SliverFixedExtentList(
                        itemExtent: rowH,
                        delegate: SliverChildBuilderDelegate(
                          childCount: list.length,
                          (context, i) {
                            final c = list[i];
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => openContact(context, c),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 18, right: 30),
                                child: Row(
                                  children: [
                                    Avatar(c.name, size: 40, contact: c),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Container(
                                        height: rowH,
                                        alignment: Alignment.centerLeft,
                                        decoration: BoxDecoration(
                                            border: Border(
                                                bottom: BorderSide(
                                                    color: separatorColor(context), width: 0.6))),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                  c.name.isEmpty
                                                      ? (c.numbers.isEmpty
                                                          ? 'Sin nombre'
                                                          : c.numbers.first)
                                                      : c.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w500,
                                                      color: labelColor(context))),
                                            ),
                                            Icon(CupertinoIcons.chevron_right,
                                                size: 16, color: secondaryColor(context)),
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
                      SliverToBoxAdapter(child: SizedBox(height: barSpace(context) + 8)),
                    ],
                  ),
                  if (q.isEmpty && list.length > 12)
                    Positioned(
                      right: 2,
                      top: 4,
                      bottom: barSpace(context) + 4,
                      child: LayoutBuilder(builder: (context, box) {
                        void pick(double dy) {
                          final i = (dy / box.maxHeight * letters.length)
                              .floor()
                              .clamp(0, letters.length - 1)
                              .toInt();
                          _jump(letters[i], list, header);
                        }

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => pick(d.localPosition.dy),
                          onVerticalDragUpdate: (d) => pick(d.localPosition.dy),
                          child: SizedBox(
                            width: 22,
                            child: Column(
                              children: [
                                for (final l in letters.characters)
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(l,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: accentColor(context))),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                ],
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
            Center(child: Avatar(c.name, size: 104, contact: c)),
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
            backgroundColor: const Color(0x00000000),
            decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(14)),
              children: [
                for (final n in c.numbers)
                  CupertinoListTile(
                    title: Text('móvil', style: TextStyle(fontSize: 14, color: labelColor(context))),
                    subtitle: Text(n,
                        style: TextStyle(
                            fontSize: 17, color: accentColor(context))),
                    onTap: () => callNumber(context, n),
                  ),
                if (c.numbers.isEmpty) const CupertinoListTile(title: Text('Sin número')),
              ],
            ),
            CupertinoListSection.insetGrouped(
            backgroundColor: const Color(0x00000000),
            decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(14)),
              children: [
                CupertinoListTile(
                  title: Text(c.starred ? 'Quitar de favoritos' : 'Añadir a favoritos',
                      style: TextStyle(color: accentColor(context))),
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
