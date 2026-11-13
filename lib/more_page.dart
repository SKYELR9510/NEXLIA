import 'dart:io';

import 'package:flutter/cupertino.dart';

import 'common.dart';
import 'native.dart';
import 'sim_choice.dart';
import 'spam_page.dart';

void _push(BuildContext context, Widget page) {
  Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute<void>(builder: (_) => page));
}

/// Pestaña "Más": configuración.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppTheme.mode, AppTheme.accent, AppData.i]),
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final modeName = ['Automático', 'Claro', 'Oscuro'][AppTheme.mode.value];
    return ListView(
      padding: EdgeInsets.only(bottom: barSpace(context) + 12),
      children: [
        const ScreenTitle('Configuración'),
        _row(context, CupertinoIcons.paintbrush_fill, const Color(0xFFFF9F0A), 'Apariencia', modeName,
            () => _push(context, const AppearancePage())),
        _row(context, CupertinoIcons.photo_fill, const Color(0xFF0A84FF), 'Pantalla de llamada',
            'Fondo propio y video al recibir llamadas', () => _push(context, const CallStylePage())),
        _row(context, CupertinoIcons.antenna_radiowaves_left_right, const Color(0xFF00B8D9),
            'SIM para llamar', _simSubtitle(), () => _push(context, const SimSettingsPage())),
        _row(context, CupertinoIcons.shield_lefthalf_fill, const Color(0xFF5E5CE6),
            'Bloqueo de llamadas', 'Spam, desconocidos y números bloqueados',
            () => _push(context, const SpamPage())),
        _row(context, CupertinoIcons.speaker_2_fill, const Color(0xFF7D3CFF), 'Sonidos y vibración',
            'Tono de llamada del teléfono', () => Native.openSettings('sound')),
        _row(context, CupertinoIcons.bell_fill, const Color(0xFFFF3B30), 'Notificaciones',
            'Avisos de llamadas de NEXLIA', () => Native.openSettings('notifications')),
        _row(context, CupertinoIcons.antenna_radiowaves_left_right, const Color(0xFF12B886),
            'SIM y redes', 'Ajustes de red del teléfono', () => Native.openSettings('sim')),
        _row(
            context,
            CupertinoIcons.phone_circle_fill,
            const Color(0xFF1466FF),
            'App de teléfono',
            AppData.i.isDefault ? 'NEXLIA es tu Teléfono predeterminado' : 'Toca para activar NEXLIA',
            () async {
          if (AppData.i.isDefault) {
            await Native.openSettings('defaults');
          } else {
            await Native.requestDefaultDialer();
            await AppData.i.reload();
          }
        }),
        _row(context, CupertinoIcons.info_circle_fill, const Color(0xFF5E6B85), 'Acerca de NEXLIA', '',
            () async {
          final v = await Native.getVersion();
          if (context.mounted) {
            await showMessage(context, 'NEXLIA', 'Conecta mejor\nVersión $v');
          }
        }),
      ],
    );
  }

  String _simSubtitle() {
    final sims = AppData.i.sims;
    if (sims.length < 2) return 'Una sola SIM';
    return 'Elige SIM 1, SIM 2 o preguntar siempre';
  }

  Widget _row(BuildContext context, IconData icon, Color color, String title, String subtitle,
      VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 18),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFFFFFFFF), size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 13, 14, 13),
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: separatorColor(context), width: 0.6))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: labelColor(context))),
                          if (subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: secondaryColor(context))),
                            ),
                        ],
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_right, size: 16, color: secondaryColor(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Apariencia: claro, oscuro, automático y color del tema.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppTheme.mode, AppTheme.accent]),
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final mode = AppTheme.mode.value;
    final dark = isDark(context);
    return CupertinoPageScaffold(
      backgroundColor: bgColor(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Apariencia', style: TextStyle(color: labelColor(context))),
        previousPageTitle: 'Más',
        backgroundColor: bgColor(context),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _preview(context, 'Claro', false, !dark, () => AppTheme.setMode(1)),
                const SizedBox(width: 28),
                _preview(context, 'Oscuro', true, dark, () => AppTheme.setMode(2)),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Modo automático',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600, color: labelColor(context))),
                      const SizedBox(height: 2),
                      Text('Sigue el modo claro u oscuro del teléfono',
                          style: TextStyle(fontSize: 13, color: secondaryColor(context))),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: mode == 0,
                  onChanged: (v) => AppTheme.setMode(v ? 0 : (dark ? 2 : 1)),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text('Tema de color',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: labelColor(context))),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < AppTheme.accents.length; i++)
                  GestureDetector(
                    onTap: () => AppTheme.setAccent(i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.accent.value == i
                                ? AppTheme.accents[i]
                                : const Color(0x00000000),
                            width: 2.5),
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accents[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, String name, bool darkTile, bool selected, VoidCallback onTap) {
    final bg = darkTile ? const Color(0xFF050A16) : const Color(0xFFFFFFFF);
    final key = darkTile ? const Color(0xFF16213A) : const Color(0xFFEAF0FA);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 112,
            height: 190,
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: selected ? accentColor(context) : separatorColor(context),
                  width: selected ? 3 : 1.5),
            ),
            child: Column(
              children: [
                Container(
                    height: 12,
                    decoration: BoxDecoration(color: key, borderRadius: BorderRadius.circular(6))),
                const Spacer(),
                for (var r = 0; r < 4; r++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var c = 0; c < 3; c++)
                          Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: key)),
                      ],
                    ),
                  ),
                Container(
                    width: 20,
                    height: 20,
                    decoration:
                        const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1FC24A))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(name,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: labelColor(context))),
          const SizedBox(height: 6),
          Icon(selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              size: 24, color: selected ? accentColor(context) : secondaryColor(context)),
        ],
      ),
    );
  }
}

/// Pestaña "Buzón": llama al buzón de voz del operador.
class VoicemailPage extends StatelessWidget {
  const VoicemailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: barSpace(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenTitle('Buzón de voz'),
          const Spacer(),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accentColor(context).withOpacity(0.75), accentColor(context)],
                ),
                boxShadow: [
                  BoxShadow(
                      color: accentColor(context).withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: const Icon(CupertinoIcons.recordingtape, color: Color(0xFFFFFFFF), size: 60),
            ),
          ),
          const SizedBox(height: 26),
          Text('Tus mensajes de voz',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: labelColor(context))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text('Llama al buzón de tu operador para escuchar tus mensajes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: secondaryColor(context))),
          ),
          const SizedBox(height: 26),
          Center(
            child: CupertinoButton(
              color: accentColor(context),
              borderRadius: BorderRadius.circular(26),
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
              onPressed: () async {
                final ok = await Native.callVoicemail();
                if (!ok && context.mounted) {
                  await showMessage(context, 'No se pudo llamar al buzón',
                      'Revisa que tu línea tenga buzón de voz configurado.');
                }
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.phone_fill, color: Color(0xFFFFFFFF), size: 20),
                  SizedBox(width: 10),
                  Text('Llamar al buzón',
                      style: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

/// Fondo de la pantalla de llamada y video para llamadas entrantes.
class CallStylePage extends StatelessWidget {
  const CallStylePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          Listenable.merge(
              [CallStyle.background, CallStyle.ringVideo, CallStyle.ringSound, CallStyle.ringTone]),
      builder: (context, _) => _content(context),
    );
  }

  Widget _button(BuildContext context, String text, VoidCallback onTap, {bool danger = false}) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: danger ? const Color(0x22FF3B30) : fillColor(context),
      borderRadius: BorderRadius.circular(22),
      onPressed: onTap,
      child: Text(text,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: danger ? const Color(0xFFFF3B30) : labelColor(context))),
    );
  }

  Widget _content(BuildContext context) {
    final bg = CallStyle.background.value;
    final video = CallStyle.ringVideo.value;
    final tone = CallStyle.ringTone.value;
    final title = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: labelColor(context));
    final note = TextStyle(fontSize: 13, color: secondaryColor(context));
    return CupertinoPageScaffold(
      backgroundColor: bgColor(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Pantalla de llamada', style: TextStyle(color: labelColor(context))),
        previousPageTitle: 'Más',
        backgroundColor: bgColor(context),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Fondo de la llamada', style: title),
            const SizedBox(height: 4),
            Text('Imagen que se ve detrás durante todas las llamadas.', style: note),
            const SizedBox(height: 14),
            Center(
              child: Container(
                width: 130,
                height: 230,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: separatorColor(context), width: 1.5),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0A2A6E), Color(0xFF040A18), Color(0xFF0B2F7A)],
                  ),
                ),
                child: bg.isEmpty
                    ? const Center(
                        child: Text('Fondo NEXLIA',
                            style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)))
                    : Image.file(File(bg),
                        fit: BoxFit.cover, errorBuilder: (context, _, __) => const SizedBox()),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _button(context, 'Elegir imagen', () async {
                  final p = await Native.pickMedia('image');
                  if (p != null && p.isNotEmpty) CallStyle.setBackground(p);
                }),
                if (bg.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  _button(context, 'Quitar', () {
                    CallStyle.setBackground('');
                    Native.removeMedia('image');
                  }, danger: true),
                ],
              ],
            ),
            const SizedBox(height: 34),
            Text('Video al recibir llamadas', style: title),
            const SizedBox(height: 4),
            Text('Se reproduce a pantalla completa mientras el teléfono suena.', style: note),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration:
                  BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(video.isEmpty ? CupertinoIcons.film : CupertinoIcons.film_fill,
                      color: video.isEmpty ? secondaryColor(context) : accentColor(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(video.isEmpty ? 'Sin video' : 'Video elegido',
                        style: TextStyle(fontSize: 16, color: labelColor(context))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _button(context, 'Elegir video', () async {
                  final p = await Native.pickMedia('video');
                  if (p != null && p.isNotEmpty) CallStyle.setRingVideo(p);
                }),
                if (video.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  _button(context, 'Quitar', () {
                    CallStyle.setRingVideo('');
                    Native.removeMedia('video');
                  }, danger: true),
                ],
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Usar el sonido del video',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600, color: labelColor(context))),
                      const SizedBox(height: 2),
                      Text('Suena la música del video en lugar del tono de llamada.', style: note),
                    ],
                  ),
                ),
                CupertinoSwitch(value: CallStyle.ringSound.value, onChanged: CallStyle.setRingSound),
              ],
            ),
            const SizedBox(height: 34),
            Text('Tono de llamada propio', style: title),
            const SizedBox(height: 4),
            Text('Una canción o audio guardado en el teléfono. Si eliges uno, suena en lugar del '
                'tono del teléfono y del sonido del video.', style: note),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration:
                  BoxDecoration(color: fillColor(context), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(CupertinoIcons.music_note_2,
                      color: tone.isEmpty ? secondaryColor(context) : accentColor(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(tone.isEmpty ? 'Tono del teléfono' : 'Tono propio elegido',
                        style: TextStyle(fontSize: 16, color: labelColor(context))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _button(context, 'Elegir audio', () async {
                  final p = await Native.pickMedia('audio');
                  if (p != null && p.isNotEmpty) CallStyle.setRingTone(p);
                }),
                if (tone.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  _button(context, 'Quitar', () {
                    CallStyle.setRingTone('');
                    Native.removeMedia('audio');
                  }, danger: true),
                ],
              ],
            ),
            const SizedBox(height: 22),
            Text(
                'También puedes enviar un video o un audio desde otra app: Compartir > NEXLIA.\n\n'
                'El volumen de la música es el de multimedia, no el del timbre. '
                'Con el teléfono en silencio o vibración no suena.',
                style: note),
          ],
        ),
      ),
    );
  }
}
