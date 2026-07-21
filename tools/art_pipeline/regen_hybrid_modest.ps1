# Hybrid regen: FLUX dev, quality upgrade + modesty rules (no clear human
# faces, no female aurat). Overwrites app/assets/art directly.
$ErrorActionPreference = "Continue"
$env:REPLICATE_API_TOKEN = (Get-ItemProperty "HKCU:\Environment").REPLICATE_API_TOKEN
$anchor = "epic fantasy trading card game illustration, painterly digital art, dramatic cinematic lighting, rich saturated colors, detailed brushwork, clean composition with clear focal subject, atmospheric depth, no text, no watermark, no border, no frame"
# Modesty clauses appended to any card featuring a humanoid figure.
$HOOD  = "the figure is deeply hooded, face entirely hidden in shadow beneath the hood, fully robed in heavy concealing cloth, no visible face, no exposed skin"
$HELM  = "clad head to toe in full plate armor with a closed full helm, face completely concealed, no exposed skin"
$BEHIND= "seen entirely from behind, face not visible, fully clothed in concealing armor and robes"
$SIL   = "rendered as a dark dramatic silhouette against bright light, face not visible, fully covered body"
$pal = @{
  V = "verdant forest tones, emerald and moss green palette, bioluminescent accents, moonlit canopy"
  P = "volcanic orange and crimson palette, ember glow, ash-filled air, heat shimmer"
  T = "deep ocean blues and teals, arcane cyan glow, mist and water spray"
  D = "golden hour light, ivory and gold palette, radiant glow, abstract sun sigils, marble architecture"
  G = "deep violet and black palette, pale moonlight, thorns and shadow tendrils"
}
$cards = @(
  # ---- Legendaries ----
  @{ id="SF001-201"; d="V"; p="majestic colossal elk god with towering crown-like glowing antlers and moss-covered hide, ancient guardian standing among giant roots, aura of authority, no human figure" },
  @{ id="SF001-221"; d="P"; c=$HELM; p="a warrior champion in full crimson and blackened-steel plate armor with a closed full helm, holding a blazing greatsword, commanding stance on a forge platform, embers swirling" },
  @{ id="SF001-241"; d="T"; c=$BEHIND; p="a deeply hooded robed archivist standing before a vast underwater library of floating glowing books, staff of coral, god rays through water" },
  @{ id="SF001-261"; d="D"; c=$BEHIND; p="a towering angelic figure with vast luminous wings and a halo shaped like an intricate golden lock, fully robed in flowing golden vestments with a raised hood, hovering above a marble spire" },
  @{ id="SF001-281"; d="G"; c=$HOOD; p="a regal hooded sovereign in layered violet veils and a crown of blackened silver set over the hood, holding a glowing circular seal-sigil in gloved hands, ravens circling, moonlit" },
  # ---- Verdance rares/humanoids ----
  @{ id="SF001-004"; d="V"; p="majestic elk guardian spirit with glowing branching antlers, moonlit ancient forest clearing, mist between colossal trees, no human figure" },
  @{ id="SF001-007"; d="V"; p="colossal ancient treefolk giant towering over the forest canopy, moss beard of vines, limbs like tree trunks, no human figure" },
  @{ id="SF001-208"; d="V"; p="forest animals and treefolk surging forward in a stampede, glowing green eyes, primal fury, no human figure" },
  @{ id="SF001-211"; d="V"; p="towering ancient tree titan with a glowing heart visible through its bark, canopy above the clouds, no human figure" },
  @{ id="SF001-202"; d="V"; c=$BEHIND; p="a hooded druid kneeling with a hand on glowing tree roots, soft light passing between fingers and soil" },
  @{ id="SF001-204"; d="V"; c=$HOOD; p="a hooded elf archer perched in tree branches drawing a bow of living wood, glowing arrow, seen from the side, face in shadow" },
  @{ id="SF001-210"; d="V"; c=$HELM; p="an armored warden in leaf-scale plate and a full helm standing guard at forest border stones, twin curved blades" },
  @{ id="SF001-213"; d="V"; c=$SIL; p="a lone hooded sentry on a high branch overlooking the moonlit forest sea, distant glow on the horizon" },
  # ---- Pyre rares/humanoids ----
  @{ id="SF001-026"; d="P"; p="huge magma elemental beast with molten rock hide and glowing lava veins, erupting landscape, no human figure" },
  @{ id="SF001-027"; d="P"; p="colossal elemental giant of burning coal and fire towering over a lava field, no human figure" },
  @{ id="SF001-030"; d="P"; p="wall of wildfire sweeping across a battlefield at night, embers swirling, no figures" },
  @{ id="SF001-225"; d="P"; p="apocalyptic storm of fire tornadoes sweeping a battlefield, distant silhouetted armies, no clear faces" },
  @{ id="SF001-229"; d="P"; p="colossal titan of cooling lava and obsidian plates wading through a burning city, no human figure" },
  @{ id="SF001-233"; d="P"; p="pillar of white-hot judgment fire striking down from the sky onto a battlefield, no figures" },
  @{ id="SF001-023"; d="P"; c=$HOOD; p="a hooded shaman summoning crackling sparks between raised hands, volcanic ritual circle, face in shadow" },
  @{ id="SF001-025"; d="P"; c=$HELM; p="a frenzied berserker in full horned helm and heavy armor charging with a massive axe, trail of fire" },
  @{ id="SF001-222"; d="P"; c=$BEHIND; p="a hooded apprentice tending a great heart-shaped forge fire, sparks orbiting" },
  @{ id="SF001-227"; d="P"; c=$HELM; p="a zealot in full plate and closed helm with a glowing sun-brand on the breastplate, twin axes" },
  @{ id="SF001-230"; d="P"; c=$SIL; p="a fully robed fire-juggler as a dark silhouette mid-leap trailing ribbons of flame, festival of embers at night" },
  @{ id="SF001-232"; d="P"; p="a warband of armored, helmeted figures raising weapons as a wave of fiery light passes over them, seen from behind, no visible faces" },
  # ---- Tide rares/humanoids ----
  @{ id="SF001-047"; d="T"; p="colossal sea serpent leviathan with glowing cyan fins breaching from stormy ocean waves, arcane light beneath, no human figure" },
  @{ id="SF001-244"; d="T"; p="massive djinn of storm clouds and rain towering over the ocean, face formed of swirling cloud, lightning in its chest, non-human" },
  @{ id="SF001-253"; d="T"; p="vast underwater archive hall with infinite shelves of glowing tablets, god rays through water, no figures" },
  @{ id="SF001-251"; d="T"; c=$HOOD; p="two identical hooded robed figures facing each other across a mirror of water, faces hidden, library background" },
  @{ id="SF001-042"; d="T"; c=$HOOD; p="a hooded mage conjuring swirling mist and water orbs, arcane focus, moonlit harbor, face in shadow" },
  @{ id="SF001-242"; d="T"; c=$BEHIND; p="a hooded scribe writing with light on floating water-glass pages, coral desk" },
  @{ id="SF001-245"; d="T"; c=$SIL; p="a lone hooded figure in silhouette before a vast cosmic vision of a glowing song, water suspended around them" },
  @{ id="SF001-248"; d="T"; c=$HOOD; p="a hooded merfolk mage binding a foe in ropes of living water, face in shadow" },
  @{ id="SF001-250"; d="T"; c=$HOOD; p="a hooded mystic meditating inside a sphere of slowly rotating water shields" },
  # ---- Dawn rares/humanoids ----
  @{ id="SF001-071"; d="D"; p="beam of purifying sunlight striking down through storm clouds onto a battlefield, shadows dissolving, no figures" },
  @{ id="SF001-264"; d="D"; p="gigantic marble construct kneeling before a sealed vault door beneath a sun temple, no human figure" },
  @{ id="SF001-265"; d="D"; p="beam of judgment light striking a battlefield, a dark shape dissolving into motes, no clear face" },
  @{ id="SF001-066"; d="D"; c=$HELM; p="a radiant champion in full golden plate armor and closed helm, sword raised absorbing golden light, cape flowing" },
  @{ id="SF001-067"; d="D"; c=$HOOD; p="an angelic warrior with luminous wings, fully robed with a radiant raised hood hiding the face, descending from sunrise clouds" },
  @{ id="SF001-271"; d="D"; c=$HOOD; p="a choir of deeply hooded angelic figures with faces hidden in golden light, wings folded, streaming radiance, eerie serenity" },
  @{ id="SF001-273"; d="D"; c=$HOOD; p="a fully robed hooded angel with wings descending gently from sunrise clouds toward a battlefield, light preceding like a blade, face hidden" },
  @{ id="SF001-061"; d="D"; c=$HELM; p="a young soldier in polished plate and a closed helm holding a spear at dawn, fortress gate" },
  @{ id="SF001-062"; d="D"; c=$HELM; p="a knight in full ivory-and-gold plate armor and closed helm holding a radiant tower shield, sunrise over marble walls, banners" },
  @{ id="SF001-065"; d="D"; c=$HELM; p="helmeted knights in full armor bearing a glowing lantern-staff marching through morning mist" },
  @{ id="SF001-262"; d="D"; c=$HELM; p="a helmeted knight in full armor drawing a blade of pure dawn light at first sunrise, dew on armor" },
  @{ id="SF001-263"; d="D"; c=$BEHIND; p="an armored, helmeted standard-bearer raising a golden banner with a halo sigil, seen from behind, troops below" },
  @{ id="SF001-266"; d="D"; c=$BEHIND; p="an armored, helmeted soldier kneeling in prayer as light gathers around clasped gauntlets, camp at dawn, seen from behind" },
  @{ id="SF001-267"; d="D"; c=$HELM; p="a guard in full plate and closed helm standing before an ancient never-opened golden door, spear crossed" },
  @{ id="SF001-270"; d="D"; c=$HOOD; p="a hooded angelic sentinel hovering with a halo rotating like a golden key, face hidden, wings spread" },
  # ---- Gloom rares/humanoids ----
  @{ id="SF001-085"; d="G"; p="a spectral wraith of shadow and tattered cloth with a pale glowing scythe and an empty dark hood where a face should be, moonlit hollow, non-human" },
  @{ id="SF001-087"; d="G"; p="colossal horror giant stitched from shadow and bone rising from a black pit, no human face" },
  @{ id="SF001-288"; d="G"; p="immense shadow giant stitched from discarded armor and darkness looming over a city wall, no human face" },
  @{ id="SF001-292"; d="G"; p="a scythe-bearing wraith with an empty hood harvesting glowing motes at midnight, methodical, non-human" },
  @{ id="SF001-291"; d="G"; c=$BEHIND; p="a hooded ancient warden placing a glowing hand on a cracking dark seal, a thousand candles behind, seen from behind" },
  @{ id="SF001-082"; d="G"; c=$HOOD; p="a hooded assassin emerging from shadow with curved daggers, face entirely hidden in darkness, moonlit alley" },
  @{ id="SF001-282"; d="G"; c=$HOOD; p="a deeply hooded cultist clutching a candle whose flame bends toward the hood, face hidden, whispering shadows" },
  @{ id="SF001-293"; d="G"; c=$BEHIND; p="a hooded mortal signing a shadow contract, quill drawing from their own faint glow, patient darkness waiting, seen from behind" }
)
$headers = @{ "Authorization" = "Token $env:REPLICATE_API_TOKEN"; "Content-Type" = "application/json"; "Prefer" = "wait" }
$outDir = "C:\TCG Claude\app\assets\art"
$ok = 0; $fail = 0
foreach ($card in $cards) {
  $concl = if ($card.ContainsKey('c')) { ", $($card.c)" } else { "" }
  $prompt = "$anchor, $($card.p)$concl, $($pal[$card.d])"
  $body = @{ input = @{ prompt = $prompt; aspect_ratio = "3:2"; num_outputs = 1; output_format = "webp"; output_quality = 95 } } | ConvertTo-Json -Depth 5
  $done = $false
  for ($try = 1; $try -le 3 -and -not $done; $try++) {
    try {
      $r = Invoke-RestMethod -Uri "https://api.replicate.com/v1/models/black-forest-labs/flux-dev/predictions" -Method Post -Headers $headers -Body $body -TimeoutSec 200
      $url = $r.output | Select-Object -First 1
      if ($url) { Invoke-WebRequest -Uri $url -OutFile (Join-Path $outDir "$($card.id).webp") | Out-Null; $done = $true }
      else { Start-Sleep 3 }
    } catch { Start-Sleep 4 }
  }
  if ($done) { $ok++ } else { $fail++; Write-Output "$($card.id) FAILED" }
}
Write-Output "DONE ok=$ok fail=$fail"
