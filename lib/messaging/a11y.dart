import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../common.dart';

/// Área táctil mínima recomendada (Android: 48 dp; Apple: 44 pt). Se usa 48.
const double minTouch = 48;

/// Control pulsable accesible:
/// - un nodo propio para lectores de pantalla (botón, etiqueta, seleccionado), sin
///   mezclarse con el texto que lo rodea;
/// - enfocable con teclado (Tab) y activable con Intro o Espacio;
/// - borde visible al recibir el foco del teclado;
/// - área táctil mínima de [minTouch].
class Tappable extends StatefulWidget {
  const Tappable({
    super.key,
    required this.onTap,
    required this.label,
    required this.child,
    this.hint,
    this.selected,
    this.inGroup = false,
    this.radius = 14,
    this.minWidth = minTouch,
    this.minHeight = minTouch,
  });

  final VoidCallback? onTap;
  final String label;
  final String? hint;
  final bool? selected;

  /// Opciones excluyentes (filtros): el lector anuncia "1 de 3" según la plataforma.
  final bool inGroup;
  final double radius;
  final double minWidth;
  final double minHeight;
  final Widget child;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool focused = false;

  void _activate() {
    if (widget.onTap == null) return;
    HapticFeedback.selectionClick();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (v) => setState(() => focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          _activate();
          return null;
        }),
      },
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        selected: widget.selected,
        inMutuallyExclusiveGroup: widget.inGroup ? true : null,
        label: widget.label,
        hint: widget.hint,
        onTap: enabled ? _activate : null,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _activate : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: widget.minWidth, minHeight: widget.minHeight),
            child: Container(
              alignment: Alignment.center,
              foregroundDecoration: focused
                  ? BoxDecoration(
                      border: Border.all(color: accentColor(context), width: 2.5),
                      borderRadius: BorderRadius.circular(widget.radius),
                    )
                  : null,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloque informativo: un nodo propio, leído como un solo texto y nunca como botón.
class InfoBlock extends StatelessWidget {
  const InfoBlock({super.key, required this.label, required this.child, this.header = false});
  final String label;
  final bool header;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Semantics(container: true, header: header, label: label, excludeSemantics: true, child: child);
}

/// Botón con texto: un nodo propio, enfocable con teclado, con área mínima y borde de foco.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.filled = true,
    this.hint,
  });

  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final bool filled;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = color ?? accentColor(context);
    final enabled = onPressed != null;
    return Tappable(
      label: text,
      hint: hint,
      radius: 24,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          constraints: const BoxConstraints(minHeight: minTouch),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(color: filled ? c : null, borderRadius: BorderRadius.circular(22)),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: filled ? const Color(0xFFFFFFFF) : c, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
