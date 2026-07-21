# Generate art for all cards lacking assets. FLUX schnell, 3:2, direct to app assets.
$ErrorActionPreference = "Continue"
$env:REPLICATE_API_TOKEN = (Get-ItemProperty "HKCU:\Environment").REPLICATE_API_TOKEN
$anchor = "epic fantasy trading card game illustration, painterly digital art, dramatic cinematic lighting, rich saturated colors, detailed brushwork, clean composition with clear focal subject, atmospheric depth, no text, no watermark, no border, no frame"
$pal = @{
  V = "verdant forest tones, emerald and moss green palette, bioluminescent accents, moonlit canopy"
  P = "volcanic orange and crimson palette, ember glow, ash-filled air, heat shimmer"
  T = "deep ocean blues and teals, arcane cyan glow, mist and water spray"
  D = "golden hour light, ivory and gold palette, radiant glow, abstract sun sigils on banners, marble architecture"
  G = "deep violet and black palette, pale moonlight, thorns and shadow tendrils"
}
$cards = @(
  @{ id="SF001-002"; d="V"; p="massive wild boar with bark-like hide and moss growing on its back, thorny tusks, charging through ancient forest undergrowth" },
  @{ id="SF001-003"; d="V"; p="towering treefolk guardian with a shield-like wall of living roots and vines, standing firm in forest clearing" },
  @{ id="SF001-005"; d="V"; p="sleek panther-like beast with leaf-patterned fur stalking along a high forest branch, glowing eyes" },
  @{ id="SF001-006"; d="V"; p="great forest spirit bear with antlers and glowing runes in its fur, guarding a shrine of stones" },
  @{ id="SF001-007"; d="V"; p="colossal ancient treefolk giant towering over the forest canopy, moss beard, limbs like tree trunks" },
  @{ id="SF001-009"; d="V"; p="radiant magical flower blooming with waves of healing green light, forest glade, floating petals" },
  @{ id="SF001-010"; d="V"; p="mighty forest spirits roaring together, shockwave of green energy rippling through trees" },
  @{ id="SF001-011"; d="V"; p="giant vines and roots bursting from the ground crushing ancient stone ruins, explosive overgrowth" },
  @{ id="SF001-021"; d="P"; p="small mischievous fire imp juggling embers, sharp grin, perched on volcanic rock" },
  @{ id="SF001-022"; d="P"; p="fierce warrior with twin ash-black blades sprinting through embers, war paint, dynamic action pose" },
  @{ id="SF001-023"; d="P"; p="tribal shaman summoning crackling sparks between raised hands, volcanic ritual circle" },
  @{ id="SF001-025"; d="P"; p="frenzied berserker warrior wreathed in flame charging with a massive axe, trail of fire" },
  @{ id="SF001-026"; d="P"; p="huge magma elemental beast with molten rock hide and glowing lava veins, erupting landscape" },
  @{ id="SF001-027"; d="P"; p="colossal elemental giant made of burning coal and fire towering over a lava field" },
  @{ id="SF001-029"; d="P"; p="massive eruption of lava and fire engulfing the sky, explosive burst of molten energy" },
  @{ id="SF001-030"; d="P"; p="wall of wildfire sweeping across a battlefield at night, silhouettes fleeing, embers swirling" },
  @{ id="SF001-031"; d="P"; p="mystic gazing into dancing flames revealing visions, sparks forming arcane symbols" },
  @{ id="SF001-041"; d="T"; p="small winged fish sprite gliding above ocean waves, iridescent fins, sparkling spray" },
  @{ id="SF001-042"; d="T"; p="hooded mage conjuring swirling mist and water orbs, arcane focus, moonlit harbor" },
  @{ id="SF001-043"; d="T"; p="massive armored deep-sea creature coiled protectively at the ocean floor, glowing lure, dark abyss" },
  @{ id="SF001-044"; d="T"; p="merfolk warrior riding a curling ocean current like a wave, trident in hand, dynamic motion" },
  @{ id="SF001-045"; d="T"; p="majestic water djinn rising from a whirlpool, body of living water and storm clouds" },
  @{ id="SF001-046"; d="T"; p="enormous sea serpent coiling through deep water, bioluminescent patterns along its body" },
  @{ id="SF001-048"; d="T"; p="powerful undertow current dragging a ghostly ship down in a spiral of water and light" },
  @{ id="SF001-049"; d="T"; p="glowing arcane tome floating above water with streams of light forming visions of knowledge" },
  @{ id="SF001-050"; d="T"; p="hypnotic spiral of water and thought energy invading a silhouetted mind, surreal dreamlike" },
  @{ id="SF001-051"; d="T"; p="giant wave fist slamming down onto a rocky shore, explosion of spray and cyan light" },
  @{ id="SF001-061"; d="D"; p="young squire in polished armor holding a spear at dawn, hopeful expression, fortress gate" },
  @{ id="SF001-063"; d="D"; p="massive enchanted wall construct of white marble and gold, glowing defensive runes" },
  @{ id="SF001-064"; d="D"; p="majestic griffin with golden feathers soaring over a fortress at sunrise, banners below" },
  @{ id="SF001-065"; d="D"; p="armored knight bearing a glowing lantern-staff leading soldiers through morning mist" },
  @{ id="SF001-066"; d="D"; p="radiant champion knight with sword raised absorbing golden light, cape flowing" },
  @{ id="SF001-067"; d="D"; p="angelic warrior with luminous wings descending from sunrise clouds, ornate golden armor" },
  @{ id="SF001-068"; d="D"; p="priest consecrating ground with pillar of warm golden light, kneeling soldiers healed" },
  @{ id="SF001-069"; d="D"; p="beam of purifying sunlight striking down through storm clouds, shadows dissolving" },
  @{ id="SF001-070"; d="D"; p="army of knights rallying at dawn, banners raised high, golden light sweeping over them" },
  @{ id="SF001-071"; d="D"; p="apocalyptic judgment of light raining down on a dark battlefield, silhouettes engulfed in radiance" },
  @{ id="SF001-081"; d="G"; p="sinister black rat with glowing violet eyes and dripping venomous fangs, sewer shadows" },
  @{ id="SF001-082"; d="G"; p="masked assassin emerging from shadows with curved poisoned daggers, moonlit alley" },
  @{ id="SF001-083"; d="G"; p="large tattered bat with violet wing membranes swooping through misty graveyard" },
  @{ id="SF001-084"; d="G"; p="giant black widow spider with violet markings lurking in web-shrouded hollow, venom drips" },
  @{ id="SF001-086"; d="G"; p="towering wraith of shadow and tattered cloth looming with skeletal hands outstretched" },
  @{ id="SF001-087"; d="G"; p="colossal horror giant stitched from shadow and bone rising from a black pit" },
  @{ id="SF001-088"; d="G"; p="withering curse of violet energy draining life from a knight, decaying flowers around" },
  @{ id="SF001-089"; d="G"; p="stream of glowing soul essence being drawn from a victim into a dark chalice" },
  @{ id="SF001-090"; d="G"; p="glowing violet death rune burning itself onto ancient stone, doom sigil, dark ritual" },
  @{ id="SF001-091"; d="G"; p="elegant dark queen sealing a pact, blood contract glowing violet, ravens circling" },
  @{ id="SF001-121"; d="P"; p="ancient obsidian basin overflowing with molten aether fire, volcanic shrine, ember glow" },
  @{ id="SF001-141"; d="T"; p="ancient coral basin overflowing with luminous blue aether water, ocean shrine, drifting light" },
  @{ id="SF001-161"; d="D"; p="ancient marble basin overflowing with radiant golden aether light, dawn shrine, floating motes" },
  @{ id="SF001-181"; d="G"; p="ancient blackstone basin overflowing with swirling violet aether shadow, thorn shrine, pale moths" }
)
$headers = @{ "Authorization" = "Token $env:REPLICATE_API_TOKEN"; "Content-Type" = "application/json"; "Prefer" = "wait" }
$outDir = "C:\TCG Claude\app\assets\art"
$ok = 0; $fail = 0
foreach ($c in $cards) {
  $dest = Join-Path $outDir "$($c.id).webp"
  if (Test-Path $dest) { continue }
  $prompt = "$anchor, $($c.p), $($pal[$c.d])"
  $body = @{ input = @{ prompt = $prompt; aspect_ratio = "3:2"; num_outputs = 1; output_format = "webp"; output_quality = 90 } } | ConvertTo-Json -Depth 5
  $done = $false
  for ($try = 1; $try -le 3 -and -not $done; $try++) {
    try {
      $r = Invoke-RestMethod -Uri "https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions" -Method Post -Headers $headers -Body $body -TimeoutSec 120
      $url = $r.output | Select-Object -First 1
      if ($url) { Invoke-WebRequest -Uri $url -OutFile $dest | Out-Null; $done = $true }
      else { Start-Sleep -Seconds 2 }
    } catch { Start-Sleep -Seconds 3 }
  }
  if ($done) { $ok++; Write-Output "$($c.id) OK" } else { $fail++; Write-Output "$($c.id) FAILED" }
}
Write-Output "DONE ok=$ok fail=$fail"
