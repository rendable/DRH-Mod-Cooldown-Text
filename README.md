# This mod likely will not be maintained

I no longer really play the game, so ongoing updates and fixes are unlikely.

# Cooldown Text

<!-- drh:show -->
Adds centered countdown text to weapon, consumable and timed player-effect HUD icons.
- Centered cooldown text on weapon and consumable buttons.
- Smaller countdowns on timed player-effect icons.
- Supports both HUD renderers and follows HUD movement and layout changes.
- Only displays timers; actual cooldowns are unchanged.
<!-- /drh:show -->

## Requirements

Dungeon Rampage Haxe V17 and DRH Mod API 1.2 or a compatible later 1.x release. The launcher resolves the API dependency. This mod uses game internals and may need updates for later game releases.

## Installation

Install the release ZIP through the DRH Launcher Mods page. Do not use GitHub's automatic source-code ZIP as the release artifact.

To test a source checkout, run this from its repository folder with your launcher path:

```powershell
& "C:\Path\To\DRH-Launcher.com" --run-mod (Get-Location).Path
```

## Publishing

The included official workflow drafts a release when you push a `v<version>` tag matching `mod.json`. Test the generated ZIP before publishing the draft. Follow [Making a mod](https://github.com/Tutez64/Dungeon-Rampage-Haxe/blob/master/docs/making-a-mod.md) to submit the published release to the mod index.

## License

MIT. See [LICENSE](LICENSE).
