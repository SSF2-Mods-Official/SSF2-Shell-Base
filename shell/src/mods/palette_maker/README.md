# Palette Maker pack

## Runtime (what the game loads)

| File | Role |
|------|------|
| `mod.json` | Metadata, `entryClass`, and `resources` list |
| `mod.swf` | Compiled AS3 (editor logic) |
| `menu_palette_maker.ssf` | Flash UI library (`VCostumeCreatorMenu`, buttons, loading screen, …) |

Host reads `resources` from `mod.json` and registers them with `ResourceManager` (no engine hardcode). Install set is those three files.

## Build-only (not read by the game)

| Path | Role |
|------|------|
| `src/` | ActionScript sources |
| `asconfig.json` | asconfigc / IDE compile config → outputs `mod.swf` |
| `src/*.bin`, `src/**/icons/*.svg` | Embedded into `mod.swf` at compile time |

## Engine (not files you ship)

At runtime the pack talks to the game via Host doors and `Ssf2` (`getDefinitionByName`) — same pattern as other external mods (`ice_climbers_mode`, `mod_menu`). No decompiled scripts or engine SWCs are needed to compile.

Rebuild SWF (src-only; Discord/Rumble/NativeJoystick ANEs from `build/` if present):

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build_mods.ps1 palette_maker
```

### Linked forms (Zelda/Sheik, Bowser/Giga, …)

Each form has its own vault JSON (`zelda.json` / `sheik.json`, `bowser.json` / `gigabowser.json`). Pairing is by CSS costume index. Save writes the current form only (partner stays stock at that slot). **Shift+Save** writes a clone into both forms’ matching slots.
