import base64
import hashlib
import json
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import shellbase as sb  # noqa: E402


def tiny_swf(payload, tag_id=1):
    head = bytes([0x00]) + struct.pack("<HH", 0x1800, 1)  # nbits=0 rect, frame rate, frame count
    tags = [(24, b"\x00\x00pw\x00"), (sb.TAG_BINARY_DATA, struct.pack("<HI", tag_id, 0) + payload.encode("ascii")), (0, b"")]
    return sb.write_swf(32, head, tags)


def cls(*methods):
    body = "\n      \n".join(methods)
    return "package a\n{\n   public class X\n   {\n" + body + "\n   }\n}\n"


def method(name, *lines):
    return "\n".join(["      public function %s() : void" % name, "      {"]
                     + ["         " + l for l in lines] + ["      }"])


class PatchTests(unittest.TestCase):
    def test_round_trip(self):
        base = "a\nb\nc\nd\ne\nf\ng\nh\n"
        target = "a\nB\nc\nd\ne\nf\ng\nh\ni\n"
        patch = sb.make_patch(base, target, "x.as")
        self.assertEqual(sb.apply_patch(base, patch, "x.as"), target)

    def test_line_separator_inside_string_stays_one_line(self):
        base = 'var s = "x\u2028y";\nreturn;\n'
        target = 'var s = "x\u2028y";\nreturn 1;\n'
        patch = sb.make_patch(base, target, "x.as")
        self.assertEqual(sb.apply_patch(base, patch, "x.as"), target)

    def test_changed_base_fails(self):
        patch = sb.make_patch("a\nb\nc\n", "a\nB\nc\n", "x.as")
        with self.assertRaises(sb.PatchError):
            sb.apply_patch("a\nz\nc\n", patch, "x.as")

    def test_patch_holds_no_dropped_or_context_text(self):
        base = "keep1\nvanilla_secret\nkeep2\n"
        patch = sb.make_patch(base, "keep1\nshell_line\nkeep2\n", "x.as")
        self.assertNotIn("vanilla_secret", patch)
        self.assertNotIn("keep1", patch)
        self.assertIn("+shell_line\n", patch)

    def test_copied_base_line_is_a_number(self):
        base = "vanilla_secret\n"
        patch = sb.make_patch(base, "vanilla_secret\nvanilla_secret\n", "x.as")
        self.assertNotIn("vanilla_secret", patch)
        self.assertIn("=0\n", patch)
        self.assertEqual(sb.apply_patch(base, patch, "x.as"), "vanilla_secret\nvanilla_secret\n")

    def test_insert_into_empty(self):
        patch = sb.make_patch("", "a\n", "x.as")
        self.assertEqual(sb.apply_patch("", patch, "x.as"), "a\n")


class MappingsTests(unittest.TestCase):
    obj = {"character": {"mario": {"file": "mario.ssf", "name": "Mário \u2605"}}, "music": {}}

    def engine_d(self, text, key=sb.MAPPINGS_KEY):
        # Utils.d in engine2: param2.substr(i % len - 1, 1); substr(-1) is the last char.
        s = base64.b64decode(text).decode("utf-8")
        out = ""
        for i, c in enumerate(s):
            idx = i % len(key) - 1
            k = key[idx] if idx >= 0 else key[len(key) + idx]
            out += chr((ord(c) - ord(k)) & 0xFFFF)
        return out

    def test_shell_encoding_decodes_like_engine(self):
        payload = sb.encode_shell_mappings(self.obj)
        inner = base64.b64decode(payload).decode("utf-8")
        got = json.loads(base64.b64decode(self.engine_d(inner)).decode("utf-8"))
        self.assertEqual(got, self.obj)

    def test_vanilla_decoder_rejects_shell_blob(self):
        payload = sb.encode_shell_mappings(self.obj)
        with self.assertRaises(Exception):
            sb.decode_vanilla_mappings(payload)

    def test_swf_payload_swap_and_ssf_wrap(self):
        swf = tiny_swf("old")
        out = sb.set_mappings_payload(swf, sb.encode_shell_mappings(self.obj))
        ssf = sb.ssf_wrap(out)
        back = sb.ssf_unwrap(ssf)
        self.assertEqual(back, out)
        self.assertEqual(sb.decode_shell_mappings(sb.mappings_payload(back)), self.obj)
        tags = sb.read_swf(back)[2]
        self.assertEqual([t[0] for t in tags], [24, sb.TAG_BINARY_DATA, 0])
        self.assertEqual(tags[0][1], b"\x00\x00pw\x00")

    def test_merge_patch(self):
        base = {"character": {"a": 1, "obama": {"x": 1}}, "css": {"x": -51, "y": 20}}
        target = {"character": {"a": 1}, "css": {"x": -73.0, "y": 20}, "exclude": []}
        patch = sb.merge_diff(base, target)
        self.assertEqual(sb.merge_apply(base, patch), target)
        self.assertIsNone(patch["character"]["obama"])


class DataLayoutTests(unittest.TestCase):
    def test_folders_and_skips(self):
        manifest = {"menu": {"menu_main": {"file": "menu_main.ssf", "file_pub": "DAT55.ssf"}},
                    "audio": {"audio": {"file": "ssf2_audio.ssf", "file_pub": "DAT141.ssf"}},
                    "music": {}}
        mappings = {"character": {"mario": {"file": "mario.ssf", "file_pub": "DAT1.ssf"},
                                  "obama": {"file": "presidentobama.ssf"}},
                    "extra": {"intro": {"file": "ssf2intro_v9.ssf", "file_pub": "DAT9.ssf"}},
                    "music": {"bgm_x": {"file": "bgm_x.ssf", "file_pub": "DAT2.ssf"}}}
        self.assertEqual(sb.data_layout(manifest, mappings), {
            "data/menu/menu_main.ssf": "DAT55.ssf",
            "data/sound/ssf2_audio.ssf": "DAT141.ssf",
            "data/character/mario.ssf": "DAT1.ssf",
            "data/misc/ssf2intro_v9.ssf": "DAT9.ssf",
            "data/sound/bgm_x.ssf": "DAT2.ssf",
        })


class IncludeOrderTests(unittest.TestCase):
    def test_matches_powershell_sort(self):
        names = ["com.mcleodgaming.ssf2.Main", "com.mcleodgaming.ssf2.api.SSF2API",
                 "com.mcleodgaming.ssf2.Config", "com.jotard.ane.DiscordEvent"]
        self.assertEqual(sb.include_order(names), [
            "com.jotard.ane.DiscordEvent", "com.mcleodgaming.ssf2.api.SSF2API",
            "com.mcleodgaming.ssf2.Config", "com.mcleodgaming.ssf2.Main"])


class PackTests(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.tmp = Path(tempfile.mkdtemp())
        root = self.tmp / "repo"
        files = {
            "tools/shellbase.py": "print('builder')\n",
            "patches/engine2/base.json": json.dumps({"vanilla_ssf2_sha256": "v" * 64, "next2flash_commit": "da21d6a1"}),
            "patches/engine2/patches/a/X.as.patch": "# a/X.as\n## class header\n## why: hook\n@@ 1 0 da39a3ee5e6b4b0d 1\n+x\n",
            "patches/mappings/patch.json": "{}",
            "shell/data/ssf2mm/mod_menu/mod.json": "{}",
            "shell/install/VC_redist.x64.exe": "exe",
            "shell/data/video/how_to_play.flv": "flv",
        }
        for rel, text in files.items():
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_text(text, encoding="utf-8")
        self.saved = (sb.ROOT, sb.ENGINE2, sb.SHELL)
        sb.ROOT, sb.ENGINE2, sb.SHELL = root, root / "patches" / "engine2", root / "shell"
        self.root = root

    def tearDown(self):
        import shutil
        sb.ROOT, sb.ENGINE2, sb.SHELL = self.saved
        shutil.rmtree(self.tmp, ignore_errors=True)

    def pack(self):
        import argparse
        sb.cmd_pack(argparse.Namespace(version="1.2.3", out=str(self.tmp / "dist")))
        return sorted((self.tmp / "dist").glob("*.ssfpatch"))

    def test_two_files_unpack_into_one_build_tree(self):
        import zipfile
        assets, core = self.pack()
        aid = sb.assets_id(self.root / "shell")
        self.assertEqual(core.name, "shell-base-1.2.3.ssfpatch")
        self.assertEqual(assets.name, "shell-assets-%s.ssfpatch" % aid)
        out = self.tmp / "unpacked"
        for p in (core, assets):
            zipfile.ZipFile(p).extractall(out)
        m = json.loads((out / "ssfpatch.json").read_text())
        self.assertEqual((m["kind"], m["version"], m["assets"], m["next2flash_commit"]), ("core", "1.2.3", aid, "da21d6a1"))
        self.assertEqual(json.loads((out / "ssfpatch-assets.json").read_text())["id"], aid)
        for rel in ("tools/shellbase.py", "patches/engine2/patches/a/X.as.patch", "patches/mappings/patch.json",
                    "shell/data/ssf2mm/mod_menu/mod.json", "shell/install/VC_redist.x64.exe",
                    "shell/data/video/how_to_play.flv"):
            self.assertTrue((out / rel).is_file(), rel)
        with zipfile.ZipFile(core) as z:
            self.assertFalse({"shell/" + rel for rel in sb.ASSET_PATHS} & set(z.namelist()))

    def test_assets_id_changes_only_with_assets(self):
        aid = sb.assets_id(self.root / "shell")
        (self.root / "shell" / "new.txt").write_text("x")
        self.assertEqual(sb.assets_id(self.root / "shell"), aid)
        (self.root / "shell" / "install" / "VC_redist.x64.exe").write_text("exe2")
        self.assertNotEqual(sb.assets_id(self.root / "shell"), aid)

    def test_assets_id_differs_from_the_old_assets_folder_layout(self):
        old = hashlib.sha256()
        for rel in sb.ASSET_PATHS:
            f = self.root / "shell" / rel
            old.update(("%s\0%s\n" % (rel, sb.sha256_bytes(f.read_bytes()))).encode("utf-8"))
        self.assertNotEqual(sb.assets_id(self.root / "shell"), old.hexdigest()[:12])

    def test_refuses_todo_why(self):
        p = self.root / "patches/engine2/patches/a/X.as.patch"
        p.write_text(p.read_text().replace("## why: hook", "## why: TODO"))
        with self.assertRaises(SystemExit):
            self.pack()


class PatchNotesTests(unittest.TestCase):
    def test_hunks_grouped_by_section_and_notes_survive(self):
        base = cls(method("g", "go();"), method("h", "stop();"))
        target = cls(method("g", "go();", "ModHost.runHook(1);"), method("h", "stop();"), method("added", "x();"))
        patch = sb.make_patch(base, target, "a/X.as", {"public function g() : void": "hook for mods"})
        self.assertIn("## public function g() : void\n## why: hook for mods\n@@", patch)
        self.assertIn("## public function added() : void\n## why: TODO\n@@", patch)
        self.assertNotIn("function h()", patch)
        self.assertEqual(sb.apply_patch(base, patch, "a/X.as"), target)
        self.assertEqual(sb.read_notes(patch), {"public function g() : void": "hook for mods"})

    def test_header_section(self):
        base = cls(method("g", "go();")).replace("   {\n", "   {\n      private var a:int;\n", 1)
        target = base.replace("private var a:int;", "private var a:int;\n      private var b:int;")
        patch = sb.make_patch(base, target, "a/X.as")
        self.assertIn("## class header\n## why: TODO\n", patch)
        self.assertEqual(sb.apply_patch(base, patch), target)


class NormalizeTests(unittest.TestCase):
    RT = method("f", "var _loc1_:int = 0;", "_loc1_ = n + 1;", "if(_loc1_ > 2 && ok)", "{", "   go(_loc1_);", "}")

    def same(self, a, b):
        return sb.normalize_method(a) == sb.normalize_method(b)

    def test_renumbered_locals_are_noise(self):
        shell = self.RT.replace("_loc1_", "_loc3_")
        self.assertTrue(self.same(self.RT, shell))

    def test_boolean_wrapper_is_noise(self):
        shell = self.RT.replace("_loc1_ > 2 && ok", "Boolean(_loc1_ > 2) && Boolean(ok)")
        self.assertTrue(self.same(self.RT, shell))

    def test_moved_default_decl_and_leading_resets_are_noise(self):
        shell = method("f", "_loc1_ = 0;", "_loc1_ = 0;", "_loc1_ = n + 1;", "if(_loc1_ > 2 && ok)", "{",
                       "   go(_loc1_);", "}", "var _loc1_:int;")
        self.assertTrue(self.same(self.RT, shell))

    def test_this_casts_split_init_and_param_copy_are_noise(self):
        rt = method("f", "var _loc1_:int = int(list.indexOf(param1));", "go(_loc1_);")
        shell = method("f", "param1 = param1;", "_loc2_ = this.list.indexOf(param1);", "go(_loc2_);",
                       "var _loc2_:int;")
        self.assertTrue(self.same(rt, shell))

    def test_step_as_class_and_self_assign_are_noise(self):
        rt = method("f", "_loc1_ = _loc1_;", "i++;", "x = new c.cls(1);")
        shell = method("f", "i += 1;", "x = new (c.cls as Class)(1);")
        self.assertTrue(self.same(rt, shell))
        self.assertFalse(self.same(method("f", "i++;"), method("f", "i += 2;")))

    def test_cast_around_expression_keeps_grouping(self):
        rt = method("f", "x = int(a + b) * 2;")
        self.assertFalse(self.same(rt, method("f", "x = a + b * 2;")))
        self.assertTrue(self.same(rt, method("f", "x = (a + b) * 2;")))

    def test_changed_expression_is_real(self):
        self.assertFalse(self.same(self.RT, self.RT.replace("n + 1", "n + 2")))

    def test_added_call_is_real(self):
        shell = self.RT.replace("   go(_loc1_);", "   go(_loc1_);\n            ModHost.runHook(1);")
        self.assertFalse(self.same(self.RT, shell))

    def test_changed_literal_is_real(self):
        self.assertFalse(self.same(self.RT, self.RT.replace("> 2", "> 3")))

    def test_mid_body_default_reset_is_real(self):
        shell = self.RT.replace("   go(_loc1_);", "   go(_loc1_);\n            _loc1_ = 0;")
        self.assertFalse(self.same(self.RT, shell))


class RebaselineTests(unittest.TestCase):
    def test_noise_reverts_and_real_edit_keeps_shell_text(self):
        g_rt = method("g", "var _loc1_:Object = null;", "_loc1_ = load();", "use(_loc1_);")
        h_rt = method("h", "var _loc1_:int = 0;", "_loc1_ = 1;")
        base = cls(g_rt, h_rt)
        g_shell = g_rt.replace("_loc1_", "_loc2_")
        h_shell = method("h", "var _loc4_:int = 0;", "_loc4_ = 1;", "ModHost.runHook(2);")
        extra = method("added")
        out, reverted, kept = sb.rebaseline_class(base, cls(g_shell, h_shell, extra))
        self.assertEqual((reverted, kept), (1, 2))  # kept counts the shell-only method too
        h_merged = method("h", "var _loc1_:int = 0;", "_loc1_ = 1;", "ModHost.runHook(2);")
        self.assertIn(g_rt, out)
        self.assertIn(h_merged, out)
        self.assertIn(extra, out)
        self.assertLess(out.index(h_merged), out.index(extra))

    def test_merge_keeps_base_style_and_renames_new_locals(self):
        rt = method("f", "var _loc1_:int = 0;", "_loc1_ = int(n);", "go(_loc1_);")
        shell = method("f", "var _loc2_:Object = null;", "var _loc3_:int = 0;", "_loc3_ = n;",
                       "_loc2_ = {\"x\":_loc3_};", "ModHost.runHook(1,_loc2_);", "this.go(_loc3_);")
        got = sb.merge_method(rt, shell)
        self.assertEqual(got, method("f", "var _loc2_:Object = null;", "var _loc1_:int = 0;", "_loc1_ = int(n);",
                                     "_loc2_ = {\"x\":_loc1_};", "ModHost.runHook(1,_loc2_);", "go(_loc1_);"))

    def test_merge_refuses_when_result_differs(self):
        rt = method("f", "a(_loc1_,_loc2_);", "b(_loc1_);")
        shell = method("f", "a(_loc1_,_loc2_);", "b(_loc2_);", "c();")
        got = sb.merge_method(rt, shell)
        self.assertTrue(got is None or sb.normalize_method(got) == sb.normalize_method(shell))

    def test_identical_class_is_untouched(self):
        base = cls(method("g", "go();"))
        self.assertEqual(sb.rebaseline_class(base, base)[0], base)


class VanillaTextTests(unittest.TestCase):
    """Rules for matching a recompiled shell method to vanilla's debug-named decompile."""

    def test_parameter_names_do_not_split_methods(self):
        self.assertEqual(sb.sig_key("public function f(e:MouseEvent, n:int = 0) : void"),
                         sb.sig_key("public function f(param1:MouseEvent, param2:int = 0) : void"))
        van = "      public function f(e:Event) : void\n      {\n         go(e);\n      }"
        shell = "      public function f(param1:Event) : void\n      {\n         go(param1);\n      }"
        self.assertTrue(sb.same_method(van, shell))

    def test_for_loop_matches_recompiled_while(self):
        van = method("f", "for(var i:int = 0; i < n; i++)", "{", "   go(i);", "}")
        shell = method("f", "var _loc1_:int = 0;", "while(_loc1_ < n)", "{", "   go(_loc1_);", "   _loc1_++;", "}")
        self.assertTrue(sb.same_method(van, shell))
        merged = sb.merge_method(van, shell.replace("   go(_loc1_);", "   go(_loc1_);\n            hook();"))
        self.assertIn("for(var i:int = 0; i < n; i++)", merged)
        self.assertIn("hook();", merged)

    def test_loop_with_continue_is_not_rewritten(self):
        van = method("f", "for(i = 0; i < n; i++)", "{", "   if(a)", "   {", "      continue;", "   }", "}")
        self.assertEqual([t for t, _ in sb.loop_lines(van)], sb.split_lines(van))

    def test_unused_decl_and_untyped_local_are_noise(self):
        van = method("f", "var k:int = 0;", "k = n;", "go(k);")
        shell = method("f", "var _loc1_:* = undefined;", "var _loc2_:int = 0;", "_loc1_ = n;", "go(_loc1_);")
        self.assertTrue(sb.same_method(van, shell))

    def test_param_alias_folds_into_parameter(self):
        shell = ("      public function f(param1:Boolean) : void\n      {\n"
                 "         var flag:Boolean = param1;\n         go(flag);\n      }")
        self.assertEqual(sb.unalias_params(shell),
                         "      public function f(param1:Boolean) : void\n      {\n         go(param1);\n      }")

    def test_string_literals_are_not_local_names(self):
        van = method("f", "var score:int = 0;", "score = n;", 'throw new Error("missing score value");')
        shell = method("f", "var _loc1_:int = 0;", "_loc1_ = n;", 'throw new Error("missing _loc1_ value");')
        self.assertFalse(sb.same_method(van, shell))

    def test_header_keeps_vanilla_imports_and_adds_shell_ones(self):
        van = "package a\n{\n   import flash.events.Event;\n   \n   public class X\n   {\n"
        shell = "package a\n{\n   import flash.events.*;\n   import a.modhost.*;\n   \n   public class X\n   {\n"
        got = sb.merge_header(van, shell, body_same=False)
        self.assertIn("import flash.events.Event;", got)
        self.assertIn("import a.modhost.*;", got)
        self.assertIn("import flash.events.*;", got)
        only_imports = "package a\n{\n   import flash.events.*;\n   \n   public class X\n   {\n"
        self.assertEqual(sb.merge_header(van, only_imports, body_same=True), van)


class PortTests(unittest.TestCase):
    A = method("a", "one();", "two();", "three();")
    B = method("b", "y();")
    C = method("c", "z();")
    OLD = cls(A, B, C)
    WHY = {"public function a() : void": "hook so mods can run first"}

    def port(self, shell, new):
        return sb.port_class("X.as", self.OLD, shell, new, self.WHY)

    def test_unchanged_upstream_keeps_shell_edit(self):
        shell = cls(self.A.replace("one();", "hook();\n         one();"), self.B, self.C)
        text, stats, report = self.port(shell, self.OLD)
        self.assertEqual(text, shell)
        self.assertEqual((stats["clean"], stats["conflicts"], report), (1, 0, []))

    def test_upstream_only_change_takes_new_text(self):
        shell = cls(self.A.replace("one();", "hook();\n         one();"), self.B, self.C)
        new_b = method("b", "y(2);")
        text, stats, _ = self.port(shell, cls(self.A, new_b, self.C))
        self.assertIn("hook();", text)
        self.assertIn("y(2);", text)
        self.assertEqual((stats["clean"], stats["upstream"]), (1, 1))

    def test_disjoint_edits_in_one_method_merge(self):
        shell = cls(self.A.replace("one();", "hook();\n         one();"), self.B, self.C)
        new = cls(self.A.replace("three();", "three(1);"), self.B, self.C)
        text, stats, report = self.port(shell, new)
        self.assertIn(method("a", "hook();", "one();", "two();", "three(1);"), text)
        self.assertEqual((stats["merged"], report), (1, []))

    def test_conflict_keeps_new_text_and_reports_why(self):
        shell = cls(self.A.replace("two();", "two(shell);"), self.B, self.C)
        new = cls(self.A.replace("two();", "two(new);"), self.B, self.C)
        text, stats, report = self.port(shell, new)
        self.assertEqual(text, new)
        self.assertEqual(stats["conflicts"], 1)
        self.assertEqual((report[0]["kind"], report[0]["why"]), ("conflict", self.WHY["public function a() : void"]))
        md = sb.port_report(report)
        self.assertIn("two(shell);", md)
        self.assertIn("two(new);", md)
        self.assertIn("hook so mods can run first", md)

    def test_method_gone_upstream_is_missing(self):
        shell = cls(self.A, self.B, method("c", "z();", "hook();"))
        text, stats, report = self.port(shell, cls(self.A, self.B))
        self.assertNotIn("hook();", text)
        self.assertEqual((stats["missing"], report[0]["kind"], report[0]["section"]),
                         (1, "missing", "public function c() : void"))

    def test_shell_only_method_stays_after_its_neighbour(self):
        added = method("added", "go();")
        shell = cls(self.A, added, self.B, self.C)
        text, stats, _ = self.port(shell, cls(self.A, method("b", "y(2);"), self.C))
        self.assertLess(text.index("function a()"), text.index("function added()"))
        self.assertLess(text.index("function added()"), text.index("function b()"))

    def test_tree_copies_added_classes_and_reports_missing_class(self):
        shell = {"X.as": cls(self.A, self.B, method("c", "hook();")), "New.as": cls(method("n")), "Y.as": "y\n"}
        tree, stats, report = sb.port_tree({"X.as": self.OLD, "Y.as": "y\n"}, shell, {"Y.as": "y2\n"}, {})
        self.assertEqual(tree, {"Y.as": "y2\n", "New.as": shell["New.as"]})
        self.assertEqual((stats["classes"], stats["missing"], report[0]["section"]), (1, 1, "class"))


class CleanResetsTests(unittest.TestCase):
    def test_keeps_last_store_per_local_in_a_run(self):
        shell = method("f", "var _loc1_:String = null;", "_loc1_ = null;", "_loc1_ = null;", "_loc2_ = 0;",
                       "_loc1_ = null;", "go(_loc1_);", "_loc1_ = null;")
        self.assertEqual(sb.clean_resets(shell), method(
            "f", "var _loc1_:String = null;", "_loc2_ = 0;", "_loc1_ = null;", "go(_loc1_);", "_loc1_ = null;"))

    def test_fields_and_reads_break_runs(self):
        shell = method("f", "m_x = null;", "m_x = null;", "_loc1_ = 0;", "use(_loc1_);", "_loc1_ = 0;")
        self.assertEqual(sb.clean_resets(shell), shell)


class OverlayTests(unittest.TestCase):
    def test_top_level_src_stays_out_of_the_build(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            shell, out = Path(d) / "shell", Path(d) / "out"
            for rel in ("src/mods/rumble/src/RumbleMod.as", "data/ssf2mm/rumble/mod.swf", "data/src/keep.txt"):
                (shell / rel).parent.mkdir(parents=True, exist_ok=True)
                (shell / rel).write_text("x", encoding="utf-8")
            sb.copy_overlay(out, shell)
            self.assertFalse((out / "src").exists())
            self.assertTrue((out / "data/ssf2mm/rumble/mod.swf").is_file())
            self.assertTrue((out / "data/src/keep.txt").is_file())


class ManifestTests(unittest.TestCase):
    def test_manifest_bin_strips_utils_d_layer(self):
        import tempfile
        manifest = {"modes": {"m": {"file": "m.ssf"}}, "character_xp": {}}
        plain = base64.b64encode(json.dumps(manifest, indent=2).encode("utf-8"))
        with tempfile.TemporaryDirectory() as d:
            swf = tiny_swf(sb.utils_e(plain.decode("ascii"), sb.MANIFEST_KEY), sb.MANIFEST_TAG_ID)
            (Path(d) / "SSF2.swf").write_bytes(swf)
            got = sb.manifest_bin(Path(d))
        self.assertEqual(got, plain)
        self.assertEqual(sb.decode_manifest(got), manifest)


class SwfTests(unittest.TestCase):
    def test_tags_equal_ignores_product_info(self):
        head = bytes([0x00]) + struct.pack("<HH", 0x1800, 1)
        a = sb.write_swf(32, head, [(41, b"date1"), (82, b"abc"), (0, b"")])
        b = sb.write_swf(32, head, [(41, b"date2"), (82, b"abc"), (0, b"")])
        c = sb.write_swf(32, head, [(41, b"date1"), (82, b"abd"), (0, b"")])
        self.assertTrue(sb.swf_tags_equal(a, b))
        self.assertFalse(sb.swf_tags_equal(a, c))


class VanillaHashTests(unittest.TestCase):
    def test_engine_for_picks_the_patch_set(self):
        captured = "9afefb865f540eba5c26549f47c6892cdfbb1802ac93aa55723462c469eaacf4"
        self.assertEqual(sb.engine_for(captured), sb.ENGINE2)
        for sha in (
            "d37bfe824779757d135333e45e9ceeea9eece1ad055094ca18f7b13fb5fe8bea",
            "ebf175c88bc37b46b0c1a34c368eae6d529d0a50f7e8ada85fdefd874f5b17c5",
            "0f13237a19bc6a7f63acb8e7371f3ce8420516292099c279061f4ad84f488fdc",
        ):
            self.assertEqual(sb.engine_for(sha), sb.VANILLA / sha)
        with self.assertRaises(SystemExit):
            sb.engine_for("0" * 64)

    def test_pe_machine_reads_the_coff_machine(self):
        import tempfile
        data = bytearray(0x80)
        data[0x3C:0x40] = (0x40).to_bytes(4, "little")
        data[0x40:0x44] = b"PE\0\0"
        data[0x44:0x46] = (0x8664).to_bytes(2, "little")
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "Adobe AIR.dll"
            path.write_bytes(data)
            self.assertEqual(sb.pe_machine(path), 0x8664)

    def test_player_target_follows_the_air_machine(self):
        self.assertEqual(sb.player_target(0x8664), ("32.0", None))
        self.assertEqual(sb.player_target(0x14C), ("32.0", 40))

    def test_names_swf_and_mappings_dat(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "SSF2.swf").write_bytes(b"not-the-game")
            problems = sb.vanilla_problems(root, {"vanilla_ssf2_sha256": "0" * 64})
        self.assertEqual(problems, ["SSF2.swf", "data/DAT51.ssf"])


if __name__ == "__main__":
    unittest.main()
