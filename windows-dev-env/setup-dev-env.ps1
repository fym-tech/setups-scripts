# ============================================================
#  Instala: PowerShell 7 | .NET SDK 10 | Node.js LTS | Git | Claude Code
#  Instala: PowerShell 7 | .NET SDK 10 | Node.js LTS | Git | Claude Code
#  No requiere winget - usa instaladores oficiales directos
#  Requiere: PowerShell 5.1+ ejecutado como Administrador
# ============================================================

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configurar politica de ejecucion permanente para permitir scripts de npm (como claude.ps1)
Write-Host ">> Configurando politica de ejecucion de scripts..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
Write-Host "   [OK] ExecutionPolicy configurada: Bypass (CurrentUser)" -ForegroundColor Green

function Write-Step { param($msg) Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "   [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "   [!!] $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "   [ERROR] $msg" -ForegroundColor Red }

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:PATH    = "$machinePath;$userPath"
}

function Add-ToUserPath {
    param([string]$NewPath)
    $current = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($current -notlike "*$NewPath*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$current;$NewPath", "User")
        Write-Ok "PATH actualizado con: $NewPath"
    } else {
        Write-Warn "Ya estaba en PATH: $NewPath"
    }
}

$TempDir = "$env:TEMP\dev-setup"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# ============================================================
#  1. POWERSHELL 7
#  Descarga el instalador oficial desde GitHub
# ============================================================
Write-Step "Instalando PowerShell 7..."

$pwshOk = $false
try {
    $pwshVer = & pwsh --version 2>$null
    if ($pwshVer -match "^PowerShell 7") { $pwshOk = $true }
} catch {}

if ($pwshOk) {
    Write-Ok "PowerShell 7 ya instalado: $pwshVer"
} else {
    try {
        # URL de descarga directa - formato estable de GitHub releases
        $pwshVersion = "7.5.1"
        $pwshUrl     = "https://github.com/PowerShell/PowerShell/releases/download/v$pwshVersion/PowerShell-$pwshVersion-win-x64.msi"
        $pwshMsi     = "$TempDir\pwsh-installer.msi"

        Write-Host "   Version: $pwshVersion" -ForegroundColor Gray
        Write-Host "   Descargando instalador..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $pwshUrl -OutFile $pwshMsi -UseBasicParsing

        Write-Host "   Ejecutando instalador..." -ForegroundColor Gray
        Start-Process "msiexec.exe" -ArgumentList "/i `"$pwshMsi`" /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1" -Wait
        Remove-Item $pwshMsi -Force

        Refresh-Path
        $pwshPath = "$env:ProgramFiles\PowerShell\7"
        if (Test-Path $pwshPath) { Add-ToUserPath $pwshPath }
        Refresh-Path

        if (Get-Command pwsh -ErrorAction SilentlyContinue) {
            Write-Ok "PowerShell 7 instalado: $(pwsh --version)"
        } else {
            Write-Warn "PowerShell 7 instalado pero requiere nueva terminal para aparecer en PATH."
        }
    } catch {
        Write-Fail "Error al instalar PowerShell 7: $_"
        Write-Warn "Descargalo manualmente en: https://github.com/PowerShell/PowerShell/releases"
    }
}

# ============================================================
#  2. .NET SDK 10
# ============================================================
Write-Step "Instalando .NET SDK 10..."

$dotnetOk = $false
try {
    $sdks = & dotnet --list-sdks 2>$null
    if ($sdks -match "^10\.") { $dotnetOk = $true }
} catch {}

if ($dotnetOk) {
    Write-Ok ".NET SDK 10 ya instalado."
} else {
    try {
        $dotnetInstallScript = "$TempDir\dotnet-install.ps1"
        Write-Host "   Descargando dotnet-install.ps1 (script oficial Microsoft)..." -ForegroundColor Gray
        Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstallScript -UseBasicParsing

        Write-Host "   Instalando .NET SDK canal 10.0..." -ForegroundColor Gray
        & $dotnetInstallScript -Channel 10.0 -InstallDir "$env:ProgramFiles\dotnet"

        Remove-Item $dotnetInstallScript -Force

        Add-ToUserPath "$env:ProgramFiles\dotnet"
        Refresh-Path

        if (Get-Command dotnet -ErrorAction SilentlyContinue) {
            Write-Ok ".NET SDK instalado: $(dotnet --version)"
        } else {
            Write-Warn ".NET instalado en '$env:ProgramFiles\dotnet' pero requiere nueva terminal para aparecer en PATH."
        }
    } catch {
        Write-Fail "Error al instalar .NET SDK 10: $_"
        Write-Warn "Descargalo manualmente en: https://dotnet.microsoft.com/download/dotnet/10.0"
    }
}

# ============================================================
#  3. NODE.JS LTS
# ============================================================
Write-Step "Instalando Node.js LTS..."

if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Ok "Node.js ya instalado: $(node --version)"
} else {
    try {
        Write-Host "   Consultando version LTS actual..." -ForegroundColor Gray
        $nodeApi = Invoke-RestMethod "https://nodejs.org/dist/index.json" -UseBasicParsing
        $lts     = $nodeApi | Where-Object { $_.lts -ne $false } | Select-Object -First 1
        $nodeVer = $lts.version
        $nodeUrl = "https://nodejs.org/dist/$nodeVer/node-$nodeVer-x64.msi"
        $nodeMsi = "$TempDir\node-lts.msi"

        Write-Host "   Version LTS detectada: $nodeVer" -ForegroundColor Gray
        Write-Host "   Descargando instalador..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeMsi -UseBasicParsing

        Write-Host "   Ejecutando instalador..." -ForegroundColor Gray
        Start-Process "msiexec.exe" -ArgumentList "/i `"$nodeMsi`" /quiet /norestart ADDLOCAL=ALL" -Wait
        Remove-Item $nodeMsi -Force

        Refresh-Path
        foreach ($p in @("$env:ProgramFiles\nodejs", "$env:APPDATA\npm")) {
            if (Test-Path $p) { Add-ToUserPath $p }
        }
        Refresh-Path

        if (Get-Command node -ErrorAction SilentlyContinue) {
            Write-Ok "Node.js instalado: $(node --version)"
            Write-Ok "npm: $(npm --version)"
        } else {
            Write-Warn "Node instalado pero requiere nueva terminal para aparecer en PATH."
        }
    } catch {
        Write-Fail "Error al instalar Node.js: $_"
        Write-Warn "Descargalo manualmente en: https://nodejs.org/en/download"
    }
}

# ============================================================
#  4. GIT
# ============================================================
Write-Step "Instalando Git..."

if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Ok "Git ya instalado: $(git --version)"
} else {
    try {
        # URL de descarga directa - formato estable de GitHub releases
        $gitVersion = "2.49.0"
        $gitUrl     = "https://github.com/git-for-windows/git/releases/download/v$gitVersion.windows.1/Git-$gitVersion-64-bit.exe"
        $gitInst    = "$TempDir\git-installer.exe"

        Write-Host "   Version: $gitVersion" -ForegroundColor Gray
        Write-Host "   Descargando instalador..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInst -UseBasicParsing

        Write-Host "   Ejecutando instalador..." -ForegroundColor Gray
        Start-Process -FilePath $gitInst -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /COMPONENTS=icons,ext\reg\shellhere,assoc,assoc_sh" -Wait
        Remove-Item $gitInst -Force

        Refresh-Path
        $gitPath = "$env:ProgramFiles\Git\cmd"
        if (Test-Path $gitPath) { Add-ToUserPath $gitPath }
        Refresh-Path

        if (Get-Command git -ErrorAction SilentlyContinue) {
            Write-Ok "Git instalado: $(git --version)"
        } else {
            Write-Warn "Git instalado pero requiere nueva terminal para aparecer en PATH."
        }
    } catch {
        Write-Fail "Error al instalar Git: $_"
        Write-Warn "Descargalo manualmente en: https://git-scm.com/download/win"
    }
}

# ============================================================
#  5. CLAUDE CODE
#  Instalacion via npm
# ============================================================
Write-Step "Instalando Claude Code..."

if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Ok "Claude Code ya instalado: $(claude --version 2>$null)"
} else {
    try {
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            Write-Fail "npm no esta disponible. Asegurate de que Node.js se instalo correctamente."
        } else {
            Write-Host "   Ejecutando: npm install -g @anthropic-ai/claude-code..." -ForegroundColor Gray
            npm install -g @anthropic-ai/claude-code

            # Asegurar que el bin global de npm este en PATH
            $npmGlobalBin = npm config get prefix
            if (Test-Path $npmGlobalBin) { Add-ToUserPath $npmGlobalBin }
            Refresh-Path

            if (Get-Command claude -ErrorAction SilentlyContinue) {
                Write-Ok "Claude Code instalado: $(claude --version 2>$null)"
            } else {
                Write-Warn "Claude Code instalado pero requiere nueva terminal para aparecer en PATH."
                Write-Warn "Ruta bin de npm: $npmGlobalBin"
            }
        }
    } catch {
        Write-Fail "Error al instalar Claude Code: $_"
    }
}

# ============================================================
#  6. VERIFICACION FINAL
# ============================================================
Write-Step "Verificacion final..."

$tools = @(
    @{ Name = "PowerShell 7"; Cmd = "pwsh";   Args = "--version" },
    @{ Name = "PowerShell 7"; Cmd = "pwsh";   Args = "--version" },
    @{ Name = ".NET SDK";     Cmd = "dotnet"; Args = "--version" },
    @{ Name = "Node.js";      Cmd = "node";   Args = "--version" },
    @{ Name = "npm";          Cmd = "npm";    Args = "--version" },
    @{ Name = "Git";          Cmd = "git";    Args = "--version" },
    @{ Name = "Claude Code";  Cmd = "claude"; Args = "--version" }
)

$allOk = $true
foreach ($t in $tools) {
    if (Get-Command $t.Cmd -ErrorAction SilentlyContinue) {
        $ver = & $t.Cmd $t.Args 2>$null
        Write-Ok "$($t.Name): $ver"
    } else {
        Write-Warn "$($t.Name): no encontrado en PATH"
        $allOk = $false
    }
}

Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($allOk) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Entorno configurado correctamente" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Proximo paso -> autenticar Claude Code:" -ForegroundColor Cyan
    Write-Host "    claude login" -ForegroundColor White
} else {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  Instalacion completada con advertencias." -ForegroundColor Yellow
    Write-Host "  Abre una nueva terminal y ejecuta:" -ForegroundColor Yellow
    Write-Host "    pwsh --version" -ForegroundColor White
    Write-Host "    dotnet --version" -ForegroundColor White
    Write-Host "    node --version" -ForegroundColor White
    Write-Host "    git --version" -ForegroundColor White
    Write-Host "    claude --version" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Yellow
}