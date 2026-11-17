# Changelog

All notable changes use SemVer.

## [0.2.1] — dev, unreleased (local testing only)

Fixed:
* Wakako gore: `wakako_okada.app` (and other story apps without body-type suffixes — `celebrity_chrome`, `us_cracks_band`, `weldon_holt`, `thompson`, `josh*`, `psycho`, `sebastian_perez`) no longer fall through the universal wound fallback. `PickDonor` name lists extended; all four `Character` records verified present in `tweakdb.bin`/`tweakdb_ep1.bin` via TDBID hash check.
* Spawner: Arasaka family added (all records verified in TweakDB) — Hanako (`Character.Hanako`), Yorinobu (`Character.Yorinobu`), Saburo (`Character.Saburo`), Michiko (`Character.Michiko`, AMM category `Arasaka`). Featured list + catalog entries + explicit donor registrations.
* Spawner: six more verified story NPCs — Johnny Silverhand (`Character.Silverhand`, also featured), Placide (`Character.Placide`), Royce (`Character.Royce`), Dum Dum (`Character.DumDum`), Brick (`Character.Brick`), Meredith Stout (`Character.Stout`) — plus wound-fallback keywords and explicit donor slots for all of them.
* Spawner: the last four parked story NPCs, resolved via AMM's own record mappings and verified in TweakDB — Anders Hellman (`Character.Haru_Kasai`, that odd record name is genuinely AMM's Hellman mapping), Maman Brigitte (`Character.Voodoo_Queen`), Oda (`Character.Cyberninja_Oda`), Sasquatch (`Character.main_boss_sasquatch`) — plus Royce's boss record (`Character.main_boss_royce`, listed as Royce (Boss)). Wound-fallback keywords added for all; no explicit donor slots (their `.app` paths aren't verified, the universal fallback covers them).
* Cries split by design: finisher-death voice lives here (death inside a finisher workspot plays `hit_reaction_heavy` once in the victim's own voiceset, gated on the NPA master switch). Downed-but-alive loop cries stay in the standalone DownedCries mod (vanilla has none, and bundling them with NPA would tie a harmless ambience mod to a game-breaking one).

## [0.2.0] — 2026-11-17
First versioned release. Stable in-game, spawner kept, unified outfit support included.

Added:
* Rebrand to No Plot Armor (`NoPlotArmor`, code prefix `NPA`, spawn tag `NoPlotArmor_Spawn`, log `[NoPlotArmor]`, CET window `No Plot Armor v0.2.0`).
* `MOD_VERSION` / `NPA_Version()` = `0.2.0`, version footer in CET UI.
* `verbose.txt` + "Verbose logging" checkbox (off by default). TARGET sampler and fire-auth logs gated behind it.
* Triple-tag migration: cleanup and spawn-gates accept `NoPlotArmor_Spawn`, `NPCOmegaGore_Spawn`, `OmegaNPC_Spawn`.
* `VERSION`, `CHANGELOG.md`, Vortex zip validator (`tools/build-zip.ps1`).
* Universal wound fallback: any woundless appearance (custom outfits included) gets body-type-matched wounds automatically. Self-seeding from vanilla gang bodies forced to load at startup — works with no archive installed, no load-order gamble. Validated in game on a custom Judy outfit. Story NPCs stay on explicit donors when their archive is present. Silent hot path.
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
