<#
.SYNOPSIS
  Runs one Joiner/Mover/Leaver step against lab.auto.tfvars, shows the plan,
  asks before applying, then confirms the state is clean.

.EXAMPLE
  .\scripts\lifecycle.ps1 -Step mover
  .\scripts\lifecycle.ps1 -Step disable
  .\scripts\lifecycle.ps1 -Step remove

  mover   Victor: sg-dev-readers -> sg-dev-contributors  (expect 1 to add, 1 to destroy)
  disable Connor: account_enabled = false                (expect 1 to change)
  remove  Connor: removed from the users map             (expect user, password, membership destroyed)
#>
param(
  [Parameter(Mandatory)]
  [ValidateSet('mover', 'disable', 'remove')]
  [string]$Step
)

$ErrorActionPreference = 'Stop'
$tfDir = Join-Path $PSScriptRoot '..\terraform' | Resolve-Path
$file  = Join-Path $tfDir 'lab.auto.tfvars'
$utf8  = New-Object System.Text.UTF8Encoding($false)   # no BOM, Terraform-safe
$text  = [IO.File]::ReadAllText($file)
$orig  = $text

switch ($Step) {
  'mover' {
    $text = [regex]::Replace($text,
      '(?s)("victor\.ramos"\s*=\s*\{.*?groups\s*=\s*)\[[^\]]*\]',
      '${1}["sg-dev-contributors"]')
  }
  'disable' {
    if ($text -notmatch '(?s)"connor\.blake"\s*=\s*\{[^}]*account_enabled') {
      $text = [regex]::Replace($text,
        '(?s)("connor\.blake"\s*=\s*\{.*?)(\r?\n\s*groups\s*=)',
        '${1}' + "`n    account_enabled = false" + '${2}')
    }
  }
  'remove' {
    $text = [regex]::Replace($text,
      '(?s)\r?\n  "connor\.blake"\s*=\s*\{.*?\r?\n  \}', '')
  }
}

if ($text -eq $orig) { throw "Step '$Step' changed nothing. Already applied, or the file layout differs." }

[IO.File]::WriteAllText($file, $text, $utf8)
Push-Location $tfDir
try {
  terraform fmt | Out-Null
  Write-Host "`n--- File change ($Step) ---" -ForegroundColor Cyan
  git --no-pager diff --no-color -- lab.auto.tfvars

  Write-Host "`n--- terraform plan ---" -ForegroundColor Cyan
  terraform plan -out "$Step.tfplan"
  if ($LASTEXITCODE -ne 0) { throw 'plan failed' }

  $go = Read-Host "`nScreenshot the plan now. Apply it? (y/n)"
  if ($go -ne 'y') { Write-Host 'Not applied. The file edit is still on disk; use git restore to undo.'; return }

  terraform apply "$Step.tfplan"
  if ($LASTEXITCODE -ne 0) { throw 'apply failed' }
  Remove-Item "$Step.tfplan" -ErrorAction SilentlyContinue

  Write-Host "`n--- Verify: expect 'No changes' ---" -ForegroundColor Cyan
  terraform plan -detailed-exitcode | Select-Object -Last 4
}
finally { Pop-Location }
