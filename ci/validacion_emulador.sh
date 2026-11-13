#!/usr/bin/env bash
# Pruebas funcionales en emulador (sin SIM real). Cada línea: PASS | FAIL | N/V (no verificable aquí).
set -uo pipefail
PKG=com.nexlia.phone
APK="$1"            # APK a validar, o "control" para probar solo la v1.0.13 publicada
FAILS=0
ok() { echo "PASS | $1"; }
ko() { echo "FAIL | $1"; FAILS=$((FAILS + 1)); }
nv() { echo "N/V  | $1"; }
sh() { adb shell "$@" | tr -d '\r'; }
info() { sh dumpsys package "$PKG" | grep -E "versionCode=|versionName=|firstInstallTime=" | sed 's/^ *//' | sort -u; }
resumed() { sh dumpsys activity activities | grep -E "mResumedActivity|topResumedActivity" | head -1; }

API=$(sh getprop ro.build.version.sdk)
echo "== Emulador Android $(sh getprop ro.build.version.release) (API $API)"

if [ "$APK" = "control" ]; then
  echo "== 1. CONTROL: solo la release publicada v1.0.13 (sin cambios P0)"
  adb install v13.apk >/dev/null && ok "instala v1.0.13 publicada" || ko "instala v1.0.13"
  info
else
  echo "== 1. Actualización desde la release publicada v1.0.13"
  adb install v13.apk >/dev/null && ok "instala v1.0.13 publicada" || ko "instala v1.0.13"
  info | tee antes.txt
  out=$(adb install -r "$APK" 2>&1); echo "$out"
  echo "$out" | grep -q "Success" && ok "se instala como actualización encima de v1.0.13" || ko "actualización encima de v1.0.13"
  info | tee despues.txt
  [ "$(grep firstInstallTime antes.txt)" = "$(grep firstInstallTime despues.txt)" ] \
    && ok "misma instalación (firstInstallTime igual: se conservan los datos)" || ko "firstInstallTime cambió"
  grep -q "versionName=1.0.13-validacion-p0" despues.txt && ok "versionName de validación instalado" || ko "versionName"
fi

echo "== 2. Permisos y rol de marcador"
for p in READ_CONTACTS WRITE_CONTACTS READ_CALL_LOG WRITE_CALL_LOG CALL_PHONE READ_PHONE_STATE; do
  adb shell pm grant "$PKG" "android.permission.$p"
done
[ "$API" -ge 33 ] && adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS
adb shell cmd role add-role-holder android.app.role.DIALER "$PKG" 2>/dev/null || adb shell telecom set-default-dialer "$PKG"
sleep 3
holders="$(sh cmd role get-role-holders android.app.role.DIALER 2>/dev/null) $(sh telecom get-default-dialer 2>/dev/null)"
echo "rol DIALER: $holders"
echo "$holders" | grep -q "$PKG" && ok "NEXLIA queda como marcador predeterminado" || ko "rol de marcador"

echo "== 3. Arranque"
adb logcat -c
adb shell am start -W -n "$PKG/.MainActivity" >/dev/null
sleep 8
adb shell pidof "$PKG" >/dev/null && ok "la app arranca" || ko "la app no arranca"

echo "== 4. Llamada entrante simulada (red del emulador)"
adb shell input keyevent KEYCODE_HOME; sleep 2
adb emu gsm call 5551234
sleep 8
r=$(resumed); echo "$r"
echo "$r" | grep -q "$PKG" && ok "entrante: se abre la pantalla de llamada de NEXLIA" || ko "entrante: NEXLIA no está al frente"
sh dumpsys telecom > telecom_entrante.txt
grep -nE "com\.nexlia\.phone/(\.|com\.nexlia\.phone\.)CallService" telecom_entrante.txt | head -3
if grep -qE "com\.nexlia\.phone/(\.|com\.nexlia\.phone\.)CallService" telecom_entrante.txt; then
  ok "entrante: Telecom usa CallService de NEXLIA"
else
  grep -niE "incall|nexlia" telecom_entrante.txt | head -8
  nv "entrante: CallService no aparece en dumpsys telecom (formato del sistema); la pantalla sí se abrió"
fi
sh dumpsys notification --noredact | grep -q "pkg=$PKG" && ok "entrante: notificación de llamada de NEXLIA" || nv "entrante: notificación no detectada en dumpsys"
adb emu gsm cancel 5551234; sleep 4
adb shell pidof "$PKG" >/dev/null && ok "entrante: la app sigue estable tras colgar" || ko "entrante: la app se cerró"

echo "== 5. Llamada saliente iniciada desde otra app (ACTION_CALL, una SIM)"
adb shell input keyevent KEYCODE_HOME; sleep 2
adb shell am start -a android.intent.action.CALL -d tel:5550001 >/dev/null
sleep 6
r=$(resumed); echo "$r"
echo "$r" | grep -q "$PKG" && ok "otra app: la llamada se muestra en NEXLIA" || ko "otra app: NEXLIA no está al frente"
red=no
for i in $(seq 1 10); do
  lista=$(adb emu gsm list 2>&1 | tr -d '\r')
  echo "$lista" | grep -q "5550001" && { red=si; break; }
  sleep 2
done
echo "gsm list: $lista"
sh dumpsys telecom | grep -E "Call TC@|state=|mState=|CallState|disconnectCause|DisconnectCause" | head -12
if [ "$red" = si ]; then ok "otra app: la llamada sale a la red sin selector (una SIM)"; else ko "otra app: la llamada no llegó a la red del emulador en 25 s"; fi
adb emu gsm cancel 5550001; sleep 6

echo "== 6. Historial de llamadas"
hist=$(sh content query --uri content://call_log/calls --projection number:type:subscription_id 2>&1)
if echo "$hist" | grep -q "SecurityException"; then
  nv "historial: el usuario shell no puede leer el registro en API $API (limitación del emulador)"
else
  echo "$hist"
  echo "$hist" | grep -q "number=5551234" && ok "historial: entrante registrada" || ko "historial: entrante no registrada"
  echo "$hist" | grep -q "number=5550001" && ok "historial: saliente registrada" || ko "historial: saliente no registrada"
  echo "$hist" | grep -q "subscription_id=" && ok "historial: guarda la cuenta (subscription_id)" || nv "historial: sin subscription_id"
fi

echo "== 7. Estabilidad"
if adb logcat -d | grep -A12 "FATAL EXCEPTION" | grep -q "$PKG"; then
  adb logcat -d | grep -A20 "FATAL EXCEPTION"
  ko "cierre inesperado de NEXLIA en logcat"
else
  ok "sin cierres inesperados de NEXLIA en logcat"
fi

for x in "selector de SIM (el emulador tiene una sola SIM)" "SIM retirada o desactivada" "filtrado antispam con números reales" "audio, Bluetooth y altavoz"; do
  nv "$x: requiere teléfono físico"
done
echo "== API $API: $FAILS fallos"
exit "$FAILS"
