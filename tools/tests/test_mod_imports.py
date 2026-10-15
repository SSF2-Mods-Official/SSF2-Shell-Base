import re
import unittest
from pathlib import Path

MODS = Path(__file__).resolve().parent.parent.parent / "shell" / "src" / "mods"

# Mods compile with strict:false, so a missing import is a runtime ReferenceError, not a build error.
ENGINE_CLASSES = {
    "GameLog": "com.mcleodgaming.ssf2.util",
    "ResourceManager": "com.mcleodgaming.ssf2.util",
    "Key": "com.mcleodgaming.ssf2.util",
    "Utils": "com.mcleodgaming.ssf2.util",
    "Main": "com.mcleodgaming.ssf2",
    "MenuController": "com.mcleodgaming.ssf2.controllers",
    "GameController": "com.mcleodgaming.ssf2.controllers",
    "MultiplayerManager": "com.mcleodgaming.ssf2.net",
}


def missing_imports(text):
    pkg = re.search(r"^\s*package\s+([\w.]*)", text, re.M)
    pkg = pkg.group(1) if pkg else ""
    code = re.sub(r"//[^\n]*|/\*.*?\*/|\"(?:\\.|[^\"\\])*\"", "", text, flags=re.S)
    missing = []
    for name, home in ENGINE_CLASSES.items():
        if not re.search(r"(?<![\w.])%s\.\w" % name, code):
            continue
        if pkg == home or re.search(r"import\s+%s\.(%s|\*)\s*;" % (re.escape(home), name), code):
            continue
        if re.search(r"\b(class|var|const|function)\s+%s\b" % name, code):
            continue
        missing.append(name)
    return missing


class ModImportTests(unittest.TestCase):
    def test_missing_gamelog_import_is_caught(self):
        src = "package com.mcleodgaming.ssf2.menus {\n import com.mcleodgaming.ssf2.Main;\n" \
              " class A { function b():void { GameLog.write(\"x\" + Main.DEBUG); } } }"
        self.assertEqual(missing_imports(src), ["GameLog"])

    def test_same_package_needs_no_import(self):
        src = "package com.mcleodgaming.ssf2.util { class A { function b():void { GameLog.write(\"x\"); } } }"
        self.assertEqual(missing_imports(src), [])

    def test_mod_sources_import_engine_classes_they_use(self):
        bad = []
        for f in sorted(MODS.rglob("*.as")):
            names = missing_imports(f.read_text(encoding="utf-8", errors="replace"))
            if names:
                bad.append("%s: %s" % (f.relative_to(MODS), ", ".join(names)))
        self.assertEqual(bad, [])


if __name__ == "__main__":
    unittest.main()
