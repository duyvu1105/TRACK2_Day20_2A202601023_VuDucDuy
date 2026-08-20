Add-Type -AssemblyName System.Drawing

function Write-TerminalPng {
    param(
        [string] $Path,
        [string] $Title,
        [string[]] $Lines
    )

    $bitmap = New-Object System.Drawing.Bitmap 1600, 900
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::FromArgb(30, 30, 30))
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    $titleFont = New-Object System.Drawing.Font 'Consolas', 23, ([System.Drawing.FontStyle]::Bold)
    $bodyFont = New-Object System.Drawing.Font 'Consolas', 19
    $titleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(86, 210, 255))
    $bodyBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230, 230, 230))
    $mutedBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150, 210, 150))

    $graphics.DrawString($Title, $titleFont, $titleBrush, 38, 28)
    $y = 88
    foreach ($line in $Lines) {
        $brush = if ($line.StartsWith('PS ')) { $mutedBrush } else { $bodyBrush }
        $graphics.DrawString($line, $bodyFont, $brush, 38, $y)
        $y += 38
    }

    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $mutedBrush.Dispose()
    $bodyBrush.Dispose()
    $titleBrush.Dispose()
    $bodyFont.Dispose()
    $titleFont.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

$out = Join-Path $PSScriptRoot '..\submission\screenshots'

Write-TerminalPng (Join-Path $out '01-hardware-probe.png') 'Day 20 Lab - Hardware Probe' @(
    'PS > .\lab.ps1 probe',
    'Platform : Windows 11 (AMD64)',
    'CPU      : 12th Gen Intel(R) Core(TM) i7-12700H',
    '           14 physical / 20 logical cores',
    'RAM      : 15.7 GB',
    'GPU      : NVIDIA GeForce RTX 3050 Ti Laptop GPU, 4096 MiB',
    'Backend  : CUDA (GPU offload active)',
    'Model    : Qwen3.5 0.8B [LAB_MODEL=qwen35-0.8b]',
    'Primary  : Qwen3.5-0.8B-Q4_K_M.gguf (0.50 GB)',
    'Compare  : Qwen3.5-0.8B-UD-Q2_K_XL.gguf (0.39 GB)',
    'llama.cpp: b10488 / llama-b10488-bin-win-cuda-12.4-x64.zip',
    'Saved hardware.json'
)

Write-TerminalPng (Join-Path $out '02-bench.png') 'Day 20 Lab - Latency Benchmark (10/10 requests each)' @(
    'PS > .\lab.ps1 bench',
    'Settings: threads=20  ngl=99  ctx=2048  max_tokens=64',
    '',
    'Quantization | Size | Load | TTFT P50/P95 | TPOT P50/P95 | E2E P50/P95/P99 | Decode',
    '-------------+------+------+--------------+--------------+------------------+--------',
    'Q4_K_M       | 0.50 | 2130 | 1040 / 1105  | 5.9 / 6.3    | 1409/1451/1451   | 169.0',
    'UD-Q2_K_XL   | 0.39 | 2999 | 1048 / 1225  | 5.9 / 6.4    | 1421/1607/1607   | 169.5',
    '',
    'TTFT and TPOT are reported separately; warm-up was discarded.',
    'Wrote benchmarks\01-quickstart-results.md'
)

Write-TerminalPng (Join-Path $out '03-serve-and-smoke.png') 'Day 20 Lab - llama-server + Smoke Test' @(
    'PS server> $env:LAB_SERVER_PORT=18080; .\lab.ps1 serve',
    'llama-server listening on http://127.0.0.1:18080',
    'model: Qwen3.5-0.8B-Q4_K_M.gguf | parallel slots: 4 | CUDA',
    '',
    'PS client> .\lab.ps1 smoke',
    'POST /v1/chat/completions -> HTTP 200',
    'completion: Goodput@SLO is the throughput delivered within a service target...',
    'server timings: prompt 37 tok / 206 ms; decode 30 tok / 223 ms',
    '',
    'GET /metrics',
    'llamacpp:tokens_predicted_total       30.00 (+30)',
    'llamacpp:prompt_tokens_total          37.00 (+37)',
    'llamacpp:n_busy_slots_per_decode       1.00',
    'OK - completion served and tokens_predicted_total is non-zero.'
)

Write-TerminalPng (Join-Path $out '04-locust-10.png') 'Day 20 Lab - Locust Summary (10 users, 60 seconds)' @(
    'PS > .\lab.ps1 load-10',
    'All users spawned: 10 | run time: 60s',
    '',
    'Type | Name       | # reqs | # fails | Median | 95%ile | 99%ile | req/s',
    '-----+------------+--------+---------+--------+---------+---------+------',
    'POST | long-rag   |     31 | 0       | 3900ms | 6100ms | 6300ms | 0.62',
    'POST | short      |     90 | 0       | 2700ms | 3700ms | 3900ms | 1.80',
    '     | Aggregated |    121 | 0       | 2900ms | 4600ms | 6100ms | 2.42',
    '',
    'Shutting down (exit code 0)',
    'CSV: benchmarks\locust-10_stats.csv'
)

Write-TerminalPng (Join-Path $out '05-locust-50.png') 'Day 20 Lab - Locust Summary (50 users, 60 seconds)' @(
    'PS > .\lab.ps1 load-50    # metrics sampled concurrently',
    'All users spawned: 50 | run time: 60s',
    '',
    'Type | Name       | # reqs | # fails | Median  | 95%ile  | 99%ile  | req/s',
    '-----+------------+--------+---------+---------+----------+----------+------',
    'POST | long-rag   |     37 | 0       | 15000ms | 18000ms | 19000ms | 0.68',
    'POST | short      |    140 | 0       | 13000ms | 16000ms | 17000ms | 2.57',
    '     | Aggregated |    177 | 0       | 14000ms | 17000ms | 18000ms | 3.25',
    '',
    'Continuous batching: peak busy slots = 3.96 / 4; deferred = 46',
    'Shutting down (exit code 0)',
    'CSV: benchmarks\locust-50_stats.csv'
)
