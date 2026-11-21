# Ultrawide HUD & Display Tweaks

A [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for **VOID/BREAKER** that makes the game nicer on ultrawide monitors (21:9, 32:9, ...).

## Features

- **Centered HUD** – pulls the HUD (health, weapons, ammo, mission objectives) toward the middle of the screen instead of the far screen edges. Default width: 60 % of the screen.
- **Centered game menus** – Inventory and the blueprint decryptor (Researcher) menu are centered as well.
- **HUD opacity** – fine-grained slider that keeps the game's tilted HUD look.
- **Flat HUD** option – draws the HUD without tilt and tint.
- **Image settings** – exposure and bloom sliders (tone down overly bright lamps).
- **In-game menu** (default key `F7`) with sliders; settings are saved automatically.
- Troubleshooting options: log opened game menus, dump the widget tree to `UE4SS.log`.

## Installation

1. Install UE4SS (tested with **v4.0.0**) into `VOIDBREAKER/Binaries/Win64/`.
   On Linux/Proton add the Steam launch option `WINEDLLOVERRIDES="dwmapi=n,b" %command%`.
2. Copy the `UltrawideDisplayTweaks` folder from this repository to
   `VOIDBREAKER/Binaries/Win64/ue4ss/Mods/`.
3. Start the game and press `F7`.

The mod only needs `enabled.txt` and the `Scripts` folder. Your settings are stored as `saved_*.txt` files next to `enabled.txt`.

## Configuration

Defaults and optional hotkeys (unbound by default) live in `UltrawideDisplayTweaks/Scripts/config.lua`, commented line by line. Restart the game after editing it.

## Notes

- Tested on Linux/Proton at 5120x1440 only; feedback for other setups is welcome.
- Exposure/bloom are applied to the player camera's post-process settings.

## License

[MIT](LICENSE)
