# ==========================================
# ADVANCED REVIT SERVER MONITOR
# ==========================================
# Features:
# - Revit Server config scan
# - maxBytesPerRead detection
# - Error analysis
# - Revit Server model inventory
# - Largest models
# - Last sync detection
# - Last error detection
# - HTML dashboard report
# - Service health
# ==========================================

## Быстрый запуск

Запустите PowerShell от имени администратора и выполните:

```powershell
irm https://raw.githubusercontent.com/Viend1211/RevitServerMonitor/main/RevitServerMonitor.ps1 | iex
```

---





[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

chcp 65001 > $null

Clear-Host

# ==========================================
# CONFIG
# ==========================================

$ReportFolder = "$PSScriptRoot\Reports"

if (!(Test-Path $ReportFolder)) {

    New-Item -ItemType Directory -Path $ReportFolder | Out-Null
}

$ReportFile = Join-Path $ReportFolder ("RevitServer_Report_" + (Get-Date -Format "yyyy-MM-dd_HH-mm") + ".html")

# ==========================================
# LOG PATHS
# ==========================================

$LogPaths = @(
    "C:\ProgramData\Autodesk\Revit Server",
    "C:\inetpub\logs\LogFiles"
)

# ==========================================
# ERROR PATTERNS
# ==========================================

$ErrorPatterns = @(
    "ERROR",
    "FAILED",
    "EXCEPTION",
    "CRITICAL",
    "TIMEOUT",
    "500",
    "503"
)

# ==========================================
# REVIT SERVER CONFIG SCAN
# ==========================================

Write-Host ""
Write-Host "Checking Revit Server configs..." -ForegroundColor Cyan
Write-Host ""

$ConfigResults = @()

$RevitServers = Get-ChildItem "C:\Program Files\Autodesk" -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -like "Revit Server*"
}

foreach ($Server in $RevitServers) {

    $ConfigFiles = @(
        (Join-Path $Server.FullName "Services\ModelService\web.config"),
        (Join-Path $Server.FullName "Services\LocalService\web.config")
    )

    foreach ($Cfg in $ConfigFiles) {

        if (Test-Path $Cfg) {

            try {

                $Content = Get-Content $Cfg -Raw

                $Match = [regex]::Match($Content,'maxBytesPerRead="(\d+)"')

                $Value = "NOT FOUND"

                if ($Match.Success) {

                    $Value = $Match.Groups[1].Value
                }

                $ConfigResults += [PSCustomObject]@{

                    Version = $Server.Name
                    Config  = $Cfg
                    Value   = $Value
                }

            } catch {}
        }
    }
}

# ==========================================
# LOG ANALYSIS
# ==========================================

Write-Host ""
Write-Host "Scanning logs..." -ForegroundColor Cyan
Write-Host ""

$Results = @()
$SyncResults = @()

foreach ($Path in $LogPaths) {

    if (Test-Path $Path) {

        Write-Host "Checking: $Path" -ForegroundColor Yellow

        $Files = Get-ChildItem $Path -Recurse -Include *.log,*.txt -File -ErrorAction SilentlyContinue

        foreach ($File in $Files) {

            try {

                $Lines = Get-Content $File.FullName -ErrorAction SilentlyContinue

                foreach ($Line in $Lines) {

                    # ERROR SEARCH
                    foreach ($Pattern in $ErrorPatterns) {

                        if ($Line -match $Pattern) {

                            $Results += [PSCustomObject]@{

                                File    = $File.FullName
                                Message = $Line
                            }

                            break
                        }
                    }

                    # SYNC SEARCH
                    if ($Line -match "sync|synchronize|saved|reload latest") {

                        $SyncResults += [PSCustomObject]@{

                            File    = $File.FullName
                            Message = $Line
                        }
                    }
                }

            } catch {}
        }
    }
}

# ==========================================
# MODEL ANALYSIS
# ==========================================

Write-Host ""
Write-Host "Scanning Revit Server projects..." -ForegroundColor Cyan
Write-Host ""

$ModelResults = @()

# Auto-detect Revit Server project folders
$ProjectPaths = @()

$RevitServersData = Get-ChildItem "C:\ProgramData\Autodesk" -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -like "Revit Server*"
}

foreach ($Srv in $RevitServersData) {

    $Proj = Join-Path $Srv.FullName "Projects"

    if (Test-Path $Proj) {

        $ProjectPaths += $Proj
    }
}

foreach ($Path in $ProjectPaths) {

    Write-Host "Checking: $Path" -ForegroundColor Yellow

    try {

        $Models = Get-ChildItem $Path -Recurse -Include *.rvt -File -ErrorAction SilentlyContinue

        foreach ($Model in $Models) {

            $SizeGB = [math]::Round(($Model.Length / 1GB),3)

            # LAST SYNC
            $LastSync = "NOT FOUND"

            foreach ($Sync in $SyncResults) {

                if ($Sync.Message -match [regex]::Escape($Model.Name)) {

                    $LastSync = $Sync.Message
                    break
                }
            }

            # LAST ERROR
            $LastError = "NONE"

            foreach ($Err in $Results) {

                if ($Err.Message -match [regex]::Escape($Model.Name)) {

                    $LastError = $Err.Message
                    break
                }
            }

            $ModelResults += [PSCustomObject]@{

                Model        = $Model.Name
                SizeGB       = $SizeGB
                LastModified = $Model.LastWriteTime
                Path         = $Model.FullName
                LastSync     = $LastSync
                LastError    = $LastError
            }
        }

    } catch {

        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

$LargestModels = $ModelResults | Sort-Object SizeGB -Descending

# ==========================================
# SERVICES
# ==========================================

Write-Host ""
Write-Host "Checking services..." -ForegroundColor Cyan
Write-Host ""

$ServiceResults = @()

$Services = Get-Service | Where-Object {

    $_.DisplayName -like "*Revit Server*" -or
    $_.Name -like "*RevitServer*"
}

foreach ($svc in $Services) {

    if ($svc.Status -ne "Running") {

        [console]::beep(1000,700)
    }

    $ServiceResults += [PSCustomObject]@{

        Service = $svc.DisplayName
        Status  = $svc.Status
    }
}

# ==========================================
# SUMMARY
# ==========================================

$ErrorCount = $Results.Count

$CriticalCount = ($Results | Where-Object {
    $_.Message -match "CRITICAL"
}).Count

$FailedCount = ($Results | Where-Object {
    $_.Message -match "FAILED"
}).Count

# ==========================================
# HTML REPORT
# ==========================================

Write-Host ""
Write-Host "Generating report..." -ForegroundColor Cyan
Write-Host ""

$Html = @"

<html>

<head>

<title>Revit Server Report</title>

<style>

body {
    font-family: Arial;
    background: #f4f4f4;
    margin: 20px;
}

h1,h2 {
    color: #333;
}

table {
    border-collapse: collapse;
    width: 100%;
    background: white;
    margin-bottom: 20px;
}

th {
    background: #444;
    color: white;
    padding: 10px;
}

td {
    border: 1px solid #ccc;
    padding: 8px;
    vertical-align: top;
}

tr:nth-child(even) {
    background: #f0f0f0;
}

.ok {
    color: green;
    font-weight: bold;
}

.alert {
    color: red;
    font-weight: bold;
}

</style>

</head>

<body>

<h1>Advanced Revit Server Monitoring Report</h1>

<p><b>Generated:</b> $(Get-Date)</p>

<h2>Revit Server Configuration</h2>

<table>

<tr>
<th>Version</th>
<th>Config</th>
<th>maxBytesPerRead</th>
</tr>

"@

foreach ($c in $ConfigResults) {

$Html += @"

<tr>
<td>$($c.Version)</td>
<td>$($c.Config)</td>
<td>$($c.Value)</td>
</tr>

"@
}

$Html += @"

</table>

<h2>Service Status</h2>

<table>

<tr>
<th>Service</th>
<th>Status</th>
</tr>

"@

foreach ($s in $ServiceResults) {

$Class = "ok"

if ($s.Status -ne "Running") {

    $Class = "alert"
}

$Html += @"

<tr>
<td>$($s.Service)</td>
<td class='$Class'>$($s.Status)</td>
</tr>

"@
}

$Html += @"

</table>

<h2>Error Summary</h2>

<table>

<tr>
<th>Metric</th>
<th>Count</th>
</tr>

<tr>
<td>Total Errors</td>
<td>$ErrorCount</td>
</tr>

<tr>
<td>Critical Errors</td>
<td>$CriticalCount</td>
</tr>

<tr>
<td>Failed Events</td>
<td>$FailedCount</td>
</tr>

</table>

<h2>Error Entries</h2>

<table>

<tr>
<th>Log File</th>
<th>Error Message</th>
</tr>

"@

foreach ($r in ($Results | Select-Object -First 500)) {

$SafeMessage = $r.Message -replace '<','&lt;' -replace '>','&gt;'

$Html += @"

<tr>
<td>$($r.File)</td>
<td>$SafeMessage</td>
</tr>

"@
}

$Html += @"

</table>

<h2>Models on Server</h2>

<table>

<tr>
<th>Model</th>
<th>Size (GB)</th>
<th>Last Modified</th>
<th>Last Sync</th>
<th>Last Error</th>
<th>Path</th>
</tr>

"@

foreach ($m in $LargestModels) {

$SafeSync  = $m.LastSync -replace '<','&lt;' -replace '>','&gt;'
$SafeError = $m.LastError -replace '<','&lt;' -replace '>','&gt;'

$Html += @"

<tr>
<td>$($m.Model)</td>
<td>$($m.SizeGB)</td>
<td>$($m.LastModified)</td>
<td>$SafeSync</td>
<td>$SafeError</td>
<td>$($m.Path)</td>
</tr>

"@
}

$Html += @"

</table>

</body>

</html>

"@

Set-Content -Path $ReportFile -Value $Html -Encoding UTF8

# ==========================================
# DONE
# ==========================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "SCAN COMPLETE" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Errors Found : $ErrorCount" -ForegroundColor Yellow
Write-Host "Models Found : $($ModelResults.Count)" -ForegroundColor Cyan
Write-Host ""

Write-Host "Report:"
Write-Host $ReportFile -ForegroundColor White
Write-Host ""

pause
