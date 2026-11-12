import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'contacts_page.dart';
import 'native.dart';

const _keys = [
  ['1', ''], ['2', 'ABC'], ['3', 'DEF'],
  ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
  ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'],
  ['*', ''], ['0', '+'], ['#', ''],
];

const _t9 = {
  'a': '2', 'b': '2', 'c': '2', 'á': '2',
  'd': '3', 'e': '3', 'f': '3', 'é': '3',
  'g': '4', 'h': '4', 'i': '4', 'í': '4',
  'j': '5', 'k': '5', 'l': '5',
  'm': '6', 'n': '6', 'o': '6', 'ñ': '6', 'ó': '6',
  'p': '7', 'q': '7', 'r': '7', 's': '7',
  't': '8', 'u': '8', 'v': '8', 'ú': '8', 'ü': '8',
  'w': '9', 'x': '9', 'y': '9', 'z': '9',
};

/// Convierte una palabra a las teclas del teclado numérico (ana -> 262).
String _toT9(String word) {
  final b = StringBuffer();
  for (final ch in word.toLowerCase().split('')) {
    b.write(_t9[ch] ?? '');
  }
  return b.toString();
}

class KeypadPage extends StatefulWidget {
  const KeypadPage({super.key});

  @override
  State<KeypadPage> createState() => _KeypadPageState();
}

class _KeypadPageState extends State<KeypadPage> {
  final TextEditingController search = TextEditingController();
  final FocusNode focus = FocusNode();

  @override
  void initState() {
    super.initState();
    dialText.addListener(_refresh);
    search.addListener(_refresh);
    focus.addListener(_refresh);
    AppData.i.addListener(_refresh);
    homeTab.addListener(_tabChanged);
  }

  @override
  void dispose() {
    dialText.removeListener(_refresh);
    AppData.i.removeListener(_refresh);
    homeTab.removeListener(_tabChanged);
    search.dispose();
    focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _tabChanged() {
    if (homeTab.value != 0) focus.unfocus();
  }

  void _press(String d) {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    dialText.value += d;
  }

  void _back() {
    final t = dialText.value;
    if (t.isEmpty) return;
    HapticFeedback.selectionClick();
    dialText.value = t.substring(0, t.length - 1);
  }

  /// Búsqueda escrita: por nombre o por número.
  List<Contact> _search(String text) {
    final q = text.trim().toLowerCase();
    if (q.isEmpty) return [];
    final qd = digits(q);
    final out = <Contact>[];
    for (final c in AppData.i.contacts) {
      if (c.name.toLowerCase().contains(q) ||
          (qd.length >= 2 && c.numbers.any((n) => digits(n).contains(qd)))) {
        out.add(c);
        if (out.length >= 60) break;
      }
    }
    return out;
  }

  /// Sugerencias al marcar: el número contiene lo marcado, o las teclas
  /// deletrean el inicio de un nombre (262 -> Ana).
  List<Contact> _suggest(String typed) {
    final d = digits(typed);
    if (d.length < 2 || d.length != typed.replaceAll('+', '').length) return [];
    final out = <Contact>[];
    for (final c in AppData.i.contacts) {
      final byNumber = c.numbers.any((n) => digits(n).contains(d));
      final byName =
          !byNumber && c.name.split(RegExp(r'\s+')).any((w) => _toT9(w).startsWith(d));
      if (byNumber || byName) {
        out.add(c);
        if (out.length >= 12) break;
      }
    }
    return out;
  }

  Future<void> _call() async {
    final number = dialText.value;
    if (number.isEmpty) {
      // Sin número, el botón verde trae el último marcado.
      for (final c in AppData.i.calls) {
        if (c.type == 2 && c.number.isNotEmpty) {
          dialText.value = c.number;
          return;
        }
      }
      return;
    }
    await callNumber(context, number);
    dialText.value = '';
  }

  Future<void> _callContact(Contact c) async {
    if (c.numbers.isEmpty) return;
    focus.unfocus();
    await callNumber(context, c.numbers.first);
    dialText.value = '';
    search.clear();
  }

  Future<void> _add() async {
    final r = await askText(context, 'Nuevo contacto',
        hints: ['Nombre', 'Número'],
        initial: ['', dialText.value],
        types: [TextInputType.name, TextInputType.phone]);
    if (r == null || r[0].isEmpty || r[1].isEmpty) return;
    await Native.addContact(r[0], r[1]);
    await AppData.i.reload();
  }

  Widget _result(Contact c) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _callContact(c),
      onLongPress: () => openContact(context, c),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 7, 18, 7),
        child: Row(
          children: [
            Avatar(c.name, size: 44, contact: c),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600, color: labelColor(context))),
                  Text(c.numbers.isEmpty ? 'Sin número' : c.numbers.first,
                      style: TextStyle(fontSize: 14, color: secondaryColor(context))),
                ],
              ),
            ),
            Icon(CupertinoIcons.phone_fill, size: 22, color: accentColor(context)),
          ],
        ),
      ),
    );
  }

  Widget _chip(Contact c) {
    return Center(
      child: GestureDetector(
        onTap: () => _callContact(c),
        onLongPress: () => openContact(context, c),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
          decoration:
              BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(24)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Avatar(c.name, size: 32, contact: c),
              const SizedBox(width: 8),
              Text(c.name,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: labelColor(context))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typed = dialText.value;
    final searching = focus.hasFocus || search.text.isNotEmpty;
    return LayoutBuilder(builder: (context, box) {
      final avail = box.maxHeight - barSpace(context) - 240;
      final d = math.max(52.0, math.min(78.0, math.min(avail / 5.7, box.maxWidth / 4.6)));
      final gap = d * 0.36;
      return Padding(
        padding: EdgeInsets.only(bottom: barSpace(context)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(
                children: [
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => brandGradient(context).createShader(r),
                    child: const Text('NEXLIA',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Color(0xFFFFFFFF))),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: () => homeTab.value = 4,
                    child: Icon(CupertinoIcons.gear_solid, size: 25, color: labelColor(context)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoTextField(
                controller: search,
                focusNode: focus,
                placeholder: 'Buscar contactos…',
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(CupertinoIcons.search, size: 20, color: secondaryColor(context)),
                ),
                suffix: !searching
                    ? null
                    : CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minSize: 36,
                        onPressed: () {
                          search.clear();
                          focus.unfocus();
                        },
                        child: Icon(CupertinoIcons.clear_circled_solid,
                            size: 20, color: secondaryColor(context)),
                      ),
                placeholderStyle: TextStyle(color: secondaryColor(context), fontSize: 16),
                style: TextStyle(color: labelColor(context), fontSize: 17),
                decoration:
                    BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(25)),
              ),
            ),
            if (searching)
              Expanded(
                child: Builder(builder: (context) {
                  final found = _search(search.text);
                  if (found.isEmpty) {
                    return Center(
                        child: Text(
                            search.text.trim().isEmpty ? 'Escribe un nombre o número' : 'Sin resultados',
                            style: TextStyle(color: secondaryColor(context), fontSize: 16)));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: found.length,
                    itemBuilder: (context, i) => _result(found[i]),
                  );
                }),
              )
            else ...[
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: SizedBox(
                  height: 54,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(typed.isEmpty ? ' ' : typed,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                            color: labelColor(context))),
                  ),
                ),
              ),
              SizedBox(
                height: 50,
                child: Builder(builder: (context) {
                  if (typed.isEmpty) return const SizedBox();
                  final found = _suggest(typed);
                  if (found.isEmpty) {
                    return Center(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 30,
                        onPressed: _add,
                        child: const Text('Añadir a contactos', style: TextStyle(fontSize: 15)),
                      ),
                    );
                  }
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: found.length,
                    itemBuilder: (context, i) => _chip(found[i]),
                  );
                }),
              ),
              const SizedBox(height: 8),
              for (var row = 0; row < 4; row++)
                Padding(
                  padding: EdgeInsets.only(bottom: gap * 0.4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var col = 0; col < 3; col++) ...[
                        if (col > 0) SizedBox(width: gap),
                        _DialKey(
                          size: d,
                          digit: _keys[row * 3 + col][0],
                          letters: _keys[row * 3 + col][1],
                          onTap: () => _press(_keys[row * 3 + col][0]),
                          onLongPress: _keys[row * 3 + col][0] == '0' ? () => _press('+') : null,
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: d,
                    height: d,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _add,
                      child: Icon(CupertinoIcons.person_add, size: d * 0.38, color: labelColor(context)),
                    ),
                  ),
                  SizedBox(width: gap),
                  GestureDetector(
                    onTap: _call,
                    child: Container(
                      width: d,
                      height: d,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF3EE06A), Color(0xFF12B83C)],
                        ),
                        boxShadow: [
                          BoxShadow(color: Color(0x5512B83C), blurRadius: 16, offset: Offset(0, 6)),
                        ],
                      ),
                      child:
                          Icon(CupertinoIcons.phone_fill, color: CupertinoColors.white, size: d * 0.44),
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox(
                    width: d,
                    height: d,
                    child: typed.isEmpty
                        ? null
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _back,
                            onLongPress: () => dialText.value = '',
                            child: Icon(CupertinoIcons.delete_left,
                                size: d * 0.38, color: labelColor(context)),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      );
    });
  }
}

class _DialKey extends StatefulWidget {
  const _DialKey(
      {required this.size,
      required this.digit,
      required this.letters,
      required this.onTap,
      this.onLongPress});
  final double size;
  final String digit;
  final String letters;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_DialKey> createState() => _DialKeyState();
}

class _DialKeyState extends State<_DialKey> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final symbol = widget.digit == '*' || widget.digit == '#';
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) => setState(() => down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: Duration(milliseconds: down ? 0 : 260),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: down ? accentColor(context).withOpacity(0.28) : fillColor(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.digit,
                style: TextStyle(
                    fontSize: widget.size * 0.4,
                    height: 1.0,
                    fontWeight: FontWeight.w600,
                    color: labelColor(context))),
            if (!symbol)
              Text(widget.letters.isEmpty ? ' ' : widget.letters,
                  style: TextStyle(
                      fontSize: widget.size * 0.14,
                      height: 1.25,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: secondaryColor(context))),
          ],
        ),
      ),
    );
  }
}
