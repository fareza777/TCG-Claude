# Checks that each art provider can actually render, without touching the
# shipped assets. Run this after rotating a key.
#
#   powershell -File tools\art_pipeline\verify_providers.ps1
#
# Each provider is called directly rather than through Invoke-CardArt, because
# the point is to prove both paths work — not to watch the fallback logic pick
# one of them.

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\ArtProvider.ps1"

$outDir = Join-Path $env:TEMP 'shardfall-art-check'
New-Item -ItemType Directory -Force $outDir | Out-Null

$prompt = 'epic fantasy trading card game illustration, painterly digital art, ' +
  'dramatic cinematic lighting, rich saturated colors, a lone armoured guardian ' +
  'seen from behind on a cliff edge overlooking a stormy valley, no text, no watermark'

function Show-Result {
  param([string]$Name, [string]$File, [string]$Error)
  if ($Error) {
    Write-Output ("{0,-10} FAIL  {1}" -f $Name, $Error)
    return
  }
  if (Test-Path $File) {
    $size = (Get-Item $File).Length
    Write-Output ("{0,-10} OK    {1} bytes -> {2}" -f $Name, $size, $File)
  }
  else {
    Write-Output ("{0,-10} FAIL  no file written" -f $Name)
  }
}

foreach ($provider in @('replicate', 'fal')) {
  $keyName = if ($provider -eq 'fal') { 'FAL_KEY' } else { 'REPLICATE_API_TOKEN' }
  if ([string]::IsNullOrWhiteSpace((Get-ArtSecret $keyName))) {
    Write-Output ("{0,-10} SKIP  {1} is not set" -f $provider, $keyName)
    continue
  }

  $file = Join-Path $outDir "$provider.webp"
  Remove-Item $file -ErrorAction SilentlyContinue
  $err = $null
  try {
    if ($provider -eq 'fal') {
      Invoke-FalArt -Prompt $prompt -OutFile $file -Model schnell `
        -AspectRatio '3:2' -OutputFormat webp | Out-Null
    }
    else {
      Invoke-ReplicateArt -Prompt $prompt -OutFile $file -Model schnell `
        -AspectRatio '3:2' -OutputFormat webp | Out-Null
    }
  }
  catch {
    $err = "$_"
  }
  Show-Result -Name $provider -File $file -Error $err
}

Write-Output ''
Write-Output "Images kept in $outDir for inspection; delete when done."
