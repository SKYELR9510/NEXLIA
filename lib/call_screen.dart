import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'native.dart';

/// Pantalla de llamada entrante, saliente y en curso.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.initial});
  final Map<dynamic, dynamic> initial;

  static bool _open = false;

  static void show(GlobalKey<NavigatorState> nav, Map<dynamic, dynamic> state) {
    final n = nav.currentState;
    if (_open || n == null) return;
    _open = true;
    n
        .push(PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => CallScreen(initial: state),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 220),
        ))
        .then((_) {
      _open = false;
      AppData.i.reload();
    });
  }

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late Map<dynamic, dynamic> st;
  StreamSubscription<Map<dynamic, dynamic>>? sub;
  Timer? ticker;
  Timer? closer;
  bool keypad = false;
  String typed = '';

  @override
  void initState() {
    super.initState();
    st = widget.initial;
    sub = Native.events.listen(_onEvent);
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && st['state'] == 'active') setState(() {});
    });
  }

  void _onEvent(Map<dynamic, dynamic> e) {
    if (e['type'] != 'call' || !mounted) return;
    final state = e['state'];
    if (state == 'none' || state == 'disconnected') {
      setState(() => st = {...st, 'state': 'disconnected'});
      closer ??= Timer(const Duration(milliseconds: 900), () async {
        // Si entró otra llamada mientras tanto, la pantalla sigue abierta.
        final now = await Native.getCallState();
        if (!mounted) return;
        final s = now['state'];
        if (s == 'none' || s == 'disconnected') {
          Navigator.of(context).pop();
        } else {
          closer = null;
          setState(() => st = now);
        }
      });
    } else {
      closer?.cancel();
      closer = null;
      setState(() => st = e);
    }
  }

  @override
  void dispose() {
    sub?.cancel();
    ticker?.cancel();
    closer?.cancel();
    super.dispose();
  }

  String get _status {
    switch (st['state']) {
      case 'ringing':
        return 'Llamada entrante…';
      case 'dialing':
        return 'Llamando…';
      case 'holding':
        return 'En espera';
      case 'active':
        final t = (st['connectTime'] as num?)?.toInt() ?? 0;
        if (t <= 0) return 'En llamada';
        final secs = (DateTime.now().millisecondsSinceEpoch - t) ~/ 1000;
        return formatDuration(secs < 0 ? 0 : secs);
      default:
        return 'Llamada finalizada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = st['state'];
    final number = (st['number'] ?? '').toString();
    var name = (st['name'] ?? '').toString();
    if (name.isEmpty) name = AppData.i.contactFor(number)?.name ?? '';
    final title = name.isNotEmpty ? name : (number.isEmpty ? 'Número oculto' : number);
    final spam = (st['spam'] ?? '').toString();
    final ringing = state == 'ringing';
    final ended = state == 'disconnected';

    return PopScope(
      canPop: false,
      child: CupertinoPageScaffold(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A2A6E), Color(0xFF040A18), Color(0xFF0B2F7A)],
                stops: [0, 0.55, 1],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text(_status,
                      style: TextStyle(
                          fontSize: state == 'active' ? 24 : 18,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xE6FFFFFF))),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)),
                    child: Avatar(name, size: 132, contact: AppData.i.contactFor(number)),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(title,
                          maxLines: 1,
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.white)),
                    ),
                  ),
                  if (name.isNotEmpty && number.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(number,
                          style: const TextStyle(fontSize: 17, color: Color(0x99FFFFFF))),
                    ),
                  if (spam.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0x33FF453A), borderRadius: BorderRadius.circular(20)),
                      child: Text('Posible spam · $spam',
                          style: const TextStyle(
                              color: Color(0xFFFF6961), fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  const Spacer(),
                  if (keypad && !ringing && !ended) _dtmfPad(),
                  if (!keypad && !ringing && !ended) _controls(),
                  const SizedBox(height: 28),
                  if (ringing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _round(CupertinoIcons.phone_down_fill, const Color(0xFFFF3B30), 'Rechazar',
                              Native.hangup),
                          _round(CupertinoIcons.phone_fill, const Color(0xFF1FC24A), 'Aceptar',
                              Native.answer),
                        ],
                      ),
                    )
                  else if (!ended)
                    _round(CupertinoIcons.phone_down_fill, const Color(0xFFFF3B30),
                        keypad ? 'Ocultar teclado' : 'Finalizar', Native.hangup,
                        onLabelTap: keypad ? () => setState(() => keypad = false) : null),
                  const SizedBox(height: 44),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _round(IconData icon, Color color, String text, Future<bool> Function() action,
      {VoidCallback? onLabelTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            action();
          },
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: CupertinoColors.white, size: 34),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onLabelTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(text, style: const TextStyle(color: CupertinoColors.white, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Widget _toggle(IconData icon, String text, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? CupertinoColors.white : const Color(0x33FFFFFF),
            ),
            child: Icon(icon, size: 30, color: on ? const Color(0xFF000000) : CupertinoColors.white),
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: CupertinoColors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _controls() {
    final muted = st['muted'] == true;
    final speaker = st['speaker'] == true;
    final holding = st['state'] == 'holding';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _toggle(CupertinoIcons.speaker_3_fill, 'Altavoz', speaker,
                  () => Native.setSpeaker(!speaker)),
              _toggle(CupertinoIcons.mic_slash_fill, 'Silenciar', muted,
                  () => Native.setMuted(!muted)),
              _toggle(CupertinoIcons.circle_grid_3x3_fill, 'Teclado', false,
                  () => setState(() => keypad = true)),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _toggle(CupertinoIcons.pause_fill, holding ? 'Reanudar' : 'En espera', holding,
                  Native.toggleHold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dtmfPad() {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: Text(typed,
              maxLines: 1,
              style: const TextStyle(color: CupertinoColors.white, fontSize: 26, letterSpacing: 2)),
        ),
        const SizedBox(height: 8),
        for (var r = 0; r < 4; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var c = 0; c < 3; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GestureDetector(
                      onTap: () {
                        final k = keys[r * 3 + c];
                        HapticFeedback.lightImpact();
                        Native.dtmf(k);
                        setState(() => typed = (typed + k).length > 18
                            ? (typed + k).substring((typed + k).length - 18)
                            : typed + k);
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        alignment: Alignment.center,
                        decoration:
                            const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)),
                        child: Text(keys[r * 3 + c],
                            style: const TextStyle(color: CupertinoColors.white, fontSize: 30)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
