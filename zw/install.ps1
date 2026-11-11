<#
.SYNOPSIS
    Install Boost 1.55.0 into ZW_3rdLibs_VC14 layout.
#>
param(
    [Parameter(Mandatory = $true)][string]$ZwRoot
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$m    = Get-Content (Join-Path $PSScriptRoot 'zw.json') -Raw | ConvertFrom-Json
$dest = Join-Path $ZwRoot $m.install.zw_dir

$libDir = Join-Path $repo 'dist\lib64-msvc-14.0'
if (-not (Test-Path (Join-Path $libDir 'libboost_filesystem-vc120-mt-1_55.lib'))) {
    & (Join-Path $PSScriptRoot 'build.ps1')
}

if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Force $dest | Out-Null }

foreach ($c in $m.install.copy) {
    $src = Join-Path $repo $c.from
    $dst = Join-Path $dest $c.to
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
    Copy-Item $src $dst -Recurse -Force
}

Write-Host "installed $($m.name) $($m.version) -> $dest"
