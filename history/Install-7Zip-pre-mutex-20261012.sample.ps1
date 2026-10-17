# PUBLIC EDUCATIONAL ADAPTATION - NOT PRODUCTION-READY.
# Original site paths, task names and identifiers have been redacted.
# Replace and review all environment-specific settings before use.
# Run as LocalSystem from a GPO scheduled task. Requires Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
$Source = '\\ad.example.com\NETLOGON\Software\7Zip'
# Fail closed when the documentation-only UNC repository is unchanged.
if ($Source -match '(?i)ad\.example\.com') {
    throw 'Documentation-only example: replace and audit the repository path before use.'
}
$LogDir = Join-Path $env:ProgramData 'Example\7Zip'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Log = Join-Path $LogDir 'deploy.log'
function Write-Log($Message) { Add-Content -LiteralPath $Log -Value "$(Get-Date -Format s) $Message" }
try {
    $manifest = Get-Content -LiteralPath (Join-Path $Source 'manifest.json') -Raw | ConvertFrom-Json
    $target = [version]$manifest.Version
    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    $pkg = $manifest.Packages.$arch
    if (-not $pkg -or $pkg.File -notmatch '^7z[0-9]+-(x64|x86)\.msi$' -or $pkg.File -notlike "*-$arch.msi") { throw 'Invalid package metadata' }
    if ($pkg.SHA256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'Invalid SHA256 in manifest' }
    $paths = @("$env:ProgramFiles\7-Zip\7z.exe")
    if (${env:ProgramFiles(x86)}) { $paths += "${env:ProgramFiles(x86)}\7-Zip\7z.exe" }
    $versions = @($paths | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object { [version](Get-Item -LiteralPath $_).VersionInfo.ProductVersion })
    if ($versions.Count -and ($versions | Sort-Object -Descending | Select-Object -First 1) -ge $target) { Write-Log "Already current: $target"; exit 0 }
    if (Get-Process -Name '7zFM','7zG','7z' -ErrorAction SilentlyContinue) { Write-Log '7-Zip running; defer upgrade'; exit 0 }
    $remote = Join-Path (Join-Path $Source 'Packages') $pkg.File
    $local = Join-Path $LogDir $pkg.File
    Copy-Item -LiteralPath $remote -Destination $local -Force
    $hash = (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash
    if ($hash -ne $pkg.SHA256) { throw 'Package hash mismatch' }
    $proc = Start-Process -FilePath "$env:windir\System32\msiexec.exe" -ArgumentList @('/i',"`"$local`"",'/qn','/norestart','/L*v',"`"$(Join-Path $LogDir 'msi.log')`"") -Wait -PassThru
    Write-Log "MSI exit code: $($proc.ExitCode)"
    if ($proc.ExitCode -notin @(0,3010)) { throw "MSI failed: $($proc.ExitCode)" }
    exit 0
} catch { Write-Log "ERROR: $($_.Exception.Message)"; exit 1 }
