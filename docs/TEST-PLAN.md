# NPCOmegaGore — focused in-game test (5 minutes, disposable save)

Use a disposable manual save in free roam. Do NOT use your main save: killing quest NPCs can permanently block quests.

## Setup

1. Load the disposable save.
2. Open the CET overlay. The `NPCOmegaGore` window lists the catalog.
3. Spawn ONE `Character.Judy` (friendly/story copy) and, if you want a control, ONE generic enemy (e.g. a Tyger Claw from the catalog).
4. Aim at each spawned NPC so the CET `TARGET` sampler logs one line per change. Press **Inspect NPC in crosshairs** on each BEFORE shooting and note the `hp`, `immSrcN`, `defeat`, `onHits`, `hits`, `goreChecks`, `deaths` values.

## Shots to fire (per NPC)

- 3–5 aimed body shots with a normal hitscan weapon (pistol/rifle, no mods that alter damage).
- If nothing registers, reload once and repeat with a second weapon. Do not change position between reloads if possible.

## What to report back (paste CET lines)

For each NPC, paste:
- The `INSPECT` line before shooting.
- The `TARGET` line after shooting stops changing (or after 10 seconds).
- The `INSPECT` line after shooting.
- Which NPC it was (spawned Judy / spawned enemy / quest-owned / civilian), which weapon, and what you SAW (impacts? blood? stagger? death? limb loss?).

## How to read the counters (no interpretation needed from you)

- `onHits` = collision hits reaching the NPC. `hits` = hits reaching the damage pipeline. `goreChecks` = dismemberment evaluations. `deaths` = death events.
- `onHits=0, hits=0` during fire = shots rejected before collision.
- `onHits>0, hits=0` = collision works, pipeline rejects.
- `hitInfo` shows `preprocess / dmg / hp / friendly / friendlyIgnored / immortalTgt / noDamage / nonlethal`.
- `immSrcN` = number of Immortal god-mode sources still on the NPC.

## Log files (paths on this machine)

- `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\scripting.log` — lines prefixed `[NPCOmegaGore]`.
- `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\r6\logs\redscript_rCURRENT.log` — only needed if the game fails to start or reports a compile error.

No other files are needed. Do not send saves.
