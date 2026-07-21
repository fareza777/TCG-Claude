# Art for the 55 expansion-2 cards. Modesty rules enforced for humanoids.
$ErrorActionPreference = "Continue"
$env:REPLICATE_API_TOKEN = (Get-ItemProperty "HKCU:\Environment").REPLICATE_API_TOKEN
$headers = @{ "Authorization" = "Token $env:REPLICATE_API_TOKEN"; "Content-Type" = "application/json"; "Prefer" = "wait" }
$anchor = "epic fantasy trading card game illustration, painterly digital art, dramatic cinematic lighting, rich saturated colors, detailed brushwork, clean composition with clear focal subject, atmospheric depth, no text, no watermark, no border, no frame"
$CONCEAL = "the figure is deeply hooded or in a full helmet with the face entirely hidden in shadow or seen from behind, fully clothed in heavy modest armor and robes, no exposed skin, no visible face"
$pal = @{
  V="verdant forest tones, emerald and moss green palette, bioluminescent accents, moonlit"
  P="volcanic orange and crimson palette, ember glow, ash-filled air, heat shimmer"
  T="deep ocean blues and teals, arcane cyan glow, mist and water"
  D="golden hour light, ivory and gold palette, radiant glow, abstract sun sigils"
  G="deep violet and black palette, pale moonlight, thorns and shadow tendrils"
}
# id, dominion, model(s/d), conceal(0/1), prompt
$cards = @(
  @{id="SF001-301";d="V";m="s";c=0;p="tiny glowing forest sprites made of leaves and light dancing over mushrooms"},
  @{id="SF001-302";d="V";m="s";c=1;p="a hooded druid with hands raised, soft green healing light blooming around, forest"},
  @{id="SF001-303";d="V";m="s";c=0;p="a fierce wolf covered in thorny bramble and moss, glowing green eyes, undergrowth"},
  @{id="SF001-304";d="V";m="s";c=0;p="a burst of glowing green growth energy, vines and flowers erupting fast, luminous spores"},
  @{id="SF001-305";d="V";m="s";c=0;p="a huge thorn-covered beast charging through a broken wooden fence, moss and bark hide"},
  @{id="SF001-306";d="V";m="s";c=0;p="radiant emerald blessing light pouring onto glowing antlers, sacred forest glade"},
  @{id="SF001-307";d="V";m="s";c=0;p="an ancient hollow tree altar overflowing with fruit flowers and green aether, fireflies"},
  @{id="SF001-308";d="V";m="d";c=0;p="a colossal ancient treefolk with a wall of living roots, glowing runes in its bark"},
  @{id="SF001-309";d="V";m="d";c=0;p="an explosive surge of nature magic sweeping across a forest, everything blooming at once, green shockwave"},
  @{id="SF001-310";d="V";m="d";c=0;p="the World-Oak, an impossibly vast ancient tree titan towering above the clouds with a glowing emerald core"},
  @{id="SF001-311";d="V";m="d";c=1;p="a hooded ancient forest guardian sovereign made of bark and moss, face hidden, crown of living antlers, roots trailing"},

  @{id="SF001-321";d="P";m="s";c=0;p="a small fiery drake whelp breathing sparks, perched on volcanic rock"},
  @{id="SF001-322";d="P";m="s";c=1;p="a burly brawler in a full closed helm and coal-black armor, fists wrapped, volcanic arena"},
  @{id="SF001-323";d="P";m="s";c=0;p="a small dart of orange fire streaking through smoke, sparks trailing"},
  @{id="SF001-324";d="P";m="s";c=1;p="a fanatic warrior in full helm wreathed in flame charging, ember trail"},
  @{id="SF001-325";d="P";m="s";c=1;p="an armored rider in a closed helm on a beast made of cinders, sweeping through ash storm"},
  @{id="SF001-326";d="P";m="s";c=0;p="a ritual circle of fire with molten runes, flames rising into a prayer, volcanic shrine"},
  @{id="SF001-327";d="P";m="s";c=0;p="a massive construct of molten metal and coal with glowing cracks, forge sparks"},
  @{id="SF001-328";d="P";m="d";c=0;p="a flaming meteor crashing down from a dark volcanic sky, huge impact of fire and shockwave"},
  @{id="SF001-329";d="P";m="d";c=0;p="a herald elemental of pure living fire raising its arms, embers exploding outward"},
  @{id="SF001-330";d="P";m="d";c=0;p="a towering avatar of the sun-forge, a walking titan of molten fire and obsidian, heart of white flame"},
  @{id="SF001-331";d="P";m="d";c=1;p="a hooded First Caller wreathed in crimson flame feeding fire into a glowing seal, face hidden, molten armor, from behind"},

  @{id="SF001-341";d="T";m="s";c=0;p="a small winged fish drifting through high glowing currents above the sea, iridescent"},
  @{id="SF001-342";d="T";m="s";c=1;p="a hooded scholar bent over a glowing water-map, cyan light, seen from behind"},
  @{id="SF001-343";d="T";m="s";c=0;p="a single ripple of glowing water spreading in a dark still pool, soft cyan light"},
  @{id="SF001-344";d="T";m="s";c=0;p="a sentinel construct grown from coral and pearl with a glowing core, harbor depths"},
  @{id="SF001-345";d="T";m="s";c=1;p="a hooded mage weaving cyan water runes, face hidden in shadow, moonlit harbor"},
  @{id="SF001-346";d="T";m="s";c=0;p="a receding wave dragging debris back into a spiral of water and light"},
  @{id="SF001-347";d="T";m="s";c=1;p="a deeply hooded oracle gazing into a sphere of dark water full of visions, face hidden"},
  @{id="SF001-348";d="T";m="d";c=0;p="a colossal leviathan silhouette turning beneath the waves, a huge wave sweeping ships back"},
  @{id="SF001-349";d="T";m="d";c=0;p="a frost-scaled sea serpent wreathed in cold cyan light, breaching dark water"},
  @{id="SF001-350";d="T";m="d";c=0;p="an immense glowing codex floating in a vast underwater archive, streams of light forming knowledge"},
  @{id="SF001-351";d="T";m="d";c=1;p="a hooded First Caller robed in flowing water, face hidden, pouring glowing memory into the sea, from behind"},

  @{id="SF001-361";d="D";m="s";c=1;p="a hooded cleric raising a lantern of warm golden light at dawn on a fortress wall"},
  @{id="SF001-362";d="D";m="s";c=1;p="a footman in full plate and closed helm holding a golden spear, marble wall, sunrise"},
  @{id="SF001-363";d="D";m="s";c=0;p="a warm shield of golden warding light glowing in the air, sunrise rays, marble"},
  @{id="SF001-364";d="D";m="s";c=1;p="a small hooded angelic cleric with folded luminous wings and a faint halo, golden light, face hidden"},
  @{id="SF001-365";d="D";m="s";c=1;p="a paladin in full golden plate and closed helm, sword drinking in radiant light, cape"},
  @{id="SF001-366";d="D";m="s";c=0;p="a wave of golden sanctifying light washing over a rank of glowing shields, banners"},
  @{id="SF001-367";d="D";m="s";c=1;p="a hooded priest with head bowed, golden censer, radiant light, face hidden, marble temple"},
  @{id="SF001-368";d="D";m="d";c=0;p="a pillar of blinding golden judgment light striking down from storm clouds, shadows dissolving"},
  @{id="SF001-369";d="D";m="d";c=1;p="a hooded angel guardian with vast luminous wings before an ancient golden door, face hidden in radiant hood"},
  @{id="SF001-370";d="D";m="d";c=0;p="a colossal golden halo shaped like an intricate lock hovering over a marble spire, blinding light, no figure"},
  @{id="SF001-371";d="D";m="d";c=1;p="a hooded First Caller angel with immense radiant wings, halo like a golden lock, face hidden, from behind above a spire"},

  @{id="SF001-381";d="G";m="s";c=0;p="a shambling undead worker climbing from an orderly bone pile in tidy catacombs, lantern light"},
  @{id="SF001-382";d="G";m="s";c=0;p="a sleek black serpent with dripping violet venom fangs coiled in shadow"},
  @{id="SF001-383";d="G";m="s";c=0;p="a glowing shadow contract signed in violet light, a hand dissolving into darkness"},
  @{id="SF001-384";d="G";m="s";c=0;p="a pale corpselight will-o-wisp floating over a misty graveyard, sickly glow"},
  @{id="SF001-385";d="G";m="s";c=0;p="a giant black widow spider weaving webs of decay and shadow, violet markings"},
  @{id="SF001-386";d="G";m="s";c=0;p="a stream of glowing life essence being drained from a target into darkness, violet magic"},
  @{id="SF001-387";d="G";m="s";c=1;p="a hooded executioner with a great curved blade emerging from shadow, face entirely hidden, moonlit"},
  @{id="SF001-388";d="G";m="d";c=0;p="a burst of annihilating violet death magic erasing a shape into ash and shadow"},
  @{id="SF001-389";d="G";m="d";c=0;p="a towering wraith lord of shadow and tattered cloth with an empty dark hood and pale scythe, thorns"},
  @{id="SF001-390";d="G";m="d";c=0;p="a swirling vortex of violet whispers and dark energy pouring from a beating crystalline heart-shard, eerie"},
  @{id="SF001-391";d="G";m="d";c=1;p="a hooded First Caller queen of shadow in layered violet veils, face entirely hidden, crown of blackened silver, ravens"}
)
$out = "C:\TCG Claude\app\assets\art"
$ok=0;$fail=0
foreach ($card in $cards) {
  $dest = Join-Path $out "$($card.id).webp"
  if (Test-Path $dest) { continue }
  $concl = if ($card.c -eq 1) { ", $CONCEAL" } else { "" }
  $prompt = "$anchor, $($card.p)$concl, $($pal[$card.d])"
  $model = if ($card.m -eq "d") { "black-forest-labs/flux-dev" } else { "black-forest-labs/flux-schnell" }
  $body = @{ input = @{ prompt = $prompt; aspect_ratio = "3:2"; num_outputs = 1; output_format = "webp"; output_quality = 90 } } | ConvertTo-Json -Depth 5
  $done=$false
  for ($t=1; $t -le 3 -and -not $done; $t++) {
    try {
      $r = Invoke-RestMethod -Uri "https://api.replicate.com/v1/models/$model/predictions" -Method Post -Headers $headers -Body $body -TimeoutSec 220
      $u = $r.output | Select-Object -First 1
      if ($u) { Invoke-WebRequest $u -OutFile $dest | Out-Null; $done=$true } else { Start-Sleep 4 }
    } catch { Start-Sleep 5 }
  }
  if ($done) { $ok++ } else { $fail++; Write-Output "$($card.id) FAIL" }
}
Write-Output "DONE ok=$ok fail=$fail"
