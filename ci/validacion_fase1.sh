#!/usr/bin/env bash
# Fase 1 en emulador (sin SIM real): SMS de solo lectura, accesibilidad y regresión de llamadas.
# Cada línea: PASS | FAIL | N/V (no verificable aquí). Datos de prueba: números 555xxxx del emulador.
set -uo pipefail
PKG=com.nexlia.phone
APK="$1"
FAILS=0
ok() { echo "PASS | $1"; }
ko() { echo "FAIL | $1"; FAILS=$((FAILS + 1)); }
nv() { echo "N/V  | $1"; }
sh() { adb shell "$@" | tr -d '\r'; }
resumed() { sh dumpsys activity activities | grep -E "mResumedActivity|topResumedActivity" | head -1; }
shot() { adb exec-out screencap -p > "capturas/$1.png"; }
dump() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb shell cat /sdcard/ui.xml | tr -d '\r' > ui.xml; }
node() { python3 ci/ui_nodes.py ui.xml "$1" "$2"; }   # node exact|prefix|contains TEXTO
tapnode() { local l; l=$(node "$1" "$2" | head -1); [ -z "$l" ] && return 1; IFS='|' read -r _ _ _ _ cx cy _ <<< "$l"; adb shell input tap "$cx" "$cy"; }
open_app() { adb shell am start -W -n "$PKG/.MainActivity" >/dev/null; sleep 9; }
to_messages() { dump; tapnode exact "Mensajes" || adb shell input tap $((W * 7 / 10)) $((H - H / 28)); sleep 4; dump; }
mkdir -p capturas

API=$(sh getprop ro.build.version.sdk)
echo "== Emulador Android $(sh getprop ro.build.version.release) (API $API)"
read W H < <(sh wm size | tail -1 | sed 's/.*: //; s/x/ /')
SMS_APP=$(sh cmd role get-role-holders android.app.role.SMS 2>/dev/null | grep -v Unknown; sh settings get secure sms_default_application)
echo "App de SMS predeterminada antes: $SMS_APP"
echo "Ranuras SIM (telephony): $(sh getprop gsm.sim.state)"

echo "== 1. Instalación y permisos"
adb install -r "$APK" >/dev/null && ok "instala el APK de la rama" || ko "instalación"
for p in READ_CONTACTS WRITE_CONTACTS READ_CALL_LOG WRITE_CALL_LOG CALL_PHONE READ_PHONE_STATE; do
  adb shell pm grant "$PKG" "android.permission.$p"
done
[ "$API" -ge 33 ] && adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS
adb shell cmd role add-role-holder android.app.role.DIALER "$PKG" 2>/dev/null || adb shell telecom set-default-dialer "$PKG"
sleep 3
holders="$(sh cmd role get-role-holders android.app.role.DIALER 2>/dev/null) $(sh telecom get-default-dialer 2>/dev/null)"
echo "$holders" | grep -q "$PKG" && ok "NEXLIA es el marcador predeterminado" || ko "rol de marcador"
perms=$(sh dumpsys package "$PKG" | grep -E "android.permission.(READ_SMS|SEND_SMS|RECEIVE_SMS)")
echo "$perms" | sed 's/^ */  /'
if echo "$perms" | grep -q "READ_SMS: granted=true.*GRANTED_BY_ROLE"; then
  echo "INFO | Android concede READ_SMS con el rol de marcador (GRANTED_BY_ROLE)"
else
  echo "INFO | READ_SMS no concedido por el rol en esta versión"
fi
echo "$perms" | grep -qE "SEND_SMS|RECEIVE_SMS" && ko "declara SEND_SMS o RECEIVE_SMS" || ok "no declara SEND_SMS ni RECEIVE_SMS"

echo "== 2. SMS de prueba"
adb emu sms send 5550123 "Mensaje de prueba para NEXLIA Fase 1"
for i in $(seq 1 20); do adb emu sms send 55501$((10 + i)) "Prueba de volumen $i" >/dev/null; done
sleep 6
n=$(sh content query --uri content://sms/inbox --projection address 2>&1 | grep -c "address=")
echo "SMS en el proveedor: $n"
[ "$n" -ge 21 ] && ok "21 SMS de prueba en el proveedor" || nv "solo $n SMS confirmados en el proveedor"

echo "== 3. Sin consentimiento en la app"
adb logcat -c
open_app
adb shell pidof "$PKG" >/dev/null && ok "la app arranca" || ko "la app no arranca"
to_messages
shot 1_sin_consentimiento
node contains "Prueba de volumen" | grep -q . && ko "se muestra un SMS sin consentimiento" || ok "sin consentimiento: no se muestra ningún SMS"

echo "== 4. Accesibilidad (árbol de uiautomator)"
btn=$(node exact "Mostrar mis SMS aquí"; node exact "Permitir lectura de SMS")
info=$(node prefix "Ver tus SMS en NEXLIA")
echo "botón: $btn"; echo "texto: $info"
[ "$(echo "$btn" | grep -c .)" = 1 ] && ok "el botón de la tarjeta es un nodo propio con su texto exacto" || ko "botón de la tarjeta no separado"
echo "$btn" | grep -q "|true|" && ok "el botón es pulsable" || ko "el botón no es pulsable"
echo "$info" | grep -q . && ! echo "$info" | grep -qE "Mostrar mis SMS aquí|Permitir lectura de SMS" \
  && ok "el texto de la tarjeta es otro nodo y no incluye la acción" || ko "texto y acción mezclados"
f=$(node exact "Filtro Todos"); echo "filtro: $f"
echo "$f" | grep -q "|true|true|" && ok "filtro 'Todos': pulsable y seleccionado" || nv "estado del filtro no expuesto como esperado: $f"
fs=$(node prefix "Filtro SMS"); echo "filtro SMS: $fs"
echo "$fs" | grep -q "|true|false|" && ok "filtro 'SMS': pulsable y no seleccionado (con su pista)" || nv "filtro SMS"
bs=$(node contains "Buscar en mensajes"); echo "buscador: $bs"
echo "$bs" | grep -q . && ok "buscador con etiqueta" || nv "buscador sin etiqueta en uiautomator"

echo "== 5. El usuario confirma (botón localizado por accesibilidad, sin coordenadas fijas)"
if tapnode exact "Mostrar mis SMS aquí" || tapnode exact "Permitir lectura de SMS"; then
  ok "toque sobre el botón localizado en el árbol de accesibilidad"
else
  ko "no se encontró el botón"
fi
sleep 3
# En versiones sin concesión por rol aparece el diálogo de permiso del sistema: se acepta.
dump
for t in "Allow" "ALLOW" "Permitir" "While using the app"; do tapnode exact "$t" && { echo "diálogo del sistema: $t"; sleep 3; break; }; done
sleep 2; dump
shot 2_sms_visibles
node contains "Prueba de volumen 20" | grep -q . && ok "los SMS de prueba aparecen en la bandeja (el más reciente arriba)" || ko "el SMS no aparece tras confirmar"
row=$(node prefix "5550130, SMS"); echo "fila: $row"
echo "$row" | grep -q "|true|" && ok "la fila SMS es un botón con canal en la etiqueta" || nv "fila SMS no localizada por prefijo"
node contains "SIM no identificada" | grep -q . && echo "INFO | aparece 'SIM no identificada' (el emulador informa varias ranuras)" \
  || ok "una sola ranura: no se muestran etiquetas de SIM"

echo "== 6. Abrir un hilo SMS (solo lectura)"
tapnode prefix "5550130, SMS"; sleep 4; dump
shot 3_hilo_sms
rs=$(node prefix "Responder en la app de SMS"); echo "responder: $rs"
echo "$rs" | grep -q "|true|" && ok "hilo: botón Responder accesible" || ko "hilo: falta el botón Responder"
node prefix "Recibido" | grep -q . && ok "hilo: cada SMS se lee como 'Recibido, ...'" || nv "hilo: etiqueta de mensaje no localizada"
adb shell input keyevent KEYCODE_BACK; sleep 2

echo "== 7. Permiso retirado en Ajustes"
if adb shell pm revoke "$PKG" android.permission.READ_SMS 2>/dev/null; then
  sleep 2
  sh dumpsys package "$PKG" | grep -E "READ_SMS: granted" | head -1 | sed 's/^ */  /'
  open_app; to_messages
  shot 4_permiso_retirado
  node contains "Prueba de volumen" | grep -q . && ko "tras retirar el permiso se siguen mostrando SMS" || ok "tras retirar el permiso no se muestran SMS"
  node contains "Se retiró el permiso de SMS" | grep -q . && ok "la tarjeta explica que se retiró el permiso" || nv "texto de permiso retirado no localizado"
  adb shell pidof "$PKG" >/dev/null && ok "la app sigue estable" || ko "la app se cerró"
else
  nv "pm revoke READ_SMS no permitido en API $API (permiso de rol)"
fi
adb shell pm grant "$PKG" android.permission.READ_SMS 2>/dev/null

echo "== 8. Regresión: llamada entrante"
adb shell input keyevent KEYCODE_HOME; sleep 2
adb emu gsm call 5551234
sleep 8
resumed | grep -q "$PKG" && ok "entrante: se abre la pantalla de llamada de NEXLIA" || ko "entrante: NEXLIA no está al frente"
shot 5_llamada_entrante
adb emu gsm cancel 5551234; sleep 4
adb shell pidof "$PKG" >/dev/null && ok "entrante: la app sigue estable tras colgar" || ko "entrante: la app se cerró"

echo "== 9. Regresión: saliente desde otra app (una SIM)"
adb shell input keyevent KEYCODE_HOME; sleep 2
adb shell am start -a android.intent.action.CALL -d tel:5550001 >/dev/null
sleep 6
resumed | grep -q "$PKG" && ok "saliente: la llamada se muestra en NEXLIA" || ko "saliente: NEXLIA no está al frente"
red=no
for i in $(seq 1 10); do adb emu gsm list 2>&1 | grep -q 5550001 && { red=si; break; }; sleep 2; done
if [ "$red" = si ]; then ok "saliente: llega a la red del emulador"
else nv "saliente: gsm list no la muestra (en API 34 ocurre igual con v1.0.13)"; fi
adb emu gsm cancel 5550001; sleep 5

echo "== 10. Estabilidad"
if adb logcat -d | grep -A12 "FATAL EXCEPTION" | grep -q "$PKG"; then
  adb logcat -d | grep -A20 "FATAL EXCEPTION"; ko "cierre inesperado de NEXLIA"
else ok "sin cierres inesperados de NEXLIA en logcat"; fi
anr=$(adb logcat -d | grep -cE "ANR in $PKG")
[ "$anr" = 0 ] && ok "sin ANR (la lectura de SMS no bloquea la interfaz)" || ko "ANR detectado ($anr)"

for x in "selector de SIM y etiquetas con dos SIM reales" "SIM retirada o desactivada" "fabricantes sin sub_id" "audio y Bluetooth"; do
  nv "$x: requiere teléfono físico"
done

ls -la capturas
tar -C capturas -czf capturas_emulador_$API.tgz .
echo "BEGIN_EMU_$API"; base64 -w 76 capturas_emulador_$API.tgz; echo "END_EMU_$API"
sha256sum capturas_emulador_$API.tgz
echo "== API $API: $FAILS fallos"
exit "$FAILS"
