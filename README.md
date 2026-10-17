# 7-Zip GPO Deployment — PowerShell, MSI, SYSVOL and RDS

[Русский](README.ru.md) · [Changelog](CHANGELOG.md) · [GPO guide](docs/gpo-setup.md)

A case study of centrally deploying and updating **7-Zip 26.04** through Group Policy Preferences, Scheduled Tasks running as **NT AUTHORITY\SYSTEM**, PowerShell 5.1 and `msiexec.exe`.

This repository is based on surviving October 2026 deployment scripts. All published scripts are **anonymized adaptations**, not byte-for-byte copies of production files.

**Do not run without review and configuration.** `ad.example.com` is a documentation-only UNC namespace; SHA256 values in `examples/` are deliberately invalid. The PowerShell templates refuse to run while the placeholder domain remains. The anonymized files were not independently executed on Windows.

## Layout

| Path | Purpose |
| --- | --- |
| `scripts/Install-7Zip.ps1` | v1.1 adaptation: version detection, MSI, SHA256, mutex |
| `scripts/Install-7Zip-RDS.ps1` | WTS API guard defers installs while interactive/RDP sessions exist |
| `scripts/7Zip-Diagnostics.ps1` | Read-only inspection of version, tasks and deployment logs |
| `scripts/Compare-SysvolFiles.ps1` | Read-only cross-DC script length and SHA256 comparison |
| `history/` | Pre-mutex baseline, v1.1, RDS v1.0, initial manifest |
| `examples/manifest.example.json` | Final manifest structure, **not real SHA256 values** |
| `docs/` | GPO design, troubleshooting, SYSVOL/DFSR distinctions |

## Design

```text
AD/GPO -> GPP Scheduled Task(s) as LOCAL SYSTEM
         -> One centrally managed script, shared mutex
         -> Manifest/version/architecture and running-process checks
         -> MSI cache and SHA256 validation
         -> msiexec /qn /norestart /L*v

RDS guard -> WTS session enumeration -> defer if any signed-in user session
AD DC1/DC2 -> compare actual NETLOGON script hashes across SYSVOL replicas
```

A scheduled task returning `0` is **not** evidence of successful installation: deferral for busy 7-Zip or RDS sessions also returns `0`. Windows Installer exit code `3010` is logged as reboot required but not automatically performed. The mutex prevents concurrent runs of these deployment scripts, not all Windows Installer workloads; error `1618` remains possible.

The version test checks the highest product version among detected 7-Zip paths; this cannot by itself demonstrate compliance of *each* concurrently installed architecture. A hash stored beside the MSI is not an independent trust anchor if an attacker can replace both. Protect write access to NETLOGON content.

The rollout also revealed divergent script copies on two DCs (2,181 vs 3,693 bytes). **Active Directory replication status from `repadmin` does not demonstrate DFSR/SYSVOL file equality.** Compare actual hashes and inspect DFSR health. The supplied one-line `dfsr-test` marker is not a replication verification report.

## Related notes

- [RU: 7-Zip deployment case](https://notes.shandrov.ru/ru/notes/windows/gpo-software-deployment-7zip-auto-update/)
- [EN: 7-Zip deployment case](https://notes.shandrov.ru/notes/windows/gpo-software-deployment-7zip-auto-update/)

## License

No license has been selected; public availability does not grant unrestricted reuse rights.
