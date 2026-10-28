/**
 * Unit tests for Music Player catalog rules (mirrors MusicCatalog.as).
 * Run: node tests/MusicCatalog.test.js
 */
"use strict";

function collectStageSelectIds(mappings) {
  const out = [];
  const seen = Object.create(null);
  if (!mappings || !mappings.stage_select_screen) {
    if (mappings && mappings.stage) {
      for (const id of Object.keys(mappings.stage)) {
        if (!seen[id]) {
          seen[id] = true;
          out.push(id);
        }
      }
    }
    return out;
  }
  const screen = mappings.stage_select_screen;
  for (const key of ["normal", "past"]) {
    const section = screen[key];
    if (!section || !Array.isArray(section.rows)) continue;
    for (const row of section.rows) {
      if (Array.isArray(row)) {
        for (const cell of row) {
          const id = String(cell);
          if (id && id !== "null" && !seen[id]) {
            seen[id] = true;
            out.push(id);
          }
        }
      } else if (row != null) {
        const id = String(row);
        if (id && !seen[id]) {
          seen[id] = true;
          out.push(id);
        }
      }
    }
  }
  return out;
}

function stageIdAllowed(stageId) {
  if (!stageId) return false;
  if (stageId === "random" || stageId === "xpstage" || stageId === "traininggrid") return false;
  return true;
}

function buildCatalog(mappings, loadedMusic) {
  const selectIds = collectStageSelectIds(mappings);
  const stageIds = [];
  const defaultStageSongs = {};
  const logos = {};
  for (const stageId of selectIds) {
    if (!stageIdAllowed(stageId)) continue;
    if (mappings.stage && !mappings.stage[stageId]) continue;
    const songs = loadedMusic[stageId] || [];
    defaultStageSongs[stageId] = songs.slice();
    stageIds.push(stageId);
    // Logos come from stagePreviewer frames (always present for select stages).
    logos[stageId] = true;
  }
  stageIds.sort();
  return { stageIds, defaultStageSongs, logos };
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

function run() {
  const mappings = {
    stage: {
      battlefield: { name: "Battlefield" },
      finaldestination: { name: "Final Destination" },
      twtnw: { name: "The World That Never Was" },
      menubg_only: { name: "Hidden" },
      random: { name: "Random" },
    },
    stage_select_screen: {
      normal: {
        rows: [
          ["battlefield", "finaldestination"],
          ["twtnw", "random"],
        ],
      },
      past: {
        rows: [["xpstage"]],
      },
    },
  };

  // Only menu-bg stage loaded with music — catalog must still list all select stages.
  const loadedMusic = {
    battlefield: [{ id: "bf_theme" }],
  };

  const cat = buildCatalog(mappings, loadedMusic);
  assert(cat.stageIds.indexOf("battlefield") >= 0, "battlefield present");
  assert(cat.stageIds.indexOf("finaldestination") >= 0, "finaldestination present without loaded music");
  assert(cat.stageIds.indexOf("twtnw") >= 0, "twtnw present");
  assert(cat.stageIds.indexOf("random") < 0, "random excluded");
  assert(cat.stageIds.indexOf("xpstage") < 0, "xpstage excluded");
  assert(cat.stageIds.indexOf("menubg_only") < 0, "stage not on select screen excluded");
  assert(cat.defaultStageSongs.battlefield.length === 1, "loaded songs attached");
  assert(cat.defaultStageSongs.finaldestination.length === 0, "unloaded stage has empty song list");
  assert(cat.logos.twtnw === true, "each select stage has logo slot (previewer)");

  // Training Grid is select-screen but must not appear as a Music Player stage.
  mappings.stage.traininggrid = { name: "Training Grid", training_only: true };
  mappings.stage_select_screen.normal.rows.push(["traininggrid"]);
  const catTrain = buildCatalog(mappings, {
    battlefield: [{ id: "bf_theme" }],
    traininggrid: [{ id: "train_theme" }],
  });
  assert(catTrain.stageIds.indexOf("traininggrid") < 0, "traininggrid excluded from stages");
  assert(catTrain.stageIds.indexOf("battlefield") >= 0, "normal stages still present");

  // Cache stamp: same select layout + same loaded-song count → no rebuild needed.
  const stamp1 = `${collectStageSelectIds(mappings).length}:${Object.keys(loadedMusic).length}`;
  const stamp2 = `${collectStageSelectIds(mappings).length}:${Object.keys(loadedMusic).length}`;
  assert(stamp1 === stamp2, "cache stamp stable when nothing added");

  // New stage on select screen → stamp changes.
  mappings.stage_select_screen.normal.rows.push(["castle"]);
  mappings.stage.castle = { name: "Castle" };
  const stamp3 = `${collectStageSelectIds(mappings).length}:${Object.keys(loadedMusic).length}`;
  assert(stamp3 !== stamp1, "stamp changes when stage added");

  const cat2 = buildCatalog(mappings, loadedMusic);
  assert(cat2.stageIds.indexOf("castle") >= 0, "new stage appears after rebuild");
  assert(cat2.stageIds.length === cat.stageIds.length + 1, "exactly one new stage");

  console.log("MusicCatalog.test.js: OK (" + cat2.stageIds.length + " stages)");
}

run();
