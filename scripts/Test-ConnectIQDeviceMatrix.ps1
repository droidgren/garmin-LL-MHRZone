[CmdletBinding()]
param(
    [string]$ProjectPath = (Join-Path $PSScriptRoot "..\LastLapMaxHRZone"),
    [string]$MonkeyCPath = "monkeyc",
    [string]$DeveloperKeyPath = $env:CIQ_DEVELOPER_KEY,
    [ValidateSet("Core", "Manifest", "Both")]
    [string]$Mode = "Core",
    [string[]]$CoreDevices = @(
        "fr255",
        "fr265",
        "fr965",
        "fenix7pro",
        "epix2pro47mm",
        "venu3",
        "vivoactive5",
        "instinct2",
        "edge840",
        "edge1040"
    ),
    [string]$OutputPath = "",
    [bool]$FailOnError = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-UniqueOrdered {
    param([string[]]$Items)

    $seen = @{}
    $ordered = New-Object System.Collections.Generic.List[string]

    foreach ($item in $Items) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        if (-not $seen.ContainsKey($item)) {
            $seen[$item] = $true
            $ordered.Add($item)
        }
    }

    return $ordered.ToArray()
}

function Get-ManifestDeviceIds {
    param([string]$ManifestPath)

    $matches1 = Select-String -Path $ManifestPath -Pattern '<iq:product id="([^"]+)"' -AllMatches
    $ids = New-Object System.Collections.Generic.List[string]

    foreach ($match in $matches1) {
        foreach ($subMatch in $match.Matches) {
            $ids.Add($subMatch.Groups[1].Value)
        }
    }

    return (Get-UniqueOrdered -Items $ids.ToArray())
}

function Resolve-MonkeyCExecutable {
    param([string]$Candidate)

    if (Test-Path -LiteralPath $Candidate) {
        return (Resolve-Path -LiteralPath $Candidate).Path
    }

    $command = Get-Command $Candidate -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    throw "Unable to find monkeyc compiler. Set -MonkeyCPath to the executable path or add monkeyc to PATH."
}

function Invoke-MonkeyCCompile {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )

    $outputLines = & $Executable @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $outputText = ""

    if ($null -ne $outputLines) {
        $outputText = ($outputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output   = $outputText
    }
}

$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
$manifestPath = Join-Path $projectRoot "manifest.xml"
$junglePath = Join-Path $projectRoot "monkey.jungle"

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

if (-not (Test-Path -LiteralPath $junglePath)) {
    throw "Jungle file not found: $junglePath"
}

$monkeycExecutable = Resolve-MonkeyCExecutable -Candidate $MonkeyCPath

$resolvedDeveloperKeyPath = ""
$useSigning = $false

if (-not [string]::IsNullOrWhiteSpace($DeveloperKeyPath)) {
    if (-not (Test-Path -LiteralPath $DeveloperKeyPath)) {
        throw "Developer key not found: $DeveloperKeyPath"
    }

    $resolvedDeveloperKeyPath = (Resolve-Path -LiteralPath $DeveloperKeyPath).Path
    $useSigning = $true
}
else {
    Write-Warning "No developer key supplied. Compiling without -y signing key."
}

$manifestDevices = Get-ManifestDeviceIds -ManifestPath $manifestPath
$coreDevices = Get-UniqueOrdered -Items $CoreDevices

$missingCore = @($coreDevices | Where-Object { $_ -notin $manifestDevices })
if ($missingCore.Count -gt 0) {
    Write-Warning ("Core devices missing from manifest: " + ($missingCore -join ", "))
}

$targetDevices = @()
$groupByDevice = @{}

switch ($Mode) {
    "Core" {
        $targetDevices = $coreDevices
        foreach ($device in $targetDevices) {
            $groupByDevice[$device] = "Core"
        }
    }
    "Manifest" {
        $targetDevices = $manifestDevices
        foreach ($device in $targetDevices) {
            $groupByDevice[$device] = "Manifest"
        }
    }
    "Both" {
        foreach ($device in $manifestDevices) {
            $groupByDevice[$device] = "Manifest"
        }

        foreach ($device in $coreDevices) {
            if ($groupByDevice.ContainsKey($device)) {
                $groupByDevice[$device] = "Core+Manifest"
            }
            else {
                $groupByDevice[$device] = "Core"
            }
        }

        $targetDevices = Get-UniqueOrdered -Items ($coreDevices + $manifestDevices)
    }
}

if ($targetDevices.Count -eq 0) {
    throw "No target devices resolved for mode '$Mode'."
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $projectRoot ("bin\device-tests\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}

$outputRoot = [System.IO.Path]::GetFullPath($OutputPath)
$logsPath = Join-Path $outputRoot "logs"

$null = New-Item -ItemType Directory -Path $outputRoot -Force
$null = New-Item -ItemType Directory -Path $logsPath -Force

$results = New-Object System.Collections.Generic.List[object]
$total = $targetDevices.Count
$index = 0

Write-Host ("Mode: {0} | Devices: {1}" -f $Mode, $total)
Write-Host ("Project: {0}" -f $projectRoot)
Write-Host ""

foreach ($deviceId in $targetDevices) {
    $index++

    $outputPrgPath = Join-Path $outputRoot ($deviceId + ".prg")
    $arguments = @(
        "-f", $junglePath,
        "-d", $deviceId,
        "-o", $outputPrgPath
    )

    if ($useSigning) {
        $arguments += @("-y", $resolvedDeveloperKeyPath)
    }

    Write-Host ("[{0}/{1}] Compiling {2}" -f $index, $total, $deviceId)

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $compileResult = Invoke-MonkeyCCompile -Executable $monkeycExecutable -Arguments $arguments
    $stopwatch.Stop()

    $status = "PASS"
    $message = "OK"

    if ($compileResult.ExitCode -ne 0) {
        $status = "FAIL"
        $message = "Compile failed"

        $nonEmptyLines = @($compileResult.Output -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 })
        if ($nonEmptyLines.Count -gt 0) {
            $message = $nonEmptyLines[$nonEmptyLines.Count - 1]
        }
    }

    $logPath = Join-Path $logsPath ($deviceId + ".log")
    Set-Content -LiteralPath $logPath -Value $compileResult.Output -Encoding UTF8

    $results.Add([PSCustomObject]@{
            DeviceId   = $deviceId
            Group      = $groupByDevice[$deviceId]
            Status     = $status
            ExitCode   = $compileResult.ExitCode
            DurationMs = [int]$stopwatch.ElapsedMilliseconds
            OutputPrg  = $(if ($status -eq "PASS") { $outputPrgPath } else { "" })
            LogPath    = $logPath
            Message    = $message
        })
}

$csvReportPath = Join-Path $outputRoot "device-compile-report.csv"
$mdReportPath = Join-Path $outputRoot "device-compile-report.md"

$results | Export-Csv -Path $csvReportPath -NoTypeInformation -Encoding UTF8

$passed = @($results | Where-Object { $_.Status -eq "PASS" })
$failed = @($results | Where-Object { $_.Status -eq "FAIL" })

$mdLines = @(
    "# Device Compile Report",
    "",
    "- Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')",
    "- Mode: $Mode",
    "- Project: $projectRoot",
    "- Devices tested: $($results.Count)",
    "- Passed: $($passed.Count)",
    "- Failed: $($failed.Count)",
    "",
    "| Device | Group | Status | ExitCode | DurationMs |",
    "|---|---|---|---:|---:|"
)

foreach ($row in $results) {
    $mdLines += "| $($row.DeviceId) | $($row.Group) | $($row.Status) | $($row.ExitCode) | $($row.DurationMs) |"
}

if ($failed.Count -gt 0) {
    $mdLines += ""
    $mdLines += "## Failure details"
    $mdLines += ""

    foreach ($row in $failed) {
        $mdLines += "- $($row.DeviceId): $($row.Message) (log: $($row.LogPath))"
    }
}

Set-Content -Path $mdReportPath -Value $mdLines -Encoding UTF8

Write-Host ""
Write-Host ("CSV report: {0}" -f $csvReportPath)
Write-Host ("MD report : {0}" -f $mdReportPath)
Write-Host ("Logs dir  : {0}" -f $logsPath)

if (($failed.Count -gt 0) -and $FailOnError) {
    exit 1
}

exit 0
