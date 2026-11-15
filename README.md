# NPC Omega Gore — experimental test build

This build attempts to allow damage and death of protected NPCs and provides a story-character spawner. It is not a finished universal gore solution. Use a separate manual save for testing: killing quest NPCs can permanently block quest progress.

Rebranded from OmegaNPC to NPCOmegaGore. Legacy `OmegaNPC_Spawn` tags are still cleaned up by **Remove spawned copies**, but new spawns use `NPCOmegaGore_Spawn`. CET log prefix is now `[NPCOmegaGore]`.

## Using the spawner

1. Install the archive using Vortex, or copy the `r6` and `bin` folders into your Cyberpunk 2077 directory. Cyber Engine Tweaks and redscript are required.
2. Launch the game, load a test save, and open the CET overlay with its configured key. The `NPCOmegaGore` window contains a searchable catalog and a record field. Select a catalog entry, then press **Spawn record**.
3. Spawned entities are copies; they are not the quest-owned originals. Some records require Phantom Liberty, quest setup, or unavailable assets. A reported spawn can still look or behave incorrectly.
4. **Remove spawned copies** targets entities tagged by this mod (plus legacy OmegaNPC tags). Put an NPC in the crosshairs and press **Inspect NPC in crosshairs** to print its health, protection and dismemberment-component information in the window and CET log.

The catalog lists 221 candidate records, based on the public Appearance Menu Mod catalog: https://github.com/MaximiliumM/appearancemenumod . Records and labels are candidates, not verified spawn or gore coverage. You can enter another `Character.*` record manually.

## What it changes

A named Mortal override is applied while NPCs are attached, and removed on uninitialization. Player attacks are flagged at creation (`AttackData.PreAttack`) with friendly fire, immortality-mode ignore and stat-pool-limit ignore, and re-flagged in the damage pipeline as a safety net. The hit-reaction CanDieCondition is bypassed for NPCs. Quest-owned god-mode sources are left intact. These mechanisms have not been verified in gameplay, across save/load or every scene, and may not overcome every protection or collision setup. They can alter fights and quest behavior. The mod does not replace models or character appearance files; for Judy it injects wound data at load time from a bundled donor file (donor pattern), so body-mod overrides keep working.

Diagnostics: `NPCOmegaGore_Describe()` reports `onHits` (collision hits reaching `GameObject.OnHit`), `hits` (hits reaching `DamageSystem.PreProcess`) and `goreChecks` (dismemberment-condition evaluations). `onHits>0` with `hits==0` means collision works but the pipeline rejects the hit; both zero during live fire means shots are still rejected before collision.

The installed Relentless Live Dismember mod excludes civilians, companions and crowd from its special *living limb-loss* branch; this mod does not remove those exclusions.

## Initial test

Use a disposable manual save in a free-roam area. Check a generic enemy, a civilian, a spawned Judy or Panam, and an actual protected quest NPC. For each, observe whether shots connect, health drops, death occurs, and gore appears. Use **Inspect NPC in crosshairs** before attacking if possible. Try a reload and a different weapon if behavior differs. Report which NPC, whether it was spawned or quest-owned, and the result; CET's log contains lines prefixed `[NPCOmegaGore]`.

## Removal

If installed with Vortex, disable the mod there. If installed manually, close the game and remove only these mod-specific paths, then load a save from before the test:

* `r6/scripts/NPCOmegaGore/`
* `bin/x64/plugins/cyber_engine_tweaks/mods/NPCOmegaGore/`

Legacy paths from the previous name, if present, should also be removed to avoid double-wrapping:

* `r6/scripts/OmegaNPC/`
* `bin/x64/plugins/cyber_engine_tweaks/mods/OmegaNPC/`

## Validation

The REDscript source compiled with the installed game compiler against a copied base cache, the installed scripts, and installed RED4ext plugin scripts. A Lua mock checked spawn creation, positioning, update and cleanup. Gameplay hit registration still needs real-world verification: compilation success does not prove ordinary gunfire connects or that gore runs.
