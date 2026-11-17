# No Plot Armor — Vortex zip builder / validator (0.2.1, local only, no publish)
# Run from repo root: powershell -ExecutionPolicy Bypass -File tools/build-zip.ps1
$ErrorActionPreference = "Stop"
$Version = (Get-Content "$PSScriptRoot/../VERSION" -Raw).Trim()
$Name = "NoPlotArmor"
$Root = Resolve-Path "$PSScriptRoot/.."
$Dist = Join-Path $Root "dist"
$Stage = Join-Path $Dist "staging/$Name-$Version"
$Zip = Join-Path $Dist "$Name-$Version.zip"

Write-Host "=== No Plot Armor $Version ==="

# 1. Required source checks
$required = @(
  "r6/scripts/NoPlotArmor/NoPlotArmor.reds",
  "r6/scripts/NoPlotArmor/NoPlotArmorCries.reds",
  "bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/init.lua",
  "bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/catalog.lua",
  "README.md", "CHANGELOG.md", "LICENSE", "VERSION"
)
foreach ($rel in $required) {
  $p = Join-Path $Root $rel
  if (-not (Test-Path $p)) { throw "Missing required file: $rel" }
  Write-Host "OK  $rel"
}

# 2. Forbid old identities in shipping code
$bad = Select-String -Path "$Root/r6/scripts/NoPlotArmor/NoPlotArmor.reds", "$Root/bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/init.lua" -Pattern "NPCOmegaGore|r6/scripts/NPCOmegaGore|mods/NPCOmegaGore|OmegaNPC_Spawn" | Where-Object {
  # Allow intentional legacy-tag migration strings
  $_.Line -notmatch 'NPCOmegaGore_Spawn.*OmegaNPC_Spawn|LEGACY_TAGS'
}
if ($bad) {
  Write-Host "Legacy references found (must be intentional only):"
  $bad | ForEach-Object { Write-Host ("  {0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()) }
  # Fail only on path-like leftovers, not tag migration
  $fatal = $bad | Where-Object { $_.Line -match 'r6/scripts/NPCOmegaGore|mods/NPCOmegaGore|module NPCOmegaGore|Begin\("NPCOmegaGore"' }
  if ($fatal) { throw "Old mod paths/names still present in code." }
} else {
  Write-Host "OK  no stale identities"
}

# 3. Version consistency
$reds = Get-Content "$Root/r6/scripts/NoPlotArmor/NoPlotArmor.reds" -Raw
$lua = Get-Content "$Root/bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/init.lua" -Raw
if ($reds -notmatch [regex]::Escape($Version)) { throw "Version $Version not found in .reds" }
if ($lua -notmatch 'MOD_VERSION\s*=\s*"' + [regex]::Escape($Version) + '"') { throw "MOD_VERSION mismatch in init.lua" }
Write-Host "OK  version $Version in reds + lua"

# 4. Stage Vortex layout: zip root must contain r6/, bin/ at top level
if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$Stage/r6/scripts/NoPlotArmor" | Out-Null
New-Item -ItemType Directory -Force -Path "$Stage/bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor" | Out-Null
Copy-Item "$Root/r6/scripts/NoPlotArmor/NoPlotArmor.reds" "$Stage/r6/scripts/NoPlotArmor/"
Copy-Item "$Root/r6/scripts/NoPlotArmor/NoPlotArmorCries.reds" "$Stage/r6/scripts/NoPlotArmor/"
Copy-Item "$Root/bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/init.lua" "$Stage/bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/"
Copy-Item "$Root/bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/catalog.lua" "$Stage/bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/"
Copy-Item "$Root/README.md", "$Root/CHANGELOG.md", "$Root/LICENSE", "$Root/VERSION" $Stage

# 5. Donor archive: NOT shipped in 0.2.0 (pending vanilla-only rebuild). Warn if local archive exists.
$localArchive = "C:/Program Files (x86)/Steam/steamapps/common/Cyberpunk 2077/archive/pc/mod/npcomegagore_donors.archive"
if (Test-Path $localArchive) {
  Write-Host "NOTE local donor archive exists but is NOT included (needs vanilla-only rebuild for Nexus)."
} else {
  Write-Host "NOTE no local donor archive found; code-only zip is correct for 0.2.0."
}

# 6. Build zip with top-level r6/, bin/
if (Test-Path $Zip) { Remove-Item $Zip -Force }
Compress-Archive -Path "$Stage/*" -DestinationPath $Zip -Force
Write-Host "Built $Zip"

# 7. Validate zip composition (what Vortex sees)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipRead = [System.IO.Compression.ZipFile]::OpenRead($Zip)
$entries = $zipRead.Entries | ForEach-Object { $_.FullName -replace '\\','/' }
$zipRead.Dispose()
Write-Host "--- zip contents ---"
$entries | Sort-Object | ForEach-Object { Write-Host "  $_" }
$need = @(
  "r6/scripts/NoPlotArmor/NoPlotArmor.reds",
  "r6/scripts/NoPlotArmor/NoPlotArmorCries.reds",
  "bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/init.lua",
  "bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/catalog.lua"
)
foreach ($n in $need) {
  if ($entries -notcontains $n) { throw "ZIP MISSING: $n (Vortex would fail)" }
}
if ($entries -match "NPCOmegaGore|OmegaNPC/") { throw "ZIP contains old paths." }
# No nested root folder (Vortex killer): first segment must be r6/bin/README etc, not NoPlotArmor-0.2.0/
if ($entries -match "^NoPlotArmor-") { throw "ZIP has extra root folder; Vortex needs r6/ and bin/ at top level." }
Write-Host "OK  Vortex layout valid: r6/ + bin/ at zip root, no nested folder, no old paths."
Write-Host ""
Write-Host "Next: Vortex -> Install From File -> $Zip, deploy, check CET window shows No Plot Armor v$Version."
Write-Host "DO NOT publish to GitHub/Nexus yet (per plan)."
