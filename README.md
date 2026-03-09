# Last Lap Max HR

Connect IQ data field that displays the maximum heart rate zone from your last completed lap.

## Current Version

- `1.0.1` (2026-03-09)

## What It Does

- Tracks the peak heart rate during the current lap
- Converts the maximum HR to a decimal zone value at the lap event (example: `4.7`)
- Displays `--` until the first lap is completed
- Optional `LL Max HRZ` header text with an on-device toggle (default ON)
- Colors the displayed value by Garmin-style HR zone (1 gray, 2 blue, 3 green, 4 orange, 5 red), with a setting to turn this on/off (default ON)
- Resets values when the activity timer is reset

## Project Layout

- `LastLapMaxHRZone/`: Connect IQ app source and resources
- `scripts/Test-ConnectIQDeviceMatrix.ps1`: multi-device compile test runner with pass/fail reports
- `store/`: Store submission drafts (description, release notes, privacy, screenshots checklist)
- `CHANGELOG.md`: Versioned project change history

## Build and Test

### One-Time SDK Setup in VS Code

Inside `LastLapMaxHRZone`, run the task:

- `Configure CIQ SDK + Key (once)`

### Build/Run Tasks

From workspace root, use **Terminal → Run Task**:

- `Device Matrix: Core`
- `Device Matrix: Manifest`
- `Device Matrix: Both`
- `Launch Simulator (Chosen Device)`

### Script Usage

From repo root:

```powershell
.\scripts\Test-ConnectIQDeviceMatrix.ps1 -DeveloperKeyPath .\developer_key.der -Mode Core
```

Reports are written to `LastLapMaxHRZone/bin/device-tests/<timestamp>/`.

## Store Packaging Docs

- Listing copy: `store/STORE_LISTING.md`
- Release notes: `store/RELEASE_NOTES.md`
- Permissions and privacy: `store/PERMISSIONS_AND_PRIVACY.md`
- Screenshot checklist: `store/SCREENSHOTS.md`

## Permission Used

- `UserProfile` (to read HR zone boundaries from device profile)
