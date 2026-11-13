# Prepara NEXLIA para compilar en Windows.
# El repositorio ya es un proyecto Flutter completo: no se genera nada.
# Uso: doble clic en instalar.bat (o clic derecho > "Ejecutar con PowerShell").

$ErrorActionPreference = "Stop"
$version = "3.50.0"
Set-Location $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "No se encontro Flutter en el PATH. Instala Flutter $version." -ForegroundColor Red
    exit 1
}

$actual = (flutter --version --machine | ConvertFrom-Json).frameworkVersion
if ($actual -ne $version) {
    Write-Host "Aviso: tienes Flutter $actual; el proyecto esta fijado en $version." -ForegroundColor Yellow
    Write-Host "Puedes cambiar con:  flutter downgrade $version   o   git -C (flutter sdk path) checkout $version"
}

Write-Host "Descargando dependencias exactas (pubspec.lock) ..."
flutter pub get --enforce-lockfile
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""
Write-Host "Listo. Con el telefono conectado por USB:" -ForegroundColor Green
Write-Host "   flutter run --release"
Write-Host ""
Write-Host "Nota: un APK compilado en la PC se firma con tu clave debug local." -ForegroundColor Yellow
Write-Host "No se instala encima de las versiones publicadas en GitHub (hay que desinstalar antes)."
