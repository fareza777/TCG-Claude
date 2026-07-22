# Dedicated storyboard art for all 29 story beats. Scenes favour landscapes /
# creatures; any humanoid uses a modesty clause (hooded / from behind / silhouette).
$ErrorActionPreference = "Continue"
$env:REPLICATE_API_TOKEN = (Get-ItemProperty "HKCU:\Environment").REPLICATE_API_TOKEN
$anchor = "epic fantasy story illustration, cinematic key art, painterly digital art, dramatic atmospheric lighting, rich saturated colors, detailed brushwork, wide establishing shot, no text, no watermark, no border, no frame"
$HOOD  = "the figure is deeply hooded, face entirely hidden in shadow beneath the hood, fully robed in heavy concealing cloth, no visible face, no exposed skin"
$BEHIND= "seen entirely from behind, face not visible, fully clothed in concealing armor and robes"
$pal = @{
  V = "verdant forest tones, emerald and moss green palette, bioluminescent accents, moonlit canopy"
  P = "volcanic orange and crimson palette, ember glow, ash-filled air, heat shimmer"
  T = "deep ocean blues and teals, arcane cyan glow, mist and water spray"
  D = "golden hour light, ivory and gold palette, radiant glow, marble architecture"
  G = "deep violet and black palette, pale moonlight, thorns and shadow tendrils"
}
$beats = @(
  @{ id="STORY-ch1-01"; d="V"; p="an ancient moonlit primeval forest, a colossal World-Oak tree glowing with emerald light in its roots, mist between giant trunks, a great stag guardian with luminous antlers watching in the distance, no human figure" },
  @{ id="STORY-ch1-02"; d="G"; p="a spectral wraith herald of shadow and tattered cloth rising from a burnt circle of blackened moss in a dark forest, an empty dark hood where a face should be, pale cold mist, non-human" },
  @{ id="STORY-ch1-03"; d="G"; p="a rotting grey forest where moss has blackened and curled, carrion bats wheeling over dead ferns, sickly violet rot creeping across the ground, no human figure" },
  @{ id="STORY-ch1-04"; d="P"; p="a forest at night with the western sky glowing ominous amber and crimson, distant fires of an approaching army on the horizon, embers drifting over the treeline, no clear figures" },
  @{ id="STORY-ch1-05"; d="P"; p="fire outriders' torches moving fast through eastern forest ferns at night, trails of ember light and smoke, distant helmeted silhouettes with no visible faces" },
  @{ id="STORY-ch1-06"; d="G"; p="a sacred forest spring fouled and running black and still, oily dark water reflecting a pale moon, dead reeds, faint violet corruption, no human figure" },
  @{ id="STORY-ch1-07"; d="D"; c=$BEHIND; p="a fully armored helmeted envoy holding a white and gold banner of a holy order entering a moonlit forest, cold discipline, radiant sigil" },
  @{ id="STORY-ch1-08"; d="V"; p="the Elderwood itself awakening, colossal ancient roots tearing free of the soil, glowing green heartwood, living mist, a rising forest titan, no human figure" },
  @{ id="STORY-ch1-09"; d="G"; p="a formation of dread-wraiths in tattered dark shrouds with empty hoods forming an honor guard before a great oak at midnight, pale scythes, non-human" },
  @{ id="STORY-ch1-10"; d="G"; c=$HOOD; p="a regal hooded sovereign queen stepping unhurried from the deep shadow of a colossal oak, layered violet veils and a crown over a raised hood, holding a glowing dark seal-sigil, moonlit" },
  @{ id="STORY-ch1-11"; d="V"; p="a glowing emerald shard pulsing like a heartbeat beneath the roots of a colossal World-Oak, four faint distant colored lights answering across the night sky, serene, no human figure" },
  @{ id="STORY-ch2-01"; d="P"; p="a vast volcanic city built around a colossal heart-shaped forge fire that beats like a pulse, its flame guttering low, ash-filled air, obsidian towers, no human figure" },
  @{ id="STORY-ch2-02"; d="P"; c=$BEHIND; p="a war-column of armored helmeted warriors crossing a glass desert past dark cold villages, crimson light bleeding up from a wound in the ground" },
  @{ id="STORY-ch2-03"; d="T"; c=$HOOD; p="a hooded archivist standing at the mouth of a glowing crimson vein in the earth, deep underwater-library light behind, holding a coral staff" },
  @{ id="STORY-ch2-04"; d="P"; p="descending into a glowing crimson vein deep underground, walls pulsing red like a living heartbeat, gentle tender heat, a vast unseen presence in the deepest dark, no clear figure" },
  @{ id="STORY-ch2-05"; d="P"; p="a cold dawn over a volcanic caldera whose eternal forge-fire has finally gone dark for the first time in a thousand years, cooling embers, ash, no human figure" },
  @{ id="STORY-ch3-01"; d="T"; p="a floating city upon a vast underwater library, endless shelves of glowing tablets beneath the waves, god rays through deep water, ink clouding the water, no human figure" },
  @{ id="STORY-ch3-02"; d="T"; p="a single half-dissolved glowing page floating in a deep dark vault, precise erasing strokes fading its ink into cold blue light, no human figure" },
  @{ id="STORY-ch3-03"; d="G"; p="pale erased memory-pages drifting like ghostly fish in lightless deep water, a memory-wraith of shadow rising with an indistinct hidden face, cold cyan and violet glow, non-human" },
  @{ id="STORY-ch3-04"; d="T"; c=$HOOD; p="a vault heart with a mirror of black still water reflecting a lone hooded robed figure endlessly, cold blue library light" },
  @{ id="STORY-ch3-05"; d="T"; p="restored glowing pages rising one by one with their ink returning, the true history legible at last, radiant cyan light in a drowned archive, no human figure" },
  @{ id="STORY-ch4-01"; d="D"; p="a radiant city of gold and ivory towers that never sleep, lit by a golden shard that casts no shadow, marble spires and banners, no human figure" },
  @{ id="STORY-ch4-02"; d="D"; p="a high sanctum wall covered in golden edicts and forbidding decrees, radiant but oppressive light, a single flickering doubt in the gloom, no human figure" },
  @{ id="STORY-ch4-03"; d="D"; p="a golden halo shaped like an intricate lock flickering for the first time, radiant golden light struggling against creeping shadow, an abstract breaking sun-sigil, no human figure" },
  @{ id="STORY-ch4-04"; d="D"; p="a steadying golden shard above a marble spire at dawn, a luminous halo-lock holding firm, serene radiant light, no human figure" },
  @{ id="STORY-ch5-01"; d="G"; p="a kingdom of silent watchers under a violet moon, black spires overlooking a restless glowing violet shard, a lonely eternal vigil, no human figure" },
  @{ id="STORY-ch5-02"; d="G"; p="an antechamber of black glass holding a thousand years of secret ledgers, faint violet glow on written pages of thankless deeds, no human figure" },
  @{ id="STORY-ch5-03"; d="G"; c=$HOOD; p="a regal hooded figure in violet veils seated unhurried at the top of a long dark stair, holding a fading dark seal, moonlight, the last lonely keeper" },
  @{ id="STORY-ch5-04"; d="G"; p="five faint colored lights (emerald, crimson, cyan, gold, violet) gathered in one dark chamber around a dimming violet seal, a thousand candles, solemn farewell, no human figure" }
)
$headers = @{ "Authorization" = "Token $env:REPLICATE_API_TOKEN"; "Content-Type" = "application/json"; "Prefer" = "wait" }
$outDir = "C:\TCG Claude\app\assets\art"
$ok = 0; $fail = 0
foreach ($b in $beats) {
  $concl = if ($b.ContainsKey('c')) { ", $($b.c)" } else { "" }
  $prompt = "$anchor, $($b.p)$concl, $($pal[$b.d])"
  $body = @{ input = @{ prompt = $prompt; aspect_ratio = "3:2"; num_outputs = 1; output_format = "webp"; output_quality = 95 } } | ConvertTo-Json -Depth 5
  $done = $false
  for ($try = 1; $try -le 3 -and -not $done; $try++) {
    try {
      $r = Invoke-RestMethod -Uri "https://api.replicate.com/v1/models/black-forest-labs/flux-dev/predictions" -Method Post -Headers $headers -Body $body -TimeoutSec 200
      $url = $r.output | Select-Object -First 1
      if ($url) { Invoke-WebRequest -Uri $url -OutFile (Join-Path $outDir "$($b.id).webp") | Out-Null; $done = $true }
      else { Start-Sleep 3 }
    } catch { Start-Sleep 4 }
  }
  if ($done) { $ok++; Write-Output "$($b.id) OK" } else { $fail++; Write-Output "$($b.id) FAILED" }
}
Write-Output "DONE ok=$ok fail=$fail"
