# Read-only, public 7-Zip / GPO deployment diagnostic helper.
# Local machine only; does not run installs, change GPO, restart services or edit firewall.
# Windows PowerShell 5.1+
[CmdletBinding()]
param(
    [string[]]$TaskNames = @('Example-7Zip-AutoUpdate','Example-7Zip-Install-Now'),
    [string]$LogDirectory = (Join-Path $env:ProgramData 'Example\7Zip')
)
$ErrorActionPreference='Continue'
Write-Host '=== Host ==='
Get-CimInstance Win32_ComputerSystem | Select-Object Name,Domain,PartOfDomain | Format-List
Write-Host '=== Installed 7-Zip ==='
$exe=@("$env:ProgramFiles\7-Zip\7z.exe")
if (${env:ProgramFiles(x86)}) { $exe += "${env:ProgramFiles(x86)}\7-Zip\7z.exe" }
foreach ($p in $exe) {
    if (Test-Path -LiteralPath $p -PathType Leaf) {
        Get-Item -LiteralPath $p | Select-Object FullName,@{N='Version';E={$_.VersionInfo.ProductVersion}} | Format-List
    }
}
Write-Host '=== GPO Scheduled Tasks ==='
foreach ($name in $TaskNames) {
    $task=Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if ($task) {
        $task | Select-Object TaskName,State,@{N='RunAs';E={$_.Principal.UserId}} | Format-Table
        Get-ScheduledTaskInfo -TaskName $name -ErrorAction SilentlyContinue |
            Select-Object LastRunTime,NextRunTime,LastTaskResult | Format-List
    } else { Write-Output "Task not found or inaccessible: $name" }
}
foreach ($name in 'deploy.log','rds-deploy.log') {
    $p=Join-Path $LogDirectory $name
    if (Test-Path -LiteralPath $p -PathType Leaf) {
        Write-Host "=== $name (last 20 lines) ==="
        Get-Content -LiteralPath $p -Tail 20
    }
}
Write-Host 'Completion of this script does not confirm installation or compliance.'
