# SSF2 Shell Base

SSF2 Shell Base turns your own copy of **Super Smash Flash 2 Beta 1.4.0.1** into a playable SSF2 Shell, written to `Build/`.

It is built for 1.4.0.1. The build does not stop when a vanilla file hash differs. A newer SSF2 release still needs the patches moved first, with `port` (see [Porting to a new SSF2 version](#porting-to-a-new-ssf2-version)).

This repo has no McLeodGaming game data and no decompiled McLeodGaming source. It holds:

- the shell's own files: the launcher, the bootstrap, the built-in mods and the ANEs;
- patches, applied to a fresh decompile of the user's `SSF2.swf`.

All game content is read from the vanilla install at build time.

## Contents

1. [Requirements](#requirements)
2. [Quick start](#quick-start)
3. [Options](#options)
4. [What you get](#what-you-get)
5. [How the build works](#how-the-build-works)
6. [Patch format](#patch-format)
7. [Repo layout](#repo-layout)
8. [Maintainers: updating the patches](#maintainers-updating-the-patches)
9. [Porting to a new SSF2 version](#porting-to-a-new-ssf2-version)
10. [Troubleshooting](#troubleshooting)
11. [Release](#release)
12. [SSF2 Mod Manager flow](#ssf2-mod-manager-flow)

## Requirements

| What | Notes |
|---|---|
| Windows 10/11 x64 | The shell runs on the 64-bit AIR captive runtime. |
| Python 3.10+ | The build script uses the standard library only. |
| Next2Flash | Supplies the decompiler (`app/n2f.py`) and the compiler (`toolchain/asconfigc`, `aflex_lite`, the bundled JRE). The patches were captured with Next2Flash `551ccc2f` (v0.2.0). |
| SSF2 Beta 1.4.0.1 | An installed copy, and only that version. The build checks `SSF2.swf` against sha256 `9afefb865f540eba5c26549f47c6892cdfbb1802ac93aa55723462c469eaacf4`. The install also supplies the game data and the `Adobe AIR` runtime. |
| About 1 GB free | `Build/` is about 910 MB. Most of it is the vanilla data, copied. |

## Quick start

```
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
```

With no arguments, `build.ps1` uses:

- the default vanilla install path, `C:\Program Files (x86)\Super Smash Flash 2 Beta`;
- Next2Flash in a folder next to this repo.

The build takes about 40 seconds. When it finishes, run `Build\Super Smash Flash 2 Beta.exe`.

## Options

```
build.ps1 [-Vanilla <install>] [-Next2Flash <folder>] [-Out <folder>]
python tools/shellbase.py build --vanilla <install> --n2f <Next2Flash> [--out <folder>]
```

| Option | Default | Meaning |
|---|---|---|
| `-Vanilla` / `--vanilla` | `C:\Program Files (x86)\Super Smash Flash 2 Beta` | The vanilla install. Its files are only read, never changed. |
| `-Next2Flash` / `--n2f` | `..\Next2Flash` | The Next2Flash checkout or install. |
| `-Out` / `--out` | `Build\` | Output folder. The build clears it first. It refuses to clear a folder that isn't a previous build. |

`--n2f` accepts a Next2Flash checkout (`app/n2f.py`) or a release install (`runtime/resources/app/n2f.py`).

Intermediate files go to `work/build/`, which is gitignored. The Next2Flash output for every step goes to `work/build/n2f.log`.

## What you get

`Build/` is a complete, standalone game folder:

| Path | Source |
|---|---|
| `Super Smash Flash 2 Beta.exe`, `META-INF/AIR/application.xml`, `mimetype`, `icons/` | `shell/` |
| `META-INF/AIR/extensions/` (native joystick x64, Discord, rumble) | `shell/` |
| `discord_game_sdk.dll` | `shell/` |
| `Adobe AIR/` | The vanilla install's runtime (64-bit AIR 32.0.0.89), which `SSF2.exe` and the ANEs are built for |
| `SSF2.swf` | `shell/`: the shell bootstrap, which loads `engine1.swf` and then `engine2.swf` |
| `data/engine/engine1.swf` | `shell/`: the libraries and a few vanilla symbols |
| `data/engine/engine2.swf` | Built from vanilla `SSF2.swf` plus `patches/engine2/` |
| `data/misc/mappings.json`, `data/misc/mappings.ssf` | Built from vanilla `DAT51.ssf` plus `patches/mappings/patch.json` |
| `data/{character,stage,menu,misc,modes,sound}/*.ssf` | Vanilla `data/DATn.ssf`, renamed |
| `data/ssf2mm/*` (debug, expansions, manager_bridge, menu_background, menu_editor, mod_menu, music_player, palette_maker, rumble) | `shell/`: built-in mods. ModHost loads them at boot. |
| `data/video/how_to_play.flv` | `shell/`, released in the assets `.ssfpatch` |
| `install/VC_redist.x64.exe` | `shell/`, released in the assets `.ssfpatch`: Microsoft's Visual C++ runtime installer, which the Discord and rumble ANEs need |
| `shell-base-build.json` | Hashes of the inputs and of the built `engine2.swf` |

Some vanilla mappings point at DATs that 1.4.0.1 doesn't ship. Five songs and the dev `test*`/`xpstage` entries are like this. The build logs them as `data missing`, and the engine drops them at load (`Resource.dropMissingMappedFiles`).

## How the build works

`tools/shellbase.py build` runs these steps in order. Any failure stops the build before `Build/` is touched.

| Step | Function | What it does | Log line |
|---|---|---|---|
| Check | `cmd_build` | Requires `SSF2.swf` in the vanilla folder. It does not compare hashes. | `vanilla hash check skipped` |
| Vanilla base | `vanilla_base`, `stage_text` | Decompiles vanilla `SSF2.swf` once. It fixes the decompiler's `.§name§` property syntax to `["name"]` and points the three `[Embed]` bins at `_assets/`. The 214 McLeodGaming classes that result are the patch base, and they compile as they are. The shell source uses the same text (see [rebaseline](#rebaseline)), so the patches carry real edits and not decompiler noise. | `vanilla base classes=214` |
| Patch | `apply_patch` | Applies `patches/engine2/patches`, adds `patches/engine2/added`, and checks every class against the shell's sha256. A hash mismatch names the Next2Flash commit in use and the one in `base.json`. | `engine2 source classes=228 mismatched=0 extra=0` |
| Compile | `N2f.compile` | Compiles the source with `patches/engine2/externs` (`engine1.swc`, `link-report.xml`, `airglobal.swc`). Settings: target 32.0, optimize, non-strict, mainClass `com.mcleodgaming.ssf2.Main`. Classes are included in the order stored in `base.json`. 200 files are written with CRLF, as captured. | `engine2.swf <n> bytes` |
| Mappings | `decode_vanilla_mappings`, `merge_apply`, `encode_shell_mappings` | Decodes the vanilla blob (`Utils.d` with key `b7d60849-…`) and applies the merge patch. Writes `mappings.json`, and also re-encodes the result into `mappings.ssf` in the shell format (one extra Base64 layer). | `mappings characters=51 stages=113 music=189` |
| Manifest | `manifest_bin` | Reads vanilla DefineBinaryData 514 and removes its `Utils.d` layer (key `cedbe0e0-…`). The plain Base64 JSON that is left becomes the shell's `ResourceManager_manifestJSON` embed. The other two embeds (word filter, country regions) are copied from vanilla unchanged. | |
| Data | `data_layout`, `copy_data` | Copies each `data/<folder>/<file>` from vanilla `data/<file_pub>`. Entries come from the manifest (menu, misc, modes, audio) and from mappings (character, stage, music, extra). The engine skips the `.ssf` header ints, so vanilla bytes work as they are. | `data copied=<n> missing=<n>` |
| Runtime and overlay | `copy_air`, `copy_overlay` | Copies the vanilla `Adobe AIR` folder, then `shell/` (without its top-level `src/`). A missing `ASSET_PATHS` file logs `asset missing shell/<path>`. | `AIR runtime files=12`, `shell files=<n>` |

The output is deterministic. `verify` confirms that the built `engine2.swf` has exactly the tags of the shell's committed one. Only the ProductInfo tag differs, because it holds the compile date.

Three details are needed to get there:

- the shell's include order, which is case-insensitive, like PowerShell `Sort-Object`;
- the shell's line endings, because CRs inside multi-line literals end up in the bytecode;
- the same externs.

## Patch format

There is one file per class, `patches/engine2/patches/<package path>/<Class>.as.patch`:

```
# com/mcleodgaming/ssf2/util/Resource.as
## public function load() : void
## why: expansion characters: load the SWF from the mod pack path
@@ <base line> <deleted count> <sha1 of deleted lines, 16 hex> <added count>
+added line
=<base line number of a line the shell keeps>
```

- Hunks are grouped by the section they change: a method signature, `class header`, or `class footer`. A `## <section>` line names it, and a `## why:` line says why the shell needs it. `apply_patch` skips every `## ` line.
- `capture` keeps each `## why:` reason by section name when it rewrites the patches. A new section gets `## why: TODO`. The log line `patch sections=<n> why missing=<n>` counts them, and `work/capture/why-missing.txt` lists the TODO sections.
- Hunks have no context lines. Deleted text is stored only as a hash, so a patch never contains a line that the shell drops. A line the shell keeps that is already in the base is `=<line number>`, not a second copy of that text.
- Positions are exact, because the base is pinned by hash per class.
- `apply_patch` stops on any hash mismatch. It never fuzzes.
- `patches/engine2/added/` holds the 13 classes that exist only in the shell: ModHost, ModAPI, GameLog, SwfRelease, and the Discord and rumble ANE wrappers.
- No embedded data is stored. The manifest is generated from vanilla at build time, so the repo carries no SSF2 asset.
- Patches carry only real edits. A method the shell doesn't change has vanilla's decompiled text in the shell source too (see [rebaseline](#rebaseline)). The 75 patches store kept vanilla lines as line numbers. The text they add is the shell's own edit.

## Repo layout

| Path | Contents |
|---|---|
| `build.ps1` | Windows wrapper for `shellbase.py build` |
| `tools/shellbase.py` | The `build`, `capture`, `rebaseline`, `verify`, `pack` and `port` commands |
| `tools/tests/test_shellbase.py` | Fixture tests for the patch format, the mappings and manifest codecs, the SWF rewrite, the data layout, the include order, the rebaseline normalizer and merge, the `## why` patch notes, the release pack and the port merge |
| `tools/tests/test_mod_imports.py` | Fails when a mod file uses an engine class such as `GameLog` without importing it. Mods compile with `strict:false`, so the build does not catch this; the game throws a ReferenceError instead. |
| `tools/tests/test_music_list.py` | Fails when the music player's stock `list.json` names a song or stage that is not in the vanilla mappings. Pack songs belong in the pack's own list. Skipped when vanilla SSF2 is not installed. |
| `tools/booter/` | Source of the booter (`shell/SSF2.swf`). Not copied into the game. |
| `tools/fixtures/engine/` | Engine fixtures (`framegate`, `swfrelease`). Each `run-fixture.ps1` compiles against `work/build/engine2/src` from the last `build`, and prints `fixture OK`. |
| `patches/engine2/base.json` | The vanilla hash, the Next2Flash commit, per-class base and target hashes, the include order and the CRLF list |
| `patches/engine2/patches/`, `patches/engine2/added/`, `patches/engine2/externs/` | engine2 inputs, described above |
| `patches/mappings/base.json`, `patches/mappings/patch.json` | The vanilla mappings DAT with its inner md5, and the merge patch. `music` is skipped. |
| `shell/` | Files copied into `Build/` as they are: the booter, built-in mods (`data/ssf2mm`). The booter source and the engine fixtures live under `tools/`, so they are not shipped. Mod source is `shell/src/mods`, and the compiler libraries are `shell/src/engine`. `tools/build-mod.ps1` compiles a mod and copies `mod.swf` into `Build/data/ssf2mm`. `src` is not copied into `Build`. |
| `ASSET_PATHS` in `shellbase.py` | The large `shell/` files that rarely change: `install/VC_redist.x64.exe` and `data/video/how_to_play.flv`. `pack` puts them in their own `.ssfpatch` and leaves them out of the core one. |

The `.gitattributes` file turns off line-ending conversion. Patches and added classes are checked by hash, so they have to stay byte-exact.

## Maintainers: updating the patches

An engine change is an edit under `patches/engine2/`. Do not decompile `engine2.swf` into a second source tree and edit that. `build` applies the patches to a fresh vanilla decompile and writes `Build/data/engine/engine2.swf`.

```
python tools/shellbase.py build --vanilla <install> --n2f <Next2Flash>
python -m unittest discover -s tools\tests
```

A mod change is `shell/src/mods`, then `tools/build-mod.ps1 <id>`.

`capture` and `rebaseline` import an already-decompiled tree into `patches/engine2/`. They are for bringing an old tree in, not for the next engine edit. `verify --shell` compares `Build/` to that same kind of tree.

### Rebaseline

This imports a decompiled tree into the patch text. It is not how an engine edit is made. An engine edit is a change in `patches/engine2/`, then `build`.

```
python tools/shellbase.py rebaseline --shell <decompiled-tree> --vanilla <install> --n2f <Next2Flash> [--dry-run]
```

Run this before `capture` when a decompiled tree was produced by a different tool or version, or from a recompiled SWF. It rewrites that tree's `expansions/decompiled/engine2/changed` method by method against the vanilla base text:

- Methods are matched by signature without parameter names (`sig_key`): vanilla keeps its debug names (`e`), a recompile has `param1`.
- Two clean-ups run on the shell method first. `unalias_params` drops `var name:T = paramN;` and uses the parameter, which a recompile adds when the method has a closure. `clean_resets` keeps only the last store per local in a run of consecutive `local = <default>;` lines.
- A method that matches vanilla after normalization (`same_method`) takes the vanilla text. Normalization ignores:
  - parameter and local names, with `_locN_` numbering and where declarations sit;
  - declared locals that nothing reads, and a local typed `*` against any type;
  - leading default resets, `paramN = paramN;` and `_locN_ = _locN_;`;
  - `this.` and the `Boolean`/`int`/`uint`/`Number`/`String` casts;
  - `x += 1` against `x++`, and `new (X as Class)(` against `new X(`;
  - `for(a; b; c)` against `a;` `while(b)` … `c;` (`loop_lines`; skipped for loops with `continue`).

  String literals are never renamed.
- Any other method is merged (`merge_method`): the vanilla text is kept and only the real changed lines are spliced in, with shell locals renamed to vanilla's names. Two shell locals can share one vanilla name when they are never live at the same time. The merge is used only when it normalizes equal to the shell method; otherwise the shell text is kept. New methods stay after the method they followed.
- The class header keeps vanilla's imports and adds the shell-only ones (`merge_header`). When only imports differ and every method is vanilla's, it takes vanilla's header.
- The manifest embed is replaced with the vanilla bytes from `manifest_bin`.

The first run backs up `changed` to `changed.bak-<date>` and the embed to `<bin>.bak-<date>`. The log shows `rebaseline <class> methods=<n> reverted=<n> kept=<n>` and `patch size before … after …`. `--dry-run` writes the new tree to `work/rebaseline/new` and leaves the shell alone. After a real run, recompile the shell's engine2 (`compile_engine2.ps1` in the manager's shell-dev tools), play a match, then `capture`.

A section that `capture` marks `## why: TODO` after a rebaseline is usually decompiler text the shell picked up, not an edit. Two cases came from the old round-trip base: mxmlc drops `trace()` calls, and the second decompile lost the parentheses in `AI.checkTaunt`'s `A && (B || C)`. Revert those methods to vanilla rather than writing a note.

## Porting to a new SSF2 version

```
python tools/shellbase.py port --old-vanilla <1.4.0.1 install> --new-vanilla <new install> --n2f <Next2Flash> [--out work/port]
```

`port` moves the shell's engine2 edits onto a new SSF2 release. It decompiles both installs (old base O, new base N) and applies the patches to O, which gives the shell source S. Then it handles each section (class header, each method, class footer) on its own:

| Case | Result | Counted as |
|---|---|---|
| O and N are the same | S, the shell's edit carries over as it is | `clean` |
| S and O are the same | N, the shell never edited it | `upstream` |
| All three differ | A line-level 3-way merge of O→S and O→N, when the two sets of changes don't touch | `merged` |
| The changes touch | N, plus a `report.md` entry | `conflicts` |
| N no longer has the method or class | Nothing, plus a `report.md` entry | `missing` |

Shell-only methods stay after the method they followed. `patches/engine2/added` classes are copied unchanged. The log line is `port classes=<n> clean=<n> upstream=<n> merged=<n> conflicts=<n> missing=<n>`.

The output is `<out>/changed/`, a full engine2 source tree for the new version, and `<out>/report.md`. Each report entry has the class, the section, its `## why:` note, and the O, S and N text. The note says what the edit is for, so a person or an AI can redo it by hand on N.

Then:

1. Copy `<out>/changed` over the shell's `expansions/decompiled/engine2/changed`, and redo every report entry.
2. Recompile the shell's engine2, play a match, and check `game.log`.
3. Run `capture` and `build` with `--vanilla <new install>`, then `verify`. `capture` records the new `SSF2.swf` hash in `patches/engine2/base.json`.
4. Check the vanilla-data rules (`data_layout`, the mappings key, the manifest tag id) against the new version.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `vanilla SSF2.swf sha256 … does not match` | Not 1.4.0.1, or a modified `SSF2.swf` | Reinstall SSF2 Beta 1.4.0.1. A newer version needs [porting](#porting-to-a-new-ssf2-version). |
| `hash mismatch` or `patched engine2 source does not match the shell (Next2Flash … decompiles differently …)` | A different Next2Flash version decompiles differently | Use the Next2Flash commit in `patches/engine2/base.json`, or rebaseline and re-run `capture` with the new one. |
| `patched engine2 source does not match the shell` with the same Next2Flash commit | A patch or added class changed on disk, often through line-ending conversion | Check out again with `.gitattributes` in place. |
| Black screen or error 3500 at launch | The Visual C++ runtime that the Discord and rumble ANEs need is missing | Install the [VC++ redistributable (x64)](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist). |
| Loading stops at 80% | A built-in mod is missing, usually `data/ssf2mm/expansions` | The game log should show `[boot] real_expansions ui n=0` after `[ModHost] boot mods ready`. |
| Anything else in game | | Read `Build/data/ssf2mm/game.log`. For build problems, read `work/build/n2f.log`. |

## Release

A release is two `.ssfpatch` files (plain zips) on the GitHub release of this repo:

| File | Contents | Changes when |
|---|---|---|
| `shell-base-<version>.ssfpatch` | `ssfpatch.json`, `tools/shellbase.py`, `patches/`, `shell/` (about 10 MB) | Every release |
| `shell-assets-<id>.ssfpatch` | `ssfpatch-assets.json` and the `ASSET_PATHS` files under `shell/` (about 65 MB) | Only when one of those files changes; `<id>` hashes their `shell/<path>` and contents |

Unzipping both into one folder gives a tree that `python tools/shellbase.py build` runs from. `ssfpatch.json` holds `format`, `kind`, `version`, `assets` (the id the core expects), `vanilla_ssf2_sha256`, `next2flash_commit` and `created`.

```
python tools/shellbase.py pack --version 1.0.0
gh release create v1.0.0 work/dist/shell-base-1.0.0.ssfpatch work/dist/shell-assets-<id>.ssfpatch --repo SSF2-Mods-Official/SSF2-Shell-Base
```

`pack` stops when any patch still has `## why: TODO`. Attach the assets file to every release, even when its id has not changed, so the latest release always has both. The manager only downloads it again when the id changes.

## SSF2 Mod Manager flow

`ShellBaseService` in the manager:

1. Reads the latest release of `SSF2-Mods-Official/SSF2-Shell-Base`. A token from `SSF2MM_GITHUB_TOKEN`, `GITHUB_TOKEN` or `GH_TOKEN` is sent when set, which only raises the API rate limit.
2. On a new PC, the setup window downloads Next2Flash, asks for the vanilla SSF2 Beta 1.4.0.1 folder, and builds the Shell. The build does not stop on a vanilla file hash. Later launches compare the release version with `shell-base-build.json` and offer a rebuild. A Shell whose `shell-base-build.json` version is `dev` is never rebuilt.
3. Uses the vanilla folder from settings or the default install path.
4. Downloads both `.ssfpatch` files into `%LocalAppData%\SSF2ModManager\shellbase`, reusing cached files, and checks the vanilla `SSF2.swf` hash. The assets file is downloaded only when its id changes. After a good build, older `.ssfpatch` files in the cache are deleted.
5. Runs `shellbase.py build` with Next2Flash's python, then copies the output over the Shell folder. User mods, `data/ssf2mm/state` and `expansions/` stay, because the build output only overwrites its own files.

The manager log shows `[shellbase] latest=<v> installed=<v>`, `[shellbase] build ok version=<v> assets=<id>` then `[shellbase] cache pruned removed=<n>`, or `[shellbase] build fail …`.
