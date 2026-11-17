# No Plot Armor — Killable Story NPCs and Dismemberment

v0.2.0 — first versioned release. Spawner kept in.

TLDR: story NPCs can be damaged, killed, and dismembered. Spawns are copies for safe testing. Killing quest NPCs can break quests — use a manual save.

## What it does

* Removes protected / immortal / invulnerable states from NPCs while attached, restores them on toggle-off.
* Flags player attacks with FriendlyFire + immortality-ignore so friendly NPCs actually take hits.
* Injects wound data for 48 story appearances so dismemberment can show (requires donor archive, see below).
* Story-character spawner (221 records, curated featured list + search). Copies are tagged `NoPlotArmor_Spawn`.
* Optional retaliation: NPCs fight back when hit (off by default).
* Inspect tool: health, protection, flesh/cyber limb counts, hit/gore counters.

## Requirements

* Cyberpunk 2077 2.x, Cyber Engine Tweaks, redscript
* Optional but recommended: Relentless Live Dismember for living-limb loss

## Install

Vortex (recommended):
1. Download the 0.2.0 zip.
2. Install in Vortex — it should map `r6/`, `bin/` to the game folder.
3. Deploy, launch, load a test save, open CET overlay.

Manual:
Copy `r6/` and `bin/` into your Cyberpunk 2077 folder.

Verify install:
* `r6/scripts/NoPlotArmor/NoPlotArmor.reds` exists
* `bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/init.lua` exists
* CET window shows `No Plot Armor v0.2.0`

Donor archive note (0.2.0):
No archive is required. The mod self-seeds wound data from two vanilla gang bodies forced to load at startup, and injects body-type-matched wounds into any woundless NPC appearance (custom outfits included, validated in game on a custom Judy outfit). A tiny optional vanilla universal archive may ship later as a fallback; the 48-file local donor set is deprecated and not redistributed.

## Use

1. CET overlay → `No Plot Armor v0.2.0`.
2. Pick a record, `Spawn record`. Copies spawn 2m in front of V.
3. `Inspect NPC in crosshairs` before/after shooting.
4. `Remove spawned copies` cleans all tags: `NoPlotArmor_Spawn`, `NPCOmegaGore_Spawn`, `OmegaNPC_Spawn`.
5. `NPCs retaliate when hit` — off by default, saved to `retaliation.txt`.
6. `Enable No Plot Armor` master switch — saved to `enabled.txt`. Off restores protection overrides and fire blocks.
7. `Verbose logging` — off by default, saved to `verbose.txt`. Turn on only for bug reports.

## Removal

Vortex: disable/uninstall.
Manual: delete:
* `r6/scripts/NoPlotArmor/`
* `bin/x64/plugins/cyber_engine_tweaks/mods/NoPlotArmor/`
* `archive/pc/mod/noplotarmor_donors.archive` (if installed)

Legacy (from older names, remove if present):
* `r6/scripts/NPCOmegaGore/`, `r6/scripts/OmegaNPC/`
* `bin/x64/plugins/cyber_engine_tweaks/mods/NPCOmegaGore/`, `.../OmegaNPC/`
* `archive/pc/mod/npcomegagore_donors.archive`

## Known issues

* Killing quest NPCs can permanently block quests. This is the point of the mod — use a disposable save.
* Friendly-fire collision uses a temporary neutral-attitude workaround while aiming. Fast target switching or delayed projectiles can miss.
* Nonlethal / fist-fight hits keep vanilla rules and will not kill.
* Save/load across sessions works for toggles, but long-term quest side effects are untested.

## Pairs well with

* GoreRunner (Blood and Carnage Overhaul) — gore visuals: gibs, blood, remade gore models. https://www.nexusmods.com/cyberpunk2077/mods/24210
* RELENTLESS - Live Dismemberment — limbs come off living enemies. https://www.nexusmods.com/cyberpunk2077/mods/35703
* Civilian Dismemberment (Collateral Damage) — technique source for our wound injection. https://www.nexusmods.com/cyberpunk2077/mods/36454
* Use Weapons and Quick Slots Everywhere — draw and shoot in safe zones, no Action Blocked popup. https://www.nexusmods.com/cyberpunk2077/mods/28411
* Gameplay Restrictions - UNLOCKED — sprint, jump and dodge in safe areas and while carrying bodies. https://www.nexusmods.com/cyberpunk2077/mods/10946

## Credits

* Character list derived from Appearance Menu Mod public catalog.
* Wound injection technique adapted from Collateral Damage's WoundInject pattern.

## Versioning

See `CHANGELOG.md`. This is v0.2.0.
License: GPL-3.0 for scripts in this repo (0.2.0 zip still carries the original MIT text; GPL applies from here on). Game assets belong to CD PROJEKT RED.
