import json
import os
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import shellbase as sb  # noqa: E402

LIST = ROOT / "shell" / "data" / "ssf2mm" / "music_player" / "list.json"
VANILLA = Path(os.environ.get("SSF2_VANILLA", r"C:\Program Files (x86)\Super Smash Flash 2 Beta"))


def stock_extras(lst, music_ids, stage_ids):
    """Ids in the stock list that the vanilla game does not have (pack songs belong in their pack list)."""
    out = sorted(set(lst.get("tracks", {})) - music_ids)
    out += sorted({s for v in lst.get("stages", {}).values() for s in v} - music_ids)
    out += sorted(set(lst.get("stages", {})) - stage_ids)
    out += sorted(set(lst.get("other", [])) - music_ids)
    return out


class MusicListTests(unittest.TestCase):
    def test_pack_song_in_stock_list_is_caught(self):
        lst = {"tracks": {"bgm_mutecity": {}, "bgm_packsong": {}}, "stages": {"fd": ["bgm_mutecity"]}, "other": []}
        self.assertEqual(stock_extras(lst, {"bgm_mutecity"}, {"fd"}), ["bgm_packsong"])

    @unittest.skipUnless((VANILLA / "data").is_dir(), "vanilla SSF2 not installed")
    def test_stock_list_only_has_vanilla_songs(self):
        info = json.loads((sb.MAPPINGS / "base.json").read_text(encoding="utf-8"))
        m = sb.decode_vanilla_mappings(sb.mappings_payload(sb.vanilla_mappings_swf(VANILLA, info)))
        lst = json.loads(LIST.read_text(encoding="utf-8"))
        self.assertEqual(stock_extras(lst, set(m["music"]), set(m["stage"])), [])


if __name__ == "__main__":
    unittest.main()
