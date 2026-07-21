# SHARDFALL art pipeline - seed batch (FLUX schnell drafts)
# Requires: $env:REPLICATE_API_TOKEN
$ErrorActionPreference = "Stop"
$anchor = "epic fantasy trading card game illustration, painterly digital art, dramatic cinematic lighting, rich saturated colors, detailed brushwork, clean composition with clear focal subject, atmospheric depth, no text, no watermark, no border, no frame"
$pal = @{
  VERDANCE = "verdant forest tones, emerald and moss green palette, bioluminescent accents, moonlit canopy"
  PYRE     = "volcanic orange and crimson palette, ember glow, ash-filled air, heat shimmer"
  TIDE     = "deep ocean blues and teals, arcane cyan glow, mist and water spray"
  DAWN     = "golden hour light, ivory and gold palette, radiant halos, marble and banners"
  GLOOM    = "deep violet and black palette, pale moonlight, thorns and shadow tendrils"
}
$cards = @(
  @{ id="SF001-002"; dom="VERDANCE"; p="tiny cute forest sprite made of leaves and glowing sap, sitting on a giant mushroom, dappled green light" },
  @{ id="SF001-003"; dom="VERDANCE"; p="burst of magical green energy erupting from forest soil, roots and flowers growing in fast motion, luminous spores" },
  @{ id="SF001-021"; dom="PYRE";     p="fierce raptor-like lizard beast with ember-orange scales and flame crest, volcanic badlands at dusk, glowing lava cracks" },
  @{ id="SF001-022"; dom="PYRE";     p="crackling bolt of orange fire streaking across dark volcanic sky, sparks and embers trailing" },
  @{ id="SF001-041"; dom="TIDE";     p="colossal sea serpent leviathan with glowing cyan fins breaching from stormy ocean waves, arcane light beneath the water" },
  @{ id="SF001-042"; dom="TIDE";     p="arcane circle of glowing water runes suspended above dark ocean, wave curling around dissolving magical energy" },
  @{ id="SF001-061"; dom="DAWN";     p="female knight in ivory and gold armor holding radiant tower shield, sunrise light over marble fortress walls, banners" },
  @{ id="SF001-081"; dom="GLOOM";    p="spectral wraith with tattered violet shroud and pale glowing scythe, thorned shadow tendrils, misty moonlit hollow" },
  @{ id="SF001-101"; dom="VERDANCE"; p="ancient stone basin overflowing with luminous green aether energy, forest roots embracing it, fireflies" }
)
$headers = @{ "Authorization" = "Token $env:REPLICATE_API_TOKEN"; "Content-Type" = "application/json"; "Prefer" = "wait" }
$outDir = "C:\TCG Claude\tools\art_pipeline\review"
foreach ($c in $cards) {
  $prompt = "$anchor, $($c.p), $($pal[$c.dom])"
  $body = @{ input = @{ prompt = $prompt; aspect_ratio = "3:2"; num_outputs = 1; output_format = "webp"; output_quality = 90 } } | ConvertTo-Json -Depth 5
  try {
    $r = Invoke-RestMethod -Uri "https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions" -Method Post -Headers $headers -Body $body -TimeoutSec 120
    $url = $r.output | Select-Object -First 1
    if ($url) {
      $file = Join-Path $outDir "$($c.id)_schnell_s1.webp"
      Invoke-WebRequest -Uri $url -OutFile $file
      Write-Output "$($c.id): OK"
    } else { Write-Output "$($c.id): NO OUTPUT ($($r.status))" }
  } catch { Write-Output "$($c.id): ERROR $($_.Exception.Message)" }
}
Write-Output "DONE"
