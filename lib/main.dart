import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'call_screen.dart';
import 'common.dart';
import 'contacts_page.dart';
import 'keypad_page.dart';
import 'native.dart';
import 'recents_page.dart';
import 'spam_page.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PhoneApp());
}

class PhoneApp extends StatelessWidget {
  const PhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      title: 'Teléfono',
      theme: const CupertinoThemeData(primaryColor: CupertinoColors.systemBlue),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int tab = 3;
  StreamSubscription<Map<dynamic, dynamic>>? sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sub = Native.events.listen(onEvent);
    AppData.i.addListener(_changed);
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
      if (mounted) setState(() => tab = 3);
      return;
    }
    final state = e['state'];
    if (state != null && state != 'none' && state != 'disconnected') {
      CallScreen.show(navKey, e);
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
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
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
                  Expanded(
                    child: IndexedStack(
                      index: tab,
                      children: [
                        const FavoritesPage(),
                        const RecentsPage(),
                        const ContactsPage(),
                        const KeypadPage(),
                        SpamPage(active: tab == 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: bottom + 10,
            child: Glass(
              radius: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    _tabItem(0, CupertinoIcons.star_fill, 'Favoritos'),
                    _tabItem(1, CupertinoIcons.clock_fill, 'Recientes'),
                    _tabItem(2, CupertinoIcons.person_crop_circle_fill, 'Contactos'),
                    _tabItem(3, CupertinoIcons.circle_grid_3x3_fill, 'Teclado'),
                    _tabItem(4, CupertinoIcons.shield_lefthalf_fill, 'Spam'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String text) {
    final on = tab == index;
    final color = on ? CupertinoColors.systemBlue.resolveFrom(context) : secondaryColor(context);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => tab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: on ? fillColor(context) : const Color(0x00000000),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 2),
              Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
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
              'Para recibir llamadas y bloquear spam, esta app debe ser tu Teléfono predeterminado.',
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
