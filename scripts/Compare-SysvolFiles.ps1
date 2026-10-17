# Compare exact script bytes on two AD domain controllers.
# Read-only; this is NOT a complete DFSR replication-health test.
# Windows PowerShell 5.1+
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string[]]$DomainControllers,
    [string]$RelativePath='NETLOGON\Software\7Zip\Scripts\Install-7Zip.ps1'
)
foreach ($dc in $DomainControllers) {
    $unc='\\'+$dc+'\'+$RelativePath
    try {
        $info=Get-Item -LiteralPath $unc -ErrorAction Stop
        [pscustomobject]@{
            DomainController=$dc
            Length=$info.Length
            SHA256=(Get-FileHash -LiteralPath $unc -Algorithm SHA256 -ErrorAction Stop).Hash
            Accessible=$true
            Error=$null
        }
    } catch {
        [pscustomobject]@{
            DomainController=$dc; Length=$null; SHA256=$null
            Accessible=$false; Error=$_.Exception.Message
        }
    }
}
