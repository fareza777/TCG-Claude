# Face concealment pass.
#
# A full visual audit of all 293 shipped arts (192 cards, 100 story frames,
# 1 arena) found 17 cards that still render a complete human likeness, or bare
# skin. The story frames and the arena frame are clean -- every figure there is
# hooded, helmed, seen from behind, or a silhouette -- so nothing outside this
# list is touched.
#
# regen_hybrid_modest.ps1 already carried the right clauses, but it was driven
# by a hand-written list of cards and these 17 were never on it (or, for
# SF001-264, were on it and the result never landed). The list below is not
# guesswork: each id was opened and looked at.
#
# The concealment is chosen per card rather than applied uniformly. A hood on
# every card would flatten five dominions into one silhouette, so a Dawn knight
# gets a closed helm, a Verdance tree-guardian gets bark where a face was, a
# Tide ritual loses its figure entirely, and only the cards that read as robed
# mystics get a hood. Where a card has no reason to show a person at all, the
# person is removed instead of covered -- the cleanest fix available.
#
# No backup folder: git holds the previous images, so
# `git checkout HEAD -- app/assets/art/SF001-091.webp` restores one.
param([string[]]$Only)   # e.g. -Only SF001-364 ; omit to run every card below
$ErrorActionPreference = "Continue"
$env:REPLICATE_API_TOKEN = (Get-ItemProperty "HKCU:\Environment").REPLICATE_API_TOKEN
. "$PSScriptRoot\ArtProvider.ps1"

$anchor = "epic fantasy trading card game illustration, painterly digital art, dramatic cinematic lighting, rich saturated colors, detailed brushwork, clean composition with clear focal subject, atmospheric depth, no text, no watermark, no signature, no border, no frame"

# Concealment clauses. Stated as what the image *is*, not what it lacks --
# diffusion models follow "hidden in shadow" far better than "no face".
$HOOD   = "the figure is deeply hooded, face entirely hidden in solid shadow beneath the hood, no facial features whatsoever, fully robed in heavy concealing cloth, no exposed skin"
$HELM   = "clad head to toe in full plate armor with a closed visored helm, face completely concealed behind steel, no facial features visible, no exposed skin"
$BEHIND = "seen entirely from behind, head turned away, face not visible at all, fully clothed in concealing robes and armor"
$VEIL   = "the face is completely covered by a hanging veil of dark cloth, no facial features visible, fully robed from shoulder to floor, no exposed skin"
$NONE   = "no people, no figures, no faces anywhere in the image"

# Carried from regen_anatomy.ps1: the hands break when they are open and facing
# the viewer, so the poses below keep them gloved, gripping, or out of frame.
$ANAT = "anatomically correct with exactly two arms and exactly two hands, five fingers per hand, hands small and simple in the composition, no extra limbs, no extra fingers"

$pal = @{
  V = "verdant forest tones, emerald and moss green palette, bioluminescent accents, moonlit canopy"
  P = "volcanic orange and crimson palette, ember glow, ash-filled air, heat shimmer"
  T = "deep ocean blues and teals, arcane cyan glow, mist and water spray"
  D = "golden hour light, ivory and gold palette, radiant glow, abstract sun sigils, marble architecture"
  G = "deep violet and black palette, pale moonlight, thorns and shadow tendrils"
}

$cards = @(
  # ---- Faces removed by taking the person out of the frame ----

  # Was a bare human profile rendered in water. The card is "draw 2, opponent
  # discards" -- it never needed a person, and a vortex reads the effect better.
  @{ id="SF001-050"; d="T"; c=$NONE; p="a vast spiral vortex of clear water turning in mid-air, glowing script and torn page fragments caught in the spiral and dissolving as they turn, empty moonlit shore behind" },

  # Was a fully modelled human face made of storm cloud. Same storm, no face.
  @{ id="SF001-244"; d="T"; c=$NONE; p="a colossal towering thunderhead shaped like a rising wave over open ocean, a core of white lightning burning inside the cloud, rain sheeting down, featureless churning vapour, no face in the cloud" },

  # Was a pale bald face in profile at the table's edge. The card is about the
  # candles and the reaching hands -- the face was never the subject.
  #
  # First attempt kept the banquet table and asked for nobody at it. A table
  # that is "set" implies diners, and the model duly seated a dozen ghouls with
  # clear faces around it -- worse than the original. The table is gone: an
  # altar has no implied guests, so there is nothing for the model to fill in.
  @{ id="SF001-289"; d="G"; c=$NONE; p="a black stone altar in a deserted crypt, seven black candles burning with violet flame along it, a single tarnished chalice at the centre, pale disembodied spectral hands reaching in out of the surrounding darkness toward the flames, ribbons of ghost-light spiralling into the chalice, empty abandoned hall, no bodies, no heads, no faces" },

  # ---- Faces replaced with bark, stone or fire ----

  # Was a man's head on a treefolk body. Now the guardian is wholly of wood.
  @{ id="SF001-209"; d="V"; c=$NONE; p="a massive treefolk guardian standing braced before an ancient oak, its head a mass of bark and moss with a deep hollow knot where a face would be, no eyes and no mouth, no human features, broad shield of living wood held across its chest in both bark-covered hands, roots gripping the forest floor" },

  # Was a nude human figure kneeling, seen from behind. Now a carved construct:
  # the flavor line says it kneels at the spire, so the pose is kept.
  #
  # First attempt clothed it but gave it a bare human head: "a smooth blank
  # faceplate" still describes a face, and the model rendered the face and
  # ignored the blankness. Naming a helmet instead of a faceplate gives it an
  # object to draw, and turning the figure away removes the head from view
  # entirely -- belt and braces, because this one already failed once.
  @{ id="SF001-264"; d="D"; c=$BEHIND; p="a gigantic armoured colossus of white marble and gilded plate kneeling with its back to the viewer and its head bowed low before a sealed vault door beneath a sun temple, a featureless domed stone helm entirely enclosing its head, every surface carved stone and metal, no skin anywhere, shafts of light from high windows" },

  # Was a woman in a fitted gown with bare arms and shoulders. The flavor says
  # it *is* the fire, so the herald becomes fire rather than a body wearing it.
  @{ id="SF001-329"; d="P"; c=$NONE; p="a towering winged herald formed entirely out of living flame and floating ember, vast burning wings spread wide, the body a column of fire wrapped in charred drifting cloth, a dark hollow void where a head would be with no face and no features, erupting volcanic ridge below" },

  # ---- Hoods, veils and helms ----

  # Was a fully rendered human face with small horns.
  @{ id="SF001-031"; d="P"; c=$HOOD; p="a deeply hooded seer leaning over a low basin of burning coals, reading the shapes in the fire, burning sigils rising from the flames into the dark, gloved hands resting on the rim of the basin" },

  # Was a mermaid with bare arms and midriff. The flavor calls them couriers, so
  # the courier stays and the body is covered.
  @{ id="SF001-044"; d="T"; c=$BEHIND; p="a robed courier wrapped head to foot in layered teal travelling cloth riding astride a great winged ray as it banks over a storm-lit sea, satchel of sealed scrolls at their side, spray thrown up behind" },

  # Was an elder in profile plus kneeling figures with visible faces.
  @{ id="SF001-068"; d="D"; c=$BEHIND; p="a circle of deeply hooded robed figures kneeling with heads bowed to the floor around a font of rising golden light in a marble rotunda, all seen from behind, sun banners hanging between the columns" },

  # Was a bare-chested horned figure with a full human face.
  @{ id="SF001-089"; d="G"; c=$HOOD; p="a deeply hooded robed figure standing over an iron cauldron, drawing a rising column of violet flame upward out of it with one gloved hand, dead branches and full moon behind" },

  # Was Ravenna with a clear face and bare shoulders. She is already hooded and
  # veiled on SF001-281, so this brings her two cards into agreement.
  @{ id="SF001-091"; d="G"; c=$VEIL; p="Ravenna the veiled sovereign in layered violet robes and a blackened silver crown set over a heavy face-veil, holding out a glowing contract sealed with violet wax in gloved hands, ravens wheeling around her, bare thorn trees and full moon" },

  # Was two rangers, the nearer one bald with a clear profile.
  @{ id="SF001-206"; d="V"; c=$BEHIND; p="two hooded rangers in heavy green travelling cloaks kneeling with their backs to the viewer in a moonlit glade, heads bowed, glowing emerald rain falling in slow heavy drops through the canopy around them" },

  # Was a woman with bare arms on a surfboard.
  @{ id="SF001-252"; d="T"; c=$BEHIND; p="a fully robed hooded sentry wrapped in layered teal cloth riding the crest of an enormous breaking wave on a narrow board, seen from behind, long spear held level, gulls and spray against a bright sky" },

  # Was a clear male face over an open book.
  @{ id="SF001-269"; d="D"; c=$HELM; p="a warden in full golden plate and a closed visored helm leaning over a great open oath-book on a lectern, one gauntleted hand flat on the page and the other holding a small burning sun-sigil above it, dark chapel, candlelight" },

  # Was a clear face under the hood -- the hood was there, the shadow was not.
  #
  # First attempt kept the hood and the head-on portrait framing, and Flux lit
  # the face again: a front-facing close-up is the one composition where the
  # face is the subject, so no amount of shadow wording survives it. The card
  # has Soar, so the fix is a flying pose seen from behind -- the face is not
  # concealed, it is simply not in the picture.
  @{ id="SF001-364"; d="D"; c=$BEHIND; p="a winged cleric in a deep green hooded cloak and light scale armour seen from directly behind and slightly below, rising in flight away from the viewer, broad white and gold feathered wings spread wide, a small thin halo hanging above the raised hood, golden sky and distant clouds" },

  # Was an open-faced helm showing the whole face.
  @{ id="SF001-365"; d="D"; c=$HELM; p="a paladin in full golden plate and a closed visored helm standing square to the viewer, both gauntleted hands gripping the hilt of a radiant longsword held point-down before them, green cloak, sunlit hall" },

  # Was a clear bearded face inside the hood.
  @{ id="SF001-367"; d="D"; c=$HOOD; p="a confessor in heavy layered gold and olive robes with a deep raised hood, cradling a small golden vessel that throws a burst of light upward across the robes, marble colonnade behind" }
)

$outDir = "C:\TCG Claude\app\assets\art"

$ok = 0; $fail = 0
foreach ($card in $cards) {
  if ($Only -and ($Only -notcontains $card.id)) { continue }
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
