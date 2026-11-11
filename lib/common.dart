import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'native.dart';

/// Número que se está escribiendo en el teclado (compartido entre pantallas).
final ValueNotifier<String> dialText = ValueNotifier<String>('');

/// Pestaña activa: 0 Teléfono, 1 Contactos, 2 Recientes, 3 Buzón, 4 Más.
final ValueNotifier<int> homeTab = ValueNotifier<int>(0);

/// Apariencia elegida por el usuario.
class AppTheme {
  /// 0 automático (sigue al teléfono), 1 claro, 2 oscuro.
  static final ValueNotifier<int> mode = ValueNotifier<int>(0);
  static final ValueNotifier<int> accent = ValueNotifier<int>(0);
  static const List<Color> accents = [
    Color(0xFF1466FF),
    Color(0xFF0B3FA8),
    Color(0xFF34436B),
    Color(0xFF7C8DB5),
  ];

  static Future<void> load() async {
    mode.value = int.tryParse(await Native.getPref('theme_mode') ?? '') ?? 0;
    final a = int.tryParse(await Native.getPref('theme_accent') ?? '') ?? 0;
    accent.value = a >= 0 && a < accents.length ? a : 0;
  }

  static void setMode(int m) {
    mode.value = m;
    Native.setPref('theme_mode', '$m');
  }

  static void setAccent(int a) {
    accent.value = a;
    Native.setPref('theme_accent', '$a');
  }
}

/// Espacio que ocupa la barra inferior, incluida la barra de navegación del sistema.
double barSpace(BuildContext c) => 62 + MediaQuery.of(c).padding.bottom;

/// Encabezado y pie pequeños para las secciones agrupadas.
Widget sectionLabel(BuildContext c, String text) => Text(text,
    style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0, color: secondaryColor(c)));

bool isDark(BuildContext c) => CupertinoTheme.brightnessOf(c) == Brightness.dark;
Color accentColor(BuildContext c) => CupertinoTheme.of(c).primaryColor;
Color bgColor(BuildContext c) => isDark(c) ? const Color(0xFF050A16) : const Color(0xFFFFFFFF);
Color groupedBg(BuildContext c) => isDark(c) ? const Color(0xFF050A16) : const Color(0xFFF4F7FC);
Color cardColor(BuildContext c) => isDark(c) ? const Color(0xFF101A2E) : const Color(0xFFFFFFFF);
Color fillColor(BuildContext c) => isDark(c) ? const Color(0xFF16213A) : const Color(0xFFEAF0FA);
Color labelColor(BuildContext c) => isDark(c) ? const Color(0xFFFFFFFF) : const Color(0xFF0B1B3A);
Color secondaryColor(BuildContext c) => isDark(c) ? const Color(0xFF93A0BC) : const Color(0xFF5E6B85);
Color separatorColor(BuildContext c) => isDark(c) ? const Color(0x22FFFFFF) : const Color(0x16000000);

/// Botón tipo píldora para filtros y accesos.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.selected, required this.onTap});
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accentColor(context) : fillColor(context),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFFFFFFFF) : labelColor(context))),
      ),
    );
  }
}

/// Título de pantalla con acción opcional a la derecha.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: labelColor(context))),
          ),
          if (trailing != null) trailing! else const SizedBox(height: 44),
        ],
      ),
    );
  }
}

/// Campo de búsqueda redondeado.
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.placeholder, required this.onChanged});
  final String placeholder;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: CupertinoTextField(
        placeholder: placeholder,
        onChanged: onChanged,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Icon(CupertinoIcons.search, size: 20, color: labelColor(context)),
        ),
        placeholderStyle: TextStyle(color: secondaryColor(context), fontSize: 16),
        style: TextStyle(color: labelColor(context), fontSize: 16),
        decoration:
            BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '#';
  final a = parts.first.characters.first.toUpperCase();
  if (parts.length == 1) return a;
  return a + parts.last.characters.first.toUpperCase();
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatWhen(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '${_two(d.hour)}:${_two(d.minute)}';
  if (diff == 1) return 'Ayer';
  if (diff < 7) {
    const names = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    return names[d.weekday - 1];
  }
  return '${_two(d.day)}/${_two(d.month)}/${d.year % 100}';
}

String formatWhenLong(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final t = '$h:${_two(d.minute)} ${d.hour < 12 ? 'a. m.' : 'p. m.'}';
  if (diff == 0) return 'Hoy, $t';
  if (diff == 1) return 'Ayer, $t';
  if (diff < 7) {
    const names = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${names[d.weekday - 1]}, $t';
  }
  return '${_two(d.day)}/${_two(d.month)}/${d.year % 100}';
}

String formatDuration(int seconds) {
  final m = seconds ~/ 60, s = seconds % 60;
  if (m >= 60) return '${m ~/ 60}:${_two(m % 60)}:${_two(s)}';
  return '${_two(m)}:${_two(s)}';
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 40});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final known = name.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor(context).withOpacity(0.75), accentColor(context)],
        ),
      ),
      child: known
          ? Text(initials(name),
              style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w600))
          : Icon(CupertinoIcons.person_fill, color: CupertinoColors.white, size: size * 0.55),
    );
  }
}

/// Título grande al estilo iOS.
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: labelColor(context))),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Superficie translúcida con desenfoque.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 32});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF000000).withOpacity(dark ? 0.45 : 0.14),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: (dark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF)).withOpacity(0.72),
              border: Border.all(
                  color: const Color(0xFFFFFFFF).withOpacity(dark ? 0.14 : 0.6), width: 0.8),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

Future<void> showMessage(BuildContext context, String title, [String? body]) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        CupertinoDialogAction(
            isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String action) async {
  final r = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action)),
      ],
    ),
  );
  return r ?? false;
}

/// Pide uno o dos textos. Devuelve null si se cancela.
Future<List<String>?> askText(BuildContext context, String title,
    {required List<String> hints, List<String>? initial, List<TextInputType>? types}) async {
  final ctrls = [
    for (var i = 0; i < hints.length; i++)
      TextEditingController(text: initial != null && i < initial.length ? initial[i] : '')
  ];
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < hints.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: CupertinoTextField(
                controller: ctrls[i],
                placeholder: hints[i],
                autofocus: i == 0,
                keyboardType: types != null && i < types.length ? types[i] : TextInputType.text,
              ),
            ),
        ],
      ),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar')),
      ],
    ),
  );
  if (ok != true) return null;
  return ctrls.map((c) => c.text.trim()).toList();
}

Future<void> callNumber(BuildContext context, String number) async {
  if (number.trim().isEmpty) return;
  final ok = await Native.placeCall(number.trim());
  if (!ok && context.mounted) {
    await showMessage(context, 'No se pudo llamar',
        'Revisa que la app tenga permiso de Teléfono y que sea la app de llamadas predeterminada.');
  }
}

/// Acciones comunes sobre un número: bloquear y reportar.
Future<void> blockFlow(BuildContext context, String number) async {
  await Native.blockNumber(number);
  if (context.mounted) await showMessage(context, 'Número bloqueado', number);
}

Future<void> reportFlow(BuildContext context, String number) async {
  final r = await askText(context, 'Reportar como spam',
      hints: ['Etiqueta (ej. ventas, cobranza, estafa)']);
  if (r == null) return;
  await Native.blockNumber(number);
  final sent = await Native.reportSpam(number, r[0]);
  if (context.mounted) {
    await showMessage(
        context,
        'Número bloqueado',
        sent
            ? 'También se envió el reporte a la base en línea.'
            : 'No se envió a la base en línea (sin servidor configurado o sin conexión).');
  }
}
