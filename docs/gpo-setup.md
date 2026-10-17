# GPO deployment and verification

1. Stage a pilot OU. Use separate scheduling/guard logic for Remote Desktop Session Hosts (RDS).
2. Publish trusted x64/x86 MSI packages and manifest through a write-protected repository readable by domain computer accounts under SYSTEM.
3. Replace all public demo placeholders, independently verify SHA256 and installer provenance, and validate the effective GPO task principal and UNC permissions.
4. Configure computer-side **Group Policy Preferences → Scheduled Tasks** with `NT AUTHORITY\SYSTEM`. The optional initial installer and daily update task must run **the same** core script and share the mutex.
5. A representative schedule is daily 03:00 with up to 1 hour random delay; configure catch-up and pilot on sleeping/offline hosts. Route RDS hosts through `Install-7Zip-RDS.ps1`.

Example command (NOT executable as published):

```text
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "\\ad.example.com\NETLOGON\Software\7Zip\Scripts\Install-7Zip.ps1"
```

Check client policy and installed product version:

```powershell
gpupdate /target:computer /force
gpresult /scope computer /r
Get-ScheduledTask -TaskName 'Example-7Zip-AutoUpdate' -ErrorAction SilentlyContinue
Get-ScheduledTaskInfo -TaskName 'Example-7Zip-AutoUpdate' -ErrorAction SilentlyContinue
Get-Item "$env:ProgramFiles\7-Zip\7z.exe" -ErrorAction SilentlyContinue |
  Select-Object FullName,@{N='Version';E={$_.VersionInfo.ProductVersion}}
```

Deployment exit `0` can mean **already current**, **busy 7-Zip deferred**, or **RDS user session deferred**. Verify actual installed version, not just Task Scheduler return codes. Exit `3010` is logged but the core script returns `0` and does not reboot; external reboot-compliance tracking is needed. Exit `1618` can occur despite this script's shared mutex if another installer is active.

For SYSVOL, compare the actual script files on each DC using `scripts/Compare-SysvolFiles.ps1`. `repadmin` checks AD replication, not SYSVOL/DFSR file equality. The supplied `dfsr-test` marker was only one timestamped line, not a full DFSR report.
