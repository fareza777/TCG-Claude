# Generate the app icon only (the shattered five-colour star emblem).
# Menu tiles stay as translucent glass so the main background shows through.
$ErrorActionPreference = "Continue"
$env:REPLICATE_API_TOKEN = (Get-ItemProperty "HKCU:\Environment").REPLICATE_API_TOKEN
$headers = @{ "Authorization" = "Token $env:REPLICATE_API_TOKEN"; "Content-Type" = "application/json"; "Prefer" = "wait" }
$ui = "C:\TCG Claude\app\assets\ui"
New-Item -ItemType Directory -Force $ui | Out-Null

$icon = "app icon logo emblem, a shattered crystalline multi-pointed star radiating five glowing colors emerald green ember orange ocean cyan radiant gold deep violet, centered on a dark obsidian rounded-square background with a subtle gold ring border, iconic, symmetrical, clean, highly detailed, premium mobile game icon, no text, no words, no letters"
$body = @{ input = @{ prompt = $icon; aspect_ratio = "1:1"; num_outputs = 1; output_format = "png"; output_quality = 95 } } | ConvertTo-Json -Depth 5

function TryModel($model) {
  for ($t=1; $t -le 3; $t++) {
    try {
      $r = Invoke-RestMethod -Uri "https://api.replicate.com/v1/models/$model/predictions" -Method Post -Headers $headers -Body $body -TimeoutSec 230
      $u = $r.output | Select-Object -First 1
      if ($u) { Invoke-WebRequest $u -OutFile "$ui\app_icon.png"; return $true } else { Start-Sleep 5 }
    } catch { Start-Sleep 5 }
  }
  return $false
}

if (TryModel "black-forest-labs/flux-dev") { Write-Output "icon OK (dev)" }
elseif (TryModel "black-forest-labs/flux-schnell") { Write-Output "icon OK (schnell)" }
else { Write-Output "icon FAIL" }
