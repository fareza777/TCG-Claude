# Anatomy repair pass.
#
# Five cards ship with malformed figures: a third hand, two six-fingered hands,
# one pair of fused hands, and one set of clawed fingers. Two of them
# (SF001-067, SF001-270) are already in regen_hybrid_modest.ps1 and came back
# broken anyway, so re-running the same prompt is not the fix.
#
# What changes here is the *composition*, not the wording. An open palm facing
# the viewer is the pose diffusion models fail at most often; hands wrapped
# around a haft, tucked into sleeves, or turned away from camera are far more
# reliable. Every prompt below removes the open-palm pose that broke.
#
# No backup folder: git already holds the previous images, so
# `git checkout HEAD -- app/assets/art/SF001-270.webp` restores one. A second
# copy inside app/assets would only be clutter that ships nowhere.
$ErrorActionPreference = "Continue"
$env:REPLICATE_API_TOKEN = (Get-ItemProperty "HKCU:\Environment").REPLICATE_API_TOKEN
. "$PSScriptRoot\ArtProvider.ps1"

$anchor = "epic fantasy trading card game illustration, painterly digital art, dramatic cinematic lighting, rich saturated colors, detailed brushwork, clean composition with clear focal subject, atmospheric depth, no text, no watermark, no signature, no border, no frame"

# Anatomy clause. Stated positively — models follow "exactly two" far better
# than they follow "not three".
$ANAT = "anatomically correct single figure with exactly two arms and exactly two hands, five fingers per hand, hands small and simple in the composition, no extra limbs, no duplicated arms, no extra fingers"

# Modesty clauses, carried unchanged from regen_hybrid_modest.ps1.
$HOOD   = "the figure is deeply hooded, face entirely hidden in shadow beneath the hood, fully robed in heavy concealing cloth, no visible face, no exposed skin"
$HELM   = "clad head to toe in full plate armor with a closed full helm, face completely concealed, no exposed skin"
$BEHIND = "seen entirely from behind, face not visible, fully clothed in concealing armor and robes"

$pal = @{
  V = "verdant forest tones, emerald and moss green palette, bioluminescent accents, moonlit canopy"
  P = "volcanic orange and crimson palette, ember glow, ash-filled air, heat shimmer"
  D = "golden hour light, ivory and gold palette, radiant glow, abstract sun sigils, marble architecture"
}

$cards = @(
  # Three hands: both arms were spread palms-out. Arms now hang inside sleeves.
  @{ id="SF001-270"; d="D"; c=$BEHIND; p="a winged sentinel in flowing golden vestments standing guard beneath a great halo of light, vast feathered wings spread wide, arms hanging straight down and completely hidden inside long draping sleeves, no hands visible, marble colonnade" },

  # Six fingers: the orb was cupped in two open palms. It floats unaided now.
  @{ id="SF001-302"; d="V"; c=$BEHIND; p="a deeply hooded druid seen from behind facing a glowing green seed-orb that floats unsupported in the air before them, arms lowered at their sides inside long sleeves, no hands visible, moonlit forest, drifting spores" },

  # Fused hands: arms hung at the sides in full view. Now folded away.
  @{ id="SF001-067"; d="D"; c=$HOOD; p="a robed winged herald in cream and gold vestments, arms folded across the chest with both hands tucked completely inside wide sleeves, no hands visible, radiant halo behind, clouds at dawn" },

  # Clawed trailing hand: the free hand was flung open mid-run. Two-handed grip.
  @{ id="SF001-022"; d="P"; c=$HELM; p="an armored raider in full plate and closed helm charging forward, gripping a single blackened greatsword with both gauntleted hands together on the hilt, no free hand, cloak streaming, cracked volcanic ground" },

  # Six-fingered gauntlet: the off hand was open. Both hands now on the haft.
  @{ id="SF001-025"; d="P"; c=$HELM; p="a berserker in heavy horned full-helm armor mid-charge, both gauntleted hands gripping the long haft of a great two-handed axe, no free hand, trail of fire behind, ash storm" }
)

$outDir = "C:\TCG Claude\app\assets\art"

$ok = 0; $fail = 0
foreach ($card in $cards) {
  $dest = Join-Path $outDir "$($card.id).webp"

  $concl  = if ($card.ContainsKey('c')) { ", $($card.c)" } else { "" }
  $prompt = "$anchor, $($card.p)$concl, $ANAT, $($pal[$card.d])"

  $provider = Invoke-CardArt -Prompt $prompt -OutFile $dest -Model dev
  if ($null -ne $provider) {
    $ok++
    Write-Output "$($card.id) OK via $provider"
  } else {
    $fail++
    Write-Output "$($card.id) FAILED"
  }
}
Write-Output "DONE ok=$ok fail=$fail"
