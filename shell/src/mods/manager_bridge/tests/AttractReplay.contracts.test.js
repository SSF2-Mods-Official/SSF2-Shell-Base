/**
 * Contract tests for attract audio stop and demo launch, asserted on the real AS3 source.
 * Run: node --test
 */
"use strict";

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const SRC_DIR = path.join(__dirname, "..", "src");
const read = (name) => fs.readFileSync(path.join(SRC_DIR, name), "utf8");
const ATTRACT = read("AttractMode.as");
const ATTRACT_DEMO = read("AttractDemo.as");
const ATTRACT_ALL = [ATTRACT, ATTRACT_DEMO, read("AttractVideo.as")].join("\n");
const ATTRACT_LINK = read("StreamAttractLink.as");
const ALL_SOURCES = fs.readdirSync(SRC_DIR).filter((f) => f.endsWith(".as")).map((f) => [f, read(f)]);

function functionBody(src, name) {
  const start = src.indexOf("function " + name + "(");
  assert.ok(start >= 0, name + " not found");
  const open = src.indexOf("{", start);
  let depth = 0;
  for (let j = open; j < src.length; j++) {
    if (src[j] === "{") depth++;
    else if (src[j] === "}" && --depth === 0) return src.slice(open, j + 1);
  }
  throw new Error("unterminated " + name);
}

function indexOrFail(body, needle, label) {
  const i = body.indexOf(needle);
  assert.ok(i >= 0, label + ": missing `" + needle + "`");
  return i;
}

function count(body, needle) {
  return body.split(needle).length - 1;
}

test("stopAttractMusic stops SoundQueue and every timeline channel", () => {
  const body = functionBody(ATTRACT, "stopAttractMusic");
  indexOrFail(body, "SQ.instance.stopMusic()", "stopAttractMusic");
  indexOrFail(body, "SQ.instance.stopAllSounds()", "stopAttractMusic");
  indexOrFail(body, "SoundMixer.stopAll()", "stopAttractMusic");
});

test("SoundMixer is imported, not looked up by name", () => {
  const users = ALL_SOURCES.filter(([, src]) => src.includes("SoundMixer."));
  assert.ok(users.length >= 2, "SoundMixer users found");
  for (const [name, src] of users) {
    assert.ok(src.includes("import flash.media.SoundMixer;"), name + " imports SoundMixer");
    assert.ok(!src.includes('"flash.media.SoundMixer"'), name + " has no getDefinitionByName for SoundMixer");
  }
});

test("startLiveDemo stops audio before it marks the demo busy, and launches once", () => {
  const body = functionBody(ATTRACT, "startLiveDemo");
  const guard = indexOrFail(body, "if (m_busy)", "startLiveDemo re-entry guard");
  const stop = indexOrFail(body, "stopAttractMusic();", "startLiveDemo");
  const media = indexOrFail(body, "hardStopAttractMedia();", "startLiveDemo");
  const busy = indexOrFail(body, "m_busy = true;", "startLiveDemo");
  assert.ok(guard < busy, "re-entry guard runs before m_busy = true");
  assert.ok(media < busy && stop < busy, "audio stopped before the demo starts");
  assert.strictEqual(count(body, "m_busy = true;"), 1, "demo marked busy exactly once");
  assert.strictEqual(count(body, "new GameCls("), 1, "one Game is built per launch");
});

test("finishSegment stops media and unloads demo SWFs before clearing busy", () => {
  const body = functionBody(ATTRACT, "finishSegment");
  const hold = indexOrFail(body, "m_playlistHold = true;", "finishSegment");
  const media = indexOrFail(body, "hardStopAttractMedia();", "finishSegment");
  const unload = indexOrFail(body, "unloadDemoResources();", "finishSegment");
  const idle = indexOrFail(body, "m_busy = false;", "finishSegment");
  assert.ok(hold < media && media < unload && unload < idle);
});

test("unloadDemoResources unloads every character, stage and music id", () => {
  const body = functionBody(ATTRACT_DEMO, "unloadDemoResources");
  for (const list of ["chars", "stages", "music"]) {
    indexOrFail(body, "unloadAll(RM, " + list + ")", "unloadDemoResources");
  }
  assert.ok(!/Lru|_CAP/.test(ATTRACT_ALL), "no LRU caps left in AttractMode");
});

test("attractAbortIntro stops intro playback and the mixer twice", () => {
  const body = functionBody(ATTRACT_LINK, "attractAbortIntro");
  const stop = indexOrFail(body, "stopActiveIntroPlayback();", "attractAbortIntro");
  const mix = indexOrFail(body, "SoundMixer.stopAll();", "attractAbortIntro");
  assert.ok(stop < mix);
  assert.strictEqual(count(body, "SoundMixer.stopAll();"), 2, "immediate + delayed mixer stop");
});
