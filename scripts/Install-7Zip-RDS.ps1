# PUBLIC EDUCATIONAL ADAPTATION - NOT PRODUCTION-READY.
# Original site paths, task names and identifiers have been redacted.
# Replace and review all environment-specific settings before use.
# Privacy adaptation: defer logs include session count, not user identities.
# Example 7-Zip RDS deployment guard v1.0
# Run from a computer GPO scheduled task as NT AUTHORITY\SYSTEM.
# Requires Windows PowerShell 5.1; calls the existing, centrally versioned installer.
# Conservative: if ANY interactive/RDP session exists (including disconnected), defer.
# No sessions are terminated and no automatic reboot is requested.
$ErrorActionPreference = 'Stop'

$Installer = '\\ad.example.com\NETLOGON\Software\7Zip\Scripts\Install-7Zip.ps1'
$LogDir = Join-Path $env:ProgramData 'Example\7Zip'
$LogPath = Join-Path $LogDir 'rds-deploy.log'

# Fail closed when the documentation-only UNC installer path is unchanged.
if ($Installer -match '(?i)ad\.example\.com') {
    throw 'Documentation-only example: replace and audit the installer path before use.'
}

function Write-RdsLog {
    param([Parameter(Mandatory=$true)][string]$Message)
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    Add-Content -LiteralPath $LogPath -Value ('{0} [{1}] {2}' -f (Get-Date -Format s), $env:COMPUTERNAME, $Message)
}

try {
    if (-not ('Example7ZipRds.SessionQuery' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Example7ZipRds {
    public static class SessionQuery {
        private enum WTSInfoClass { WTSInitialProgram=0, WTSApplicationName=1, WTSWorkingDirectory=2,
            WTSOEMId=3, WTSSessionId=4, WTSUserName=5, WTSWinStationName=6, WTSDomainName=7 }

        private enum WTSConnectState { Active, Connected, ConnectQuery, Shadow, Disconnected,
            Idle, Listen, Reset, Down, Init }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct WtsSessionInfo {
            public int SessionId;
            [MarshalAs(UnmanagedType.LPWStr)] public string StationName;
            public WTSConnectState State;
        }

        [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool WTSEnumerateSessions(IntPtr server, int reserved, int version,
            out IntPtr sessions, out int count);

        [DllImport("wtsapi32.dll", SetLastError = true)]
        private static extern void WTSFreeMemory(IntPtr memory);

        [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool WTSQuerySessionInformation(IntPtr server, int sessionId,
            WTSInfoClass infoClass, out IntPtr data, out int bytes);

        private static string GetSessionText(int sessionId, WTSInfoClass infoClass) {
            IntPtr data = IntPtr.Zero;
            int bytes;
            if (!WTSQuerySessionInformation(IntPtr.Zero, sessionId, infoClass, out data, out bytes))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "WTS query failed");
            try { return data == IntPtr.Zero ? "" : (Marshal.PtrToStringUni(data) ?? ""); }
            finally { if (data != IntPtr.Zero) WTSFreeMemory(data); }
        }

        public static string[] GetSignedInUsers() {
            IntPtr sessions = IntPtr.Zero;
            int count = 0;
            if (!WTSEnumerateSessions(IntPtr.Zero, 0, 1, out sessions, out count))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "WTS session enumeration failed");
            try {
                var result = new List<string>();
                int structSize = Marshal.SizeOf(typeof(WtsSessionInfo));
                for (int i = 0; i < count; i++) {
                    IntPtr ptr = new IntPtr(sessions.ToInt64() + ((long)i * structSize));
                    var entry = (WtsSessionInfo)Marshal.PtrToStructure(ptr, typeof(WtsSessionInfo));
                    if (entry.SessionId == 0) continue; // Services/session 0
                    string user = GetSessionText(entry.SessionId, WTSInfoClass.WTSUserName);
                    if (String.IsNullOrWhiteSpace(user)) continue;
                    string domain = GetSessionText(entry.SessionId, WTSInfoClass.WTSDomainName);
                    result.Add(String.Format("{0}\\{1} (session {2}, {3})", domain, user,
                        entry.SessionId, entry.State));
                }
                return result.ToArray();
            }
            finally { if (sessions != IntPtr.Zero) WTSFreeMemory(sessions); }
        }
    }
}
'@ -ErrorAction Stop
    }

    $Users = @([Example7ZipRds.SessionQuery]::GetSignedInUsers())
    if ($Users.Count -gt 0) {
        Write-RdsLog ('DEFER: {0} signed-in user session(s); upgrade not attempted' -f $Users.Count)
        exit 0 # Intentional deferral: no change made; next scheduled attempt will retry.
    }

    if (-not (Test-Path -LiteralPath $Installer -PathType Leaf)) {
        throw "Installer unavailable: $Installer"
    }

    Write-RdsLog 'START: no user sessions; invoking centrally managed 7-Zip installer'
    $Process = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $Installer + '"')) `
        -Wait -PassThru -ErrorAction Stop

    Write-RdsLog "FINISH: installer exit code $($Process.ExitCode)"
    exit [int]$Process.ExitCode
}
catch {
    try { Write-RdsLog "ERROR: $($_.Exception.Message)" }
    catch { Write-Error $_ }
    exit 1
}
