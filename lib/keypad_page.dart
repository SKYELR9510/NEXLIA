import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'native.dart';

const _keys = [
  ['1', ''], ['2', 'ABC'], ['3', 'DEF'],
  ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
  ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'],
  ['*', ''], ['0', '+'], ['#', ''],
];

final _letters = RegExp(r'[A-Za-zÀ-ÿ]');

class KeypadPage extends StatefulWidget {
  const KeypadPage({super.key});

  @override
  State<KeypadPage> createState() => _KeypadPageState();
}

class _KeypadPageState extends State<KeypadPage> {
  final TextEditingController ctrl = TextEditingController();
  final FocusNode focus = FocusNode();

  @override
  void initState() {
    super.initState();
    ctrl.text = dialText.value;
    dialText.addListener(_fromDial);
    ctrl.addListener(_fromField);
    focus.addListener(_refresh);
    homeTab.addListener(_tabChanged);
  }

  @override
  void dispose() {
    dialText.removeListener(_fromDial);
    homeTab.removeListener(_tabChanged);
    ctrl.dispose();
    focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _tabChanged() {
    if (homeTab.value != 0) focus.unfocus();
  }

  void _fromDial() {
    if (ctrl.text != dialText.value) ctrl.text = dialText.value;
  }

  void _fromField() {
    if (dialText.value != ctrl.text) dialText.value = ctrl.text;
    _refresh();
  }

  void _press(String d) {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    ctrl.text = ctrl.text + d;
  }

  void _back() {
    final t = ctrl.text;
    if (t.isEmpty) return;
    HapticFeedback.selectionClick();
    ctrl.text = t.substring(0, t.length - 1);
  }

  void _clear() {
    ctrl.clear();
    focus.unfocus();
  }

  /// Contactos cuyo nombre o número coincide con lo escrito.
  List<Contact> _matches(String text) {
    final q = text.trim().toLowerCase();
    if (q.isEmpty) return [];
    final qd = digits(q);
    final byName = _letters.hasMatch(q);
    final out = <Contact>[];
    for (final c in AppData.i.contacts) {
      final hit = byName
          ? c.name.toLowerCase().contains(q)
          : (qd.length >= 2 && c.numbers.any((n) => digits(n).contains(qd)));
      if (hit) out.add(c);
      if (out.length >= 40) break;
    }
    return out;
  }

  Future<void> _call() async {
    final text = ctrl.text.trim();
    if (text.isEmpty) {
      // Sin número, el botón verde trae el último marcado.
      for (final c in AppData.i.calls) {
        if (c.type == 2 && c.number.isNotEmpty) {
          ctrl.text = c.number;
          return;
        }
      }
      return;
    }
    var number = text;
    if (_letters.hasMatch(text)) {
      final m = _matches(text);
      if (m.isEmpty || m.first.numbers.isEmpty) return;
      number = m.first.numbers.first;
    }
    focus.unfocus();
    await callNumber(context, number);
    ctrl.clear();
  }

  Future<void> _add() async {
    final r = await askText(context, 'Nuevo contacto',
        hints: ['Nombre', 'Número'],
        initial: ['', _letters.hasMatch(ctrl.text) ? '' : ctrl.text],
        types: [TextInputType.name, TextInputType.phone]);
    if (r == null || r[0].isEmpty || r[1].isEmpty) return;
    await Native.addContact(r[0], r[1]);
    await AppData.i.reload();
  }

  Widget _result(Contact c) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: c.numbers.isEmpty
          ? null
          : () async {
              focus.unfocus();
              await callNumber(context, c.numbers.first);
              ctrl.clear();
            },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 7, 18, 7),
        child: Row(
          children: [
            Avatar(c.name, size: 42, contact: c),
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

  @override
  Widget build(BuildContext context) {
    final text = ctrl.text;
    final searching = focus.hasFocus || _letters.hasMatch(text);
    final matches = _matches(text);
    return LayoutBuilder(builder: (context, box) {
      final avail = box.maxHeight - barSpace(context) - 200;
      final d = math.max(52.0, math.min(78.0, math.min(avail / 5.7, box.maxWidth / 4.6)));
      final gap = d * 0.36;
      return Padding(
        padding: EdgeInsets.only(bottom: barSpace(context)),
        child: Column(
          children: [
            ScreenTitle('NEXLIA',
                trailing: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () => homeTab.value = 4,
                  child: Icon(CupertinoIcons.gear_solid, size: 26, color: labelColor(context)),
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Pill('Teléfono', selected: true, onTap: () {}),
                  const SizedBox(width: 8),
                  Pill('Contactos', selected: false, onTap: () => homeTab.value = 1),
                  const SizedBox(width: 8),
                  Pill('Recientes', selected: false, onTap: () => homeTab.value = 2),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoTextField(
                controller: ctrl,
                focusNode: focus,
                placeholder: 'Buscar nombre o número…',
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(CupertinoIcons.search, size: 20, color: labelColor(context)),
                ),
                suffix: (text.isEmpty && !focus.hasFocus)
                    ? null
                    : CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minSize: 36,
                        onPressed: _clear,
                        child: Icon(CupertinoIcons.clear_circled_solid,
                            size: 20, color: secondaryColor(context)),
                      ),
                placeholderStyle: TextStyle(color: secondaryColor(context), fontSize: 16),
                style: TextStyle(
                    color: labelColor(context),
                    fontSize: text.isEmpty || searching ? 17 : 22,
                    fontWeight: FontWeight.w600),
                decoration:
                    BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(25)),
              ),
            ),
            if (searching)
              Expanded(
                child: matches.isEmpty
                    ? Center(
                        child: Text(text.trim().isEmpty ? 'Escribe un nombre o número' : 'Sin resultados',
                            style: TextStyle(color: secondaryColor(context), fontSize: 16)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: matches.length,
                        itemBuilder: (context, i) => _result(matches[i]),
                      ),
              )
            else ...[
              SizedBox(
                height: 62,
                child: matches.isEmpty ? null : _result(matches.first),
              ),
              const Spacer(),
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
                      child: Icon(CupertinoIcons.person_add, size: d * 0.4, color: labelColor(context)),
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
                          BoxShadow(color: Color(0x5512B83C), blurRadius: 14, offset: Offset(0, 6)),
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
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _back,
                      onLongPress: () => ctrl.clear(),
                      child: Icon(CupertinoIcons.delete_left, size: d * 0.4, color: labelColor(context)),
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
                    fontWeight: FontWeight.w700,
                    color: labelColor(context))),
            if (!symbol)
              Text(widget.letters.isEmpty ? ' ' : widget.letters,
                  style: TextStyle(
                      fontSize: widget.size * 0.14,
                      height: 1.25,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: labelColor(context))),
          ],
        ),
      ),
    );
  }
}
