<#
.SYNOPSIS
    Reads all Clarity JSON files from data/clarity-history/ and generates a
    self-contained, local-only HTML dashboard showing trends over time.

.DESCRIPTION
    LOCAL USE ONLY — not part of any CI/CD pipeline, not committed to _site/.
    Output goes to local-dashboard/ which is in .gitignore.

    Metrics aggregated per day (where present in the API response):
      - Sessions
      - Average scroll depth (%)
      - Average engagement / active time (seconds)
      - Rage clicks
      - Dead clicks

    Requirements:
      - PowerShell 5.1+ or PowerShell 7+
      - Internet access for Chart.js CDN (used only when you open the HTML)

.USAGE
    pwsh scripts/Generate-Dashboard.ps1
#>

# ---------------------------------------------------------------------------
# 0. Paths
# ---------------------------------------------------------------------------

$repoRoot      = Split-Path $PSScriptRoot -Parent
$dataDir       = Join-Path $repoRoot "data" "clarity-history"
$dashboardDir  = Join-Path $repoRoot "local-dashboard"
$outputFile    = Join-Path $dashboardDir "index.html"

# ---------------------------------------------------------------------------
# 1. Gather JSON files
# ---------------------------------------------------------------------------

Write-Host "Reading Clarity data files from: $dataDir"

if (-not (Test-Path $dataDir)) {
    Write-Warning "No data directory found at '$dataDir'. Run the fetch script first."
    exit 1
}

$files = Get-ChildItem -Path $dataDir -Filter "*.json" | Sort-Object Name

if ($files.Count -eq 0) {
    Write-Warning "No JSON files found in '$dataDir'. Nothing to visualise."
    exit 1
}

Write-Host "Found $($files.Count) data file(s)."

# ---------------------------------------------------------------------------
# 2. Parse and aggregate metrics
# ---------------------------------------------------------------------------

# Each entry will become one point on the chart.
# We collect arrays that Chart.js can consume directly.
$labels         = @()   # dates (x-axis)
$sessions       = @()
$scrollDepths   = @()
$engagementTimes= @()
$rageClicks     = @()
$deadClicks     = @()

foreach ($file in $files) {
    # Date comes from the filename (YYYY-MM-DD.json)
    $date = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

    try {
        $envelope = Get-Content $file.FullName -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Could not parse $($file.Name): $_  — skipping."
        continue
    }

    # The Clarity API returns an array of metric blocks, each shaped as:
    #   { metricName: "Traffic", information: [ { totalSessionCount, ... }, ... ] }
    # We extract the blocks we care about by metricName.
    $metricBlocks = $envelope.data   # top-level array

    # Helper: find a named metric block and return its information rows
    function Get-Rows([object[]]$blocks, [string]$name) {
        $block = $blocks | Where-Object { $_.metricName -eq $name }
        if ($block) { return @($block.information) }
        return @()
    }

    # Helper: sum a property across rows (null-safe)
    function Sum-Prop([object[]]$rows, [string]$prop) {
        ($rows | ForEach-Object { [double]($_.$prop ?? 0) } | Measure-Object -Sum).Sum
    }
    # Helper: average a property across rows that have it
    function Avg-Prop([object[]]$rows, [string]$prop) {
        $vals = $rows | Where-Object { $_.$prop -ne $null } | ForEach-Object { [double]$_.$prop }
        if ($vals.Count -eq 0) { return 0 }
        ($vals | Measure-Object -Average).Average
    }

    # --- Sessions (Traffic block) ---
    $trafficRows = Get-Rows $metricBlocks "Traffic"
    $s = Sum-Prop $trafficRows "totalSessionCount"

    # --- Scroll depth (%) ---
    $scrollRows = Get-Rows $metricBlocks "Scroll Depth"
    $sd = Avg-Prop $scrollRows "scrollDepth"
    if ($sd -eq 0) { $sd = Avg-Prop $scrollRows "avgScrollDepth" }

    # --- Engagement time (seconds) ---
    $engRows = Get-Rows $metricBlocks "Engagement Time"
    $et = Avg-Prop $engRows "engagementTime"
    if ($et -eq 0) { $et = Avg-Prop $engRows "activeTime" }

    # --- Rage clicks ---
    $rageRows = Get-Rows $metricBlocks "Rage Click Count"
    $rc = Sum-Prop $rageRows "rageClickCount"

    # --- Dead clicks ---
    $deadRows = Get-Rows $metricBlocks "Dead Click Count"
    $dc = Sum-Prop $deadRows "deadClickCount"

    $labels          += $date
    $sessions        += [math]::Round($s)
    $scrollDepths    += [math]::Round($sd, 1)
    $engagementTimes += [math]::Round($et, 1)
    $rageClicks      += [math]::Round($rc)
    $deadClicks      += [math]::Round($dc)

    Write-Host "  $date — sessions: $([math]::Round($s)), scroll: $([math]::Round($sd,1))%, " `
               "engagement: $([math]::Round($et,1))s, rage: $([math]::Round($rc)), dead: $([math]::Round($dc))"
}

# Convert PowerShell arrays to JSON arrays for embedding in HTML
function To-JsArray([array]$arr) {
    "[" + ($arr -join ", ") + "]"
}
function To-JsStringArray([array]$arr) {
    "[" + ($arr | ForEach-Object { "`"$_`"" } -join ", ") + "]"
}

$jsLabels          = To-JsStringArray $labels
$jsSessions        = To-JsArray $sessions
$jsScrollDepths    = To-JsArray $scrollDepths
$jsEngagementTimes = To-JsArray $engagementTimes
$jsRageClicks      = To-JsArray $rageClicks
$jsDeadClicks      = To-JsArray $deadClicks

$generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm") + " (local)"

# ---------------------------------------------------------------------------
# 3. Build self-contained HTML
# ---------------------------------------------------------------------------

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Clarity Analytics Dashboard — culture-engineers.nl</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js"></script>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #0f1117;
      color: #e2e8f0;
      padding: 2rem;
    }
    h1 { font-size: 1.6rem; font-weight: 700; margin-bottom: 0.25rem; }
    .subtitle { font-size: 0.85rem; color: #94a3b8; margin-bottom: 2rem; }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(560px, 1fr));
      gap: 1.5rem;
    }
    .card {
      background: #1e2330;
      border-radius: 12px;
      padding: 1.25rem 1.5rem 1.5rem;
      box-shadow: 0 4px 20px rgba(0,0,0,0.4);
    }
    .card h2 { font-size: 0.95rem; font-weight: 600; color: #94a3b8; margin-bottom: 1rem; }
    canvas { display: block; width: 100% !important; }
    .footer { margin-top: 2rem; font-size: 0.75rem; color: #475569; text-align: center; }
  </style>
</head>
<body>

<h1>Clarity Analytics — culture-engineers.nl</h1>
<p class="subtitle">Local dashboard · Generated: $generatedAt · $($files.Count) day(s) of data</p>

<div class="grid">

  <!-- Sessions -->
  <div class="card">
    <h2>Daily Sessions</h2>
    <canvas id="chartSessions" height="220"></canvas>
  </div>

  <!-- Scroll depth -->
  <div class="card">
    <h2>Average Scroll Depth (%)</h2>
    <canvas id="chartScroll" height="220"></canvas>
  </div>

  <!-- Engagement time -->
  <div class="card">
    <h2>Average Engagement Time (seconds)</h2>
    <canvas id="chartEngagement" height="220"></canvas>
  </div>

  <!-- Rage + Dead clicks -->
  <div class="card">
    <h2>Rage Clicks &amp; Dead Clicks</h2>
    <canvas id="chartClicks" height="220"></canvas>
  </div>

</div>

<p class="footer">Data source: Microsoft Clarity Data Export API · LOCAL USE ONLY — not published to the live site</p>

<script>
  // Shared axis / tooltip config so all charts look consistent
  const sharedOptions = {
    responsive: true,
    interaction: { mode: 'index', intersect: false },
    plugins: {
      legend: { labels: { color: '#cbd5e1', font: { size: 12 } } },
      tooltip: { backgroundColor: '#1e2330', titleColor: '#e2e8f0', bodyColor: '#94a3b8' }
    },
    scales: {
      x: { ticks: { color: '#64748b', maxRotation: 45 }, grid: { color: '#2d3748' } },
      y: { ticks: { color: '#64748b' },                  grid: { color: '#2d3748' }, beginAtZero: true }
    }
  };

  const labels = $jsLabels;

  // Sessions
  new Chart(document.getElementById('chartSessions'), {
    type: 'line',
    data: {
      labels,
      datasets: [{
        label: 'Sessions',
        data: $jsSessions,
        borderColor: '#6366f1',
        backgroundColor: 'rgba(99,102,241,0.15)',
        fill: true, tension: 0.3, pointRadius: 3
      }]
    },
    options: sharedOptions
  });

  // Scroll depth
  new Chart(document.getElementById('chartScroll'), {
    type: 'line',
    data: {
      labels,
      datasets: [{
        label: 'Avg Scroll Depth (%)',
        data: $jsScrollDepths,
        borderColor: '#10b981',
        backgroundColor: 'rgba(16,185,129,0.15)',
        fill: true, tension: 0.3, pointRadius: 3
      }]
    },
    options: { ...sharedOptions,
      scales: { ...sharedOptions.scales,
        y: { ...sharedOptions.scales.y, max: 100 }
      }
    }
  });

  // Engagement time
  new Chart(document.getElementById('chartEngagement'), {
    type: 'bar',
    data: {
      labels,
      datasets: [{
        label: 'Avg Engagement Time (s)',
        data: $jsEngagementTimes,
        backgroundColor: 'rgba(245,158,11,0.7)',
        borderColor: '#f59e0b',
        borderWidth: 1, borderRadius: 4
      }]
    },
    options: sharedOptions
  });

  // Rage + Dead clicks
  new Chart(document.getElementById('chartClicks'), {
    type: 'bar',
    data: {
      labels,
      datasets: [
        {
          label: 'Rage Clicks',
          data: $jsRageClicks,
          backgroundColor: 'rgba(239,68,68,0.7)',
          borderColor: '#ef4444',
          borderWidth: 1, borderRadius: 4
        },
        {
          label: 'Dead Clicks',
          data: $jsDeadClicks,
          backgroundColor: 'rgba(100,116,139,0.7)',
          borderColor: '#64748b',
          borderWidth: 1, borderRadius: 4
        }
      ]
    },
    options: sharedOptions
  });
</script>
</body>
</html>
"@

# ---------------------------------------------------------------------------
# 4. Write the file
# ---------------------------------------------------------------------------

if (-not (Test-Path $dashboardDir)) {
    New-Item -ItemType Directory -Path $dashboardDir -Force | Out-Null
    Write-Host "Created directory: $dashboardDir"
}

Set-Content -Path $outputFile -Value $html -Encoding UTF8
Write-Host ""
Write-Host "Dashboard written to: $outputFile"

# ---------------------------------------------------------------------------
# 5. Open in the default browser
# ---------------------------------------------------------------------------

Write-Host "Opening dashboard in default browser..."
Start-Process $outputFile
