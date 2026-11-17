# No Plot Armor — focused in-game test (5 minutes, disposable save)

Use a disposable manual save in free roam. Do NOT use your main save: killing quest NPCs can permanently block quests.

## Setup

1. Load the disposable save.
2. Open the CET overlay. The `No Plot Armor v0.2.1` window lists the catalog.
3. Start with a catalog NPC that previously failed: **Wakako Okada**, or one of the new Arasaka spawns (**Hanako**, **Yorinobu**, **Saburo**, **Michiko**). If you need a comparison, try Fingers, Wilson, Reed, or **Lizzy Wizzy (PL)**. Test one copy at a time so the log is easy to follow.
4. Cries: down an NPC non-lethally and listen for spaced pain barks in that NPC's own voice (log: `first cry for`). Then finisher-kill a copy and listen for the one-shot victim cry (log: `finisher cry for`).
4. Press **Inspect NPC in crosshairs** before shooting. Check the appearance and the initial `fleshLimbs` and `cyberLimbs` counts.
5. For full log output, enable **Verbose logging** first. Leave it off for normal play.

## Shots to fire (per NPC)

- 3–5 aimed body shots with a normal hitscan weapon (pistol/rifle, no mods that alter damage).
- Once the NPC is dead, try a few aimed limb shots and inspect again. Record any visible limb loss and whether either limb counter increased.
- If nothing registers, reload once and repeat with a second weapon. Do not change position between reloads if possible.

## What to report back (paste CET lines)

For each NPC, paste:
- The `INSPECT` line before shooting.
- The `TARGET` line after shooting stops changing (or after 10 seconds, verbose on).
- The `INSPECT` line after shooting.
- The catalog name, whether it was a spawned copy, the weapon, and what changed on screen (impact, health, death, or limb loss).

## How to read the counters (no interpretation needed from you)

- `onHits` = collision hits reaching the NPC. `hits` = hits reaching the damage pipeline. `goreChecks` = dismemberment evaluations. `deaths` = death events.
- `onHits=0, hits=0` during fire = shots rejected before collision.
- `onHits>0, hits==0` = collision works, pipeline rejects.
- `hitInfo` shows `preprocess / dmg / hp / friendly / friendlyIgnored / immortalTgt / noDamage / nonlethal`.
- `immSrcN` = number of Immortal god-mode sources still on the NPC.

## Log files (paths on this machine)

- `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\scripting.log` — lines prefixed `[NoPlotArmor]`.
- `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\r6\logs\redscript_rCURRENT.log` — only needed if the game fails to start or reports a compile error.

No other files are needed. Do not send saves.
