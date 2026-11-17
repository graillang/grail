# Install Grail from an unpacked release tree on Windows.
#
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 [-Prefix DIR] [-AddToPath]
#
# The default prefix is %LOCALAPPDATA%\Grail. -AddToPath updates the per-user
# PATH; without it the script only prints the directory to add.
[CmdletBinding()]
param(
    [string]$Prefix = (Join-Path $env:LOCALAPPDATA 'Grail'),
    [switch]$AddToPath
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$binary = Join-Path $here 'bin\grail.exe'
$runtime = Join-Path $here 'lib\grail\runtime.grl'

if (-not (Test-Path $binary)) { throw "bin\grail.exe not found next to $PSCommandPath" }
if (-not (Test-Path $runtime)) { throw 'lib\grail\runtime.grl not found; unpack the full release archive' }

$binDir = Join-Path $Prefix 'bin'
$libDir = Join-Path $Prefix 'lib\grail\std'
New-Item -ItemType Directory -Force -Path $binDir, $libDir | Out-Null

Copy-Item -Force $binary (Join-Path $binDir 'grail.exe')
Copy-Item -Force $runtime (Join-Path $Prefix 'lib\grail\runtime.grl')
$std = Join-Path $here 'lib\grail\std'
if (Test-Path $std) { Copy-Item -Force (Join-Path $std '*.grl') $libDir }

$docSource = Join-Path $here 'share\doc\grail'
if (Test-Path $docSource) {
    $docTarget = Join-Path $Prefix 'share\doc\grail'
    New-Item -ItemType Directory -Force -Path $docTarget | Out-Null
    Copy-Item -Force (Join-Path $docSource '*') $docTarget
}

# The standard library arrives checked and built in the build store, as rustup ships libstd.
& (Join-Path $binDir 'grail.exe') cache warm
if ($LASTEXITCODE -ne 0) { Write-Host "'grail cache warm' did not finish; the first build will check the standard library instead" }

Write-Host "installed $binDir\grail.exe"
Write-Host "runtime and standard library: $Prefix\lib\grail"
Write-Host 'building programs still needs clang and lld on PATH'

if ($AddToPath) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($userPath -split ';' | Where-Object { $_ })
    if ($entries -notcontains $binDir) {
        [Environment]::SetEnvironmentVariable('Path', (($entries + $binDir) -join ';'), 'User')
        Write-Host "added $binDir to the per-user PATH (open a new terminal)"
    }
} else {
    Write-Host "add $binDir to PATH to run 'grail'"
}
