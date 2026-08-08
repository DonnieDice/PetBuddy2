# v2.3.21 - 2026-08-08

## Changes
- **Minimap API update**: `RGX:CreateMinimapButton()` → `RGXMinimap:Create()` (new API)
- Slash commands already use `RGX:RegisterSlashCommand`
- Database already uses `RGX:NewDatabase()`

# Unreleased

## Fixes

- Fixed item-button secure actions not being deterministically reapplied after combat. `SafeSetButtonAttribute` correctly refuses `SetAttribute` during combat lockdown (taint-safe), but the deferred-refresh flag was never consumed and the item-button event bridge did not listen for `PLAYER_REGEN_ENABLED` — a button configured during combat only recovered incidentally on the next bag update. The bridge now listens for combat end and rebuilds the buttons when a write was deferred.

# v2.3.20 - 2026-06-30

## Fixes

- Fixed tainted aura scan — eating/combat helper now uses `C_UnitAuras.GetPlayerAuraBySpellID` instead of indexing aura slots, avoiding the secret `spellId` field that triggers hardware-event taint in combat.

# v2.3.19 - 2026-06-30

## Changes

- Updated Battle Pet Utility! for WoW Retail 12.0.7 with RGX-Framework dependency support.
- Completed PetBuddy2 to Battle Pet Utility! naming/branding cleanup across the live addon files.
- Restored HUD icon and TGA asset paths for the title, minimap, and loadout controls.

## Fixes

- Fixed broken HUD frame/icon rendering after the rename.
- Fixed BPU database initialization paths that could leave `addon.db` unavailable to frame handlers.
- Fixed tainted aura checks by avoiding secret aura-name comparisons in the eating/combat helper path.
- Fixed combat lockdown blocked action from zone tracker frame height updates.

# v2.3.18 - 2026-05-01

## Changes

- Updated BattlePetUtility font integration to use the corrected shared RGX font pipeline.
- Refreshed BattlePetUtility UI text rendering so addon panels and controls use the intended bundled font styling.
- Aligned BattlePetUtility option UI presentation with the updated RGX Framework behavior.

## Fixes

- Fixed BattlePetUtility font display issues caused by incomplete shared font registration/lookup behavior.
- Fixed inconsistent option UI text styling after the RGX font/layout updates.
