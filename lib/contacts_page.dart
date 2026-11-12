import 'package:flutter/cupertino.dart';

import 'common.dart';
import 'native.dart';

void openDetail(BuildContext context, {Contact? contact, String number = ''}) {
  Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute<void>(
      builder: (_) => ContactDetail(contact: contact, number: number)));
}

void openContact(BuildContext context, Contact c) => openDetail(context, contact: c);

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

/// Ficha de un contacto o de un número que no está en la agenda.
class ContactDetail extends StatefulWidget {
  const ContactDetail({super.key, this.contact, this.number = ''});
  final Contact? contact;
  final String number;

  @override
  State<ContactDetail> createState() => _ContactDetailState();
}

class _ContactDetailState extends State<ContactDetail> {
  List<String> blocked = [];

  Contact? get c => widget.contact;
  List<String> get numbers =>
      c?.numbers ?? (widget.number.isEmpty ? <String>[] : <String>[widget.number]);
  String get mainNumber => numbers.isEmpty ? '' : numbers.first;

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
      numbers.isNotEmpty && numbers.every((n) => blocked.any((b) => sameNumber(b, n)));

  Future<void> _toggleBlock() async {
    final was = isBlocked;
    for (final n in numbers) {
      if (was) {
        await Native.unblockNumber(n);
      } else {
        await Native.blockNumber(n);
      }
    }
    await _load();
  }

  Future<void> _toggleStar() async {
    final contact = c;
    if (contact == null) return;
    setState(() => contact.starred = !contact.starred);
    await Native.setStarred(contact.id, contact.starred);
    await AppData.i.reload();
  }

  Future<void> _delete() async {
    final contact = c;
    if (contact == null) return;
    if (!await confirm(context, '¿Eliminar a ${contact.name}?', 'Eliminar')) return;
    await Native.deleteContact(contact.id);
    await AppData.i.reload();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addContact() async {
    final r = await askText(context, 'Nuevo contacto', hints: ['Nombre']);
    if (r == null || r[0].isEmpty) return;
    await Native.addContact(r[0], mainNumber);
    await AppData.i.reload();
    if (mounted) Navigator.pop(context);
  }

  Widget _action(IconData icon, String text, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.16)),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(height: 7),
            Text(text,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: labelColor(context))),
          ],
        ),
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(30, 20, 30, 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: secondaryColor(context))),
      );

  Widget _card(List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration:
          BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Container(
                  height: 0.6,
                  margin: const EdgeInsets.only(left: 16),
                  color: separatorColor(context)),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _line(Widget child, {VoidCallback? onTap}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), child: child),
      );

  Widget _danger(String text, VoidCallback onTap) => _line(
      Row(children: [
        Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16, color: Color(0xFFFF3B30)))),
      ]),
      onTap: onTap);

  @override
  Widget build(BuildContext context) {
    final contact = c;
    final name = contact?.name ?? (mainNumber.isEmpty ? 'Número oculto' : mainNumber);
    final history = AppData.i.calls
        .where((e) => numbers.any((n) => sameNumber(n, e.number)))
        .take(15)
        .toList();
    return CupertinoPageScaffold(
      backgroundColor: groupedBg(context),
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Atrás',
        backgroundColor: groupedBg(context),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration:
                    BoxDecoration(shape: BoxShape.circle, gradient: brandGradient(context)),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: groupedBg(context)),
                  child: Avatar(contact?.name ?? '', size: 112, contact: contact),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700, color: labelColor(context))),
            ),
            if (contact != null && mainNumber.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(mainNumber,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: secondaryColor(context))),
              ),
            if (isBlocked)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Bloqueado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFF3B30))),
              ),
            const SizedBox(height: 20),
            if (mainNumber.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _action(CupertinoIcons.phone_fill, 'Llamar', const Color(0xFF1FC24A),
                        () => callNumber(context, mainNumber)),
                    _action(CupertinoIcons.chat_bubble_fill, 'Mensaje', accentColor(context),
                        () => Native.sendSms(mainNumber)),
                    _action(CupertinoIcons.chat_bubble_2_fill, 'WhatsApp', const Color(0xFF25D366),
                        () => Native.openWhatsApp(mainNumber)),
                    if (contact != null)
                      _action(contact.starred ? CupertinoIcons.star_fill : CupertinoIcons.star,
                          'Favorito', const Color(0xFFFFB300), _toggleStar)
                    else
                      _action(CupertinoIcons.person_add, 'Añadir', accentColor(context), _addContact),
                  ],
                ),
              ),
            if (numbers.length > 1) ...[
              _header('Números'),
              _card([
                for (final n in numbers)
                  _line(
                      Row(children: [
                        Expanded(
                            child: Text(n,
                                style: TextStyle(fontSize: 16, color: labelColor(context)))),
                        Icon(CupertinoIcons.phone_fill, size: 19, color: accentColor(context)),
                      ]),
                      onTap: () => callNumber(context, n)),
              ]),
            ],
            _header('Historial'),
            _card([
              if (history.isEmpty)
                _line(Row(children: [
                  Text('Sin llamadas',
                      style: TextStyle(fontSize: 15, color: secondaryColor(context))),
                ])),
              for (final e in history)
                _line(Row(
                  children: [
                    Icon(callIcon(e), size: 16, color: callColor(context, e)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(callKind(e),
                              style: TextStyle(fontSize: 15, color: labelColor(context))),
                          Text(formatWhenLong(e.date),
                              style: TextStyle(fontSize: 13, color: secondaryColor(context))),
                        ],
                      ),
                    ),
                    if (e.duration > 0)
                      Text(formatDuration(e.duration),
                          style: TextStyle(fontSize: 13, color: secondaryColor(context))),
                  ],
                )),
            ]),
            if (numbers.isNotEmpty || contact != null) ...[
              const SizedBox(height: 20),
              _card([
                if (numbers.isNotEmpty)
                  _danger(isBlocked ? 'Desbloquear' : 'Bloquear número', _toggleBlock),
                if (contact == null && mainNumber.isNotEmpty)
                  _danger('Reportar como spam', () async {
                    await reportFlow(context, mainNumber);
                    await _load();
                  }),
                if (contact != null) _danger('Eliminar contacto', _delete),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
