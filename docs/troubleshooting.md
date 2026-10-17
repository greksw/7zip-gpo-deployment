# 7-Zip deployment troubleshooting

| Symptom | Check |
| --- | --- |
| Task missing | Computer OU link, Security Filtering, `gpresult /scope computer /r`, computer policy refresh |
| `LastTaskResult = 267011` | Task has not run; not an MSI return code |
| Task result 0, outdated binary | `7-Zip running; defer upgrade` log path, installed version, MSI log |
| SHA256 mismatch | Manifest integrity, actual MSI hash, repository write permissions |
| MSI `1618` | Another Windows Installer instance, beyond this script's mutex |
| MSI `3010` | Reboot required; script does not automatically reboot |
| Different DCs yield different results | Compare SYSVOL script contents and SHA256 on each DC; check DFSR separately |

`repadmin /replsummary` measures AD replication; it is not proof of SYSVOL/DFSR **file** convergence. Compare the actual package/manifests/script hashes on both DCs rather than relying on directory replication status alone.
