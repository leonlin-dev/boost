<#
.SYNOPSIS
    Build Boost 1.55.0 minimal required libraries (filesystem + system) with MSVC.
#>
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$m    = Get-Content (Join-Path $PSScriptRoot 'zw.json') -Raw | ConvertFrom-Json

$cacheDir = Join-Path $repo 'dist'
if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Force $cacheDir | Out-Null }
$tarPath = Join-Path $cacheDir $m.asset.filename

# Use local _3rdlib_build cache if present and uncopied
$legacyTar = Join-Path $repo '..\..\_3rdlib_build\boost.tar.gz'
if ((-not (Test-Path $tarPath)) -and (Test-Path $legacyTar)) {
    Copy-Item $legacyTar $tarPath
}

if (-not (Test-Path $tarPath)) {
    Write-Host "Downloading $($m.asset.url)..."
    Invoke-WebRequest -Uri $m.asset.url -OutFile $tarPath
}

# Verify SHA256
$hash = (Get-FileHash $tarPath -Algorithm SHA256).Hash.ToLower()
if ($hash -ne $m.asset.sha256.ToLower()) {
    throw "SHA256 mismatch for $($m.asset.filename): expected $($m.asset.sha256), got $hash"
}

# Unpack
$extractDir = Join-Path $cacheDir 'unpacked'
$boostRoot = Join-Path $extractDir 'boost_1_55_0'
if (-not (Test-Path (Join-Path $boostRoot 'boost\version.hpp'))) {
    Write-Host "Extracting $($m.asset.filename)..."
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    New-Item -ItemType Directory -Force $extractDir | Out-Null
    & tar -xzf $tarPath -C $extractDir
}

# Build directory & MSVC compilation
$objDir = Join-Path $cacheDir 'obj'
$libDir = Join-Path $cacheDir 'lib64-msvc-14.0'
if (Test-Path $objDir) { Remove-Item $objDir -Recurse -Force }
New-Item -ItemType Directory -Force $objDir | Out-Null
if (Test-Path $libDir) { Remove-Item $libDir -Recurse -Force }
New-Item -ItemType Directory -Force $libDir | Out-Null

$cppFiles = @(
    "libs\filesystem\src\codecvt_error_category.cpp",
    "libs\filesystem\src\operations.cpp",
    "libs\filesystem\src\path.cpp",
    "libs\filesystem\src\path_traits.cpp",
    "libs\filesystem\src\portability.cpp",
    "libs\filesystem\src\unique_path.cpp",
    "libs\filesystem\src\utf8_codecvt_facet.cpp",
    "libs\filesystem\src\windows_file_codecvt.cpp",
    "libs\system\src\error_code.cpp"
)

# Resolve vcvars64.bat if cl is not in path
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    $vc = Get-ChildItem "C:\Program Files\Microsoft Visual Studio\18" -Recurse -Filter vcvars64.bat -EA SilentlyContinue | Select -First 1 -Expand FullName
    if (-not $vc) {
        $vc = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft Visual Studio" -Recurse -Filter vcvars64.bat -EA SilentlyContinue | Select -First 1 -Expand FullName
    }
    if (-not $vc) { throw "vcvars64.bat not found" }
    $vcvarsPrefix = "`"$vc`" -vcvars_ver=14.29 >nul &&"
} else {
    $vcvarsPrefix = ""
}

$objDirSlash = $objDir.Replace('\', '/') + '/'
$compileCmds = @()
foreach ($f in $cppFiles) {
    $compileCmds += "cl /nologo /c /W3 /WX- /O2 /MD /EHsc /DBOOST_ALL_NO_LIB /DBOOST_FILESYSTEM_STATIC_LINK /DBOOST_SYSTEM_STATIC_LINK /D_CRT_SECURE_NO_WARNINGS /I. /Fo`"$objDirSlash`" `"$f`""
}
$linkCmd1 = "lib /nologo /out:`"$libDir\libboost_filesystem-vc120-mt-1_55.lib`" `"$objDir\*.obj`""
$linkCmd2 = "copy /y `"$libDir\libboost_filesystem-vc120-mt-1_55.lib`" `"$libDir\libboost_system-vc120-mt-1_55.lib`" >nul"

$fullBatch = "$vcvarsPrefix cd /d `"$boostRoot`" && " + ($compileCmds -join " && ") + " && $linkCmd1 && $linkCmd2"

cmd /c $fullBatch
if ($LASTEXITCODE -ne 0) { throw "Boost build failed with exit code $LASTEXITCODE" }

Write-Host "Boost 1.55.0 filesystem + system built successfully -> $libDir"
