<div align="center">

<img src="media/logo.png" alt="Battle Pet Utility logo" width="144">

# Battle Pet Utility

### A compact battle-pet HUD, loadout manager, and utility toolkit for World of Warcraft Retail

[![Release](https://img.shields.io/github/v/release/RGXMods/BattlePetUtility?style=for-the-badge&logo=github&color=b512fc)](https://github.com/RGXMods/BattlePetUtility/releases)
[![WoW Retail](https://img.shields.io/badge/WoW-Retail-148eff?style=for-the-badge&logo=worldofwarcraft&logoColor=white)](https://worldofwarcraft.blizzard.com/)

[![CurseForge](https://img.shields.io/badge/CurseForge-Download-f16436?style=flat-square&logo=curseforge&logoColor=white)](https://www.curseforge.com/wow/addons/BattlePetUtility)
[![Discord](https://img.shields.io/badge/Discord-RealmGX-5865f2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/rgxmods)

**[Features](#features) | [Installation](#installation) | [Usage](#usage) | [Compatibility](#compatibility) | [Support](#support)**

</div>

---

## Overview

**Battle Pet Utility (BPU)** keeps battle-pet team status, pet actions, zone
progress, and loadouts in one compact, draggable frame. It is designed for
normal pet collecting and battling without requiring several separate utility
windows.

Battle Pet Utility is the current name of the addon formerly released as
PetBuddy2. Current installs, saved variables, documentation, and support use
the BattlePetUtility name.

## Features

### Team and Battle Controls

- **Team HUD:** Displays all active battle-pet slots with health and experience
  bars.
- **Automatic team restore:** Saves the active team and restores it after
  login.
- **Drag and drop:** Moves pets between battle slots from the HUD.
- **Ability controls:** Changes each active pet's selected abilities from the
  frame.
- **Battle-state handling:** Keeps the frame and controls synchronized when
  entering and leaving pet battles.

### Loadouts and Integrations

- **Native loadouts:** Saves account-wide teams with rename, overwrite,
  restore, and delete actions.
- **Rematch integration:** Works with the Rematch team save/load flow when
  Rematch is installed.
- **PetTracker compatibility:** Uses PetTracker's live zone data when available
  without competing with its pet-journal behavior.
- **BattlePetBreedID support:** Shows enhanced breed information when that
  optional addon is installed.

### Pet Utilities

- **Quick-action buttons:** Provides access to pet healing, bandages,
  currencies, stones, rewards, and supported pet consumables.
- **Stable-master healing:** Supports automatic pet healing through stable
  masters.
- **Companion resummoning:** Can resummon a companion after common state
  transitions.
- **Charm totals:** Aggregates supported pet charm items and currencies in the
  HUD.

### Zone Tracking and Interface

- **Zone Pet Tracker:** Shows zone completion, collected pets, and missing pets
  for supported modern and legacy pet zones.
- **Movable minimap button:** Left-click toggles the main frame, right-click
  opens options, and dragging repositions the button.
- **Configurable presentation:** Includes scale, font, texture, opacity,
  visibility, and minimize controls.
- **Persistent settings:** Saves frame position, visibility, loadouts, and
  interface preferences between sessions.

## Compatibility

Battle Pet Utility supports **World of Warcraft Retail**. The current interface
value is maintained in [`BattlePetUtility.toc`](BattlePetUtility.toc), which is
the source of truth as Retail clients update.

### Requirements

- World of Warcraft Retail
- [RGX-Framework](https://github.com/RGXMods/RGX-Framework) as a required addon

### Optional Addons

- [Rematch](https://www.curseforge.com/wow/addons/rematch)
- [PetTracker](https://www.curseforge.com/wow/addons/pettracker)
- [Battle Pet BreedID](https://www.curseforge.com/wow/addons/battle-pet-breedid)

Battle Pet Utility works without the optional addons; each one enhances a
specific integration described above.

## Installation

### Addon Manager

Install Battle Pet Utility from
[CurseForge](https://www.curseforge.com/wow/addons/BattlePetUtility) or
[GitHub Releases](https://github.com/RGXMods/BattlePetUtility/releases). Ensure
your addon manager also installs the required RGX-Framework dependency.

### Manual Installation

1. Download Battle Pet Utility and RGX-Framework.
2. Extract both addons into the Retail AddOns directory:

   ```text
   World of Warcraft/_retail_/Interface/AddOns/
   ```

3. Confirm the folders are named `BattlePetUtility` and `RGX-Framework`.
4. Restart WoW or run `/reload`, then enable both addons at character select.

## Usage

Type `/bpu` to toggle the Battle Pet Utility frame. Right-click the frame or
the minimap button to open options, then enable the HUD sections and utilities
you want to use.

### Slash Commands

| Command | Description |
|---|---|
| `/bpu` | Toggle the Battle Pet Utility frame |
| `/bpu help` | Show command help |
| `/bpu welcome` | Toggle the login welcome message |
| `/bpu version` | Print the installed addon version |
| `/bpu icon on` | Show the minimap button |
| `/bpu icon off` | Hide the minimap button |

`/pb` is also registered as a short alias.

### Suggested First Setup

1. Open the frame with `/bpu`.
2. Open options and choose the HUD sections you want visible.
3. Adjust scale, opacity, fonts, and textures for your UI.
4. Save a native loadout, or use Rematch if it is installed.
5. Enable zone tracking and utility buttons as needed.

## Troubleshooting

### The Frame Does Not Appear

- Run `/bpu` and verify the addon is enabled for the current character.
- Confirm both `BattlePetUtility` and `RGX-Framework` are installed.
- Use `/bpu icon on` if only the minimap button is missing.
- Run `/reload` after updating or changing addon load state.

### Loadouts or Team Data Look Stale

- Avoid changing secure pet actions during combat; deferred updates are applied
  after combat ends.
- If Rematch is installed, verify which addon is managing the active team.
- Keep only one `BattlePetUtility` folder in the AddOns directory.

### Zone Data Is Unexpected

- PetTracker data is preferred when PetTracker is installed.
- Update the pet journal or change zones to refresh collection data.
- Include the current zone and optional-addon list when reporting a problem.

## Documentation

- [Release history](docs/CHANGES.md)
- [Documentation index](docs/README.md)
- [Roadmap](docs/ROADMAP.md)
- [Release process](docs/RELEASING.md)

## Support and Contributing

- Use [GitHub Issues](https://github.com/RGXMods/BattlePetUtility/issues) for
  reproducible bugs and user-facing feature requests.
- Join the [RealmGX Discord](https://discord.gg/rgxmods) for setup help and
  feedback.
- Include reproduction steps, your Retail client version, and installed
  optional addons in bug reports.

Development is maintained in the
[RGXMods GitLab repository](https://gitlab.dicematrix.cloud/rgxmods/warcraft/BattlePetUtility),
the source of truth for code and CI/CD. Public packages and release notes are
published through [RGXMods GitHub Releases](https://github.com/RGXMods/BattlePetUtility/releases).

Personal support for the author is available through
[GitHub Sponsors](https://github.com/sponsors/donniedice) and
[Buy Me a Coffee](https://buymeacoffee.com/donniedice).

---

<div align="center">

**Made by [DonnieDice](https://github.com/donniedice) for the [RealmGX](https://realmgx.com) community.**

_Your pets deserve a better HUD._

<img src="media/kiwi.gif" alt="RealmGX Kiwi" width="80">

</div>
