# AntiCheat

External plugin for Pokemon Infinite Fusion.

## Features

- Checks optional root `configuration.json` and `Data/Scripts/999_Main/999_Main.rb` when a new game starts or a save is loaded or saved.
- If `configuration.json` exists, truthy `cheats` values trigger detection, including spacing, capitalization, quoted `true`, and `1`; missing file does nothing.
- Detects writes that could enable debug mode, including whitespace variations, line continuations, truthy expressions, environment or method results, and `||=` or `|=` assignments. Clear `false` and `nil` assignments are ignored.
- When detected, marks the current save as game over and immediately disables debug mode.
- Blocks map transfers and door or stair events while the cheat flag is active.
- Reports the detection reason to the debug console when a blocked transition is attempted.
- Shows a warning message when a blocked transition is attempted.
- If the debug modification is removed, the flag clears on the next save or load.

## Detection scope

- Detection is intentionally static and limited to writes to `$DEBUG` in `999_Main.rb`.
- Normal whitespace, line continuations, truthy expressions, indirect values, and common assignment operators are covered.
- This is a client-side deterrent. A player who can modify the game files can also modify or remove the detector.

## Files

- `001_AntiCheat.rb` - plugin source.
- `meta.txt` - plugin metadata.
- `Data/PluginScripts.rxdata` - compiled plugin cache used by the game.

After changing the Ruby source, regenerate the compiled plugin cache before running the game.
