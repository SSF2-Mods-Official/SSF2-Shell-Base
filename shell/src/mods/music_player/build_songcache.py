#!/usr/bin/env python3
"""Build songcache.json from stage/sound SWFs (no game launch).

Stage playlists come from the document-class register:
  register("music",[{"id":"bgm_jungleisland"},{"id":"bgm_UndertheOceanBoilingPot"}]);
Tracks with no stage list go into "other".
"""

from __future__ import annotations

import json
import re
from collections import OrderedDict
from pathlib import Path

HERE = Path(__file__).resolve().parent
SHELL = HERE.parents[2]  # .../SSF2 Shell
STAGE_DIR = SHELL / "data" / "stage"
SOUND_DIR = SHELL / "data" / "sound"
CACHE_PATH = HERE / "songcache.json"
LIST_PATH = HERE / "list.json"
# Stages that must not appear in the stock jukebox list (mode / debug / locked).
SKIP_STAGE_PREFIX = ("targettest", "locked", "test1", "test2", "test3", "test4")
SKIP_STAGE_EXACT = {"xpstage", "random", "space"}

BGM_RE = re.compile(rb"bgm_[A-Za-z0-9_]+")


def stage_songs(data: bytes) -> list[str]:
    """Pull bgm ids from the music register near the sounds block."""
    sounds_at = data.find(b"sounds")
    candidates: list[tuple[int, int, list[str]]] = []
    search_from = 0
    while True:
        i = data.find(b"music", search_from)
        if i < 0:
            break
        window = data[i : i + 512]
        found: list[str] = []
        pos = 0
        while True:
            m = BGM_RE.search(window, pos)
            if not m:
                break
            start = m.start()
            if start > 0 and window[start - 1] == len(m.group()):
                s = m.group().decode("ascii")
                if s not in found:
                    found.append(s)
            pos = m.end()
        if found:
            candidates.append((len(found), i, found))
        search_from = i + 5

    if not candidates:
        found = []
        for m in BGM_RE.finditer(data):
            if m.start() > 0 and data[m.start() - 1] == len(m.group()):
                s = m.group().decode("ascii")
                if s not in found:
                    found.append(s)
        return found

    best: tuple[float, list[str]] | None = None
    for count, i, found in candidates:
        score = count * 10.0
        if sounds_at >= 0 and abs(i - sounds_at) < 200:
            score += 50
        if sounds_at >= 0 and i > sounds_at:
            score += 20
        if best is None or score > best[0]:
            best = (score, found)
    return best[1] if best else []


def parse_id3_meta(data: bytes) -> tuple[str | None, str | None]:
    title = None
    artist = None
    i = data.find(b"songName")
    if i < 0:
        return title, artist
    j = i + 8
    if j >= len(data):
        return title, artist
    ln = data[j]
    if 1 <= ln <= 120 and j + 1 + ln <= len(data):
        raw = data[j + 1 : j + 1 + ln]
        title = raw.decode("utf-8", errors="replace")
        k = j + 1 + ln
        if data[k : k + 6] == b"artist":
            k += 6
            if k < len(data):
                al = data[k]
                if 0 <= al <= 120 and k + 1 + al <= len(data):
                    raw = data[k + 1 : k + 1 + al]
                    artist = raw.decode("utf-8", errors="replace")
    return title, artist


def mp3_duration_ms(data: bytes) -> float:
    br_v1_l3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]
    br_v2_l3 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0]
    br_v1_l2 = [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 0]
    br_v2_l2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0]
    br_v1_l1 = [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, 0]
    br_v2_l1 = [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256, 0]
    sr_tab = {3: [44100, 48000, 32000], 2: [22050, 24000, 16000], 0: [11025, 12000, 8000]}
    n = len(data)
    i = 0
    while i < n - 4:
        if data[i] == 0xFF and (data[i + 1] & 0xE0) == 0xE0:
            b1, b2 = data[i + 1], data[i + 2]
            ver = (b1 >> 3) & 3
            layer = (b1 >> 1) & 3
            br_i = (b2 >> 4) & 0xF
            sr_i = (b2 >> 2) & 3
            pad = (b2 >> 1) & 1
            if ver != 1 and layer != 0 and br_i not in (0, 15) and sr_i != 3:
                if layer == 3:
                    brs = br_v1_l1 if ver == 3 else br_v2_l1
                elif layer == 2:
                    brs = br_v1_l2 if ver == 3 else br_v2_l2
                else:
                    brs = br_v1_l3 if ver == 3 else br_v2_l3
                bitrate = brs[br_i] * 1000
                sr = sr_tab[ver][sr_i]
                if layer == 3:
                    flen = int((12 * bitrate / sr) + pad) * 4
                    spf = 384
                elif ver == 3:
                    flen = int(144 * bitrate / sr) + pad
                    spf = 1152
                else:
                    flen = int(72 * bitrate / sr) + pad
                    spf = 576 if layer == 1 else 1152
                nxt = i + flen
                if flen >= 24 and nxt + 1 < n and data[nxt] == 0xFF and (data[nxt + 1] & 0xE0) == 0xE0:
                    frames = 0
                    samples = 0
                    rate = sr
                    pos = i
                    while pos + 4 <= n and data[pos] == 0xFF and (data[pos + 1] & 0xE0) == 0xE0:
                        b1, b2 = data[pos + 1], data[pos + 2]
                        ver = (b1 >> 3) & 3
                        layer = (b1 >> 1) & 3
                        br_i = (b2 >> 4) & 0xF
                        sr_i = (b2 >> 2) & 3
                        pad = (b2 >> 1) & 1
                        if ver == 1 or layer == 0 or br_i in (0, 15) or sr_i == 3:
                            break
                        if layer == 3:
                            brs = br_v1_l1 if ver == 3 else br_v2_l1
                        elif layer == 2:
                            brs = br_v1_l2 if ver == 3 else br_v2_l2
                        else:
                            brs = br_v1_l3 if ver == 3 else br_v2_l3
                        bitrate = brs[br_i] * 1000
                        sr = sr_tab[ver][sr_i]
                        if layer == 3:
                            flen = int((12 * bitrate / sr) + pad) * 4
                            spf = 384
                        elif ver == 3:
                            flen = int(144 * bitrate / sr) + pad
                            spf = 1152
                        else:
                            flen = int(72 * bitrate / sr) + pad
                            spf = 576 if layer == 1 else 1152
                        if flen < 24 or pos + flen > n:
                            break
                        frames += 1
                        samples += spf
                        rate = sr
                        pos += flen
                    if frames > 10:
                        return samples / rate * 1000.0
        i += 1
    return 0.0


def main() -> None:
    old_tracks: dict = {}
    if CACHE_PATH.exists():
        try:
            old_tracks = json.loads(CACHE_PATH.read_text(encoding="utf-8")).get("tracks") or {}
        except Exception:
            old_tracks = {}

    stages: OrderedDict[str, list[str]] = OrderedDict()
    assigned: set[str] = set()
    for swf in sorted(STAGE_DIR.glob("*.swf")):
        songs = stage_songs(swf.read_bytes())
        stages[swf.stem] = songs
        assigned.update(songs)

    all_tracks: list[str] = []
    for swf in sorted(SOUND_DIR.glob("bgm_*.swf")):
        if swf.read_bytes()[:3] != b"FWS":
            continue
        all_tracks.append(swf.stem)

    other = sorted(t for t in all_tracks if t not in assigned)

    tracks: OrderedDict[str, dict] = OrderedDict()
    for tid in sorted(set(all_tracks) | assigned):
        path = SOUND_DIR / f"{tid}.swf"
        title = tid
        artist = ""
        linkage = tid
        duration = 0.0
        hydrated = False
        if path.exists() and path.read_bytes()[:3] == b"FWS":
            data = path.read_bytes()
            t, a = parse_id3_meta(data)
            if t:
                title = t
                hydrated = True
            if a:
                artist = a
                hydrated = True
            duration = mp3_duration_ms(data)

        prev = old_tracks.get(tid) or {}
        prev_dur = float(prev.get("durationMs") or 0)
        if prev_dur > 0 and (not duration or abs(prev_dur - duration) / max(duration, 1) > 0.05):
            duration = prev_dur
        if prev.get("title") and prev["title"] != tid and title == tid:
            title = prev["title"]
            hydrated = True
        if prev.get("artist") and not artist:
            artist = prev["artist"]
            hydrated = True
        if prev.get("linkage") == tid:
            linkage = tid

        if title != tid or artist or duration > 0:
            hydrated = True

        tracks[tid] = {
            "title": title,
            "artist": artist,
            "linkage": linkage,
            "durationMs": duration if duration else 0,
            "hydrated": hydrated,
        }

    payload = {"stages": stages, "other": other, "tracks": tracks}
    CACHE_PATH.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {CACHE_PATH}")
    print(f"stages={len(stages)} other={len(other)} tracks={len(tracks)}")

    # Immutable stock pack for the jukebox (runtime must never write this file).
    stock_stages: OrderedDict[str, list[str]] = OrderedDict()
    for sid, songs in stages.items():
        if sid in SKIP_STAGE_EXACT:
            continue
        if any(sid.startswith(p) for p in SKIP_STAGE_PREFIX):
            continue
        stock_stages[sid] = songs
    list_payload = OrderedDict(
        [
            ("packId", "ssf2"),
            ("name", "Super Smash Flash 2"),
            ("version", "1.3.1.2"),
            ("immutable", True),
            (
                "notes",
                [
                    "Stock SSF2 stage music. NEVER write this file at runtime.",
                    "User edits go to applicationStorage music_player/overrides.json.",
                    "Game updates / fan packs ship under expansions/songs/packs/.",
                    "Edit this file when stock stage song lists are wrong.",
                ],
            ),
            ("stages", stock_stages),
            ("other", other),
            ("tracks", tracks),
        ]
    )
    LIST_PATH.write_text(json.dumps(list_payload, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {LIST_PATH} stock_stages={len(stock_stages)}")


if __name__ == "__main__":
    main()
