# Dedicated storyboard art for every story beat. Scenes favour landscapes /
# creatures; any humanoid uses a modesty clause (hooded / from behind / silhouette).
#
# Pass -Only to regenerate a subset instead of the whole campaign:
#   .\generate_story_art.ps1 -Only STORY-ch1-12,STORY-ch1-13
#   .\generate_story_art.ps1 -Only 'STORY-ch1-*'
param([string[]]$Only)
$ErrorActionPreference = "Continue"
$env:REPLICATE_API_TOKEN = (Get-ItemProperty "HKCU:\Environment").REPLICATE_API_TOKEN
. "$PSScriptRoot\ArtProvider.ps1"
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
  # ── Chapter I — twenty scenes, one per beat ──────────────────────────────
  @{ id="STORY-ch1-01"; d="V"; p="an ancient moonlit primeval forest, a colossal World-Oak glowing with emerald light in its roots, mist between giant trunks, a great stag guardian with luminous antlers standing alert in the distance, no human figure" },
  @{ id="STORY-ch1-02"; d="V"; p="a perfectly bare circular clearing in a lush moonlit forest where nothing grows, the soil grey and refusing, healthy ferns stopping dead at its edge, faint violet taint, no human figure" },
  @{ id="STORY-ch1-03"; d="V"; p="a tiny glowing sapling-spirit of moss and green light standing at a great root-line, looking up at enormous ancient roots, bioluminescent motes, tender and small, non-human" },
  @{ id="STORY-ch1-04"; d="G"; c=$BEHIND; p="a lone hooded traveller in heavy mud-caked robes staggering out of a black southern marsh into a moonlit treeline, dragging mist and rot behind, exhausted" },
  @{ id="STORY-ch1-05"; d="G"; c=$BEHIND; p="a fully armored hooded scout halted among night ferns holding a knotted measuring cord, turning to look up at a colossal distant oak, cold moonlight, no visible face" },
  @{ id="STORY-ch1-06"; d="G"; c=$HOOD; p="a deeply hooded herald in tattered dark robes standing on a narrow deer-path at dusk with both hands open and empty, forest closing in behind, pale violet mist" },
  @{ id="STORY-ch1-07"; d="V"; p="a great luminous stag walking away into deep moonlit forest with its antlers lowered, seen from behind, refusing to answer, cold mist between trunks, no human figure" },
  @{ id="STORY-ch1-08"; d="V"; p="an unrolled oilcloth map lit by low firelight showing an intricate network of tree roots and hollows drawn in ink, a carrion nest of sticks and bone around it, no human figure" },
  @{ id="STORY-ch1-09"; d="G"; c=$BEHIND; p="a disciplined formation of fully armored helmeted warriors advancing up a narrow forest deer-path at night in matched colours, spears level, no visible faces" },
  @{ id="STORY-ch1-10"; d="G"; p="a bared armored forearm with black corruption spreading in branching veins beneath the skin, pulsing faintly violet, gauntlet removed, close study, no face visible" },
  @{ id="STORY-ch1-11"; d="V"; p="ancient thousand-year forest trees standing drowned in a black bog that has risen overnight, still water to the trunks, dead reflections, silent, no human figure" },
  @{ id="STORY-ch1-12"; d="D"; c=$BEHIND; p="a column of golden armored helmeted knights with white and gold banners cresting a moonlit forest ridgeline, radiant sigils, cold discipline" },
  @{ id="STORY-ch1-13"; d="G"; p="a high ridge view at night of two separate excavation sites glowing far below on opposite sides of a colossal oak, violet lanterns to the south and golden fires to the east, converging, no clear figures" },
  @{ id="STORY-ch1-14"; d="G"; p="ancient weathered battlefield bones and shattered armour tangled deep among colossal tree roots underground, a stone grave-slab half swallowed by wood, faint violet glow, no living figure" },
  @{ id="STORY-ch1-15"; d="G"; c=$BEHIND; p="a silent column of hooded forest wardens walking south in step through night ferns, black corruption veining their hands, seen from behind, no faces" },
  @{ id="STORY-ch1-16"; d="G"; c=$BEHIND; p="a sword planted upright at the lip of a black excavated shaft under a colossal oak, a lone hooded figure descending into the dark below without a torch" },
  @{ id="STORY-ch1-17"; d="G"; p="a formless mass of shadow and pale mist rising out of a black shaft beneath enormous roots, vaguely shaped like a person but wrong, no face, cold violet light, non-human" },
  @{ id="STORY-ch1-18"; d="G"; c=$HOOD; p="a regal deeply hooded sovereign in layered violet veils working at the mouth of a black shaft with pale corpses stacked around her like sandbags, filling it in, moonlit" },
  @{ id="STORY-ch1-19"; d="V"; p="an enormous luminous stag charging at full speed through moonlit forest, antlers lowered, emerald light trailing, fury and grief, no human figure" },
  @{ id="STORY-ch1-20"; d="G"; c=$HOOD; p="a final confrontation at the roots of a colossal oak, a deeply hooded sovereign in violet veils facing the viewer across a sealed black shaft, dark seal-sigil blazing, storm of leaves, moonlit" },
  # ── Chapter II — Ashmar, the dying forge ─────────────────────────────────
  @{ id="STORY-ch2-01"; d="P"; p="a vast volcanic city built around a colossal heart-shaped forge fire the size of a cathedral, its flame guttering low to a dull dying coal, wet grey ash and cold rain over obsidian towers, no human figure" },
  @{ id="STORY-ch2-02"; d="P"; c=$BEHIND; p="a long queue of heavily cloaked hooded figures waiting in a cold ash-covered volcanic street for a single glowing warming-stone, breath steaming, four streets deep, no visible faces" },
  @{ id="STORY-ch2-03"; d="P"; c=$BEHIND; p="a massive armored warlord in horned obsidian plate reading a decree from the steps of a great forge, seen from behind above a silent crowd, dull red firelight, no visible face" },
  @{ id="STORY-ch2-04"; d="P"; c=$HOOD; p="a lone deeply hooded figure in heavy mourning robes waiting at a volcanic hold gate with a dead smith's heavy tools strapped across her back, cold ash falling" },
  @{ id="STORY-ch2-05"; d="P"; p="a long jagged wound in a caldera floor breathing slow warm air, faint crimson glow pulsing out of it in even pushes like lungs, ash swirling at the lip, no human figure" },
  @{ id="STORY-ch2-06"; d="T"; p="a ring of dark deep-sea warships encircling a volcanic harbour at dawn, every hull facing outward away from the city, no shots fired, cold grey sea, no clear figures" },
  @{ id="STORY-ch2-07"; d="T"; c=$HOOD; p="a deeply hooded archivist robed to the fingertips coming ashore alone on a black volcanic beach holding a glowing coral staff, no weapon, deep blue light against ash" },
  @{ id="STORY-ch2-08"; d="T"; p="a vast measuring chart of a volcano's interior drawn in glowing cyan ink on dark vellum, the numbers refusing to add up, a coral stylus resting on it, no human figure" },
  @{ id="STORY-ch2-09"; d="P"; p="an entire hillside village burning at dusk, a single enormous column of bright smoke rising over a cold dark volcanic landscape, the brightest thing for miles, no clear figures" },
  @{ id="STORY-ch2-10"; d="P"; c=$BEHIND; p="a volcanic city split by hasty barricades of slag and iron, two banners facing each other across an ash street, armored hooded figures on both sides, no visible faces" },
  @{ id="STORY-ch2-11"; d="P"; p="a descent down a vast glowing crimson vein deep underground, walls pulsing red in a slow steady rhythm like a living heartbeat, tiny lantern light far below, no clear figure" },
  @{ id="STORY-ch2-12"; d="P"; p="an enormous underground chamber whose walls are not stone but slowly moving flesh-warm rock, faint crimson light between the folds, vast and patient, no human figure" },
  @{ id="STORY-ch2-13"; d="P"; p="crimson heat visibly draining away downward out of a great forge chamber, warmth withdrawing into the deep dark below instead of rising, cold blue creeping in at the edges, no human figure" },
  @{ id="STORY-ch2-14"; d="G"; c=$BEHIND; p="a lone armored figure walking calmly out of the deepest dark of an underground vein into lantern light, not out of breath, black corruption veining his exposed forearm, no visible face" },
  @{ id="STORY-ch2-15"; d="G"; p="enormous cloven hoofprints crossing fine grey volcanic ash on an underground chamber floor, coming from one dark tunnel and going toward a deeper one, lantern light, no living figure" },
  @{ id="STORY-ch2-16"; d="T"; p="a colossal sluice mechanism of coral and dark iron built to flood a volcanic vein with seawater, engineers' scaffolds around it, cold cyan glow, no clear figures" },
  @{ id="STORY-ch2-17"; d="P"; p="a colossal cathedral-sized forge fire seen from below, being deliberately allowed to die down, embers falling like slow snow, cold dark creeping in from the vault above, no human figure" },
  @{ id="STORY-ch2-18"; d="P"; p="a colossal forge fire stoked to blinding white heat, entire wagon-loads of timber feeding it, the whole caldera lit harsh white, violent and desperate, no clear figures" },
  @{ id="STORY-ch2-19"; d="G"; c=$BEHIND; p="a lone armored figure standing braced in a narrow burning doorway holding it shut from the inside, black corruption climbing his neck, white forge-light blazing behind, no visible face" },
  @{ id="STORY-ch2-20"; d="P"; c=$BEHIND; p="a massive armored warlord in horned obsidian plate waiting at the top of a long forge stair with a blinding white forge roaring behind him, seen from behind and below, no visible face" },
  # ── Chapter III — Meridine, the erased archive ───────────────────────────
  @{ id="STORY-ch3-01"; d="T"; p="a floating city upon a vast underwater library, endless shelves of glowing tablets descending into deep water further than light reaches, crepuscular rays, no human figure" },
  @{ id="STORY-ch3-02"; d="T"; p="a single glowing stone tablet in a dark flooded vault with its ink visibly thinning away letter by letter into nothing, half the text already gone, cold cyan light, no human figure" },
  @{ id="STORY-ch3-03"; d="G"; c=$HOOD; p="a deeply hooded infiltrator in dark clinging robes standing empty-handed among drowned library shelves, carrying no bag and stealing nothing, violet glow in cyan water" },
  @{ id="STORY-ch3-04"; d="T"; p="a quiet flooded reading room with one tablet on a stone table, a single line of its glowing text dissolving mid-sentence, ripples in still black water, no human figure" },
  @{ id="STORY-ch3-05"; d="T"; p="a sealed official scroll with a heavy wax seal sinking slowly into black vault water, cyan light above it, unread and now unreadable, no human figure" },
  @{ id="STORY-ch3-06"; d="D"; p="a line of golden Aurelian warships breaking straight through a harbour boom chain into a floating archive city, white and gold sails, cold discipline, no clear figures" },
  @{ id="STORY-ch3-07"; d="D"; c=$BEHIND; p="a column of golden armored helmeted knights descending purposefully past nine centuries of drowned glowing library shelves, torch-light on gold, no visible faces" },
  @{ id="STORY-ch3-08"; d="T"; p="one small stone contract tablet alone on an enormous empty shelf built for six hundred, five distinct seal-marks pressed into it, cold blue vault light, no human figure" },
  @{ id="STORY-ch3-09"; d="T"; c=$HOOD; p="a deeply hooded archivist in heavy robes drawing a stylus across a glowing tablet and unmaking its text, the letters coming apart into cold blue motes, solemn office" },
  @{ id="STORY-ch3-10"; d="G"; p="a hidden second library one shelf below the first, its tablets full of writing nobody living has written, violet glow beneath cyan, endless and patient, no human figure" },
  @{ id="STORY-ch3-11"; d="T"; p="enormous cloven hoofprints crossing pale silt on a deep seabed beneath library shelves, the water above them completely undisturbed, cold blue light, no living figure" },
  @{ id="STORY-ch3-12"; d="G"; p="a great chart of five distant cities each drawn sitting directly on top of a dark doorway, drawn in an inhuman hand, violet ink on dark vellum, no human figure" },
  @{ id="STORY-ch3-13"; d="G"; p="an ancient contract tablet whose blank clause is suddenly full of nine hundred year old glowing script, violet light bleeding from the letters, no human figure" },
  @{ id="STORY-ch3-14"; d="G"; p="four short lines of ancient glowing script alone in a lightless vault, five faded seal-marks beneath them, cold violet and cyan, solemn, no human figure" },
  @{ id="STORY-ch3-15"; d="D"; c=$BEHIND; p="golden armored figures loading glowing library shelves onto barges by torchlight in a flooded vault, crates and cranes, hurried triumph, no visible faces" },
  @{ id="STORY-ch3-16"; d="T"; p="a single line of ancient script violently struck through by a different older shakier hand, the name beneath it unreadable forever, cold blue light, no human figure" },
  @{ id="STORY-ch3-17"; d="G"; p="every tablet in a vast drowned library going blank at once from the deepest shelf upward, a rising tide of pure blankness swallowing the glowing text, no human figure" },
  @{ id="STORY-ch3-18"; d="T"; c=$HOOD; p="a deeply hooded robed archivist standing alone in a flooded vault as her own outline comes apart into cold blue motes from the hem upward, deliberate and calm" },
  @{ id="STORY-ch3-19"; d="G"; p="an empty absence in the exact shape of a person, wearing hooded archivist robes that hang on nothing at all, cold violet light in a drowned vault, non-human" },
  @{ id="STORY-ch3-20"; d="G"; p="a towering shape of pure blankness and unwritten paper rising through a drowned library, shelves emptying into it, violet and cold cyan, faceless, non-human" },
  # ── Chapter IV — Aurelia, the hollow halo ────────────────────────────────
  @{ id="STORY-ch4-01"; d="D"; p="a radiant city of gold and ivory towers under a great golden halo-ring that casts no shadows anywhere, unnaturally even light, marble spires, no human figure" },
  @{ id="STORY-ch4-02"; d="D"; p="an immense sanctum wall covered end to end in nine hundred years of gold-leaf edicts and laws, oppressive radiance, no human figure" },
  @{ id="STORY-ch4-03"; d="D"; p="a great golden halo-ring stuttering and dimming above a marble city, and for one breath every spire casts a long black shadow, no human figure" },
  @{ id="STORY-ch4-04"; d="D"; c=$BEHIND; p="a triumphal procession carrying loaded library shelves through an enormous ivory gate, golden armored helmeted knights escorting barge-crates, no visible faces" },
  @{ id="STORY-ch4-05"; d="D"; c=$HOOD; p="a deeply hooded robed keeper burning a small handful of gold-leaf pages in a brazier in a marble alcove at night, secret and unhurried, golden embers" },
  @{ id="STORY-ch4-06"; d="D"; p="a colossal golden halo-ring seen close, revealed to be an intricate mechanism of interlocking rings under visible strain, hairline cracks, radiant gold, no human figure" },
  @{ id="STORY-ch4-07"; d="D"; p="a golden ray of light traced from a marble spire down into a dark hole in the earth, showing the light comes from below and not above, radiant and unsettling, no human figure" },
  @{ id="STORY-ch4-08"; d="D"; c=$BEHIND; p="golden armored helmeted figures advancing down a marble colonnade carrying an immense unrolled charge scroll, cold radiant light, no visible faces" },
  @{ id="STORY-ch4-09"; d="G"; p="an enormous ivory city gate being closed for the first time in nine hundred years while a formless shadow waits outside it in broad daylight, violet against gold, non-human" },
  @{ id="STORY-ch4-10"; d="D"; p="gold leaf letters lifting off an immense wall of edicts and hanging in the air of a marble sanctum in a vast glittering swarm, the wall going blank behind them, no human figure" },
  @{ id="STORY-ch4-11"; d="D"; p="an endless marble spiral stair climbing inside a golden spire, radiant light above and creeping shadow below, utterly empty, no human figure" },
  @{ id="STORY-ch4-12"; d="D"; c=$BEHIND; p="a landing on a marble stair held by forty golden armored helmeted knights in close formation, a flickering halo above them, no visible faces" },
  @{ id="STORY-ch4-13"; d="D"; p="a fallen golden helm and a dropped sword on marble stairs beneath a flickering halo, blood-gold light, an argument ended, no living figure" },
  @{ id="STORY-ch4-14"; d="G"; p="an ancient lock-mechanism of gold whose measured span has visibly run out, its final graduation passed eleven marks ago, violet corrosion at the edge, no human figure" },
  @{ id="STORY-ch4-15"; d="V"; p="an enormous luminous stag standing on a marble stair inside a golden spire, flanks steaming in cold air, emerald light against gold, calm and terrible, no human figure" },
  @{ id="STORY-ch4-16"; d="V"; p="a colossal ancient oak grave-slab remembered in emerald light, a great stag lying beside it through a thousand seasons of moon and snow, devotion and vigil, no human figure" },
  @{ id="STORY-ch4-17"; d="G"; p="a vast indistinct shape suggested at the very bottom of a shaft of golden light, too deep to resolve, violet dark closing around it, no clear figure" },
  @{ id="STORY-ch4-18"; d="G"; p="a colossal golden halo-ring tearing apart above a marble city, every shadow in the streets below suddenly pointing straight down, gold shattering to violet, no human figure" },
  @{ id="STORY-ch4-19"; d="D"; c=$HOOD; p="a deeply hooded robed keeper walking into the broken heart of a golden halo mechanism and being taken into it like a key into a lock, blinding radiance" },
  @{ id="STORY-ch4-20"; d="G"; p="a shattered golden halo hanging above a darkened marble city, violet shadow pouring through its broken ring and taking a vast faceless shape, non-human" },
  # ── Chapter V — Nyxhollow, the thankless vigil ───────────────────────────
  @{ id="STORY-ch5-01"; d="G"; p="a disciplined city of black spires under a violet moon with clean swept streets and full granaries, orderly watchfires at every gate, austere and well kept, no human figure" },
  @{ id="STORY-ch5-02"; d="G"; p="an immense hall of black glass ledgers stacked nine hundred years deep, every page a column of tally marks glowing faint violet, solemn, no human figure" },
  @{ id="STORY-ch5-03"; d="G"; p="an open black glass ledger whose final eleven entries are negative numbers written in a single steady hand, violet lamplight, quietly devastating, no human figure" },
  @{ id="STORY-ch5-04"; d="V"; p="an enormous luminous stag standing alone in the middle of a dark hall of black glass, giving an account of itself, violet and emerald light meeting, no human figure" },
  @{ id="STORY-ch5-05"; d="G"; p="a tall wall of carved names in black stone, exactly one name per generation for nine hundred years without a single gap, violet votive light, no human figure" },
  @{ id="STORY-ch5-06"; d="G"; p="the final freshly carved name at the bottom of a wall of names, pale stone dust still unswept on the floor beneath it, one small guttering lamp, no human figure" },
  @{ id="STORY-ch5-07"; d="G"; p="a great violet shard hanging in a shaft of still air beneath a city, pulsing unevenly and stuttering like something breathing badly, black stone all around, no human figure" },
  @{ id="STORY-ch5-08"; d="G"; c=$BEHIND; p="four travel-stained riders from four different distant realms arriving at a black city gate on the same day, banners of green, crimson, cyan and gold, no visible faces" },
  @{ id="STORY-ch5-09"; d="G"; p="a plain well-maintained stone stair descending into darkness beneath a city, its wooden handrail worn glass-smooth by nine hundred years of hands, humble and holy, no human figure" },
  @{ id="STORY-ch5-10"; d="G"; p="a long descending stair where every landing holds a small oil lamp carefully lit and tended, a line of warm lights going down into deep black, no human figure" },
  @{ id="STORY-ch5-11"; d="G"; p="the last lit lamp on a descending stair with absolute lightless dark beginning one step below it, no human figure" },
  @{ id="STORY-ch5-12"; d="G"; c=$HOOD; p="a small deeply hooded robed figure sitting with her back against bare stone in a lightless chamber, hands open and still on her knees, awake, one distant lamp" },
  @{ id="STORY-ch5-13"; d="G"; p="two overlapping voices rendered as two violet light-forms sharing one outline and beginning to blur into each other, cold stone chamber, non-human" },
  @{ id="STORY-ch5-14"; d="G"; c=$HOOD; p="a deeply hooded robed woman half embedded in ancient stone in a deep chamber, fully covered in heavy cloth, turning her head toward the viewer after a thousand years, faint violet glow" },
  @{ id="STORY-ch5-15"; d="G"; p="an utterly empty chamber of plain stone beneath an ancient grave, absolutely nothing buried there, dust and silence, quietly shocking, no human figure" },
  @{ id="STORY-ch5-16"; d="G"; p="a vast storm of violet light and formless voice sweeping across five distant landscapes at once, forest and volcano and sea and marble and black spires, non-human" },
  @{ id="STORY-ch5-17"; d="V"; p="an enormous luminous stag standing at an ancient stone offering itself, emerald light against violet dark, refused and grieving, no human figure" },
  @{ id="STORY-ch5-18"; d="G"; c=$HOOD; p="two deeply hooded robed figures in a lightless stone chamber, one rising to leave and one sitting down in her place with hands open on her knees, violet glow, solemn handover" },
  @{ id="STORY-ch5-19"; d="G"; p="nine hundred years of accumulated unanswered voice erupting as a colossal violet storm-shape in a deep stone chamber, faceless and enormous, non-human" },
  @{ id="STORY-ch5-20"; d="G"; p="a colossal violet heart-shard blazing above a black city while a vast faceless shape of shadow and voice wears it like a crown, storm and lightning, non-human" }
)
$headers = @{ "Authorization" = "Token $env:REPLICATE_API_TOKEN"; "Content-Type" = "application/json"; "Prefer" = "wait" }
$outDir = "C:\TCG Claude\app\assets\art"
$ok = 0; $fail = 0
foreach ($b in $beats) {
  if ($Only -and -not ($Only | Where-Object { $b.id -like $_ })) { continue }
  $concl = if ($b.ContainsKey('c')) { ", $($b.c)" } else { "" }
  $prompt = "$anchor, $($b.p)$concl, $($pal[$b.d])"
  $body = @{ input = @{ prompt = $prompt; aspect_ratio = "3:2"; num_outputs = 1; output_format = "webp"; output_quality = 95 } } | ConvertTo-Json -Depth 5
  # Replicate first; ArtProvider falls back to fal.ai on a quota refusal.
  $provider = Invoke-CardArt -Prompt $prompt -OutFile (Join-Path $outDir "$($b.id).webp") -Model dev
  $done = $null -ne $provider
  if ($done) { $ok++; Write-Output "$($b.id) OK" } else { $fail++; Write-Output "$($b.id) FAILED" }
}
Write-Output "DONE ok=$ok fail=$fail"
