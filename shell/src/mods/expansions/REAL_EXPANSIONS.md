# Real Expansions

Turns `expansions/character/<id>/` packs that include `assets.swf` into **real CSS characters** (registered fighter + UI art; roster placement comes from the CSS editor).

Drop the folder in and enable the **Expansions** pack (**Vault → Manage Mods**). You do **not** need a `character.<id>` block in `mappings.json`.

## Pack layout

```
expansions/character/<id>/
  <id>.swf                   # fighter (name, guid, seriesIcon live inside this SWF)
  assets.swf                 # UI art — generic SymbolClass names, no character prefix
  costumes.json              # optional
  classic.json               # Classic Mode series / teammates (recommended)
```

Do **not** put `var characterID:String = "hero";` on the CSS chip. The engine fills `characterID` from the folder id.

### `assets.fla` linkages (export for ActionScript)

Same names in every pack. Publish as `assets.swf`.

| SymbolClass | Engine request | Used for |
| --- | --- | --- |
| `select` | `{id}_select` | CSS grid chip |
| `charselect` | `{id}_charselect` | CSS player-box PA |
| `stock` | `{id}_stock` | HUD / CSS stock |
| `icon` | `{id}_icon` / series hole | Series symbol |
| `classic` | `{id}_classic` | Classic portrait |
| `classic_trophy` | `{id}_classic_trophy` | Classic / All-Star trophy |
| `event` | `{id}_event` | Event mode art |
| `allstar` | `{id}_allstar` | All-Star mode art |
| `allstar_congrats` | `{id}_allstar_congrats` | All-Star congrats |
| `congrats` | `{id}_congrats` | Congrats / clear screen |
| `cssp` | `{id}_cssp` | CSS sprite-preview extra |

Do not prefix with the character id. Do not run the JSFL prefix-renamers on this FLA.

### classic.json

```json
{
  "series": "dragonball",
  "teammates": "goku,ichigo,naruto,luffy,donkeykong,lucario",
  "addToSeriesCharacters": true
}
```

## Drag and drop

1. Put the folder under `expansions/character/<id>/` with `assets.swf` + fighter file.
2. Enable **Expansions**. Restart / press F5.
3. On first launch the fighter SWF is loaded once, `displayName` / `seriesIcon` are copied into Stats, and `css_meta.json` + `series_icon.svg` are written next to the pack. The SWF is then unloaded. Later boots skip that load. `assets.swf` stays loaded.
4. The pack is registered (mappings `character.<id>` entry and UI templates), but it is **not** placed on the CSS grid automatically. Add it to the roster with the **CSS editor** and save; the editor save owns `character_select_screen.rows` and the random pool. `RealExpansionsMod` never appends slots.

## Optional mappings.json overrides

Hand-edit `data/misc/mappings.json` only if you do not use the CSS editor:

| What you put in mappings | Effect |
| --- | --- |
| `"<id>"` in a CSS row | That grid slot shows the pack |
| `"<id>"` in `random_characters.characters` | The pack is in the random pool |
| `"<id>"` in `exclude_character_from_random` | Kept out of the random pool |
| `character.<id>` block | Left as-is (not overwritten). Not required for auto packs. |

```json
"exclude_character_from_random": [ "sandbag" ]
```

Do **not** inject `menu_characters.swf` / `misc2.swf` or rewrite `mappings.swf` binary.
