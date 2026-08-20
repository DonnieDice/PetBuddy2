# BattlePetUtility

BattlePetUtility is a Retail-only WoW addon for battle-pet loadouts, pet-related action buttons, healing, summoning, zone tracking, and options. `BattlePetUtility.toc` is the authoritative metadata and load list; it currently targets Retail interface `120007` and requires `RGX-Framework`.

## Layout

- `data/` contains runtime Lua modules. Keep their TOC order intact when adding dependencies between modules.
- `ui/` contains the XML templates and frames loaded after the Lua modules.
- `media/` contains shipped textures and icons.
- `docs/CHANGES.md` is the canonical changelog; `docs/RELEASING.md` and `docs/ROADMAP.md` contain supporting release and planning notes.

## Framework Rules

- Use the existing RGX APIs for lifecycle events, timers, hooks, slash commands, the database, minimap integration, and debug output rather than introducing parallel plumbing.
- The RGXPetBattles migration is complete: battle-pet operations use `RGX:GetPetBattles()`. Do not reintroduce direct `C_PetBattles` calls.
- The RGXDropdowns migration is complete for addon context menus: `data/options_dropdown.lua` uses `RGXDropdowns:CreateContextMenu`. Preserve the legacy menu-item schema consumed by that adapter.
- `data/itembuttons.lua` must not change secure button attributes during combat. Preserve `SafeSetButtonAttribute` and the deferred `PLAYER_REGEN_ENABLED` refresh path.
- Keep aura checks on `C_UnitAuras.GetPlayerAuraBySpellID`; do not inspect secret aura fields.
- Framework references: `../RGX-Framework/AGENTS.md`, `../RGX-Framework/docs/API.md`, and `../RGX-Framework/docs/DROPDOWNS.md`.

## Development And Release

- Match the existing tab indentation and semicolon-terminated style in `data/`.
- There is no standalone build or automated test suite. Install the repository as `BattlePetUtility` in the Retail AddOns directory, ensure `RGX-Framework` is installed, run `/reload`, and exercise the HUD, loadouts, context menus, item buttons, pet battle transitions, and combat-lockdown recovery.
- For a release, update `BattlePetUtility.toc` and the relevant documentation/changelog entries. Stable tags use `vX.Y.Z`; `.github/workflows/release.yml` validates the tag against the TOC version and packages with BigWigsMods/packager. Branch pushes to `dev` and `alpha` produce their corresponding channels.
