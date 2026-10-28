# Manager Bridge

Built-in link between the game and SSF2 Mod Manager. `ManagerBridgeMod` forwards boot calls to `Ssf2StreamMod`, which does the work:

- **File bridge** with the Mod Manager and the SSF2 Stream panel: deep links (CSS, SSS, menus, events, instant match), commands, catalog dumps, menu music.
- **Attract mode** (`AttractMode`): idle demos, intro videos, and how-to segments on the title screen.
- **Boot intro**: skip, stock intros, random, or a custom FLV.
- **Crash reports**: uncaught errors are logged, shown as a toast, and flagged to the Mod Manager.

It does not patch `engine2.swf`.

## Classes

`Ssf2StreamMod` is the coordinator: shared session fields, `onBoot` / `onBootEnd`, the host hooks, `log`, and `runStep` / `logStepError` (one `<step> failed: <err>` line when a critical step throws). Each part holds it as `core`.

| Class | Owns |
|---|---|
| `StreamLaunchPrefs` | `launch.json`, `boot.json`, fullscreen, vault prefs, credits audit. |
| `StreamCmdChannel` | `cmd.json` poll, dispatch, ack/clear, apply-launch, soft teardown. |
| `StreamBootIntro` | Stock and custom boot intros, skip to title, vault redirect. |
| `StreamAttractLink` | Arms `AttractMode`, random intro pool. |
| `StreamDeepLink` | Deep-link state machine (wait home, open CSS, fix up, match). |
| `StreamCssMenus` | Menu lookup, CSS open/init, mode statics. |
| `StreamRoster` | Roster and rules onto the CSS. |
| `StreamMatchStart` | Match start from CSS or fallback Game, live patch, sandbag. |
| `StreamEvents` | Event mode launches. |
| `StreamMusic` | `now-playing.json`, `menu-music.json`, menu/match music, song HUD. |
| `StreamCatalog` | `catalog.json`. |
| `StreamCursor` | `cursor.json`, `pointer.json`, `stage.json`. |
| `StreamUncaughtHooks` | UNCAUGHT_ERROR arming on app, stage and loaders. |
| `StreamCrash` | Uncaught response, crash replay, `alert.json`, `last_error.txt`. |

`AttractMode` is the attract state machine; `AttractDemo` runs the live CPU demo and `AttractVideo` the How to Play, intro and logo segments.

## Files in `data/ssf2mm/state`

| File | Direction | Use |
|---|---|---|
| `launch.json` | Manager → game | Deep link read once at boot. |
| `boot.json` | Manager → game | Boot intro, fullscreen, attract settings. |
| `cmd.json` | Manager → game | Live commands (`op`), polled every 500 ms and cleared after reading. |
| `catalog.json` | game → Manager | Characters, stages, music, menus (`refreshcatalog`). |
| `menu-music.json` | both | Menu playlist and loop setting. |
| `now-playing.json` | game → Manager | Current song. |
| `pointer.json` | Manager → game | Stream panel pointer. |
| `cursor.json` | game → Manager | Hand-cursor targets for the Stream panel. |
| `stage.json` | game → Manager | Game window (Flash stage) size, for pointer mapping. |
| `alert.json` | game → Manager | Asks the Manager to open the log after a crash. |
| `last_error.txt` | game → Manager | Last uncaught error, for Copy Last Uncaught Error. |

The log is `data/ssf2mm/game.log`.

## Writing `cmd.json`

The game drops a command whose text is identical to the previous one. Every writer must include a unique `cmdId` (a counter or timestamp), for example `{"op":"refreshcatalog","cmdId":"1739999999123"}`.

## Build

`work/mod_build.ps1 -Id manager_bridge`. The LaunchScreen fixture runs with `fixture/run-fixture.ps1` (set `SSF2_DEV_TOOLS` to the shell-dev `tools` folder if it is not in the default location).
