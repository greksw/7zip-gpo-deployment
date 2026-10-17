# PUBLIC EDUCATIONAL ADAPTATION - NOT PRODUCTION-READY.
# Original site paths, task names and identifiers have been redacted.
# Replace and review all environment-specific settings before use.
# Example 7-Zip deployment v1.1
# Windows PowerShell 5.1, run as NT AUTHORITY\SYSTEM from GPO tasks.
# Both Example-7Zip-Install-Now and Example-7Zip-AutoUpdate must use this same script.
$ErrorActionPreference = 'Stop'

$Source = '\\ad.example.com\NETLOGON\Software\7Zip'
$LogDir = Join-Path $env:ProgramData 'Example\7Zip'
$Log = Join-Path $LogDir 'deploy.log'
$MutexName = 'Global\Example-7Zip-Deploy'
$MutexWaitMinutes = 15

# Fail closed when the documentation-only UNC repository is unchanged.
if ($Source -match '(?i)ad\.example\.com') {
    throw 'Documentation-only example: replace and audit the repository path before use.'
}

function Write-Log {
    param([string]$Message)
    Add-Content -LiteralPath $Log -Value "$(Get-Date -Format s) [$env:COMPUTERNAME] $Message"
}

function Invoke-7ZipDeployment {
    $manifest = Get-Content -LiteralPath (Join-Path $Source 'manifest.json') -Raw | ConvertFrom-Json
    $target = [version]$manifest.Version
    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    $pkg = $manifest.Packages.$arch

    if (-not $pkg) { throw "Missing $arch package in manifest" }

    # Official 7-Zip MSI naming: 7z2604-x64.msi and 7z2604.msi (x86).
    $expectedPattern = if ($arch -eq 'x64') { '^7z[0-9]+-x64\.msi$' } else { '^7z[0-9]+\.msi$' }
    if ($pkg.File -notmatch $expectedPattern) { throw "Invalid $arch package filename: $($pkg.File)" }
    if ($pkg.SHA256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'Invalid SHA256 in manifest' }

    $paths = @("$env:ProgramFiles\7-Zip\7z.exe")
    if (${env:ProgramFiles(x86)}) { $paths += "${env:ProgramFiles(x86)}\7-Zip\7z.exe" }
    $versions = @($paths | Where-Object { Test-Path -LiteralPath $_ } |
        ForEach-Object { [version](Get-Item -LiteralPath $_).VersionInfo.ProductVersion })

    if ($versions.Count -and (($versions | Sort-Object -Descending | Select-Object -First 1) -ge $target)) {
        Write-Log "Already current: $target"
        return 0
    }

    if (Get-Process -Name '7zFM','7zG','7z' -ErrorAction SilentlyContinue) {
        Write-Log '7-Zip running; defer upgrade'
        return 0
    }

    $remote = Join-Path (Join-Path $Source 'Packages') $pkg.File
    $local = Join-Path $LogDir $pkg.File
    Copy-Item -LiteralPath $remote -Destination $local -Force
    $hash = (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash
    if ($hash -ne $pkg.SHA256) { throw 'Package hash mismatch' }

    $msiLog = Join-Path $LogDir 'msi.log'
    $proc = Start-Process -FilePath "$env:windir\System32\msiexec.exe" -ArgumentList @(
        '/i', "`"$local`"", '/qn', '/norestart', '/L*v', "`"$msiLog`""
    ) -Wait -PassThru

    Write-Log "MSI exit code: $($proc.ExitCode)"
    if ($proc.ExitCode -notin @(0,3010)) { throw "MSI failed: $($proc.ExitCode)" }
    if ($proc.ExitCode -eq 3010) { Write-Log 'Reboot required (not initiated)' }
    return 0
}

$mutex = $null
$lockAcquired = $false
$exitCode = 1

try {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    $mutex = New-Object System.Threading.Mutex($false, $MutexName)

    try {
        $lockAcquired = $mutex.WaitOne([TimeSpan]::FromMinutes($MutexWaitMinutes))
    }
    catch [System.Threading.AbandonedMutexException] {
        # A previous process exited without releasing its mutex.
        $lockAcquired = $true
        Write-Log 'WARN: abandoned deployment mutex acquired'
    }

    if (-not $lockAcquired) {
        Write-Log "ERROR: concurrent deployment still running after $MutexWaitMinutes minutes"
    }
    else {
        $exitCode = Invoke-7ZipDeployment
    }
}
catch {
    try { Write-Log "ERROR: $($_.Exception.Message)" }
    catch { Write-Error "7-Zip deployment failed; cannot write log: $($_.Exception.Message)" }
    $exitCode = 1
}
finally {
    if ($lockAcquired -and $null -ne $mutex) {
        $mutex.ReleaseMutex()
    }
    if ($null -ne $mutex) { $mutex.Dispose() }
}

exit $exitCode
