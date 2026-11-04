param(
    [Parameter(Mandatory=$true)][string]$SdkPath,
    [Parameter(Mandatory=$true)][string]$SigningKey,
    [switch]$Tests
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$compiler = Join-Path $SdkPath 'bin/monkeyc.bat'
if (!(Test-Path -LiteralPath $compiler)) { throw 'No se encuentra monkeyc.bat en el SDK indicado.' }
if (!(Test-Path -LiteralPath $SigningKey)) { throw 'No se encuentra la clave privada indicada.' }
$SigningKey = (Resolve-Path -LiteralPath $SigningKey).Path
Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Path bin -Force | Out-Null
    foreach ($component in @('provider', 'field')) {
        $options = @('-f', "garmin/$component/monkey.jungle", '-d', 'fr970', '-y', $SigningKey, '-o', "bin/atulado-$component-fr970.prg", '-w')
        if ($Tests -and $component -eq 'provider') { $options += '-t' }
        & $compiler @options
        if ($LASTEXITCODE -ne 0) { throw "Error al compilar $component. Comprueba el perfil fr970 en SDK Manager." }
    }
} finally { Pop-Location }
