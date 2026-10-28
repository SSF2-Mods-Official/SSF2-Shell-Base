/**
 * Mod menu scroll math. Constants are read from ModMenuScroll.as so they cannot go stale.
 * The JS functions below mirror these AS3 statics in ModMenuScroll.as (ModMenuMod calls them):
 *   itemTopY(view, itemIndex)       -> itemTopY
 *   sectionStartsAt(view, itemIndex) -> sectionStartsAt
 *   maxScrollIndex(view, track)     -> maxScrollIndex
 * fixture/ModMenuScrollFixture.as runs the AS3 statics themselves.
 * If the AS3 changes, the source-shape test fails and this port must be updated.
 * Run: node --test
 */
"use strict";

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const SRC = fs.readFileSync(path.join(__dirname, "..", "src", "ModMenuMod.as"), "utf8");
const SCROLL_SRC = fs.readFileSync(path.join(__dirname, "..", "src", "ModMenuScroll.as"), "utf8");

function readConst(name) {
  const m = SCROLL_SRC.match(new RegExp("const\\s+" + name + "\\s*:\\s*int\\s*=\\s*(-?\\d+)\\s*;"));
  assert.ok(m, name + " not found in ModMenuScroll.as");
  return Number(m[1]);
}

function readVarInt(name) {
  const m = SRC.match(new RegExp("var\\s+" + name + "\\s*:\\s*int\\s*=\\s*(-?\\d+)\\s*;"));
  assert.ok(m, name + " not found in ModMenuMod.as");
  return Number(m[1]);
}

function functionBody(name, src = SCROLL_SRC) {
  const start = src.indexOf("function " + name + "(");
  assert.ok(start >= 0, name + " not found");
  let i = src.indexOf("{", start);
  let depth = 0;
  for (let j = i; j < src.length; j++) {
    if (src[j] === "{") depth++;
    else if (src[j] === "}" && --depth === 0) return src.slice(i, j + 1);
  }
  throw new Error("unterminated " + name);
}

const ROW_H = readConst("ROW_H");
const SECTION_H = readConst("SECTION_H");

function sectionStartsAt(view, itemIndex) {
  if (itemIndex < 0 || itemIndex >= view.length) return false;
  const sec = String(view[itemIndex].section || "");
  if (sec.length < 1) return false;
  if (itemIndex === 0) return true;
  return sec !== String(view[itemIndex - 1].section || "");
}

function itemTopY(view, itemIndex) {
  let y = 0;
  let lastSec = "\x00";
  for (let i = 0; i < view.length && i <= itemIndex; i++) {
    const sec = String(view[i].section || "");
    if (sec !== lastSec) {
      lastSec = sec;
      if (sec.length > 0) y += SECTION_H;
    }
    if (i === itemIndex) return y;
    y += ROW_H;
  }
  return y;
}

function maxScrollIndex(view, track) {
  const last = view.length - 1;
  if (last < 1) return 0;
  const bottom = itemTopY(view, last) + ROW_H;
  let s = 0;
  while (s < last && bottom - itemTopY(view, s) + (sectionStartsAt(view, s) ? SECTION_H : 0) > track) s++;
  return s;
}

function buildView(sections) {
  const view = [];
  for (const s of sections) {
    for (let i = 0; i < s.n; i++) view.push({ section: s.section, label: s.section + ":" + i });
  }
  return view;
}

test("constants are read from ModMenuScroll.as", () => {
  assert.ok(ROW_H > 0 && SECTION_H > 0, "ROW_H=" + ROW_H + " SECTION_H=" + SECTION_H);
});

test("AS3 source still has the shape this port mirrors", () => {
  const max = functionBody("maxScrollIndex").replace(/\s+/g, " ");
  assert.match(max, /bottom = itemTopY\(view, last\) \+ ROW_H;/);
  assert.match(max, /while \(s < last && bottom - itemTopY\(view, s\) \+ \(sectionStartsAt\(view, s\) \? SECTION_H : 0\) > track\)/);
  const top = functionBody("itemTopY").replace(/\s+/g, " ");
  assert.match(top, /y \+= SECTION_H;/);
  assert.match(top, /y \+= ROW_H;/);
  const scrollbar = functionBody("updateScrollThumb", SRC).replace(/\s+/g, " ");
  assert.match(scrollbar, /maxScroll = maxScrollIndex\(track\);/);
  const wrapper = functionBody("maxScrollIndex", SRC).replace(/\s+/g, " ");
  assert.match(wrapper, /ModMenuScroll\.maxScrollIndex\(m_view, track\)/);
});

test("itemTopY counts one header per section", () => {
  const view = buildView([{ section: "A", n: 2 }, { section: "B", n: 2 }]);
  assert.strictEqual(itemTopY(view, 0), SECTION_H);
  assert.strictEqual(itemTopY(view, 1), SECTION_H + ROW_H);
  assert.strictEqual(itemTopY(view, 2), 2 * SECTION_H + 2 * ROW_H);
  assert.strictEqual(itemTopY(view, 3), 2 * SECTION_H + 3 * ROW_H);
});

test("short list never scrolls", () => {
  const view = buildView([{ section: "A", n: 3 }]);
  assert.strictEqual(maxScrollIndex(view, 10000), 0);
});

test("max scroll shows the last row and no further", () => {
  const gh = readVarInt("m_gh");
  const track = (gh - 40) - 56; // openMenu: m_listBottom = m_gh - 40, m_listTop = 56
  const view = buildView([{ section: "Display", n: 8 }, { section: "Essentials", n: 6 }, { section: "Roster", n: 5 }]);
  const last = view.length - 1;
  const bottom = itemTopY(view, last) + ROW_H;
  assert.ok(bottom > track, "list taller than track");
  const s = maxScrollIndex(view, track);
  const span = (from) => bottom - itemTopY(view, from) + (sectionStartsAt(view, from) ? SECTION_H : 0);
  assert.ok(s > 0 && s < last);
  assert.ok(span(s) <= track, "last row fits at max scroll");
  assert.ok(span(s - 1) > track, "one less scroll would cut the last row");
});
