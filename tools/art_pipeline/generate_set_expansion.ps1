# Art for the 65 expansion cards of "The Sundering". FLUX schnell, 3:2.
$ErrorActionPreference = "Continue"
$env:REPLICATE_API_TOKEN = (Get-ItemProperty "HKCU:\Environment").REPLICATE_API_TOKEN
$anchor = "epic fantasy trading card game illustration, painterly digital art, dramatic cinematic lighting, rich saturated colors, detailed brushwork, clean composition with clear focal subject, atmospheric depth, no text, no watermark, no border, no frame"
$pal = @{
  V = "verdant forest tones, emerald and moss green palette, bioluminescent accents, moonlit canopy"
  P = "volcanic orange and crimson palette, ember glow, ash-filled air, heat shimmer"
  T = "deep ocean blues and teals, arcane cyan glow, mist and water spray"
  D = "golden hour light, ivory and gold palette, radiant glow, abstract sun sigils, marble architecture"
  G = "deep violet and black palette, pale moonlight, thorns and shadow tendrils"
}
$cards = @(
  @{ id="SF001-201"; d="V"; p="majestic colossal elk god with crown-like glowing antlers and moss-covered hide, ancient king of the forest standing among giant roots, aura of authority" },
  @{ id="SF001-202"; d="V"; p="hooded elf druid kneeling with hand on glowing tree roots, soft light passing between fingers and soil" },
  @{ id="SF001-203"; d="V"; p="enormous giant made of moss and boulders slowly rising from a hillside, birds scattering" },
  @{ id="SF001-204"; d="V"; p="elegant elf archer perched in tree branches drawing a bow of living wood, glowing arrow" },
  @{ id="SF001-205"; d="V"; p="small luminous oak sapling growing atop ancient stone circle, protective ward of light around it" },
  @{ id="SF001-206"; d="V"; p="gentle rain of glowing green droplets falling over wounded warriors in a forest clearing, healing light" },
  @{ id="SF001-207"; d="V"; p="whip of thorned vines lashing out in an arc, torn leaves in the air, motion blur" },
  @{ id="SF001-208"; d="V"; p="forest animals and treefolk surging forward together in stampede, eyes glowing green, primal fury" },
  @{ id="SF001-209"; d="V"; p="stout treefolk sentinel with deep root legs planted in the forest floor, shield of bark" },
  @{ id="SF001-210"; d="V"; p="elf warrior in leaf-scale armor with twin curved blades, standing guard at forest border stones" },
  @{ id="SF001-211"; d="V"; p="towering ancient tree titan with a glowing heart visible in its chest through bark, canopy above the clouds" },
  @{ id="SF001-212"; d="V"; p="cornucopia of luminous fruits and flowers spilling from a hollow tree altar, fireflies" },
  @{ id="SF001-213"; d="V"; p="lone elf sentry on a high branch overlooking the moonlit forest sea, distant glow on the horizon" },
  @{ id="SF001-221"; d="P"; p="fierce female warrior champion with molten crown and blazing greatsword, commanding pose on a forge platform, embers swirling" },
  @{ id="SF001-222"; d="P"; p="young shaman apprentice tending a great forge fire with bare hands, sparks orbiting" },
  @{ id="SF001-223"; d="P"; p="sleek drake with wings of cinder and smoke banking through volcanic canyon" },
  @{ id="SF001-224"; d="P"; p="armored war hound with magma cracks along its hide sprinting across ash plains" },
  @{ id="SF001-225"; d="P"; p="apocalyptic storm of fire tornadoes sweeping a battlefield, silhouetted armies" },
  @{ id="SF001-226"; d="P"; p="spear of solid lava mid-flight trailing molten droplets, target glowing in distance" },
  @{ id="SF001-227"; d="P"; p="zealot warrior with sun-forge brand glowing on chest, twin axes, fanatic devotion" },
  @{ id="SF001-228"; d="P"; p="djinn of white flame and smoke uncoiling from a cracked forge, grinning" },
  @{ id="SF001-229"; d="P"; p="colossal titan of cooling lava and obsidian plates wading through a burning city" },
  @{ id="SF001-230"; d="P"; p="acrobatic fire dancer mid-leap trailing ribbons of flame, festival of embers at night" },
  @{ id="SF001-231"; d="P"; p="sacred eternal flame in an ancient brazier shaped like a heart, pulsing light, kneeling silhouettes" },
  @{ id="SF001-232"; d="P"; p="warband raising weapons as a wave of fiery light passes over them, battle cry" },
  @{ id="SF001-233"; d="P"; p="pillar of white-hot judgment fire striking down from the sky onto a battlefield" },
  @{ id="SF001-241"; d="T"; p="elderly sage in flowing robes of woven water standing in a vast underwater library, floating glowing books, worried expression" },
  @{ id="SF001-242"; d="T"; p="merfolk scribe writing with light on floating water-glass pages, coral desk" },
  @{ id="SF001-243"; d="T"; p="sentinel construct grown from pearl and coral, glowing core, harbor gate" },
  @{ id="SF001-244"; d="T"; p="massive djinn of storm clouds and rain towering over the ocean, lightning in its chest" },
  @{ id="SF001-245"; d="T"; p="young mage's eyes reflecting a brief vision of a vast cosmic song, water suspended around her" },
  @{ id="SF001-246"; d="T"; p="colossal tidal wave curling over a fleet of ships, arcane runes glowing in the water" },
  @{ id="SF001-247"; d="T"; p="nightmarish deep sea horror with too many glowing eyes rising from black water" },
  @{ id="SF001-248"; d="T"; p="merfolk mage binding a struggling warrior in ropes of living water" },
  @{ id="SF001-249"; d="T"; p="page of glowing text dissolving into water droplets, quill hovering, empty archive shelf" },
  @{ id="SF001-250"; d="T"; p="calm mystic meditating inside a sphere of slowly rotating water shields" },
  @{ id="SF001-251"; d="T"; p="two identical sages facing each other across a mirror of water, one older, library background" },
  @{ id="SF001-252"; d="T"; p="merfolk rider surfing a wind-wave high above the sea, spear of coral" },
  @{ id="SF001-253"; d="T"; p="vast underwater archive hall with infinite shelves of glowing tablets, god rays through water" },
  @{ id="SF001-261"; d="D"; p="serene angelic champion with vast luminous wings and a halo shaped like an intricate golden lock, floating above a marble spire, bittersweet expression" },
  @{ id="SF001-262"; d="D"; p="knight drawing a blade of pure dawn light at first sunrise, dew on armor" },
  @{ id="SF001-263"; d="D"; p="soldier raising a golden banner embroidered with a halo sigil, troops rallying below" },
  @{ id="SF001-264"; d="D"; p="gigantic marble construct kneeling before a sealed vault door beneath a sun temple" },
  @{ id="SF001-265"; d="D"; p="beam of judgment light striking a battlefield, a dark figure dissolving into motes" },
  @{ id="SF001-266"; d="D"; p="soldier kneeling in morning prayer as light gathers around clasped hands, camp at dawn" },
  @{ id="SF001-267"; d="D"; p="stoic guard standing before an ancient never-opened golden door, spear crossed" },
  @{ id="SF001-268"; d="D"; p="small spirit of light with swift wings carrying a sealed glowing letter over rooftops at dawn" },
  @{ id="SF001-269"; d="D"; p="knight swearing an oath with hand on a glowing tome, five signatures burning on the page" },
  @{ id="SF001-270"; d="D"; p="angelic sentinel hovering in place, its halo rotating like a golden key mechanism" },
  @{ id="SF001-271"; d="D"; p="choir of angels with mouths open in silent song, golden light streaming, no sound lines, eerie serenity" },
  @{ id="SF001-272"; d="D"; p="circle of consecrated ground glowing warm gold, wounded soldiers resting whole again" },
  @{ id="SF001-273"; d="D"; p="angel descending gently from sunrise clouds toward a battlefield, light preceding her like a blade" },
  @{ id="SF001-281"; d="G"; p="regal dark queen in layered violet veils with a crown of blackened silver, holding a glowing seal-sigil, weary determined eyes, ravens" },
  @{ id="SF001-282"; d="G"; p="hooded cultist clutching a candle whose flame bends toward him, whispering shadows" },
  @{ id="SF001-283"; d="G"; p="ghoul climbing from a tidy bone pile in organized catacombs, lantern light" },
  @{ id="SF001-284"; d="G"; p="sleek shade spirit gliding between moonbeams, barely visible, violet wisps" },
  @{ id="SF001-285"; d="G"; p="gentle undead figure carrying a lantern of sickly green plague light through a village" },
  @{ id="SF001-286"; d="G"; p="ghostly mouths whispering from graveyard soil, violet mist forming words" },
  @{ id="SF001-287"; d="G"; p="single black flower blooming explosively with deadly violet pollen, skeleton of a deer nearby" },
  @{ id="SF001-288"; d="G"; p="immense shadow giant stitched from discarded armor and darkness looming over a city wall" },
  @{ id="SF001-289"; d="G"; p="banquet table of shadow where ghostly hands feast on streams of light" },
  @{ id="SF001-290"; d="G"; p="veil of thorned shadow roses ensnaring a knight, petals drawing glowing droplets" },
  @{ id="SF001-291"; d="G"; p="ancient warden woman placing her glowing hand on a cracking dark seal, a thousand candles behind her" },
  @{ id="SF001-292"; d="G"; p="scythe-bearing wraith harvesting glowing leaks of light at midnight, methodical, calm" },
  @{ id="SF001-293"; d="G"; p="mortal signing a shadow contract, quill drawing from their own faint glow, patient darkness waiting" }
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
  if ($done) { $ok++ } else { $fail++; Write-Output "$($c.id) FAILED" }
}
Write-Output "DONE ok=$ok fail=$fail"
