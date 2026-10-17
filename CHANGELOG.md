# Reconstructed source history

This history was **reconstructed from supplied script snapshots**, not from preserved Git commits. Published versions are sanitized adaptations, not exact production source copies, and were not re-executed on Windows.

## Core installer v1.1

- Added a named global mutex shared by the `Install-Now` and `AutoUpdate` tasks, with a 15-minute wait and abandoned-mutex handling.
- Moved installation logic into `Invoke-7ZipDeployment`, releasing the mutex in `finally`.
- Added workstation identity in logs and explicit logging of MSI exit `3010` (reboot required, not initiated).
- Fixed official MSI naming: **x64** `7z2604-x64.msi`, **x86** `7z2604.msi` (no `-x86` suffix).
- Uploaded `Install-7Zip.ps1` and `Install-7Zip-v1.1.ps1` were byte-identical.

## Pre-mutex snapshot (backup recorded 2026-10-12 10:37:15)

- Already included architecture selection, product-version check, busy-process deferral, local MSI cache, hash check, silent installation and basic logging.
- Incorrectly expected `-x86.msi` as the x86 installer filename.
- Had no mutex protecting the two scheduled deployment tasks.
- No version label was present in the script; **we do not invent a v1.0 tag for it**.

## RDS guard v1.0 (independent component)

- Enumerates WTS sessions via `wtsapi32.dll`, including disconnected user sessions.
- Defers installation if any user session exists without terminating sessions or rebooting; returns code `0` on deferral.
- Otherwise invokes the centrally versioned installer and propagates its exit code.
- Public adaptation logs **session counts only**, not account identities.

## Manifest evolution (26.04)

- Initial placeholder manifest contained invalid SHA256 values and x86 filename `7z2604-x86.msi`.
- Final manifest used `7z2604.msi` and SHA256 strings of correct length; the binaries were not supplied, so independent hash verification was not possible.
- Public manifest substitutes nonfunctional hash placeholders.

## Evidence limits

- No conclusive fleet-wide compliance, production rollback, or full DFSR verification can be inferred from the sources.
- A one-line `dfsr-test` marker is **not** proof that SYSVOL/DFSR replication was healthy.
- Historical Git release tags have not been reconstructed.
