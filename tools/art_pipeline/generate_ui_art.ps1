# Generate the app icon only (the shattered five-colour star emblem).
# Menu tiles stay as translucent glass so the main background shows through.
$ErrorActionPreference = "Continue"
. "$PSScriptRoot\ArtProvider.ps1"
$ui = "C:\TCG Claude\app\assets\ui"
New-Item -ItemType Directory -Force $ui | Out-Null

$icon = "app icon logo emblem, a shattered crystalline multi-pointed star radiating five glowing colors emerald green ember orange ocean cyan radiant gold deep violet, centered on a dark obsidian rounded-square background with a subtle gold ring border, iconic, symmetrical, clean, highly detailed, premium mobile game icon, no text, no words, no letters"

function TryModel($model) {
  # Replicate first; ArtProvider falls back to fal.ai on a quota refusal.
  $tier = if ($model -like "*dev*") { "dev" } else { "schnell" }
  $out = Join-Path $ui "app_icon.png"
  return $null -ne (Invoke-CardArt -Prompt $icon -OutFile $out -Model $tier -AspectRatio "1:1" -OutputFormat png)
}

if (TryModel "black-forest-labs/flux-dev") { Write-Output "icon OK (dev)" }
elseif (TryModel "black-forest-labs/flux-schnell") { Write-Output "icon OK (schnell)" }
else { Write-Output "icon FAIL" }
