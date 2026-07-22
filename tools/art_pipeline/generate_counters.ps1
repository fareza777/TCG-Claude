# Generate unique art for the two counterspell cards (both non-humanoid → safe).
$ErrorActionPreference = "Continue"
$env:REPLICATE_API_TOKEN = (Get-ItemProperty "HKCU:\Environment").REPLICATE_API_TOKEN
$anchor = "epic fantasy trading card game illustration, painterly digital art, dramatic cinematic lighting, rich saturated colors, detailed brushwork, clean composition with clear focal subject, atmospheric depth, no text, no watermark, no border, no frame"
$pal = @{
  T = "deep ocean blues and teals, arcane cyan glow, mist and water spray"
  G = "deep violet and black palette, pale moonlight, thorns and shadow tendrils"
}
$cards = @(
  @{ id="SF001-354"; d="T"; p="a towering wall of dark water rising to swallow and extinguish a bright bolt of arcane spell-light, the incoming spell dissolving into steam and cyan runic ripples, a suspended sphere of still water snuffing the magic, no human figure" },
  @{ id="SF001-394"; d="G"; p="a spreading void of absolute darkness devouring a floating glowing spell-sigil, tendrils of violet shadow snuffing the arcane light into nothing, pale motes of a broken incantation fading into a silent black rift, no human figure" }
)
$headers = @{ "Authorization" = "Token $env:REPLICATE_API_TOKEN"; "Content-Type" = "application/json"; "Prefer" = "wait" }
$outDir = "C:\TCG Claude\app\assets\art"
$ok = 0; $fail = 0
foreach ($card in $cards) {
  $prompt = "$anchor, $($card.p), $($pal[$card.d])"
  $body = @{ input = @{ prompt = $prompt; aspect_ratio = "3:2"; num_outputs = 1; output_format = "webp"; output_quality = 95 } } | ConvertTo-Json -Depth 5
  $done = $false
  for ($try = 1; $try -le 3 -and -not $done; $try++) {
    try {
      $r = Invoke-RestMethod -Uri "https://api.replicate.com/v1/models/black-forest-labs/flux-dev/predictions" -Method Post -Headers $headers -Body $body -TimeoutSec 200
      $url = $r.output | Select-Object -First 1
      if ($url) { Invoke-WebRequest -Uri $url -OutFile (Join-Path $outDir "$($card.id).webp") | Out-Null; $done = $true }
      else { Start-Sleep 3 }
    } catch { Write-Output "err: $_"; Start-Sleep 4 }
  }
  if ($done) { $ok++; Write-Output "$($card.id) OK" } else { $fail++; Write-Output "$($card.id) FAILED" }
}
Write-Output "DONE ok=$ok fail=$fail"
