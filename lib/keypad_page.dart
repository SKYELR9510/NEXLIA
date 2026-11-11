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
    var number = dialText.value;
    if (number.isEmpty) {
      // Como en el iPhone: sin número, el botón verde trae el último marcado.
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
    final r = await askText(context, 'Nuevo contacto', hints: ['Nombre']);
    if (r == null || r[0].isEmpty) return;
    await Native.addContact(r[0], dialText.value);
    await AppData.i.reload();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final avail = box.maxHeight - barSpace - 150;
      final d = math.max(54.0, math.min(84.0, math.min(avail / 5.9, box.maxWidth / 4.4)));
      final gap = d * 0.2;
      return Padding(
        padding: const EdgeInsets.only(bottom: barSpace),
        child: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: dialText,
                builder: (context, text, _) {
                  final contact = text.length >= 6 ? AppData.i.contactFor(text) : null;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(text.isEmpty ? ' ' : text,
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 1,
                                  color: labelColor(context))),
                        ),
                      ),
                      SizedBox(
                        height: 34,
                        child: text.isEmpty
                            ? null
                            : contact != null
                                ? Center(
                                    child: Text(contact.name,
                                        style: TextStyle(fontSize: 16, color: secondaryColor(context))))
                                : CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minSize: 30,
                                    onPressed: () => _add(context),
                                    child: const Text('Añadir número', style: TextStyle(fontSize: 16)),
                                  ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  );
                },
              ),
            ),
            for (var row = 0; row < 4; row++)
              Padding(
                padding: EdgeInsets.only(bottom: gap * 0.75),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var col = 0; col < 3; col++) ...[
                      if (col > 0) SizedBox(width: gap * 1.4),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: d),
                SizedBox(width: gap * 1.4),
                GestureDetector(
                  onTap: () => _call(context),
                  child: Container(
                    width: d,
                    height: d,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34C759)),
                    child: Icon(CupertinoIcons.phone_fill, color: CupertinoColors.white, size: d * 0.42),
                  ),
                ),
                SizedBox(width: gap * 1.4),
                SizedBox(
                  width: d,
                  height: d,
                  child: ValueListenableBuilder<String>(
                    valueListenable: dialText,
                    builder: (context, text, _) => text.isEmpty
                        ? const SizedBox()
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _back,
                            onLongPress: () => dialText.value = '',
                            child: Icon(CupertinoIcons.delete_left_fill,
                                size: d * 0.36, color: secondaryColor(context)),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
    final base = CupertinoColors.secondarySystemFill.resolveFrom(context);
    final pressed = CupertinoColors.systemFill.resolveFrom(context);
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
          color: down ? pressed.withOpacity(0.55) : base,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.digit,
                style: TextStyle(
                    fontSize: widget.size * (symbol ? 0.44 : 0.42),
                    height: 1.0,
                    fontWeight: FontWeight.w400,
                    color: labelColor(context))),
            if (!symbol)
              Text(widget.letters.isEmpty ? ' ' : widget.letters,
                  style: TextStyle(
                      fontSize: widget.size * 0.13,
                      height: 1.3,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: labelColor(context))),
          ],
        ),
      ),
    );
  }
}
