# Build a clean, relocatable Release package in dist\DSLRay.
param(
    [string]$BuildDir = 'build',
    [string]$QtRoot = 'C:\Qt\6.11.1\mingw_64',
    [string]$MinGWBin = 'C:\Qt\Tools\mingw1310_64\bin',
    [string]$CMake = 'C:\Qt\Tools\CMake_64\bin\cmake.exe',
    [string]$NinjaBin = 'C:\Qt\Tools\Ninja'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (![IO.Path]::IsPathRooted($BuildDir)) { $BuildDir = Join-Path $projectRoot $BuildDir }
$previousPath = $env:PATH
try {
    $env:PATH = "$MinGWBin;$NinjaBin;$QtRoot\bin;$previousPath"
    & $CMake -S $projectRoot -B $BuildDir -G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_PREFIX_PATH=$QtRoot"
    if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed.' }
    & $CMake --build $BuildDir --target portable --parallel 4
    if ($LASTEXITCODE -ne 0) { throw 'Portable build failed. The previous package was preserved.' }
} finally {
    $env:PATH = $previousPath
}
