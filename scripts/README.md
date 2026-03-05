# Device Matrix Test Script

Use `Test-ConnectIQDeviceMatrix.ps1` to compile the data field across a prioritized device set or your full `manifest.xml` target list and generate pass/fail reports.

## What it generates

- `device-compile-report.csv` with one row per device
- `device-compile-report.md` for quick human review
- `logs/<device>.log` with full `monkeyc` output per device

By default, output is written to:

`LastLapMaxHRZone/bin/device-tests/<timestamp>/`

## Quick start

From repo root (`d:\garmin-LL-MHRZone`):

```powershell
.\scripts\Test-ConnectIQDeviceMatrix.ps1 -DeveloperKeyPath .\developer_key.der -Mode Core
```

## VS Code one-click tasks

Use **Terminal → Run Task** and choose:

- `Device Matrix: Core`
- `Device Matrix: Manifest`
- `Device Matrix: Both`
- `Launch Simulator (Chosen Device)`

These tasks read SDK/key from `LastLapMaxHRZone/.vscode/ciq.local.json`.

`Launch Simulator (Chosen Device)` prompts for a device id (default `fr55`), compiles the app for that target, and deploys it to Connect IQ Simulator.

## Common runs

Core matrix (fast regression):

```powershell
.\scripts\Test-ConnectIQDeviceMatrix.ps1 -DeveloperKeyPath .\developer_key.der -Mode Core
```

All devices in `manifest.xml`:

```powershell
.\scripts\Test-ConnectIQDeviceMatrix.ps1 -DeveloperKeyPath .\developer_key.der -Mode Manifest
```

Core + full manifest union:

```powershell
.\scripts\Test-ConnectIQDeviceMatrix.ps1 -DeveloperKeyPath .\developer_key.der -Mode Both
```

Custom output folder:

```powershell
.\scripts\Test-ConnectIQDeviceMatrix.ps1 -DeveloperKeyPath .\developer_key.der -Mode Core -OutputPath .\LastLapMaxHRZone\bin\device-tests\latest
```

Do not fail shell/CI job when some devices fail:

```powershell
.\scripts\Test-ConnectIQDeviceMatrix.ps1 -DeveloperKeyPath .\developer_key.der -Mode Manifest -FailOnError $false
```

## Parameters

- `-ProjectPath`: path to app folder (default: `..\LastLapMaxHRZone` relative to script)
- `-MonkeyCPath`: `monkeyc` executable path or command name (default: `monkeyc`)
- `-DeveloperKeyPath`: signing key path (default: `$env:CIQ_DEVELOPER_KEY`)
- `-Mode`: `Core`, `Manifest`, or `Both`
- `-CoreDevices`: override core matrix device IDs
- `-OutputPath`: report/output folder path
- `-FailOnError`: exit with code `1` if any device fails (default: `true`)
