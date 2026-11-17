# Changelog

All notable changes use SemVer.

## [0.2.0] — 2026-11-17
First versioned release. Stable in-game, spawner kept, unified outfit support included.

Added:
* Rebrand to No Plot Armor (`NoPlotArmor`, code prefix `NPA`, spawn tag `NoPlotArmor_Spawn`, log `[NoPlotArmor]`, CET window `No Plot Armor v0.2.0`).
* `MOD_VERSION` / `NPA_Version()` = `0.2.0`, version footer in CET UI.
* `verbose.txt` + "Verbose logging" checkbox (off by default). TARGET sampler and fire-auth logs gated behind it.
* Triple-tag migration: cleanup and spawn-gates accept `NoPlotArmor_Spawn`, `NPCOmegaGore_Spawn`, `OmegaNPC_Spawn`.
* `VERSION`, `CHANGELOG.md`, Vortex zip validator (`tools/build-zip.ps1`).
* Universal wound fallback: any woundless appearance (custom outfits included) gets body-type-matched wounds automatically. Self-seeding from vanilla gang bodies forced to load at startup — works with no archive installed, no load-order gamble. Story NPCs stay on explicit donors when their archive is present. Silent hot path.
First versioned release. Stable in-game, spawner kept.

Added:
* Rebrand to No Plot Armor (`NoPlotArmor`, code prefix `NPA`, spawn tag `NoPlotArmor_Spawn`, log `[NoPlotArmor]`, CET window `No Plot Armor v0.2.0`).
* `MOD_VERSION` / `NPA_Version()` = `0.2.0`, version footer in CET UI.
* `verbose.txt` + "Verbose logging" checkbox (off by default). TARGET sampler and fire-auth logs gated behind it.
* Triple-tag migration: cleanup and spawn-gates accept `NoPlotArmor_Spawn`, `NPCOmegaGore_Spawn`, `OmegaNPC_Spawn`.
* `VERSION`, `CHANGELOG.md`, Vortex zip validator (`tools/build-zip.ps1`).

Changed:
* Cut release log spam: removed per-aim "Temporarily neutralized" log, silenced startup/diagnostic spam unless verbose.
* README rewritten from experimental test build to release page. Removal paths updated to new + legacy folders.
* `Remove spawned copies` message simplified to "all tags".

Fixed:
* Lua/REDscript API mismatch after rename (`NPA_SetEnabled`, `NPA_UpdateShotTarget`, `NPA_NeutralizeSpawn`, `NPA_AdjustSpawnHealth`, `NoPlotArmor_Describe`).

Known / pending for Nexus:
* Donor archive (`noplotarmor_donors.archive`, 48 appearances) not shipped in 0.2.0 zip — local build contains body-mod variants and is not cleared for redistribution. Needs vanilla-only rebuild. Killability + spawner work without it; wounds fall back to vanilla/other mods.
* In-game save/load long-term quest side effects untested by design (killing quest NPCs breaks quests).

## [0.1.x] — unversioned test builds (history)
* OmegaNPC → NPCOmegaGore rename, early FriendlyFire fix, OnHit diagnostics.
* Bullet `FriendlyFire` record tweak, fire-path telemetry, player fire-auth statuses.
* Judy wound donor injector, 48-appearance donor set, Panam health/gore fallbacks.
* Master toggle (`enabled.txt`), retaliation toggle (`retaliation.txt`), target sampler, spawner neutrality.
* User-confirmed hit registration in game; expanded gore data pending validation.
