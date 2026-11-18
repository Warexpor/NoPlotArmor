# Changelog

All notable changes use SemVer.

## [0.2.1] — 2026-11-18

Fixed:
* Wakako gore: `wakako_okada.app` (and other story apps without body-type suffixes — `celebrity_chrome`, `us_cracks_band`, `weldon_holt`, `thompson`, `josh*`, `psycho`, `sebastian_perez`) no longer fall through the universal wound fallback. `PickDonor` name lists extended; all four `Character` records verified present in `tweakdb.bin`/`tweakdb_ep1.bin` via TDBID hash check.
* Spawner: Arasaka family added (all records verified in TweakDB) — Hanako (`Character.Hanako`), Yorinobu (`Character.Yorinobu`), Saburo (`Character.Saburo`), Michiko (`Character.Michiko`, AMM category `Arasaka`). Featured list + catalog entries + explicit donor registrations.
* Spawner: Johnny Silverhand REMOVED again — `Character.Silverhand` exists in TweakDB but is not spawnable via plain entity creation (spawn times out; AMM and NightCityAllies both spawn him through AMM's custom `AMM_Character.Silverhand` entity instead). No point shipping a button that errors. His wound-fallback keyword stays, so quest Johnny keeps gore.
* Spawner: the last four parked story NPCs, resolved via AMM's own record mappings and verified in TweakDB — Anders Hellman (`Character.Haru_Kasai`, that odd record name is genuinely AMM's Hellman mapping), Maman Brigitte (`Character.Voodoo_Queen`), Oda (`Character.Cyberninja_Oda`), Sasquatch (`Character.main_boss_sasquatch`) — plus Royce's boss record (`Character.main_boss_royce`, listed as Royce (Boss)). Wound-fallback keywords added for all; no explicit donor slots (their `.app` paths aren't verified, the universal fallback covers them).
* Cries split by design: finisher-death voice lives here (hooked on the finisher's own game-effect event while the victim is still alive and voiced, in their own voiceset, gated on the NPA master switch). Downed-but-alive loop cries stay in the standalone DownedCries mod (vanilla has none, and bundling them with NPA would tie a harmless ambience mod to a game-breaking one).

Changed:
* Children are no longer excluded: protection/mortal overrides, friendly-fire/hit flags, attitude/collision handling, and kill checks apply to child NPCs too. Universal wound fallback now injects body-matched wounds for child appearances too (boy/male paths pick masculine donor, girl/female feminine, unknown child defaults feminine) — this feeds the blood effects, not dismemberment (see crutch note below).
* Dead-child corpse dismemberment fallback: sufficiently damaged corpse regions on a dead child are allowed through (same 10%-of-health rule as the Panam-spawn fallback), living children still use the native branch only.
* Child collision fix: bullets ghosting through kids is a pre-pipeline filter. `r6/tweaks/NoPlotArmorKids.yaml` now covers all 43 known kid records (full list dumped from TweakDB): isChild to false everywhere via TweakXL, and the 14 records whose reaction preset is the Child type (the check behind `IsCharacterChildren` reads the StimReactionComponent preset type, not the isChild flat — found by tracing vanilla scripts) move to `ReactionPresets.Civilian_Passive`. Quest-scene kids already on NoReaction/Neutral/Passive presets are untouched. CET still flips isChild on any other kid record the crosshair lands on (a Redscript equivalent isn't possible in this script build, so TweakXL owns the boot flip).
* Spawner: kid test copies now in the default featured list (Dorian/Dorian Kutcher, Monique/Monique Kutcher, Rick Martinez) — no more "Show all" needed for the killability test.
* Kid hit crutch: kid bodies ship with no bullet/melee hitboxes, so the physics query never delivers a hit event no matter the flags (proven: all protections stripped, native child-check off, still onHits=0). New aim-gated path in `AttackData.PreAttack`: a shot or swing fired while the crosshair is genuinely on a kid deals 34%-of-max-HP scripted damage through the stat pools (death flow included) plus the vanilla `blood_headshot` game-effect, and logs into the usual hit counters so inspect shows it registering. Shots that miss do nothing. Nonlethal/fistfight attacks are excluded, preserving vanilla rules. Honest limits: the tracer visual still flies through (nothing to collide with), and true gore does not run on kids — no wound/dismemberment pipeline without hit events, so blood effects plus ragdoll death is the whole show.
* Kid death now bypasses the defeat mechanic (`disableDefeatedState: true` on all 43 kid records — the Joss kid showed `defeat=true`, and the standing T-pose matches a knockout with no anim rather than a death) and re-enables ragdoll on the killing blow (`SetDisableRagdoll(false)`), keeping the delayed force-ragdoll event (now 0.3s). If the T-pose was defeat, corpses now die outright and drop; if it was the death anim, the event still drops them.
* Perf: the CET crosshair kid-flip check (inspect string + TweakDB reads every frame while aiming) is throttled to 1 Hz — it was the likely aim stutter.
* Finisher cries now include children for consistency with killability.
* Retaliation stays adult-only by design: children are killable but never turn hostile (no combat AI, avoids stuck behavior); hits on kids are still recorded in the inspect counters.

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
