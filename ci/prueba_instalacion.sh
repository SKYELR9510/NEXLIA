#!/usr/bin/env bash
# Instala la release publicada v1.0.13 y luego el APK de pruebas como ACTUALIZACIÓN.
set -euo pipefail
PKG=com.nexlia.phone
info() { adb shell dumpsys package "$PKG" | grep -E "versionCode=|versionName=|firstInstallTime=|lastUpdateTime=" | sed 's/^ *//' | sort -u; }

echo "== Android del emulador: $(adb shell getprop ro.build.version.release) (API $(adb shell getprop ro.build.version.sdk))"
echo "== 1) Instalar v1.0.13 (release publicada)"
adb install v13.apk
info | tee antes.txt

echo "== 2) Instalar el APK de pruebas encima (actualización, sin desinstalar)"
adb install -r "$1" 2>&1 | tee instalar.txt
grep -q "Success" instalar.txt
info | tee despues.txt

grep -q "versionName=1.0.13-pruebas-p0-sim" despues.txt && echo "RESULTADO: ACTUALIZACION_OK"
if [ "$(grep firstInstallTime antes.txt)" = "$(grep firstInstallTime despues.txt)" ]; then
  echo "RESULTADO: MISMA_INSTALACION (se conserva firstInstallTime: fue actualización, no instalación nueva)"
else
  echo "RESULTADO: firstInstallTime cambió"; exit 1
fi

echo "== 3) Arranque"
adb logcat -c
adb shell am start -W -n "$PKG/.MainActivity"
sleep 10
if adb shell pidof "$PKG" >/dev/null; then echo "RESULTADO: ARRANCA_OK"; else echo "RESULTADO: NO_ARRANCA"; exit 1; fi
if adb logcat -d | grep -A8 "FATAL EXCEPTION"; then echo "RESULTADO: CIERRE_INESPERADO"; exit 1; fi
echo "RESULTADO: SIN_CIERRES"
