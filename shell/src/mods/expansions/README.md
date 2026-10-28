# Expansions

Built-in pack that bundles three parts (`ExpansionsMod` boots them in this order):

| Part | What it does |
|------|--------------|
| `EventExpansionsMod` | Scans `expansions/events/` for event packs, merges them into `event_mode.eventList`, swaps `EventMenu` for `ExpansionEventMenu` (Vanilla / Expansions / Downloads lists), runs event series, and browses + installs events from the GameBanana Event category. |
| `ExpansionLoaderMod` | Registers `expansion_loader.rm` (`ExpansionResources.dispatch`, the engine's ResourceManager door for drop-in character/stage packs) and `expansion_loader.vectorIcon` (`VectorIconSvg`), then calls `ModHost.discoverAndLoadExpansions()` to load `expansions/character/` packs (`.ssf` / `.swf` plus optional `stock.png`, `PA.png`, `costumes.json`, `settings.json`). |
| `RealExpansionsMod` | Packs with `assets.swf` become real CSS characters: mappings entry, UI templates via `getLibraryMC` / `loadRealExpansionUi`, guid sync via `acceptCharacterGuid`. See [REAL_EXPANSIONS.md](REAL_EXPANSIONS.md). |

## Runtime

| File | Role |
|------|------|
| `mod.json` | Enable flag + entry |
| `mod.swf` | `ExpansionsMod` → the three parts above |

Disable in Vault → Manage Mods to skip folder scanning, the event list merge and GameBanana downloads (manifest `character_xp` entries still load from the base game).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File work\mod_build.ps1 -Id expansions
```