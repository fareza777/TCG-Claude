# Shared card-art generation with a provider fallback.
#
# Dot-source this from a generation script:
#
#   . "$PSScriptRoot\ArtProvider.ps1"
#   Invoke-CardArt -Prompt $prompt -OutFile $dest -Model schnell
#
# Replicate is the primary. When it refuses for a billing or rate reason —
# which is what running out of quota looks like — fal.ai is tried instead, so a
# long generation run does not die halfway with a half-filled asset folder.
#
# NEITHER KEY IS STORED HERE. Both are read from the environment, matching how
# the existing scripts already pick up REPLICATE_API_TOKEN. See
# docs/ART_PIPELINE.md for how to set them.

function Get-ArtSecret {
  param([string]$Name)
  # Session first, then the persisted user environment.
  $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, 'User')
  }
  return $value
}

# Errors that mean "this provider will not serve you right now", as opposed to
# a transient blip worth retrying on the same provider.
function Test-QuotaFailure {
  param($ErrorRecord)
  $status = $null
  try { $status = [int]$ErrorRecord.Exception.Response.StatusCode } catch { }
  if ($status -in 402, 429) { return $true }
  $text = "$ErrorRecord"
  return $text -match 'quota|billing|credit|insufficient|payment|rate limit|spend'
}

function Invoke-ReplicateArt {
  param(
    [string]$Prompt, [string]$OutFile, [string]$Model,
    [string]$AspectRatio, [string]$OutputFormat
  )

  $token = Get-ArtSecret 'REPLICATE_API_TOKEN'
  if ([string]::IsNullOrWhiteSpace($token)) { return $null }

  $slug = if ($Model -eq 'dev') { 'flux-dev' } else { 'flux-schnell' }
  $headers = @{
    'Authorization' = "Token $token"
    'Content-Type'  = 'application/json'
    'Prefer'        = 'wait'
  }
  $body = @{
    input = @{
      prompt         = $Prompt
      aspect_ratio   = $AspectRatio
      num_outputs    = 1
      output_format  = $OutputFormat
      output_quality = 90
    }
  } | ConvertTo-Json -Depth 5

  $uri = "https://api.replicate.com/v1/models/black-forest-labs/$slug/predictions"
  $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -TimeoutSec 180
  $url = $response.output | Select-Object -First 1
  if (-not $url) { throw 'Replicate returned no image' }
  Invoke-WebRequest -Uri $url -OutFile $OutFile | Out-Null
  return 'replicate'
}

function Invoke-FalArt {
  param(
    [string]$Prompt, [string]$OutFile, [string]$Model,
    [string]$AspectRatio, [string]$OutputFormat
  )

  $key = Get-ArtSecret 'FAL_KEY'
  if ([string]::IsNullOrWhiteSpace($key)) { return $null }

  $slug = if ($Model -eq 'dev') { 'fal-ai/flux/dev' } else { 'fal-ai/flux/schnell' }
  $headers = @{
    'Authorization' = "Key $key"
    'Content-Type'  = 'application/json'
  }
  # Mirror the primary's framing exactly, so a run that falls back mid-way does
  # not change shape or format between cards.
  $size = switch ($AspectRatio) {
    '1:1' { @{ width = 1024; height = 1024 } }
    '3:2' { @{ width = 1024; height = 683 } }
    '2:3' { @{ width = 683; height = 1024 } }
    '16:9' { @{ width = 1024; height = 576 } }
    default { @{ width = 1024; height = 683 } }
  }
  $body = @{
    prompt        = $Prompt
    image_size    = $size
    num_images    = 1
    output_format = $OutputFormat
  } | ConvertTo-Json -Depth 5

  $response = Invoke-RestMethod -Uri "https://fal.run/$slug" -Method Post -Headers $headers -Body $body -TimeoutSec 180
  $url = $response.images | Select-Object -First 1 -ExpandProperty url
  if (-not $url) { throw 'fal.ai returned no image' }
  Invoke-WebRequest -Uri $url -OutFile $OutFile | Out-Null
  return 'fal'
}

<#
.SYNOPSIS
  Renders one card illustration, falling back to fal.ai when Replicate is out.
.OUTPUTS
  The provider that produced the file ('replicate' or 'fal'), or $null on failure.
#>
function Invoke-CardArt {
  param(
    [Parameter(Mandatory)][string]$Prompt,
    [Parameter(Mandatory)][string]$OutFile,
    [ValidateSet('schnell', 'dev')][string]$Model = 'schnell',
    [string]$AspectRatio = '3:2',
    [ValidateSet('webp', 'png', 'jpeg')][string]$OutputFormat = 'webp',
    [int]$Attempts = 3
  )

  $quotaHit = $false

  for ($try = 1; $try -le $Attempts; $try++) {
    if (-not $quotaHit) {
      try {
        $result = Invoke-ReplicateArt -Prompt $Prompt -OutFile $OutFile -Model $Model `
          -AspectRatio $AspectRatio -OutputFormat $OutputFormat
        if ($result) { return $result }
        # No token configured; go straight to the fallback.
        $quotaHit = $true
      }
      catch {
        if (Test-QuotaFailure $_) {
          Write-Warning "Replicate is out of quota; switching to fal.ai."
          $quotaHit = $true
        }
        else {
          Start-Sleep -Seconds (2 * $try)
          continue
        }
      }
    }

    try {
      $result = Invoke-FalArt -Prompt $Prompt -OutFile $OutFile -Model $Model `
        -AspectRatio $AspectRatio -OutputFormat $OutputFormat
      if ($result) { return $result }
      Write-Warning 'FAL_KEY is not set, so there is no fallback provider.'
      return $null
    }
    catch {
      if (Test-QuotaFailure $_) {
        Write-Warning 'fal.ai is out of quota as well.'
        return $null
      }
      Start-Sleep -Seconds (2 * $try)
    }
  }

  return $null
}
