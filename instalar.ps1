# Crea el proyecto Flutter y copia el codigo del marcador encima.
# Uso: clic derecho > "Ejecutar con PowerShell", o doble clic en instalar.bat
param([string]$Destino = "C:\proyectos\nexlia")

$ErrorActionPreference = "Stop"
$origen = $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "No se encontro Flutter en el PATH." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $Destino | Out-Null
Set-Location $Destino

Write-Host "1/4 Creando proyecto Flutter en $Destino ..."
flutter create --org com.nexlia --project-name phone --platforms android .
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "2/4 Copiando el codigo ..."
Copy-Item "$origen\lib\*" "$Destino\lib" -Recurse -Force
Copy-Item "$origen\android\AndroidManifest.xml" "$Destino\android\app\src\main\AndroidManifest.xml" -Force
$kt = "$Destino\android\app\src\main\kotlin\com\nexlia\phone"
New-Item -ItemType Directory -Force -Path $kt | Out-Null
Copy-Item "$origen\android\kotlin\*.kt" $kt -Force
Copy-Item "$origen\android\res\*" "$Destino\android\app\src\main\res" -Recurse -Force
if (Test-Path "$Destino\test\widget_test.dart") { Remove-Item "$Destino\test\widget_test.dart" }

Write-Host "3/4 Ajustando Android minimo (Android 10) ..."
foreach ($g in @("$Destino\android\app\build.gradle.kts", "$Destino\android\app\build.gradle")) {
    if (Test-Path $g) {
        $t = Get-Content $g -Raw
        $t = $t -replace "flutter\.minSdkVersion", "29"
        [System.IO.File]::WriteAllText($g, $t)
    }
}

Write-Host "4/4 Descargando dependencias ..."
flutter pub get

Write-Host ""
Write-Host "Listo. Conecta el telefono por USB y ejecuta:" -ForegroundColor Green
Write-Host "   cd $Destino"
Write-Host "   flutter run --release"
