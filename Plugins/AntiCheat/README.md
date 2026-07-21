# AntiCheat

External Pokemon Infinite Fusion plugin.

## Behavior

- Checks `configuration.json` for a truthy `cheats` entry.
- Checks `Data/Scripts/999_Main/999_Main.rb` for `$DEBUG` assignments.
- Detection marks save as game over and disables debug mode.
- Blocks doors and map transitions while flagged.
- Shows a random warning or prank message when blocked.
- Reports detection reason in debug console.
- Removing cheat changes clears flag on next load or save.

## Files

- `001_AntiCheat.rb` - source.
- `meta.txt` - metadata.
- `Data/PluginScripts.rxdata` - compiled cache.

Recompile cache after changing Ruby source.
