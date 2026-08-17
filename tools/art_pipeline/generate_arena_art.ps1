# Opening art for the Proving Gauntlet. Same modesty rules as the story
# pipeline: no clear faces, fully concealing armour or robes on any humanoid.
param([string[]]$Only)
$ErrorActionPreference = "Continue"
$env:REPLICATE_API_TOKEN = (Get-ItemProperty "HKCU:\Environment").REPLICATE_API_TOKEN
. "$PSScriptRoot\ArtProvider.ps1"
$anchor = "epic fantasy story illustration, cinematic key art, painterly digital art, dramatic atmospheric lighting, rich saturated colors, detailed brushwork, wide establishing shot, no text, no watermark, no border, no frame"
$BEHIND = "seen entirely from behind, face not visible, fully clothed in concealing armor and robes"
$beats = @(
  @{ id="ARENA-gauntlet"; c=$BEHIND; p="a vast torchlit underground fighting pit ringed by tiers of shadowed spectators, five dominion banners in emerald crimson cyan gold and violet hanging over the sand, a lone fully armored helmeted challenger walking out to the centre, dust and torch smoke, mixed warm and cold light" }
)
$outDir = "C:\TCG Claude\app\assets\art"
$ok = 0; $fail = 0
foreach ($b in $beats) {
  if ($Only -and -not ($Only | Where-Object { $b.id -like $_ })) { continue }
  $concl = if ($b.ContainsKey('c')) { ", $($b.c)" } else { "" }
  $prompt = "$anchor, $($b.p)$concl"
  $provider = Invoke-CardArt -Prompt $prompt -OutFile (Join-Path $outDir "$($b.id).webp") -Model dev
  if ($null -ne $provider) { $ok++; Write-Output "$($b.id) OK" } else { $fail++; Write-Output "$($b.id) FAILED" }
}
Write-Output "DONE ok=$ok fail=$fail"
