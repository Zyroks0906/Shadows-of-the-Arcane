<# : actualizar_y_jugar.bat
@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$scriptDir = '%~dp0'; $scriptContent = [System.IO.File]::ReadAllText('%~f0'); Invoke-Expression $scriptContent"
if %errorlevel% neq 0 (
    echo.
    echo Ocurrio un error al actualizar el juego.
    pause
)
exit /b %errorlevel%
#>

# ============================================================
#  SHADOWS OF THE ARCANE - ACTUALIZAR A LA ULTIMA VERSION Y JUGAR
#  Trae los ultimos commits de la rama develop, importa los
#  recursos nuevos y abre el juego. No instala nada: eso ya lo
#  hizo setup_and_play.bat la primera vez.
# ============================================================

$Host.UI.RawUI.WindowTitle = "Shadows of the Arcane - Actualizar y jugar"
$branch = "develop"

Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "      SHADOWS OF THE ARCANE - ACTUALIZAR (rama $branch)      " -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Donde esta el juego: este script puede estar dentro de la carpeta del juego o al lado.
if (-not $scriptDir -or -not (Test-Path $scriptDir)) { $scriptDir = (Get-Location).Path }
$scriptDir = $scriptDir.TrimEnd('\')
if (Test-Path (Join-Path $scriptDir "project.godot")) {
    $projectDir = $scriptDir
} else {
    $projectDir = Join-Path $scriptDir "Shadows-of-the-Arcane"
}
$godotDir = Join-Path (Split-Path -Parent $projectDir) "godot"

# 2. Git y el juego ya los instalo setup_and_play.bat; este script solo actualiza.
$gitCmd = Get-Command "git" -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    foreach ($p in @("C:\Program Files\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe", "C:\Program Files (x86)\Git\cmd\git.exe")) {
        if (Test-Path $p) { $env:PATH += ";$(Split-Path -Parent $p)"; $gitCmd = Get-Command "git" -ErrorAction SilentlyContinue; break }
    }
}
if (-not $gitCmd -or -not (Test-Path (Join-Path $projectDir ".git"))) {
    Write-Host " [ERROR] No encuentro el juego instalado con Git. Ejecuta primero setup_and_play.bat." -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Host "[1/3] Trayendo la ultima version..." -ForegroundColor Cyan
$before = (& git -C $projectDir rev-parse --short HEAD 2>$null)
& git -C $projectDir fetch origin $branch
# Si hay cambios locales (por ejemplo, el editor toco algun archivo), se guardan aparte
# en vez de perderlos: se pueden recuperar con "git stash list".
$dirty = (& git -C $projectDir status --porcelain)
if ($dirty) {
    Write-Host " -> Habia cambios locales: se guardan aparte (git stash) para no perderlos." -ForegroundColor DarkYellow
    & git -C $projectDir stash push -u -m "auto: antes de actualizar $(Get-Date -Format 'yyyy-MM-dd HH:mm')" | Out-Null
}
& git -C $projectDir checkout $branch 2>$null
if ($LASTEXITCODE -ne 0) { & git -C $projectDir checkout -b $branch "origin/$branch" }
# La copia del jugador solo sigue a develop: se pone exactamente igual que la del servidor.
& git -C $projectDir reset --hard "origin/$branch" | Out-Null
$after = (& git -C $projectDir rev-parse --short HEAD)
if ($before -eq $after) {
    Write-Host " -> Ya tenias la ultima version ($after)." -ForegroundColor Green
} else {
    Write-Host " -> Actualizado: $before -> $after. Novedades:" -ForegroundColor Green
    & git -C $projectDir --no-pager log --oneline --no-decorate -n 25 "$before..$after" | ForEach-Object { Write-Host "    * $_" -ForegroundColor Gray }
}

if (-not (Test-Path (Join-Path $projectDir "project.godot"))) {
    Write-Host " [ERROR] La carpeta del juego no esta completa. Ejecuta setup_and_play.bat." -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}

# 3. Godot 4.6.2: el que descargo setup_and_play.bat (aqui no se instala nada).
Write-Host ""
Write-Host "[2/3] Buscando Godot 4.6.2..." -ForegroundColor Cyan
$godotExe = $null
foreach ($cand in @((Join-Path $godotDir "Godot_v4.6.2-stable_win64.exe"), (Join-Path $projectDir "godot\Godot_v4.6.2-stable_win64.exe"),
        (Join-Path $scriptDir "Godot_v4.6.2-stable_win64.exe"), "E:\INSTALLERS\Godot_v4.6.2-stable_win64.exe")) {
    if (Test-Path $cand) { $godotExe = $cand; break }
}
if (-not $godotExe) {
    $sys = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($sys) { $godotExe = $sys.Source }
}
if (-not $godotExe) {
    Write-Host " [ERROR] No encuentro Godot 4.6.2. Ejecuta primero setup_and_play.bat (lo descarga)." -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}
Write-Host " -> $godotExe" -ForegroundColor Green

# 4. Importar los recursos nuevos (texturas, sonidos, shaders) y jugar.
Write-Host ""
Write-Host "[3/3] Importando recursos nuevos (puede tardar un poco la primera vez)..." -ForegroundColor Cyan
Start-Process -FilePath $godotExe -ArgumentList @("--headless", "--path", $projectDir, "--import") -Wait -NoNewWindow
Write-Host " -> Listo. Abriendo el juego..." -ForegroundColor Green
Start-Process -FilePath $godotExe -ArgumentList @("--path", $projectDir)
Start-Sleep -Seconds 2
exit 0
