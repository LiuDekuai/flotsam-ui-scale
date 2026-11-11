# Flotsam UI Scale 200%

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform: Windows](https://img.shields.io/badge/platform-Windows-lightgrey)

Raise the **in-game UI scale limit of *Flotsam* from 125% to 200%**
(50%–200% slider range). Made for 4K / high-DPI displays where 125% is still too small.

* Changes **8 bytes** in two scene files (2 per slider) — no game logic touched
* **SHA-256 version check** before patching, so unknown builds are never modified
* Automatic backup + one-command uninstall
* Re-run after a game update

> 中文说明见 [README.md](README.md) · Changelog: [CHANGELOG.md](CHANGELOG.md)

---

## Game

| | |
| --- | --- |
| Game | **Flotsam** by Pajama Llama Games |
| Stores | Steam (AppID `821250`), Epic Games Store, GOG |
| Verified build | **1.0.1f10_b3** (Unity `6000.3.28f1`, Epic, 2026-11-11) |
| OS | Windows 10 / 11 |

If your files do not match the recorded SHA-256 (other store / newer build),
the installer refuses to run instead of corrupting anything.

## Why 125%?

The value lives in
`%USERPROFILE%\AppData\LocalLow\Pajama Llama Games\Flotsam\PlayerSettings.json`
(`GraphicsPlayerData.UIScale`). At runtime `CanvasScaleSetter` assigns it
directly to `Canvas.scaleFactor` — **there is no cap in code**.
The cap comes from the `UIScaleSlider` Unity `Slider` component serialized in
`Flotsam_Data\level1` and `level2`, whose `m_MaxValue` is `1.25`.

## Install

1. Fully close the game.
2. Download / clone this repo.
3. Run **`install.bat`** and accept the UAC prompt (admin is required for `Program Files`).
4. Launch the game → *Settings → Video → UI Scale* → the slider now goes up to **200%**.

PowerShell alternative (elevated):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Scale 1.75
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -WhatIf   # dry run, no admin
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -GameDir "D:\Epic Games\Flotsam"
```

## Uninstall

Run **`uninstall.bat`**, or:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1
```

## How it works

1. `level1` (main menu) and `level2` (gameplay) each contain two `UIScaleSlider`
   `Slider` components.
2. `Slider.m_MaxValue` sits at object offset `+0x154`.
3. The installer rewrites `1.25` → target scale (default `2.0`), after verifying
   that restoring `1.25` reproduces the known original SHA-256.
4. `PlayerSettings.json` is updated to the same value.

No game assets are redistributed in this repository; the patch is generated
locally from your own installation.

## Notes

* Only affects the single-player game; nothing online, no anti-cheat involved.
* Game updates overwrite the patch — just run `install.bat` again.
* Backups: `%LOCALAPPDATA%\FlotsamUIScale\backup\` (refreshed on every install).
* Above ~175% some fixed-size panels may overlap — lower the slider in game.

## Porting to a new build

```bash
pip install UnityPy
python tools/find_ui_scale_slider.py "C:\Program Files\Epic Games\Flotsam\Flotsam_Data"
```

Update `$Offsets` / `$KnownHashes` at the top of `scripts/install.ps1`.

## License

[MIT](LICENSE) — scripts and docs only, no game assets.
