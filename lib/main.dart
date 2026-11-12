import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'call_screen.dart';
import 'common.dart';
import 'contacts_page.dart';
import 'keypad_page.dart';
import 'more_page.dart';
import 'native.dart';
import 'recents_page.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // La app dibuja también detrás de la barra de navegación del sistema.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await AppTheme.load();
  await CallStyle.load();
  runApp(const PhoneApp());
}

class PhoneApp extends StatelessWidget {
  const PhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppTheme.mode, AppTheme.accent]),
      builder: (context, _) {
        final m = AppTheme.mode.value;
        return CupertinoApp(
          navigatorKey: navKey,
          debugShowCheckedModeBanner: false,
          title: 'NEXLIA',
          theme: CupertinoThemeData(
            brightness: m == 1 ? Brightness.light : (m == 2 ? Brightness.dark : null),
            primaryColor: AppTheme.accents[AppTheme.accent.value],
          ),
          builder: (context, child) {
            final dark = m == 2 ||
                (m == 0 && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: const Color(0x00000000),
                statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
                statusBarBrightness: dark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: const Color(0x00000000),
                systemNavigationBarDividerColor: const Color(0x00000000),
                systemNavigationBarContrastEnforced: false,
                systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
              ),
              child: child!,
            );
          },
          home: const Home(),
        );
      },
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  StreamSubscription<Map<dynamic, dynamic>>? sub;
  bool splash = true;
  Map<dynamic, dynamic> callState = {'state': 'none'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sub = Native.events.listen(onEvent);
    AppData.i.addListener(_changed);
    homeTab.addListener(_changed);
    CallScreen.minimized.addListener(_changed);
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => splash = false);
    });
    init();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> init() async {
    await Native.requestPermissions();
    await AppData.i.reload();
    onEvent(await Native.getCallState());
    final n = await Native.takeDialNumber();
    if (n != null && n.isNotEmpty) onEvent({'type': 'dial', 'number': n});
  }

  void onEvent(Map<dynamic, dynamic> e) {
    if (e['type'] == 'dial') {
      dialText.value = (e['number'] ?? '').toString();
      navKey.currentState?.popUntil((r) => r.isFirst);
      homeTab.value = 0;
      return;
    }
    if (e['type'] == 'shared') {
      final path = (e['path'] ?? '').toString();
      final video = e['kind'] == 'video';
      if (path.isEmpty) return;
      if (video) {
        CallStyle.setRingVideo(path);
      } else {
        CallStyle.setRingTone(path);
      }
      final ctx = navKey.currentContext;
      if (ctx != null) {
        showMessage(ctx, video ? 'Video de llamada guardado' : 'Tono de llamada guardado',
            'Se usará cuando te llamen. Puedes cambiarlo en Más > Pantalla de llamada.');
      }
      return;
    }
    final state = e['state'];
    if (state == null) return;
    if (mounted) setState(() => callState = e);
    if (state != 'none' && state != 'disconnected') {
      if (mounted && splash) setState(() => splash = false);
      CallScreen.show(navKey, e);
    } else {
      CallScreen.minimized.value = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AppData.i.reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppData.i.removeListener(_changed);
    homeTab.removeListener(_changed);
    CallScreen.minimized.removeListener(_changed);
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final tab = homeTab.value;
    return CupertinoPageScaffold(
      backgroundColor: bgColor(context),
      child: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (!AppData.i.isDefault) const _DefaultBanner(),
                  if (CallScreen.minimized.value)
                    GestureDetector(
                      onTap: () => CallScreen.show(navKey, callState, force: true),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            color: const Color(0xFF12B83C), borderRadius: BorderRadius.circular(16)),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.phone_fill, color: Color(0xFFFFFFFF), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text('Llamada en curso · toca para volver',
                                  style: TextStyle(
                                      color: Color(0xFFFFFFFF),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: tab,
                      children: const [
                        KeypadPage(),
                        ContactsPage(),
                        RecentsPage(),
                        VoicemailPage(),
                        MorePage(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(bottom: bottom, top: 6),
              decoration: BoxDecoration(
                color: bgColor(context),
                border: Border(top: BorderSide(color: separatorColor(context), width: 0.6)),
              ),
              child: Row(
                children: [
                  _tabItem(0, CupertinoIcons.phone_fill, 'Teléfono'),
                  _tabItem(1, CupertinoIcons.person_fill, 'Contactos'),
                  _tabItem(2, CupertinoIcons.clock_fill, 'Recientes'),
                  _tabItem(3, CupertinoIcons.recordingtape, 'Buzón'),
                  _tabItem(4, CupertinoIcons.line_horizontal_3, 'Más'),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !splash,
              child: AnimatedOpacity(
                opacity: splash ? 1 : 0,
                duration: const Duration(milliseconds: 350),
                child: const _Splash(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String text) {
    final on = homeTab.value == index;
    final color = on ? accentColor(context) : secondaryColor(context);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          homeTab.value = index;
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2A6E), Color(0xFF030814), Color(0xFF0B3FA8)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/icon.png', width: 150, height: 150),
          const SizedBox(height: 26),
          const Text('NEXLIA',
              style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2)),
          const SizedBox(height: 6),
          const Text('Conecta mejor', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 18)),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _DefaultBanner extends StatelessWidget {
  const _DefaultBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemOrange.resolveFrom(context).withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Para recibir llamadas y bloquear spam, NEXLIA debe ser tu Teléfono predeterminado.',
              style: TextStyle(fontSize: 13, color: labelColor(context)),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            onPressed: () async {
              await Native.requestDefaultDialer();
              await AppData.i.reload();
            },
            child: const Text('Activar', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
