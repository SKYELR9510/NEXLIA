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

class KeypadPage extends StatelessWidget {
  const KeypadPage({super.key});

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

  Future<void> _call(BuildContext context) async {
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

  Future<void> _add(BuildContext context) async {
    final r = await askText(context, 'Nuevo contacto',
        hints: ['Nombre', 'Número'],
        initial: ['', dialText.value],
        types: [TextInputType.name, TextInputType.phone]);
    if (r == null || r[0].isEmpty || r[1].isEmpty) return;
    await Native.addContact(r[0], r[1]);
    await AppData.i.reload();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final avail = box.maxHeight - barSpace(context) - 190;
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
            ValueListenableBuilder<String>(
              valueListenable: dialText,
              builder: (context, text, _) {
                final contact = text.length >= 6 ? AppData.i.contactFor(text) : null;
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 50,
                      decoration: BoxDecoration(
                          color: fillColor(context), borderRadius: BorderRadius.circular(25)),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.search, size: 20, color: labelColor(context)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(text.isEmpty ? 'Buscar un número…' : text,
                                  maxLines: 1,
                                  style: TextStyle(
                                      fontSize: text.isEmpty ? 16 : 24,
                                      fontWeight: text.isEmpty ? FontWeight.w400 : FontWeight.w600,
                                      letterSpacing: text.isEmpty ? 0 : 1,
                                      color:
                                          text.isEmpty ? secondaryColor(context) : labelColor(context))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 26,
                      child: Center(
                        child: Text(contact?.name ?? '',
                            style: TextStyle(fontSize: 15, color: accentColor(context))),
                      ),
                    ),
                  ],
                );
              },
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
                    onTap: () => _add(context),
                    child: Icon(CupertinoIcons.person_add, size: d * 0.4, color: labelColor(context)),
                  ),
                ),
                SizedBox(width: gap),
                GestureDetector(
                  onTap: () => _call(context),
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
                    child: Icon(CupertinoIcons.phone_fill, color: CupertinoColors.white, size: d * 0.44),
                  ),
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: d,
                  height: d,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _back,
                    onLongPress: () => dialText.value = '',
                    child: Icon(CupertinoIcons.delete_left, size: d * 0.4, color: labelColor(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
