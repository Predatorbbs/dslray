param(
    [Parameter(Mandatory = $true)][string]$AppExe,
    [Parameter(Mandatory = $true)][string]$LauncherExe,
    [Parameter(Mandatory = $true)][string]$DeployTool,
    [Parameter(Mandatory = $true)][string]$CompilerBin,
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$LogDirectory,
    [Parameter(Mandatory = $true)][string]$Configuration
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Configuration -ne 'Release') { throw 'The portable target requires a Release build.' }

$sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path
$distRoot = [IO.Path]::GetFullPath((Join-Path $sourceRoot 'dist'))
New-Item -ItemType Directory -Force -Path $distRoot, $LogDirectory | Out-Null
if ((Get-Item -LiteralPath $distRoot).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'The distribution directory must not be a junction or symbolic link.'
}
function Assert-InDist([string]$Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    if (!$absolute.StartsWith($distRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the distribution directory: $absolute"
    }
    if ((Test-Path -LiteralPath $absolute) -and
        ((Get-Item -LiteralPath $absolute).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Refusing to replace a junction or symbolic link: $absolute"
    }
    return $absolute
}
$output = Assert-InDist (Join-Path $distRoot 'DSLRay')
# A separate stage keeps the previous package usable if deployment/checking fails.
$stage = Assert-InDist (Join-Path $distRoot ('.DSLRay staging-' + [Guid]::NewGuid().ToString('N')))
$bin = Join-Path $stage 'bin'
New-Item -ItemType Directory -Path $bin | Out-Null
Copy-Item -LiteralPath $AppExe -Destination (Join-Path $bin 'appDSLRay.exe')
Copy-Item -LiteralPath $LauncherExe -Destination (Join-Path $stage 'appDSLRay.exe')

$oldPath = $env:PATH
try {
    $env:PATH = "$CompilerBin;$(Split-Path -Parent $DeployTool);$oldPath"
    if (!(Test-Path -LiteralPath $DeployTool -PathType Leaf)) { throw "Missing deploy tool: $DeployTool" }
    $deployArguments = @('--release', '--compiler-runtime', '--qmldir', (Join-Path $sourceRoot 'qml'),
        '--dir', $bin, '--libdir', $bin, '--plugindir', (Join-Path $stage 'plugins'),
        '--qml-deploy-dir', (Join-Path $stage 'qml'), '--translationdir', (Join-Path $stage 'translations'),
        (Join-Path $bin 'appDSLRay.exe'))
    try {
        # Windows PowerShell treats native stderr warnings as errors. Keep them
        # in the log, and determine success from the tool's actual exit code.
        $ErrorActionPreference = 'Continue'
        & $DeployTool @deployArguments *> (Join-Path $LogDirectory 'deploy.log')
        $deployExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
    }
    if ($deployExitCode -ne 0) { throw "windeployqt failed; see $LogDirectory\deploy.log" }
} finally {
    $env:PATH = $oldPath
}
$qtConf = "[Paths]" + [Environment]::NewLine +
    "Prefix=.." + [Environment]::NewLine +
    "Binaries=bin" + [Environment]::NewLine +
    "Libraries=bin" + [Environment]::NewLine +
    "Plugins=plugins" + [Environment]::NewLine +
    "QmlImports=qml" + [Environment]::NewLine +
    "Translations=translations" + [Environment]::NewLine
[IO.File]::WriteAllText((Join-Path $bin 'qt.conf'), $qtConf, [Text.UTF8Encoding]::new($false))

# Prove that the package loads without the developer's Qt installation on PATH.
$environmentNames = @('PATH', 'QT_PLUGIN_PATH', 'QT_QPA_PLATFORM_PLUGIN_PATH', 'QML_IMPORT_PATH',
    'QML2_IMPORT_PATH', 'QTDIR', 'QT_QPA_PLATFORM', 'QT_FORCE_STDERR_LOGGING')
$savedEnvironment = @{}
foreach ($name in $environmentNames) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, $null, 'Process')
}
try {
    $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
    $env:QT_QPA_PLATFORM = 'windows'
    $env:QT_FORCE_STDERR_LOGGING = '1'
    # Own the process handle directly: Start-Process/PassThru can lose ExitCode
    # for short-lived GUI applications on Windows PowerShell 5.1.
    $check = New-Object System.Diagnostics.Process
    $check.StartInfo.FileName = Join-Path $stage 'appDSLRay.exe'
    $check.StartInfo.Arguments = '--check-deployment'
    $check.StartInfo.WorkingDirectory = $env:TEMP
    $check.StartInfo.UseShellExecute = $false
    $check.StartInfo.CreateNoWindow = $true
    $check.StartInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $check.StartInfo.RedirectStandardOutput = $true
    $check.StartInfo.RedirectStandardError = $true
    $null = $check.Start()
    $stdout = $check.StandardOutput.ReadToEndAsync()
    $stderr = $check.StandardError.ReadToEndAsync()
    if (!$check.WaitForExit(30000)) {
        # Stop only the check process and its own staged application child.
        Get-CimInstance Win32_Process -Filter "ParentProcessId = $($check.Id)" |
            Where-Object { $_.ExecutablePath -eq (Join-Path $bin 'appDSLRay.exe') } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
        $check.Kill()
        throw "Deployment check timed out; stage retained at $stage"
    }
    $check.WaitForExit()
    [IO.File]::WriteAllText((Join-Path $LogDirectory 'check.stdout.log'), $stdout.GetAwaiter().GetResult())
    [IO.File]::WriteAllText((Join-Path $LogDirectory 'check.stderr.log'), $stderr.GetAwaiter().GetResult())
    $checkExitCode = $check.ExitCode
    $check.Dispose()
    if ($checkExitCode -ne 0) {
        throw "Deployment check failed ($checkExitCode); see $LogDirectory\check.stderr.log"
    }
} finally {
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
}
$rootFiles = @(Get-ChildItem -LiteralPath $stage -File)
if ($rootFiles.Count -ne 1 -or $rootFiles[0].Name -ne 'appDSLRay.exe') {
    throw "Unexpected files in package root; stage retained at $stage"
}
$backup = $null
$backedUp = New-Object 'System.Collections.Generic.List[string]'
$published = New-Object 'System.Collections.Generic.List[string]'
if (Test-Path -LiteralPath $output) {
    $running = @(Get-Process -Name appDSLRay -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith($output + '\', [StringComparison]::OrdinalIgnoreCase) })
    if ($running.Count) { throw "Close DSLRay from $output and retry; stage retained at $stage" }
    $backup = Assert-InDist (Join-Path $distRoot ('DSLRay-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 6)))
    New-Item -ItemType Directory -Path $backup | Out-Null
} else {
    New-Item -ItemType Directory -Path $output | Out-Null
}
try {
    # Keep the root directory in place: Explorer/terminals can hold it open.
    # Move each complete entry to a backup, then publish the checked stage.
    foreach ($entry in @(Get-ChildItem -LiteralPath $output -Force)) {
        $source = Assert-InDist $entry.FullName
        $destination = Assert-InDist (Join-Path $backup $entry.Name)
        Move-Item -LiteralPath $source -Destination $destination
        $backedUp.Add($entry.Name)
    }
    foreach ($entry in @(Get-ChildItem -LiteralPath $stage -Force)) {
        $source = Assert-InDist $entry.FullName
        $destination = Assert-InDist (Join-Path $output $entry.Name)
        Move-Item -LiteralPath $source -Destination $destination
        $published.Add($entry.Name)
    }
} catch {
    # Put only this run's moved entries back; never delete user content.
    foreach ($name in $published) {
        Move-Item -LiteralPath (Assert-InDist (Join-Path $output $name)) -Destination (Assert-InDist (Join-Path $stage $name))
    }
    foreach ($name in $backedUp) {
        Move-Item -LiteralPath (Assert-InDist (Join-Path $backup $name)) -Destination (Assert-InDist (Join-Path $output $name))
    }
    throw
}
Remove-Item -LiteralPath (Assert-InDist $stage) # Empty after publishing; no recursive removal.
if ($backup) { Write-Host "Previous package preserved: $backup" }
Write-Host "Portable package ready: $output"
Write-Host "Launch: $output\appDSLRay.exe"
Write-Host "Deployment check passed with Qt removed from PATH."
