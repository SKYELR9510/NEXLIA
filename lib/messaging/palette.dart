import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../common.dart';

// Colores de mensajería con contraste comprobado (WCAG 2.1 AA: 4,5:1 para texto normal).
// El acento lo elige el usuario (Más > Apariencia), así que los fondos sólidos se
// oscurecen si con ese acento el texto blanco no llega a 4,5:1.

double _lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double luminance(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

/// Relación de contraste WCAG entre dos colores opacos.
double contrastRatio(Color a, Color b) {
  final x = luminance(a), y = luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Mezcla [fg] con opacidad [alpha] sobre [bg] (para fondos tintados).
Color over(Color fg, double alpha, Color bg) => Color.lerp(bg, fg.withValues(alpha: 1), alpha)!;

/// Oscurece [bg] hasta que [fg] alcance [min] de contraste.
Color solidFor(Color bg, {Color fg = const Color(0xFFFFFFFF), double min = 4.5}) {
  var c = bg.withValues(alpha: 1);
  for (var i = 0; i < 20 && contrastRatio(fg, c) < min; i++) {
    c = Color.lerp(c, const Color(0xFF000000), 0.08)!;
  }
  return c;
}

const _white = Color(0xFFFFFFFF);

/// Fondo sólido de NEXLIA Chat (burbuja propia, botón Enviar, contador) con texto blanco legible.
Color chatSolid(BuildContext c) => solidFor(accentColor(c));

/// Texto y etiquetas de NEXLIA Chat sobre fondo de pantalla o tinte.
Color chatInk(BuildContext c) => isDark(c) ? const Color(0xFF6FA0FF) : const Color(0xFF0B4FD1);

/// Verde de SMS: sólido (fondos con texto blanco) y tinta (texto sobre tinte).
const smsSolid = Color(0xFF0A7C5C);
Color smsInk(BuildContext c) => isDark(c) ? const Color(0xFF4ADBA8) : const Color(0xFF07694D);

/// Etiqueta PRUEBA.
Color demoInk(BuildContext c) => isDark(c) ? const Color(0xFFFFB35C) : const Color(0xFF9A4A00);
const demoTint = Color(0xFFFF9500);

/// Mensaje no enviado: fondo con texto blanco y color de icono de aviso.
const failedSolid = Color(0xFFC62828);
Color failedInk(BuildContext c) => isDark(c) ? const Color(0xFFFF6B60) : const Color(0xFFD70015);

/// Opacidad del tinte de los avisos: con 0,08 el texto secundario supera 4,5:1 con todos los acentos.
const bannerTint = 0.08;

/// Texto sobre fondos sólidos.
const onSolid = _white;
