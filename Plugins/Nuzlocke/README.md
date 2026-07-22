# Nuzlocke Rules

External plugin for Pokemon Infinite Fusion.

## Features

- Adds a dedicated **Nuzlocke Options** menu to the main Options screen.
- Includes an optional **Skip repeat encounters** setting that acts like a Repel in areas whose encounter is already used.
- Rules remain inactive until the player obtains the Pokédex.
- Enabling requires two confirmations. Both prompts default to **No** and are red.
- Once enabled, the option cannot be disabled. Choosing **No** or pressing Back during either confirmation leaves it Off. Trying to disable it re-enables the option and shows a warning.
- The setting is stored per save file. New games start with the setting Off.
- The Transfer Box is disabled while Nuzlocke rules are active, but remains usable as a normal PC box.
- Hall of Fame entries display `Nuzlocke mode` when completed with Nuzlocke enabled.

### Catch rule

- Only the configured number of first wild Pokemon encountered in an area can be caught.
- `Encounters per area` can raise the allowance to 2, 3, or 4; the default is 1.
- Areas are identified by their normalized map name. Multiple floors with the same name count as one area, and split routes with the same name count as one area.
- Trailing floor markers such as `B1F` and `B2F` are ignored, so cave floors count as one area.
- The encounter is consumed when the wild battle starts. Fleeing, fainting, or failing to catch the Pokemon loses that area's encounter.
- Static Pokemon, including overworld interaction encounters, use the same area allowance as random encounters.
- Later Pokeball attempts in a used area are blocked with a battle message.

### Retired Pokemon

- A player Pokemon that faints in battle or from overworld poison is marked retired permanently.
- Retired Pokemon are moved to PC storage after battle when possible.
- Retired Pokemon show a red overlay in the party and PC box icons.
- Retired Pokemon cannot be withdrawn, moved into the party, or moved there through multi-select actions. Mixed multi-select moves are blocked if any selected Pokemon is retired.
- Retired Pokemon cannot be fused, reverse-fused, or unfused.
- Reviving a retired Pokemon does not clear its retired state.

### Game over

- If no usable Pokemon remain in the party or any PC box, the player blacks out normally and then the save is marked game over.
- The game saves immediately after game over. With multi-save support, a save slot must already be assigned for the save to succeed.
- After game over, map transfers and door events are blocked with a message.
- If all party Pokemon faint while usable Pokemon remain in storage, the normal blackout is followed by the PC replacement screen.

## Files

- `001_Nuzlocke_Rules.rb` - plugin source.
- `meta.txt` - plugin metadata.
- `Data/PluginScripts.rxdata` - compiled plugin cache used by the game.

After changing the Ruby source, regenerate the compiled plugin cache before running the game.
