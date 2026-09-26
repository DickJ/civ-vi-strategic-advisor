# Civ VI Strategic Advisor

An offline, player-visible-information-only strategy overlay for vanilla Sid
Meier's Civilization VI. The overlay ranks the best actions anywhere in the
local player's empire, previews unit paths and targets on the map, and explains
the strategic and tactical factors behind each recommendation.

This repository currently contains the first playable vertical slice:

- a non-replacing `AddUserInterfaces` overlay for macOS/Windows portability;
- an offline deterministic evaluator (no API key, network, or external process);
- empire-wide ranking of tactical attacks, healing, exploration, settlement,
  worker positioning, defense, and coordinated military formations;
- strategic weighting for science, culture, domination, and religious wins;
- opponent, diplomacy, city-state suzerain, military, era, geography, and
  visible-unit context in scoring/explanations;
- click-to-select, camera focus, destination/path highlighting, and detailed
  explanations;
- automatic recomputation after game-core event playback so recommendations
  update repeatedly during a turn.

The advisor previews actions only. It never issues orders.

## Install on Windows

Extract the release ZIP, then double-click:

```text
install-windows.cmd
```

The installer uses Windows' configured Documents folder, including OneDrive
redirection, and installs the mod at:

```text
Documents\My Games\Sid Meier's Civilization VI\Mods\CivVITrainer
```

Alternatively, copy the included `CivVITrainer` folder there manually. Restart
Civ VI, open **Additional Content > Mods**, and enable **Civ VI Strategic
Advisor**.

The PowerShell installer can also be run directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-CivVITrainer.ps1
```

## Install on macOS

Run:

```sh
./scripts/install-macos.sh
```

Or copy the `CivVITrainer` directory into:

```text
~/Library/Application Support/Sid Meier's Civilization VI/Mods/
```

Then enable **Civ VI Strategic Advisor** under Additional Content and start a
single-player vanilla game.

## Use

The advisor appears at the upper-right after the map loads. Click a ranked
recommendation to:

1. select its primary unit (where applicable),
2. center the camera on the destination,
3. highlight the proposed path/targets, and
4. open the technical explanation.

Use **Refresh** to recompute immediately. The list also refreshes after game
actions finish and at the beginning of each local turn.

## Privacy and fair-play boundary

`CivVITrainer_State.lua` is the only module allowed to read the Civ VI API. It
filters opponent units through the local player's current plot visibility and
only includes major civilizations after contact. The evaluator receives a plain
snapshot, so it cannot accidentally inspect hidden game objects.

## Development

The core evaluator accepts ordinary Lua tables and does not depend on Civ VI.
Run the static checks with:

```sh
./scripts/check.sh
```

For live testing, enable Civ VI logging and inspect `Lua.log` after loading a
match. The adapter intentionally uses guarded API calls so minor differences in
vanilla patch levels degrade individual signals instead of breaking the UI.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the scoring model and
[docs/ROADMAP.md](docs/ROADMAP.md) for the next milestones.
