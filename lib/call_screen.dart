import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'common.dart';
import 'native.dart';

/// Pantalla de llamada entrante, saliente y en curso.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.initial});
  final Map<dynamic, dynamic> initial;

  static bool _open = false;

  /// La llamada sigue, pero el usuario salió a marcar otro número.
  static final ValueNotifier<bool> minimized = ValueNotifier<bool>(false);

  static void show(GlobalKey<NavigatorState> nav, Map<dynamic, dynamic> state,
      {bool force = false}) {
    final n = nav.currentState;
    final st = state['state'];
    if (force || st == 'ringing' || st == 'dialing') minimized.value = false;
    if (_open || n == null || minimized.value) return;
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
    final title = st['conference'] == true
        ? 'Conferencia'
        : (name.isNotEmpty ? name : (number.isEmpty ? 'Número oculto' : number));
    final spam = (st['spam'] ?? '').toString();
    final ringing = state == 'ringing';
    final ended = state == 'disconnected';

    final video = CallStyle.ringVideo.value;
    final bg = CallStyle.background.value;
    final tone = CallStyle.ringTone.value;

    return PopScope(
      canPop: false,
      // Atrás: la llamada sigue y se vuelve a la app (queda una franja verde para regresar).
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !ringing && !ended) _minimize();
      },
      child: CupertinoPageScaffold(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Color(0x00000000),
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Color(0x00000000),
            systemNavigationBarDividerColor: Color(0x00000000),
            systemNavigationBarContrastEnforced: false,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A2A6E), Color(0xFF040A18), Color(0xFF0B2F7A)],
                stops: [0, 0.55, 1],
              ),
            ),
            child: Stack(
              children: [
                if (ringing && video.isNotEmpty)
                  Positioned.fill(
                    child: RingVideo(
                        path: video,
                        sound: CallStyle.ringSound.value && spam.isEmpty && tone.isEmpty),
                  )
                else if (bg.isNotEmpty)
                  Positioned.fill(
                    child: Image.file(File(bg),
                        fit: BoxFit.cover, errorBuilder: (context, _, __) => const SizedBox()),
                  ),
                if ((ringing && video.isNotEmpty) || bg.isNotEmpty)
                  Positioned.fill(
                    // Oscurece el fondo para que el texto y los botones se lean.
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x99000000), Color(0x33000000), Color(0xB3000000)],
                          stops: [0, 0.4, 1],
                        ),
                      ),
                    ),
                  ),
                if (ringing && tone.isNotEmpty && spam.isEmpty)
                  RingVideo(path: tone, sound: true, audioOnly: true),
                Positioned.fill(
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
              ],
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

  Widget _toggle(IconData icon, String text, bool on, VoidCallback? onTap) {
    return Expanded(
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? CupertinoColors.white : const Color(0x2EFFFFFF),
                ),
                child: Icon(icon,
                    size: 28, color: on ? const Color(0xFF0A2A6E) : CupertinoColors.white),
              ),
              const SizedBox(height: 8),
              Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: CupertinoColors.white, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  void _minimize() {
    CallScreen.minimized.value = true;
    Navigator.of(context).pop();
  }

  void _addCall() {
    homeTab.value = 0;
    _minimize();
  }

  Widget _controls() {
    final muted = st['muted'] == true;
    final speaker = st['speaker'] == true;
    final bluetooth = st['bluetooth'] == true;
    final btAvailable = st['btAvailable'] == true;
    final holding = st['state'] == 'holding';
    final two = ((st['count'] as num?)?.toInt() ?? 1) >= 2 && st['conference'] != true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        children: [
          Row(
            children: [
              _toggle(CupertinoIcons.mic_slash_fill, 'Silenciar', muted,
                  () => Native.setMuted(!muted)),
              _toggle(CupertinoIcons.circle_grid_3x3_fill, 'Teclado', false,
                  () => setState(() => keypad = true)),
              _toggle(CupertinoIcons.speaker_3_fill, 'Altavoz', speaker,
                  () => Native.setSpeaker(!speaker)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (two)
                _toggle(CupertinoIcons.arrow_merge, 'Unir', false, Native.mergeCalls)
              else
                _toggle(CupertinoIcons.add, 'Agregar', false, _addCall),
              if (two)
                _toggle(CupertinoIcons.arrow_swap, 'Cambiar', false, Native.swapCalls)
              else
                _toggle(CupertinoIcons.pause_fill, holding ? 'Reanudar' : 'En espera', holding,
                    Native.toggleHold),
              _toggle(CupertinoIcons.bluetooth, 'Bluetooth', bluetooth,
                  btAvailable ? () => Native.setBluetooth(!bluetooth) : null),
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

/// Video a pantalla completa mientras entra una llamada.
class RingVideo extends StatefulWidget {
  const RingVideo({super.key, required this.path, required this.sound, this.audioOnly = false});
  final String path;

  /// Solo sonido (tono propio), sin imagen.
  final bool audioOnly;

  /// Si es true, el video suena en lugar del tono (solo con el teléfono en modo sonido).
  final bool sound;

  @override
  State<RingVideo> createState() => _RingVideoState();
}

class _RingVideoState extends State<RingVideo> {
  VideoPlayerController? c;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final ctrl = VideoPlayerController.file(File(widget.path),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      c = ctrl;
      await ctrl.initialize();
      await ctrl.setLooping(true);
      final audible = widget.sound && await Native.ringerNormal();
      await ctrl.setVolume(audible ? 1 : 0);
      if (!mounted) return;
      if (audible) await Native.silenceRinger();
      await ctrl.play();
      if (mounted) setState(() => ready = true);
    } catch (_) {
      // Si el video no se puede reproducir, queda el fondo normal.
    }
  }

  @override
  void dispose() {
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = c;
    if (!ready || ctrl == null || widget.audioOnly) return const SizedBox();
    final size = ctrl.value.size;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(ctrl)),
      ),
    );
  }
}
