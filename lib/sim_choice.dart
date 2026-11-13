import 'package:flutter/cupertino.dart';

import 'common.dart';
import 'native.dart';

/// Preferencia de SIM para llamar: [simAsk] o la clave de una cuenta.
const simPrefKey = 'sim_pref';
const simAsk = 'ask';

enum SimDecisionKind {
  /// Menos de dos cuentas: se llama como siempre, sin elegir SIM.
  direct,

  /// Hay una SIM guardada y sigue disponible.
  useSaved,

  /// Hay que mostrar el selector.
  ask,
}

class SimDecision {
  const SimDecision(this.kind, {this.account = '', this.staleSaved = false});
  final SimDecisionKind kind;
  final String account;

  /// La SIM guardada ya no está (retirada o desactivada).
  final bool staleSaved;
}

/// Decide qué hacer antes de llamar. No depende de la SIM predeterminada de Android:
/// con dos o más cuentas, se pregunta salvo que el usuario haya fijado una en NEXLIA.
SimDecision decideSim(List<SimInfo> sims, String pref) {
  if (sims.length < 2) return const SimDecision(SimDecisionKind.direct);
  if (pref.isEmpty || pref == simAsk) return const SimDecision(SimDecisionKind.ask);
  if (sims.any((s) => s.key == pref)) {
    return SimDecision(SimDecisionKind.useSaved, account: pref);
  }
  return const SimDecision(SimDecisionKind.ask, staleSaved: true);
}

class SimPreference {
  static Future<String> get() async => (await Native.getPref(simPrefKey)) ?? simAsk;
  static Future<void> set(String value) => Native.setPref(simPrefKey, value);
}

class SimPick {
  const SimPick(this.key, {this.remember = false});
  final String key;
  final bool remember;
}

/// Selector previo a la llamada. Devuelve null si se cancela.
Future<SimPick?> showSimPicker(BuildContext context, List<SimInfo> sims,
    {String number = '', bool stale = false}) {
  return showCupertinoModalPopup<SimPick>(
    context: context,
    builder: (ctx) => _SimPickerSheet(sims: sims, number: number, stale: stale),
  );
}

class _SimPickerSheet extends StatefulWidget {
  const _SimPickerSheet({required this.sims, required this.number, required this.stale});
  final List<SimInfo> sims;
  final String number;
  final bool stale;

  @override
  State<_SimPickerSheet> createState() => _SimPickerSheetState();
}

class _SimPickerSheetState extends State<_SimPickerSheet> {
  bool remember = false;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + bottom),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Con qué SIM llamas?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: labelColor(context))),
            if (widget.number.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(widget.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: secondaryColor(context))),
              ),
            if (widget.stale)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('La SIM que tenías guardada ya no está disponible. Elige otra.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: CupertinoColors.systemOrange.resolveFrom(context))),
              ),
            const SizedBox(height: 16),
            for (final s in widget.sims)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context, SimPick(s.key, remember: remember)),
                  child: Container(
                    height: 62,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        color: fillColor(context), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration:
                              BoxDecoration(shape: BoxShape.circle, gradient: brandGradient(context)),
                          child: Text('${s.slot}',
                              style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: labelColor(context))),
                              if (s.number.isNotEmpty)
                                Text(s.number,
                                    style: TextStyle(fontSize: 13, color: secondaryColor(context))),
                            ],
                          ),
                        ),
                        Icon(CupertinoIcons.phone_fill, size: 20, color: accentColor(context)),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Usar siempre esta SIM',
                        style: TextStyle(fontSize: 15, color: labelColor(context))),
                  ),
                  CupertinoSwitch(value: remember, onChanged: (v) => setState(() => remember = v)),
                ],
              ),
            ),
            CupertinoButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Más > SIM para llamar: Preguntar siempre, SIM 1 o SIM 2.
class SimSettingsPage extends StatefulWidget {
  const SimSettingsPage({super.key});

  @override
  State<SimSettingsPage> createState() => _SimSettingsPageState();
}

class _SimSettingsPageState extends State<SimSettingsPage> {
  List<SimInfo> sims = [];
  String pref = simAsk;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await Native.getSimAccounts();
    final p = await SimPreference.get();
    if (!mounted) return;
    setState(() {
      sims = s;
      AppData.i.sims = s;
      pref = p;
      loaded = true;
    });
  }

  Future<void> _choose(String value) async {
    setState(() => pref = value);
    await SimPreference.set(value);
  }

  Widget _option(String title, String subtitle, String value, bool selected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _choose(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: separatorColor(context), width: 0.6))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 17, color: labelColor(context))),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: TextStyle(fontSize: 13, color: secondaryColor(context))),
                ],
              ),
            ),
            if (selected) Icon(CupertinoIcons.checkmark_alt, color: accentColor(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = pref == simAsk || sims.any((s) => s.key == pref);
    return CupertinoPageScaffold(
      backgroundColor: groupedBg(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('SIM para llamar', style: TextStyle(color: labelColor(context))),
        previousPageTitle: 'Más',
        backgroundColor: groupedBg(context),
        border: null,
      ),
      child: SafeArea(
        child: !loaded
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (sims.length < 2)
                    Text(
                        'Este teléfono tiene una sola SIM activa: las llamadas salen por ella '
                        'sin preguntar.',
                        style: TextStyle(fontSize: 15, color: secondaryColor(context)))
                  else ...[
                    Container(
                      decoration: BoxDecoration(
                          color: cardColor(context), borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: [
                          _option('Preguntar siempre', 'Elige la SIM antes de cada llamada', simAsk,
                              pref == simAsk || !valid),
                          for (final s in sims)
                            _option(s.label, s.number.isEmpty ? 'SIM ${s.slot}' : s.number, s.key,
                                pref == s.key),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                        'Se aplica a las llamadas que haces desde NEXLIA. Si la SIM elegida '
                        'deja de estar disponible, NEXLIA vuelve a preguntar.',
                        style: TextStyle(fontSize: 13, color: secondaryColor(context))),
                    if (!valid)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('La SIM que tenías guardada ya no está disponible.',
                            style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.systemOrange.resolveFrom(context))),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}
