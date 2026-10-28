#!/usr/bin/env python3
"""Build SSF2 Shell engine2.swf and mappings from a vanilla SSF2 Beta 1.4.0.1 install.

Commands:
  build    vanilla install + Next2Flash -> Build/
  capture  a decompiled engine tree -> patches/engine2/ and patches/mappings/ (import only)
  verify   Build/ against a decompiled engine tree (import check)
  pack     work/dist/shell-base-<version>.ssfpatch and work/dist/shell-assets-<id>.ssfpatch (release)
  rebaseline  shell source -> vanilla decompile text where the shell made no edit (maintainer only)
  port     shell edits moved onto a new SSF2 version -> work/port/changed and report.md (maintainer only)
"""
import argparse
import base64
import collections
import datetime
import difflib
import hashlib
import json
import re
import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINE2 = ROOT / "patches" / "engine2"
MAPPINGS = ROOT / "patches" / "mappings"
SHELL = ROOT / "shell"
# Large shell files shipped in their own release zip (shell-assets-<id>), so a new release does not resend them.
ASSET_PATHS = ("data/video/how_to_play.flv", "install/VC_redist.x64.exe")
PACK_FORMAT = 1
PACK_CORE = ("tools/shellbase.py", "patches", "shell")

MAIN_CLASS = "com.mcleodgaming.ssf2.Main"
MG_PREFIX = "com/mcleodgaming/"
ENGINE1_CLASSES = {"com/mcleodgaming/ssf2/util/Debug_fps_fpsSymbol.as"}
MAPPINGS_KEY = "b7d60849-fa99-4514-b41e-16693ce7acc0"
EMBED_ASSETS = {
    "ProfanityFilter_wordfilter": "1_com.mcleodgaming.ssf2.util.ProfanityFilter_wordfilter.bin",
    "ResourceManager_manifestJSON": "2_com.mcleodgaming.ssf2.util.ResourceManager_manifestJSON.bin",
    "CountryRegionData_countryRegionDataJSON": "3_com.mcleodgaming.ssf2.util.CountryRegionData_countryRegionDataJSON.bin",
}
MANIFEST_ASSET = "ResourceManager_manifestJSON"
MANIFEST_KEY = "cedbe0e0-b9de-4e16-92cc-d32781a0bfe0"
MANIFEST_TAG_ID = 514
MAPPINGS_SKIP = {"music"}
DATA_FOLDERS = {
    "character": "character", "character_xp": "character",
    "stage": "stage", "stage_xp": "stage",
    "misc": "misc", "extra": "misc",
    "audio": "sound", "music": "sound",
    "menu": "menu", "modes": "modes",
}
AIR_SKIP = {"sentinel", "Template.exe", "template.msi", "Thawte Root Certificate.cer"}
TAG_PRODUCT_INFO = 41
TAG_BINARY_DATA = 87


def log(msg):
    print("[shellbase] " + msg, flush=True)


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_text(text):
    return sha256_bytes(text.encode("utf-8"))


def norm_text(text):
    return text.replace("\r\n", "\n").rstrip() + "\n"


def read_utf8(path):
    return path.read_bytes().decode("utf-8")


def split_lines(text):
    parts = text.split("\n")
    lines = [p + "\n" for p in parts[:-1]]
    if parts[-1]:
        lines.append(parts[-1])
    return lines


def write_text(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.encode("utf-8"))


def reset_dir(path):
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True)
    return path


# ---------------------------------------------------------------- source patches

def block_hash(lines):
    return hashlib.sha1("".join(lines).encode("utf-8")).hexdigest()[:16]


HEADER_SECTION = "class header"
FOOTER_SECTION = "class footer"
TODO_WHY = "TODO"


def patch_sections(text):
    """[(first line, end line, name)] for the class header, each method (by signature) and the footer."""
    prefix, blocks, _ = split_class(text)
    if not blocks:
        return [(0, len(split_lines(text)), HEADER_SECTION)]
    out, line = [], len(split_lines(prefix))
    out.append((0, line, HEADER_SECTION))
    for (sig, n), gap, block in blocks:
        start = line + len(split_lines(gap))
        end = start + len(split_lines(block))
        out.append((line, end, sig if n == 1 else "%s #%d" % (sig, n)))
        line = end
    out.append((line, len(split_lines(text)), FOOTER_SECTION))
    return out


def _section_at(sections, b, j1, j2):
    for j in list(range(j1, j2)) or [j1]:
        if b[j].strip() if j < len(b) else False:
            for start, end, name in sections:
                if start <= j < end:
                    return name
    for start, end, name in sections:
        if start <= j1 < end:
            return name
    return sections[-1][2]


def make_patch(base, target, rel, notes=None):
    """Hunks without context: '@@ <base line> <deleted> <sha1 of deleted> <added>' then '+' lines.

    Deleted base text is stored only as a hash, so a patch holds no line that the target drops.
    Hunks are grouped under '## <section>' and '## why: <reason>' lines; apply_patch skips them.
    """
    a, b = split_lines(base), split_lines(target)
    if (a and not a[-1].endswith("\n")) or (b and not b[-1].endswith("\n")):
        raise PatchError("%s: text must end with a newline" % rel)
    notes = notes or {}
    sections = patch_sections(target)
    copied = {}
    for i, line in enumerate(a):
        copied.setdefault(line, i)
    out = ["# " + rel + "\n"]
    current = None
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            continue
        name = _section_at(sections, b, j1, j2)
        if name != current:
            why = notes.get(name, notes.get(sig_key(name), TODO_WHY))
            out.append("## %s\n## why: %s\n" % (name, why))
            current = name
        out.append("@@ %d %d %s %d\n" % (i1, i2 - i1, block_hash(a[i1:i2]), j2 - j1))
        for line in b[j1:j2]:
            # A line that already exists in the base is a line number, not a second copy of that text.
            if line in copied:
                out.append("=%d\n" % copied[line])
            else:
                out.append("+" + line)
    return "".join(out)


def read_notes(patch):
    """{section: why} from a patch's '## <section>' / '## why:' pairs, TODO entries left out."""
    notes, section = {}, None
    for line in split_lines(patch):
        if line.startswith("## why: "):
            why = line[8:].rstrip("\n")
            if section is not None and why != TODO_WHY:
                notes[section] = why
        elif line.startswith("## "):
            section = sig_key(line[3:].rstrip("\n"))
    return notes


_HUNK = re.compile(r"^@@ (\d+) (\d+) ([0-9a-f]{16}) (\d+)\n$")


class PatchError(Exception):
    pass


def apply_patch(base, patch, rel=""):
    src = split_lines(base)
    lines = [l for l in split_lines(patch) if not l.startswith("## ")]
    out = []
    pos = 0
    i = 1 if lines and lines[0].startswith("# ") else 0
    while i < len(lines):
        m = _HUNK.match(lines[i])
        if not m:
            raise PatchError("%s: bad hunk header %r" % (rel, lines[i]))
        at, deleted, digest, added = int(m.group(1)), int(m.group(2)), m.group(3), int(m.group(4))
        if at < pos or at + deleted > len(src):
            raise PatchError("%s: hunk at line %d out of range" % (rel, at + 1))
        if block_hash(src[at:at + deleted]) != digest:
            raise PatchError("%s: base text changed at line %d" % (rel, at + 1))
        out.extend(src[pos:at])
        pos = at + deleted
        body = lines[i + 1:i + 1 + added]
        if len(body) != added:
            raise PatchError("%s: hunk at line %d is truncated" % (rel, at + 1))
        for l in body:
            if l.startswith("+"):
                out.append(l[1:])
            elif l.startswith("=") and l[1:].strip().isdigit():
                n = int(l[1:])
                if n >= len(src):
                    raise PatchError("%s: hunk at line %d copies a missing base line" % (rel, at + 1))
                out.append(src[n])
            else:
                raise PatchError("%s: hunk at line %d is truncated" % (rel, at + 1))
        i += 1 + added
    out.extend(src[pos:])
    return "".join(out)

# ---------------------------------------------------------------- swf / ssf

def read_swf(data):
    sig = data[:3]
    version = data[3]
    if sig == b"CWS":
        body = zlib.decompress(data[8:])
    elif sig == b"FWS":
        body = data[8:]
    else:
        raise ValueError("not an uncompressed or zlib SWF: %r" % sig)
    nbits = body[0] >> 3
    head = (5 + nbits * 4 + 7) // 8 + 4
    tags = []
    p = head
    while p < len(body):
        rec = struct.unpack_from("<H", body, p)[0]
        p += 2
        code, length = rec >> 6, rec & 0x3F
        if length == 0x3F:
            length = struct.unpack_from("<I", body, p)[0]
            p += 4
        tags.append((code, body[p:p + length]))
        p += length
    return version, body[:head], tags


def write_swf(version, head, tags):
    parts = [head]
    for code, data in tags:
        if len(data) < 0x3F and code != TAG_BINARY_DATA:
            parts.append(struct.pack("<H", (code << 6) | len(data)))
        else:
            parts.append(struct.pack("<HI", (code << 6) | 0x3F, len(data)))
        parts.append(data)
    body = b"".join(parts)
    return b"FWS" + bytes([version]) + struct.pack("<I", len(body) + 8) + body


def ssf_unwrap(data):
    if data[1:3] == b"WS":
        return data
    raw = zlib.decompress(data)
    count = struct.unpack_from(">i", raw, 4)[0]
    return raw[8 + 4 * count:]


def ssf_wrap(swf):
    return zlib.compress(struct.pack(">ii", len(swf), 0) + swf, 9)


def swf_tags_equal(a, b, ignore=(TAG_PRODUCT_INFO,)):
    ta = [t for t in read_swf(a)[2] if t[0] not in ignore]
    tb = [t for t in read_swf(b)[2] if t[0] not in ignore]
    return ta == tb


# ---------------------------------------------------------------- mappings

def utils_d(text, key=MAPPINGS_KEY):
    """Utils.d: Base64 decode, then subtract key chars (uint16) with index i % len - 1."""
    s = base64.b64decode(text).decode("utf-8")
    return "".join(chr((ord(c) - ord(key[(i % len(key)) - 1])) & 0xFFFF) for i, c in enumerate(s))


def utils_e(text, key=MAPPINGS_KEY):
    """Inverse of utils_d."""
    s = "".join(chr((ord(c) + ord(key[(i % len(key)) - 1])) & 0xFFFF) for i, c in enumerate(text))
    return base64.b64encode(s.encode("utf-8")).decode("ascii")


def mappings_payload(swf):
    for code, data in read_swf(swf)[2]:
        if code == TAG_BINARY_DATA:
            return data[6:].decode("utf-8-sig")
    raise ValueError("mappings SWF has no DefineBinaryData tag")


def decode_vanilla_mappings(payload):
    """Vanilla Resource.getProp: JSON(Base64(Utils.d(blob)))."""
    return json.loads(base64.b64decode(utils_d(payload)).decode("utf-8"))


def encode_shell_mappings(obj):
    """Shell Resource.getProp: JSON(Base64(Utils.d(Base64(blob))))."""
    text = json.dumps(obj, separators=(",", ":"), ensure_ascii=False)
    inner = utils_e(base64.b64encode(text.encode("utf-8")).decode("ascii"))
    return base64.b64encode(inner.encode("ascii")).decode("ascii")


def decode_shell_mappings(payload):
    return json.loads(base64.b64decode(utils_d(base64.b64decode(payload).decode("utf-8"))).decode("utf-8"))


def set_mappings_payload(swf, payload):
    version, head, tags = read_swf(swf)
    out = []
    for code, data in tags:
        if code == TAG_BINARY_DATA:
            data = data[:6] + payload.encode("ascii")
        out.append((code, data))
    return write_swf(version, head, out)


_DELETE = None


def merge_diff(base, target):
    """RFC 7386 merge patch that turns base into target."""
    if not isinstance(base, dict) or not isinstance(target, dict):
        return target
    out = {}
    for k in base:
        if k not in target:
            out[k] = _DELETE
    for k, v in target.items():
        if k not in base:
            out[k] = v
        elif base[k] != v:
            out[k] = merge_diff(base[k], v)
    return out


def merge_apply(base, patch):
    if not isinstance(patch, dict):
        return patch
    out = dict(base) if isinstance(base, dict) else {}
    for k, v in patch.items():
        if v is None:
            out.pop(k, None)
        else:
            out[k] = merge_apply(out.get(k), v)
    return out


# ---------------------------------------------------------------- next2flash

class N2f:
    def __init__(self, root, work):
        self.root = Path(root).resolve()
        self.app = next((d for d in (self.root / "app", self.root / "runtime" / "resources" / "app")
                         if (d / "n2f.py").is_file()), None)
        if self.app is None:
            raise SystemExit("Next2Flash not found: %s (expected app/n2f.py or runtime/resources/app/n2f.py)" % self.root)
        self.log_path = work / "n2f.log"
        self.log_path.parent.mkdir(parents=True, exist_ok=True)

    def run(self, *args):
        cmd = [sys.executable, "n2f.py"] + [str(a) for a in args]
        with open(self.log_path, "a", encoding="utf-8") as fh:
            fh.write("\n$ " + " ".join(cmd) + "\n")
            fh.flush()
            code = subprocess.call(cmd, cwd=self.app, stdout=fh, stderr=subprocess.STDOUT)
        if code != 0:
            raise SystemExit("Next2Flash failed (%d): %s; see %s" % (code, args[0], self.log_path))

    def airglobal(self):
        for libs in ("toolchain/aflex_lite/frameworks/libs", "runtime/resources/toolchain/aflex_lite/frameworks/libs"):
            p = self.root / libs / "air" / "airglobal.swc"
            if p.is_file():
                return p
        raise SystemExit("airglobal.swc not found under %s" % self.root)

    def commit(self):
        try:
            return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=self.root,
                                           stderr=subprocess.DEVNULL).decode().strip()
        except Exception:
            return ""

    def decompile(self, swf, out):
        reset_dir(out)
        self.run("decompile", swf, "--all", "-d", out)
        return out

    def compile(self, src, classes, out_swf, project):
        externs = ENGINE2 / "externs"
        opts = {
            "source-path": [src.as_posix()],
            "includes": list(classes),
            "external-library-path": [(externs / "engine1.swc").as_posix(), self.airglobal().as_posix()],
            "target-player": "32.0",
            "optimize": True,
            "debug": False,
            "strict": False,
            "warnings": False,
            "static-link-runtime-shared-libraries": True,
            "load-externs": [(externs / "link-report.xml").as_posix()],
            "output": out_swf.as_posix(),
        }
        project.write_text(json.dumps({"mainClass": MAIN_CLASS, "compilerOptions": opts}, indent=2))
        if out_swf.exists():
            out_swf.unlink()
        self.run("asconfig", "--project", project)
        if not out_swf.is_file():
            raise SystemExit("compile produced no output: %s" % out_swf)


def read_tree(root, mg_only=False):
    out = {}
    for f in sorted(root.rglob("*.as")):
        rel = f.relative_to(root).as_posix()
        if mg_only and not rel.startswith(MG_PREFIX):
            continue
        if rel in ENGINE1_CLASSES:
            continue
        out[rel] = norm_text(read_utf8(f))
    return out


def class_name(rel):
    return rel[:-3].replace("/", ".")


def include_order(names):
    """Script order in the ABC follows the includes list; the shell sorts it like PowerShell Sort-Object."""
    return sorted(set(names), key=str.casefold)


def find_bin(bin_dir, base):
    hits = sorted(bin_dir.glob("*_com.mcleodgaming.ssf2.util.%s.bin" % base))
    if not hits:
        raise SystemExit("vanilla binaryData missing %s in %s" % (base, bin_dir))
    return hits[0]


_SECTION = re.compile("\\.\u00a7([^\u00a7]+)\u00a7")
_EMBED = re.compile(r'\[Embed\(source="[^"]+"')


def stage_text(rel, text):
    """Decompiler text -> compilable text: `.§name§` becomes `["name"]`, embeds point at `_assets/`."""
    text = _SECTION.sub(lambda m: '["%s"]' % m.group(1), text)
    stem = rel.rsplit("/", 1)[-1][:-3]
    for base, name in EMBED_ASSETS.items():
        if stem.endswith(base):
            text = _EMBED.sub('[Embed(source="../../../../../_assets/%s"' % name, text)
    return text


def vanilla_base(n2f, vanilla_root, work):
    """Decompile vanilla SSF2.swf once; the compilable MG classes are the patch base."""
    vdec = n2f.decompile(vanilla_root / "SSF2.swf", work / "vanilla")
    base = {rel: stage_text(rel, text) for rel, text in read_tree(vdec / "scripts", mg_only=True).items()}
    log("vanilla base classes=%d" % len(base))
    return base, vdec / "binaryData"


# ---------------------------------------------------------------- rebaseline

_FUNC = re.compile(r"^(\s*)(?:[\w$]+\s+)*function\s")
_DEFAULT_DECL = re.compile(r"^\s*var ([\w$]+):([^=;]+?)(?: = (?:null|0|false|NaN|undefined|Number\(NaN\)))?;\s*$")
_DEFAULT_SET = re.compile(r"^\s*([\w$]+) = (?:null|0|false|NaN|undefined|Number\(NaN\));\s*$")
_INIT_DECL = re.compile(r"^(\s*)var ([\w$]+):([^=;]+?) = (.*)$")
_VAR_NAME = re.compile(r"^\s*var ([\w$]+):", re.M)
_FOR_VAR = re.compile(r"\bfor(?: each)?\(var ([\w$]+):")
_SELF_PARAM = re.compile(r"^\s*(param\d+|_loc\d+_) = \1;\s*$")
_STEP = re.compile(r"^(\s*)([\w$.\[\]]+) ([+-])= 1;")
_NEW_AS_CLASS = re.compile(r"new \(([^()]+?) as Class\)\(")


def _line_shape(line):
    line = _STEP.sub(lambda m: m.group(1) + m.group(2) + m.group(3) * 2 + ";", line)
    return _NEW_AS_CLASS.sub(r"new \1(", line)
_THIS = re.compile(r"\bthis\.")
_LOC = re.compile(r"_loc\d+_")


_SIG = re.compile(r"^(.*?function\s+(?:[gs]et\s+)?[\w$]+\()(.*)(\).*)$")
_PARAM = re.compile(r"(^|,\s*)(\.\.\.)?([\w$]+)(?=\s*(?::|,|$))")


def sig_params(sig):
    m = _SIG.match(sig.strip())
    return [p.group(3) for p in _PARAM.finditer(m.group(2))] if m else []


def sig_key(sig):
    """Signature without parameter names: vanilla keeps debug names (`e`), a recompile has `param1`."""
    m = _SIG.match(sig.strip())
    if not m:
        return sig.strip()
    return m.group(1) + _PARAM.sub(lambda p: p.group(1) + (p.group(2) or "") + "_", m.group(2)) + m.group(3)


def _locals_rx(block):
    """Tokens that name a local: _locN_, the parameters, and every name declared with var in the method.
    The decompiler names locals instead of numbering them when a method has a closure."""
    names = {n for n in _VAR_NAME.findall(block) + _FOR_VAR.findall(block) if not _LOC.fullmatch(n)}
    names |= set(sig_params(block.split("\n", 1)[0])) - {"_"}
    names = sorted(names, key=len, reverse=True)
    alt = "|".join([r"_loc\d+_"] + [re.escape(n) for n in names])
    return _CodeRx(re.compile(r'(?<![\w$."/])(?:%s)(?![\w$"])' % alt))


_STRING = re.compile(r'"(?:[^"\\\n]|\\.)*"')


class _CodeRx:
    """A local-name regex that leaves string literals alone."""

    def __init__(self, rx):
        self.rx = rx

    def _parts(self, text):
        i = 0
        for m in _STRING.finditer(text):
            yield text[i:m.start()], m.group(0)
            i = m.end()
        yield text[i:], ""

    def sub(self, repl, text):
        return "".join(self.rx.sub(repl, code) + lit for code, lit in self._parts(text))

    def findall(self, text):
        return [n for code, _ in self._parts(text) for n in self.rx.findall(code)]

    def fullmatch(self, text):
        return self.rx.fullmatch(text)


def split_class(text):
    """(prefix, [(key, gap, block)], suffix); a block is a function from its signature to the matching '}'."""
    lines = split_lines(text)
    blocks, seen = [], {}
    gap_start, i = 0, 0
    first = None
    while i < len(lines):
        m = _FUNC.match(lines[i])
        if m and i + 1 < len(lines) and lines[i + 1] == m.group(1) + "{\n":
            indent = m.group(1)
            j = i + 2
            while j < len(lines) and lines[j] != indent + "}\n":
                j += 1
            if j >= len(lines):
                break
            sig = sig_key(lines[i])
            seen[sig] = seen.get(sig, 0) + 1
            if first is None:
                first = i
                gap = ""
            else:
                gap = "".join(lines[gap_start:i])
            blocks.append(((sig, seen[sig]), gap, "".join(lines[i:j + 1])))
            gap_start = i = j + 1
            continue
        i += 1
    if first is None:
        return text, [], ""
    return "".join(lines[:first]), blocks, "".join(lines[gap_start:])


_SIMPLE = re.compile(r"^[!-]?[\w$.]+$")
_GROUP = re.compile(r"\([^()]*\)|\[[^\[\]]*\]")
_CASTS = ("Boolean", "int", "uint", "Number", "String")


def _operand(text):
    prev = None
    while prev != text:
        prev, text = text, _GROUP.sub("", text)
    return bool(_SIMPLE.match(text))


def strip_call(text, name, keep_group=True):
    """Remove name(...) coercion wrappers; the argument keeps parens unless it is a plain operand."""
    out, i, head = [], 0, name + "("
    while True:
        k = text.find(head, i)
        if k < 0:
            out.append(text[i:])
            return "".join(out)
        if k > 0 and (text[k - 1].isalnum() or text[k - 1] in "_.$"):
            out.append(text[i:k + len(head)])
            i = k + len(head)
            continue
        depth, j = 1, k + len(head)
        while j < len(text) and depth:
            depth += {"(": 1, ")": -1}.get(text[j], 0)
            j += 1
        inner = strip_call(text[k + len(head):j - 1], name, keep_group)
        out.append(text[i:k])
        out.append("(" + inner + ")" if keep_group and not _operand(inner) else inner)
        i = j


def strip_boolean(text):
    # Boolean() wraps whole conditions, where the grouping is redundant.
    return strip_call(text, "Boolean", keep_group=False)


_FOR = re.compile(r"^(\s*)for\(([^;]*); ([^;]*); ([^;]*)\)\s*$")


def loop_lines(block):
    """(text, raw) per line with `for(a; b; c)` read as `a;` `while(b)` ... `c;`, the way a recompile
    decompiles it. Only the first piece of a for carries the raw line, so merged output keeps vanilla's for."""
    lines = split_lines(block)
    out, steps = [], {}
    for i, line in enumerate(lines):
        for step in steps.pop(i, []):
            out.append((step, ""))
        m = _FOR.match(line)
        if not (m and i + 1 < len(lines) and lines[i + 1] == m.group(1) + "{\n"):
            out.append((line, line))
            continue
        ind, init, cond, step = m.groups()
        j = i + 2
        while j < len(lines) and lines[j] != ind + "}\n":
            j += 1
        if j >= len(lines) or "continue" in "".join(lines[i:j]):
            out.append((line, line))
            continue
        if step:
            steps.setdefault(j, []).insert(0, ind + "   " + step + ";\n")
        pieces = ([ind + init + ";\n"] if init else []) + [ind + "while(" + (cond or "true") + ")\n"]
        out.append((pieces[0], line))
        out += [(p, "") for p in pieces[1:]]
    return out


def normalize_method(block):
    """Decompiler-neutral form: local declarations, leading default resets, no-op param copies,
    this., coercion casts, for loops and local names removed."""
    rx = _locals_rx(block)
    kept, decls = [], {}
    leading = True
    for n, (line, _) in enumerate(loop_lines(block)):
        m = _DEFAULT_DECL.match(line)
        if m:
            decls[m.group(1)] = m.group(2).strip()
            continue
        m = _DEFAULT_SET.match(line)
        if n >= 2 and leading and m and rx.fullmatch(m.group(1)):
            continue
        if _SELF_PARAM.match(line):
            continue
        if n >= 2:
            leading = False
        m = _INIT_DECL.match(line)
        if m:
            decls[m.group(2)] = m.group(3).strip()
            line = m.group(1) + m.group(2) + " = " + m.group(4)
        kept.append(_line_shape(line.rstrip()) + "\n")
    body = strip_boolean(_THIS.sub("", "".join(kept)))
    for name in _CASTS[1:]:
        body = strip_call(body, name)
    names = {}
    for name in rx.findall(body):
        names.setdefault(name, "L%d" % len(names))
    body = rx.sub(lambda m: names[m.group(0)], body)
    # A declared local nothing reads is not part of the method.
    return body, sorted((names[n], t) for n, t in decls.items() if n in names)


def same_method(a, b):
    """normalize_method equality; a local typed `*` matches any type (the decompiler's untyped local)."""
    (ba, da), (bb, db) = normalize_method(a), normalize_method(b)
    if ba != bb or [n for n, _ in da] != [n for n, _ in db]:
        return False
    return all(ta == tb or "*" in (ta, tb) for (_, ta), (_, tb) in zip(da, db))


def _norm_lines(block, rx):
    """Per line: (shape or None for lines normalization drops, raw line, read text). Shapes ignore local names."""
    out, leading = [], True
    for n, (line, raw) in enumerate(loop_lines(block)):
        m = _DEFAULT_SET.match(line)
        if _DEFAULT_DECL.match(line) or _SELF_PARAM.match(line) or (
                n >= 2 and leading and m and rx.fullmatch(m.group(1))):
            out.append((None, raw, line))
            continue
        if n >= 2:
            leading = False
        m = _INIT_DECL.match(line)
        shape = m.group(1) + m.group(2) + " = " + m.group(4) if m else line
        shape = strip_boolean(_THIS.sub("", _line_shape(shape.rstrip())))
        for name in _CASTS[1:]:
            shape = strip_call(shape, name)
        out.append((rx.sub("L", shape), raw, line))
    return out


def merge_method(base, shell, why=None):
    """Base method text with only the shell's real lines spliced in, shell locals renamed to base names.
    None when the result would not normalize to the shell method; the reason goes to `why`."""
    why = why if why is not None else []
    rr, rs = _locals_rx(base), _locals_rx(shell)
    R, S = _norm_lines(base, rr), _norm_lines(shell, rs)
    rk = [i for i, r in enumerate(R) if r[0] is not None]
    sk = [j for j, s in enumerate(S) if s[0] is not None]
    sm = difflib.SequenceMatcher(None, [R[i][0] for i in rk], [S[j][0] for j in sk], autojunk=False)
    ops = sm.get_opcodes()
    names = {}
    for tag, i1, i2, j1, j2 in ops:
        if tag != "equal":
            continue
        for a, b in zip(rk[i1:i2], sk[j1:j2]):
            for rn, sn in zip(rr.findall(R[a][2]), rs.findall(S[b][2])):
                if names.setdefault(sn, rn) != rn:
                    why.append("name %s is %s and %s" % (sn, names[sn], rn))
                    return None
    # Vanilla can reuse one name where the recompile used two registers; allowed when the shell's
    # two locals never overlap, and the check below compares against the shell with them joined.
    groups = collections.defaultdict(list)
    for sn, rn in names.items():
        groups[rn].append(sn)
    join = {}
    for rn, sns in groups.items():
        if len(sns) < 2:
            continue
        spans = []
        for sn in sns:
            at = [j for j, s in enumerate(S) if sn in rs.findall(s[2])]
            spans.append((at[0], at[-1]) if at else (-1, -1))
        spans.sort()
        if any(a[1] >= b[0] for a, b in zip(spans, spans[1:])):
            why.append("shell locals %s overlap where vanilla has one %s" % (",".join(sns), rn))
            return None
        join.update({sn: sns[0] for sn in sns[1:]})
    base_names = set(rr.findall(base))
    used = {int(x[4:-1]) for x in base_names if _LOC.fullmatch(x)}
    nxt = [max(used) + 1 if used else 0]

    def rename(m):
        n = m.group(0)
        if n not in names:
            if not _LOC.fullmatch(n) and n not in base_names:
                names[n] = n
            else:
                names[n] = "_loc%d_" % nxt[0]
                nxt[0] += 1
        return names[n]

    out, cur = [], 0
    for tag, i1, i2, j1, j2 in ops:
        if tag == "equal":
            end = rk[i2 - 1] + 1
            out += [r[1] for r in R[cur:end]]
            cur = end
            continue
        if i1 < i2:
            end = rk[i2 - 1] + 1
            out += [r[1] for r in R[cur:end] if r[0] is None]
            cur = end
        for j in sk[j1:j2]:
            out.append(rs.sub(rename, S[j][1]))
    out += [r[1] for r in R[cur:]]
    out = [l for l in out if l]
    # Shell-only locals declared on lines that normalization dropped need a declaration.
    declared = {m.group(1) for m in map(_DEFAULT_DECL.match, out) if m}
    declared |= {m.group(2) for m in map(_INIT_DECL.match, out) if m}
    extra = []
    for _, line, _ in S:
        m = _DEFAULT_DECL.match(line)
        if m and m.group(1) in names and names[m.group(1)] not in declared and names[m.group(1)] not in base_names:
            extra.append(rs.sub(rename, line))
            declared.add(names[m.group(1)])
    if extra:
        out[2:2] = extra
    uses = collections.Counter(_locals_rx("".join(out)).findall("".join(out)))
    out = [l for l in out if not ((m := _DEFAULT_DECL.match(l)) and uses[m.group(1)] == 1)]
    merged = "".join(out)
    if join:
        shell = rs.sub(lambda m: join.get(m.group(0), m.group(0)), shell)
    if not same_method(merged, shell):
        why += ["merged text normalizes differently", merged]
        return None
    return merged


_ALIAS = re.compile(r"^\s*var ([\w$]+):[^=;]+ = (param\d+);\s*$")


def unalias_params(block):
    """Drop `var name:T = paramN;` and use paramN for name. A recompile copies parameters into named
    locals when the method has a closure; vanilla uses the parameter directly."""
    lines = split_lines(block)
    params = set(sig_params(lines[0]))
    for i, line in enumerate(lines):
        m = _ALIAS.match(line)
        if not m or m.group(2) not in params:
            continue
        name, param = m.groups()
        word = re.compile(r"(?<![\w$.])%s(?![\w$])" % re.escape(param))
        if sum(len(word.findall(l)) for l in lines[1:]) != 1:
            continue
        lines[i] = ""
        rx = _CodeRx(re.compile(r"(?<![\w$.\"/])%s(?![\w$\"])" % re.escape(name)))
        lines = [lines[0]] + [rx.sub(param, l) for l in lines[1:]]
    return "".join(lines)


def clean_resets(block):
    """In each run of consecutive `local = <default>;` lines keep only the last store per local;
    nothing reads between them, so the earlier stores are dead."""
    rx = _locals_rx(block)
    lines = split_lines(block)
    out, run = [], []

    def flush():
        last = {}
        for i, (name, _) in enumerate(run):
            last[name] = i
        out.extend(l for i, (name, l) in enumerate(run) if last[name] == i)
        run.clear()

    for line in lines:
        m = _DEFAULT_SET.match(line)
        if m and rx.fullmatch(m.group(1)):
            run.append((m.group(1), line))
            continue
        flush()
        out.append(line)
    flush()
    return "".join(out)


def same_header(a, b):
    key = lambda s: sorted(l.strip() for l in split_lines(s) if l.strip())
    return key(a) == key(b)


_IMPORT = re.compile(r"^\s*import [\w$.*]+;\s*$")


def merge_header(base, shell, body_same):
    """Shell header with vanilla's imports plus the shell-only ones; vanilla's header when only imports differ
    and every method is vanilla's (a recompile turns explicit imports into wildcards)."""
    if same_header(base, shell):
        return base
    bl, sl = split_lines(base), split_lines(shell)
    rest = lambda ls: [l for l in ls if not _IMPORT.match(l)]
    if body_same and same_header("".join(rest(bl)), "".join(rest(sl))):
        return base
    bi = [l for l in bl if _IMPORT.match(l)]
    si = [i for i, l in enumerate(sl) if _IMPORT.match(l)]
    if not bi or not si:
        return shell
    have = {l.strip() for l in bi}
    imports = bi + [sl[i] for i in si if sl[i].strip() not in have]
    return "".join(sl[:si[0]] + imports + [l for i, l in enumerate(sl[si[0]:], si[0]) if i not in set(si)])


def rebaseline_class(base, shell):
    """Shell class rebuilt on the round-trip text: noise-only methods use the base, real edits keep the shell."""
    bp, bblocks, bs = split_class(base)
    sp, sblocks, ss = split_class(shell)
    sblocks = [(k, g, clean_resets(unalias_params(b))) for k, g, b in sblocks]
    if not bblocks or not sblocks:
        return (base if base == shell else shell), 0, 0
    shell_by_key = {k: (g, b) for k, g, b in sblocks}
    reverted = kept = 0
    out = [None]
    placed = set()
    for key, gap, block in bblocks:
        if key not in shell_by_key:
            continue
        sblock = shell_by_key[key][1]
        if same_method(block, sblock):
            out.append(gap + block)
            reverted += 1
        else:
            out.append(gap + (merge_method(block, sblock) or sblock))
            kept += 1
        placed.add(key)
        # shell-only methods that follow this one in the shell
        idx = [k for k, _, _ in sblocks].index(key)
        for k2, g2, b2 in sblocks[idx + 1:]:
            if k2 in placed or k2 in {k for k, _, _ in bblocks}:
                break
            out.append((g2 or "\n") + b2)
            placed.add(k2)
            kept += 1
    for k2, g2, b2 in sblocks:
        if k2 not in placed:
            out.append((g2 or "\n") + b2)
            kept += 1
    out.append(bs if same_header(bs, ss) else ss)
    out[0] = merge_header(bp, sp, kept == 0 and len(placed) == len(bblocks) and out[-1] == bs)
    return "".join(out), reverted, kept


# ---------------------------------------------------------------- port

def class_sections(text):
    """[(section name, gap, text)]: the class header, each method as named in patches, the class footer."""
    prefix, blocks, suffix = split_class(text)
    out = [(HEADER_SECTION, "", prefix)]
    for (sig, n), gap, block in blocks:
        out.append((sig if n == 1 else "%s #%d" % (sig, n), gap, block))
    out.append((FOOTER_SECTION, "", suffix))
    return out


def _edits(a, b):
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    return [(i1, i2, tuple(b[j1:j2])) for tag, i1, i2, j1, j2 in sm.get_opcodes() if tag != "equal"]


def merge3(o, s, n):
    """Line-level 3-way merge of o->s and o->n; None when an edit from each side touches the same lines."""
    O = split_lines(o)
    es, en = _edits(O, split_lines(s)), _edits(O, split_lines(n))
    for a in es:
        for b in en:
            if a != b and a[0] <= b[1] and b[0] <= a[1]:
                return None
    out, pos = [], 0
    for i1, i2, rep in sorted(set(es) | set(en)):
        out += O[pos:i1] + list(rep)
        pos = i2
    return "".join(out + O[pos:])


def port_class(rel, o, s, n, notes):
    """Shell class s (old base o plus patches) moved onto new base n, section by section.
    Returns (text or None when n lacks the class, Counter, [report entries])."""
    stats, report = collections.Counter(), []

    def entry(kind, name, ot, st, nt):
        report.append({"kind": kind, "class": rel, "section": name, "why": notes.get(sig_key(name), ""),
                       "old": ot, "shell": st, "new": nt})

    if n is None:
        stats["missing"] += 1
        entry("missing", "class", None, None, None)
        return None, stats, report
    # The gap before a method (blank lines, fields between methods) belongs to that method's section.
    O = {k: g + t for k, g, t in class_sections(o)}
    Sl = [(k, "", g + t) for k, g, t in class_sections(s)]
    Nl = [(k, "", g + t) for k, g, t in class_sections(n)]
    S = {k: t for k, _, t in Sl}
    out = []
    for name, gap, nt in Nl:
        ot, st = O.get(name), S.get(name)
        if st == ot:
            text = nt
            stats["upstream"] += ot != nt
        elif ot == nt or st == nt:
            text = st
            stats["clean"] += 1
        elif ot is None or st is None:
            text = nt
            stats["conflicts"] += 1
            entry("conflict", name, ot, st, nt)
        else:
            text = merge3(ot, st, nt)
            if text is None:
                text = nt
                stats["conflicts"] += 1
                entry("conflict", name, ot, st, nt)
            else:
                stats["merged"] += 1
        if text is not None:
            out.append([name, gap, text])
    names = [r[0] for r in out]
    in_new = {k for k, _, _ in Nl}
    for i, (name, gap, st) in enumerate(Sl):
        if name in in_new:
            continue
        ot = O.get(name)
        if ot is None:
            prev = next((Sl[j][0] for j in range(i - 1, -1, -1) if Sl[j][0] in names), HEADER_SECTION)
            at = names.index(prev) + 1
            out.insert(at, [name, gap, st])
            names.insert(at, name)
            stats["clean"] += 1
        elif st != ot:
            stats["missing"] += 1
            entry("missing", name, ot, st, None)
    return "".join(g + t for _, g, t in out), stats, report


def port_tree(old_base, shell, new_base, notes):
    """{rel: text} for the new version: new base classes, with every shell class ported onto them."""
    tree, stats, report = dict(new_base), collections.Counter(), []
    for rel, s in sorted(shell.items()):
        o = old_base.get(rel)
        if o is None or o == s:
            if o is None:
                tree[rel] = s
            continue
        text, st, rep = port_class(rel, o, s, new_base.get(rel), notes.get(rel, {}))
        stats["classes"] += 1
        stats.update(st)
        report += rep
        if text is not None:
            tree[rel] = text
    return tree, stats, report


def _fence(text):
    return "```as3\n%s```\n" % (text if text else "(none)\n")


def port_report(report):
    out = ["# Port report\n\n%d sections need a hand port. Each has its `## why:` note, the old base, "
           "the shell and the new base. The new base is what `changed/` holds for it now.\n" % len(report)]
    for e in report:
        out.append("\n## %s :: %s\n\n- kind: %s\n- why: %s\n\n### old base\n\n%s\n### shell\n\n%s\n### new base\n\n%s"
                   % (e["class"], e["section"], e["kind"], e["why"] or "(no note)",
                      _fence(e["old"]), _fence(e["shell"]), _fence(e["new"])))
    return "".join(out)


# ---------------------------------------------------------------- game layout

def manifest_bin(vanilla_root):
    """Shell manifest embed: vanilla's DefineBinaryData 514 without the Utils.d layer (plain Base64 JSON)."""
    for code, data in read_swf((vanilla_root / "SSF2.swf").read_bytes())[2]:
        if code == TAG_BINARY_DATA and struct.unpack_from("<H", data)[0] == MANIFEST_TAG_ID:
            return utils_d(data[6:].decode("utf-8-sig"), MANIFEST_KEY).encode("ascii")
    raise SystemExit("vanilla SSF2.swf has no manifest tag %d" % MANIFEST_TAG_ID)


def decode_manifest(data):
    return json.loads(base64.b64decode(data).decode("utf-8"))


def data_layout(manifest, mappings):
    """(data/<folder>/<file>, vanilla DAT name) for every resource the engine loads by name."""
    out = {}
    for source in (manifest, mappings):
        for cat, folder in DATA_FOLDERS.items():
            entries = source.get(cat)
            if not isinstance(entries, dict):
                continue
            for entry in entries.values():
                if isinstance(entry, dict) and entry.get("file") and entry.get("file_pub"):
                    out["data/%s/%s" % (folder, entry["file"])] = entry["file_pub"]
    return out


def copy_data(vanilla, out, layout):
    copied, missing = 0, []
    for rel, dat in sorted(layout.items()):
        src = vanilla / "data" / dat
        if not src.is_file():
            missing.append("%s <- %s" % (rel, dat))
            continue
        dest = out / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dest)
        copied += 1
    log("data copied=%d missing=%d" % (copied, len(missing)))
    for m in missing:
        log("data missing %s" % m)
    return copied


def copy_air(vanilla_root, out):
    """The captive runtime from the vanilla install; SSF2.exe and its ANEs are built against it."""
    src = vanilla_root / "Adobe AIR"
    if not src.is_dir():
        raise SystemExit("vanilla install has no Adobe AIR folder: %s" % src)
    n = 0
    for f in sorted(src.rglob("*")):
        if f.is_file() and f.name not in AIR_SKIP:
            dest = out / "Adobe AIR" / f.relative_to(src)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(f, dest)
            n += 1
    log("AIR runtime files=%d" % n)


def copy_overlay(out, src=SHELL, label="shell", skip=("src",)):
    """Top-level folders in skip stay out of the build: shell/src is mod source, the game loads data/ssf2mm."""
    n = 0
    for f in sorted(src.rglob("*")):
        if f.is_file():
            rel = f.relative_to(src)
            if rel.parts[0] in skip:
                continue
            dest = out / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(f, dest)
            n += 1
    log("%s files=%d" % (label, n))


def reset_out(out):
    if out.exists() and any(out.iterdir()):
        if out != ROOT / "Build" and not (out / "shell-base-build.json").exists():
            raise SystemExit("refusing to clear %s: not a previous Shell Base build" % out)
        shutil.rmtree(out)
    out.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------- commands

def vanilla_mappings_swf(vanilla_root, info):
    dat = vanilla_root / "data" / info["dat"]
    swf = ssf_unwrap(dat.read_bytes())
    got = hashlib.md5(swf).hexdigest().upper()
    if got != info["inner_md5"]:
        raise SystemExit("mappings DAT %s inner md5 %s, expected %s" % (dat.name, got, info["inner_md5"]))
    return swf


def vanilla_problems(vanilla, meta):
    """Paths under the vanilla install whose hash is not 1.4.0.1. Empty when they match."""
    problems = []
    swf = Path(vanilla) / "SSF2.swf"
    if not swf.is_file():
        problems.append("SSF2.swf")
    elif sha256_bytes(swf.read_bytes()) != meta["vanilla_ssf2_sha256"]:
        problems.append("SSF2.swf")
    info = json.loads((MAPPINGS / "base.json").read_text(encoding="utf-8"))
    rel = "data/" + info["dat"]
    dat = Path(vanilla) / "data" / info["dat"]
    if not dat.is_file():
        problems.append(rel)
    else:
        try:
            vanilla_mappings_swf(vanilla, info)
        except SystemExit:
            problems.append(rel)
    return problems


def cmd_capture(a):
    shell = Path(a.shell).resolve()
    vanilla = Path(a.vanilla).resolve()
    work = reset_dir(ROOT / "work" / "capture")
    n2f = N2f(a.n2f, work)
    changed = shell / "expansions" / "decompiled" / "engine2" / "changed"
    shell_assets = shell / "expansions" / "decompiled" / "engine2" / "_assets"
    externs = shell / "expansions" / "decompiled" / "engine2" / "externs"

    reset_dir(ENGINE2 / "externs")
    for name in ("engine1.swc", "link-report.xml"):
        shutil.copyfile(externs / name, ENGINE2 / "externs" / name)

    base, _ = vanilla_base(n2f, vanilla, work)
    target = read_tree(changed)
    old = ENGINE2 / "patches"
    notes = {f.relative_to(old).as_posix()[:-len(".patch")]: read_notes(read_utf8(f))
             for f in old.rglob("*.patch")} if old.exists() else {}
    patches = reset_dir(ENGINE2 / "patches")
    added = reset_dir(ENGINE2 / "added")
    removed = sorted(r for r in base if r not in target)
    n_patch = n_added = n_sections = n_todo = 0
    todo = []
    for rel, text in target.items():
        if rel in base:
            if base[rel] != text:
                patch = make_patch(base[rel], text, rel, notes.get(rel))
                write_text(patches / (rel + ".patch"), patch)
                n_patch += 1
                for line in split_lines(patch):
                    if line.startswith("## why: "):
                        n_sections += 1
                        if line == "## why: %s\n" % TODO_WHY:
                            n_todo += 1
                            todo.append("%s :: %s" % (rel, prev[3:].rstrip()))
                    prev = line
        else:
            write_text(added / rel, text)
            n_added += 1
    if (shell_assets / EMBED_ASSETS[MANIFEST_ASSET]).read_bytes() != manifest_bin(vanilla):
        raise SystemExit("shell manifest embed differs from the vanilla manifest; run rebaseline first")
    if (ENGINE2 / "assets").exists():
        shutil.rmtree(ENGINE2 / "assets")

    meta = {
        "vanilla_ssf2_sha256": sha256_bytes((vanilla / "SSF2.swf").read_bytes()),
        "next2flash_commit": n2f.commit(),
        "shell_engine2_sha256": sha256_bytes((shell / "data" / "engine" / "engine2.swf").read_bytes()),
        "removed": removed,
        "includes": include_order(class_name(r) for r in target),
        "crlf": sorted(f.relative_to(changed).as_posix() for f in changed.rglob("*.as")
                       if b"\r\n" in f.read_bytes()),
        "base": {r: sha256_text(t) for r, t in base.items()},
        "target": {r: sha256_text(t) for r, t in target.items()},
    }
    (ENGINE2 / "base.json").write_text(json.dumps(meta, indent=1, sort_keys=True) + "\n")
    log("engine2 patches=%d added=%d removed=%d same=%d" % (
        n_patch, n_added, len(removed), len(base) - n_patch - len(removed)))
    (work / "why-missing.txt").write_text("".join(t + "\n" for t in todo), encoding="utf-8")
    log("patch sections=%d why missing=%d (list in %s)" % (n_sections, n_todo, work / "why-missing.txt"))

    MAPPINGS.mkdir(exist_ok=True)
    dat = a.mappings_dat
    vswf = ssf_unwrap((vanilla / "data" / dat).read_bytes())
    vjson = decode_vanilla_mappings(mappings_payload(vswf))
    sjson = json.loads((shell / "data" / "misc" / "mappings.json").read_text(encoding="utf-8-sig"))
    patch = merge_diff({k: v for k, v in vjson.items() if k not in MAPPINGS_SKIP},
                       {k: v for k, v in sjson.items() if k not in MAPPINGS_SKIP})
    (MAPPINGS / "patch.json").write_text(json.dumps(patch, indent=2, sort_keys=True) + "\n")
    (MAPPINGS / "base.json").write_text(json.dumps(
        {"dat": dat, "inner_md5": hashlib.md5(vswf).hexdigest().upper(), "skip": sorted(MAPPINGS_SKIP)},
        indent=2) + "\n")
    log("mappings patch keys=%d" % len(patch))

    for rel, text in target.items():
        pp = patches / (rel + ".patch")
        if rel not in base:
            got = read_utf8(added / rel)
        elif pp.exists():
            got = apply_patch(base[rel], read_utf8(pp), rel)
        else:
            got = base[rel]
        if got != text:
            raise SystemExit("capture self-check failed: %s" % rel)
    log("capture self-check OK classes=%d" % len(target))


def patch_size(base, tree):
    files = added = 0
    for rel, text in tree.items():
        if rel in base and base[rel] != text:
            files += 1
            added += sum(1 for l in split_lines(make_patch(base[rel], text, rel)) if l.startswith("+"))
    return files, added


def cmd_rebaseline(a):
    shell = Path(a.shell).resolve()
    vanilla = Path(a.vanilla).resolve()
    work = reset_dir(ROOT / "work" / "rebaseline")
    n2f = N2f(a.n2f, work)
    changed = shell / "expansions" / "decompiled" / "engine2" / "changed"
    base, _ = vanilla_base(n2f, vanilla, work)
    target = read_tree(changed)
    new, report = {}, []
    reverted = kept = 0
    for rel, text in target.items():
        if rel in base and base[rel] != text:
            out, r, k = rebaseline_class(base[rel], text)
            log("rebaseline %s methods=%d reverted=%d kept=%d" % (rel, r + k, r, k))
            reverted += r
            kept += k
            if r:
                report.append(rel)
        else:
            out = text
        new[rel] = out
    before, after = patch_size(base, target), patch_size(base, new)
    log("rebaseline methods reverted=%d kept=%d" % (reverted, kept))
    log("patch size before files=%d added=%d after files=%d added=%d" % (before + after))
    (work / "rebaseline.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
    if a.dry_run:
        for rel, text in new.items():
            write_text(work / "new" / rel, text)
        log("dry run: shell not changed; new tree in %s" % (work / "new"))
        return
    backup = changed.parent / ("changed.bak-" + a.stamp)
    if not backup.exists():
        shutil.copytree(changed, backup)
        log("backup %s" % backup)
    crlf = {f.relative_to(changed).as_posix() for f in changed.rglob("*.as") if b"\r\n" in f.read_bytes()}
    written = 0
    for rel, text in new.items():
        if text == target[rel]:
            continue
        write_text(changed / rel, text.replace("\n", "\r\n") if rel in crlf else text)
        written += 1
    log("rebaseline wrote classes=%d" % written)
    asset = changed.parent / "_assets" / EMBED_ASSETS[MANIFEST_ASSET]
    data = manifest_bin(vanilla)
    if asset.read_bytes() != data:
        keep = asset.with_name(asset.name + ".bak-" + a.stamp)
        if not keep.exists():
            shutil.copyfile(asset, keep)
        asset.write_bytes(data)
        log("manifest embed replaced with vanilla bytes=%d" % len(data))


def cmd_build(a):
    vanilla = Path(a.vanilla).resolve()
    out = Path(a.out).resolve() if a.out else ROOT / "Build"
    work = reset_dir(ROOT / "work" / "build")
    n2f = N2f(a.n2f, work)
    meta = json.loads((ENGINE2 / "base.json").read_text(encoding="utf-8"))

    if not (vanilla / "SSF2.swf").is_file():
        raise SystemExit("vanilla folder has no SSF2.swf")
    log("vanilla hash check skipped")
    vsha = sha256_bytes((vanilla / "SSF2.swf").read_bytes())

    base, vbins = vanilla_base(n2f, vanilla, work)
    hint = "Next2Flash %s decompiles differently from %s, the one the patches were captured with" % (
        n2f.commit() or "release", meta["next2flash_commit"])

    eng = work / "engine2"
    src = reset_dir(eng / "src")
    assets = reset_dir(eng / "_assets")
    tree = {}
    for rel, text in base.items():
        if rel in meta["removed"]:
            continue
        p = ENGINE2 / "patches" / (rel + ".patch")
        try:
            tree[rel] = apply_patch(text, read_utf8(p), rel) if p.exists() else text
        except SystemExit as e:
            raise SystemExit("%s; %s" % (e, hint))
    for f in sorted((ENGINE2 / "added").rglob("*.as")):
        tree[f.relative_to(ENGINE2 / "added").as_posix()] = read_utf8(f)
    bad = sorted(r for r, h in meta["target"].items() if sha256_text(tree.get(r, "")) != h)
    extra = sorted(r for r in tree if r not in meta["target"])
    log("engine2 source classes=%d mismatched=%d extra=%d" % (len(tree), len(bad), len(extra)))
    if bad or extra:
        for r in (bad + extra)[:20]:
            log("source mismatch %s" % r)
        raise SystemExit("patched engine2 source does not match the shell (%s)" % hint)
    crlf = set(meta["crlf"])
    for rel, text in tree.items():
        # Line endings inside multi-line literals reach the bytecode.
        write_text(src / rel, text.replace("\n", "\r\n") if rel in crlf else text)
    manifest = manifest_bin(vanilla)
    for b, name in EMBED_ASSETS.items():
        if b == MANIFEST_ASSET:
            (assets / name).write_bytes(manifest)
        else:
            shutil.copyfile(find_bin(vbins, b), assets / name)

    info = json.loads((MAPPINGS / "base.json").read_text(encoding="utf-8"))
    vswf = vanilla_mappings_swf(vanilla, info)
    vjson = decode_vanilla_mappings(mappings_payload(vswf))
    mjson = merge_apply(vjson, json.loads((MAPPINGS / "patch.json").read_text(encoding="utf-8")))

    built = work / "engine2.swf"
    n2f.compile(src, meta["includes"], built, work / "engine2.asconfig.json")
    log("engine2.swf %d bytes" % built.stat().st_size)

    reset_out(out)
    copy_air(vanilla, out)
    copy_overlay(out)
    for rel in ASSET_PATHS:
        if not (SHELL / rel).is_file():
            log("asset missing shell/%s (not copied)" % rel)
    copy_data(vanilla, out, data_layout(decode_manifest(manifest), mjson))
    engine_dir = out / "data" / "engine"
    engine_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(built, engine_dir / "engine2.swf")

    misc = out / "data" / "misc"
    misc.mkdir(parents=True, exist_ok=True)
    (misc / "mappings.json").write_text(json.dumps(mjson, indent=2) + "\n", encoding="utf-8")
    (misc / "mappings.ssf").write_bytes(ssf_wrap(set_mappings_payload(vswf, encode_shell_mappings(mjson))))
    log("mappings characters=%d stages=%d music=%d" % (
        len(mjson.get("character", {})), len(mjson.get("stage", {})), len(mjson.get("music", {}))))

    packed = ROOT / "ssfpatch.json"
    (out / "shell-base-build.json").write_text(json.dumps({
        "version": json.loads(packed.read_text(encoding="utf-8"))["version"] if packed.is_file() else "dev",
        "assets": assets_id(),
        "vanilla_ssf2_sha256": vsha,
        "next2flash_commit": n2f.commit(),
        "engine2_sha256": sha256_bytes((engine_dir / "engine2.swf").read_bytes()),
    }, indent=2) + "\n")
    log("build OK -> %s" % out)


def pack_files(root, rels, skip=()):
    for rel in rels:
        p = root / rel
        for f in [p] if p.is_file() else sorted(p.rglob("*")):
            arc = f.relative_to(root).as_posix()
            if f.is_file() and "__pycache__" not in f.parts and f.suffix != ".pyc" and arc not in skip:
                yield arc, f


def assets_id(shell=None):
    """Content id of the ASSET_PATHS files under shell/: changes only when one of them changes. Empty when one is missing.
    The hash covers the zip path (shell/<rel>), so a zip with another layout never shares an id."""
    shell = shell or SHELL
    if not all((shell / rel).is_file() for rel in ASSET_PATHS):
        return ""
    h = hashlib.sha256()
    for rel, f in pack_files(shell, ASSET_PATHS):
        h.update(("shell/%s\0%s\n" % (rel, sha256_bytes(f.read_bytes()))).encode("utf-8"))
    return h.hexdigest()[:12]


def write_pack(path, manifest_name, manifest, files):
    import zipfile
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    n = 0
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        z.writestr(manifest_name, json.dumps(manifest, indent=2) + "\n")
        for arc, f in files:
            z.write(f, arc)
            n += 1
    tmp.replace(path)
    log("pack %s files=%d bytes=%d" % (path.name, n, path.stat().st_size))


def cmd_pack(a):
    """Write the release pair: shell-base-<version>.ssfpatch and shell-assets-<id>.ssfpatch.
    Unzipping both into one folder gives a tree that `build` runs from."""
    todo = [str(f.relative_to(ENGINE2)) for f in sorted((ENGINE2 / "patches").rglob("*.patch"))
            if "## why: %s" % TODO_WHY in (l.rstrip() for l in read_utf8(f).splitlines())]
    if todo:
        raise SystemExit("patches still have '## why: %s' (%d files, e.g. %s); fill them before packing"
                         % (TODO_WHY, len(todo), todo[0]))
    missing = [rel for rel in ASSET_PATHS if not (SHELL / rel).is_file()]
    if missing:
        raise SystemExit("asset missing: shell/%s" % missing[0])
    out = Path(a.out).resolve() if a.out else ROOT / "work" / "dist"
    meta = json.loads((ENGINE2 / "base.json").read_text(encoding="utf-8"))
    aid = assets_id()
    stamp = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()
    write_pack(out / ("shell-assets-%s.ssfpatch" % aid), "ssfpatch-assets.json",
               {"format": PACK_FORMAT, "kind": "assets", "id": aid, "created": stamp},
               (("shell/" + rel, f) for rel, f in pack_files(SHELL, ASSET_PATHS)))
    write_pack(out / ("shell-base-%s.ssfpatch" % a.version), "ssfpatch.json",
               {"format": PACK_FORMAT, "kind": "core", "version": a.version, "assets": aid,
                "vanilla_ssf2_sha256": meta["vanilla_ssf2_sha256"],
                "next2flash_commit": meta["next2flash_commit"], "created": stamp},
               pack_files(ROOT, PACK_CORE, {"shell/" + rel for rel in ASSET_PATHS}))
    log("pack version=%s assets=%s -> %s" % (a.version, aid, out))


def cmd_port(a):
    old, new = Path(a.old_vanilla).resolve(), Path(a.new_vanilla).resolve()
    out = Path(a.out).resolve() if a.out else ROOT / "work" / "port"
    work = reset_dir(ROOT / "work" / "port-decompile")
    n2f = N2f(a.n2f, work)
    meta = json.loads((ENGINE2 / "base.json").read_text(encoding="utf-8"))
    vsha = sha256_bytes((old / "SSF2.swf").read_bytes())
    if vsha != meta["vanilla_ssf2_sha256"]:
        raise SystemExit("--old-vanilla SSF2.swf sha256 %s is not the version the patches were captured on (%s)"
                         % (vsha, meta["vanilla_ssf2_sha256"]))
    old_base, _ = vanilla_base(n2f, old, work / "old")
    new_base, _ = vanilla_base(n2f, new, work / "new")
    shell, notes = {}, {}
    for rel, text in old_base.items():
        p = ENGINE2 / "patches" / (rel + ".patch")
        if rel in meta["removed"]:
            continue
        if p.exists():
            patch = read_utf8(p)
            shell[rel] = apply_patch(text, patch, rel)
            notes[rel] = read_notes(patch)
        else:
            shell[rel] = text
    for f in sorted((ENGINE2 / "added").rglob("*.as")):
        shell[f.relative_to(ENGINE2 / "added").as_posix()] = read_utf8(f)
    tree, stats, report = port_tree(old_base, shell, new_base, notes)
    for rel in meta["removed"]:
        tree.pop(rel, None)
    changed = reset_dir(out / "changed")
    crlf = set(meta["crlf"])
    for rel, text in tree.items():
        write_text(changed / rel, text.replace("\n", "\r\n") if rel in crlf else text)
    (out / "report.md").write_text(port_report(report), encoding="utf-8")
    for e in report:
        log("port %s %s :: %s" % (e["kind"], e["class"], e["section"]))
    log("port classes=%d clean=%d upstream=%d merged=%d conflicts=%d missing=%d" % tuple(
        stats[k] for k in ("classes", "clean", "upstream", "merged", "conflicts", "missing")))
    log("port tree classes=%d -> %s (report %s)" % (len(tree), changed, out / "report.md"))


def cmd_verify(a):
    shell = Path(a.shell).resolve()
    out = Path(a.out).resolve() if a.out else ROOT / "Build"
    ok = True
    built = (out / "data" / "engine" / "engine2.swf").read_bytes()
    ref = (shell / "data" / "engine" / "engine2.swf").read_bytes()
    same = swf_tags_equal(built, ref)
    log("engine2 tags equal (ProductInfo ignored): %s" % same)
    ok &= same

    mjson = json.loads(read_utf8(out / "data" / "misc" / "mappings.json"))
    sjson = json.loads((shell / "data" / "misc" / "mappings.json").read_text(encoding="utf-8-sig"))
    strip = lambda o: {k: v for k, v in o.items() if k not in MAPPINGS_SKIP}
    same = strip(mjson) == strip(sjson)
    log("mappings.json equals shell outside %s: %s" % (sorted(MAPPINGS_SKIP), same))
    ok &= same
    ssf = decode_shell_mappings(mappings_payload(ssf_unwrap((out / "data" / "misc" / "mappings.ssf").read_bytes())))
    same = ssf == mjson
    log("mappings.ssf decodes to mappings.json: %s" % same)
    ok &= same

    if a.vanilla:
        inner = lambda p: hashlib.md5(ssf_unwrap(p.read_bytes())).hexdigest()
        vhash = {inner(p) for p in (Path(a.vanilla) / "data").glob("DAT*.ssf")}
        referenced = set(data_layout(decode_manifest(manifest_bin(Path(a.vanilla))), sjson))
        want = missing = differ = other = 0
        for f in sorted((shell / "data").rglob("*.ssf")):
            rel = f.relative_to(shell).as_posix()
            if rel not in referenced or rel == "data/misc/mappings.ssf":
                continue
            h = inner(f)
            if h not in vhash:
                other += 1
                log("data shell-modified %s" % rel)
                continue
            want += 1
            b = out / rel
            if not b.is_file():
                if rel.startswith("data/sound/"):
                    log("music not in build (shell-only track) %s" % rel)
                    continue
                missing += 1
                log("data missing in build %s" % rel)
            elif inner(b) != h:
                differ += 1
                log("data differs in build %s" % rel)
        log("data vanilla-derived=%d missing=%d differ=%d shell-modified-or-custom=%d" % (want, missing, differ, other))
        ok &= missing == 0 and differ == 0
    if not ok:
        raise SystemExit("verify FAILED")
    log("verify OK")


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--vanilla", required=True, help="SSF2 Beta 1.4.0.1 install folder")
    b.add_argument("--n2f", required=True, help="Next2Flash folder")
    b.add_argument("--out", help="output folder (default Build/)")
    b.add_argument("--allow-vanilla-mismatch", action="store_true",
                   help="continue after vanilla hash mismatch; the manager asks once")
    k = sub.add_parser("pack")
    k.add_argument("--version", required=True, help="release version, e.g. 1.0.0")
    k.add_argument("--out", help="output folder (default work/dist/)")
    c = sub.add_parser("capture")
    c.add_argument("--shell", required=True, help="decompiled tree with expansions/decompiled/engine2/changed (import only; day-to-day edits are patches/engine2)")
    c.add_argument("--vanilla", required=True)
    c.add_argument("--n2f", required=True)
    c.add_argument("--mappings-dat", default="DAT51.ssf")
    r = sub.add_parser("rebaseline")
    r.add_argument("--shell", required=True)
    r.add_argument("--vanilla", required=True)
    r.add_argument("--n2f", required=True)
    r.add_argument("--dry-run", action="store_true", help="report and write work/rebaseline/new only")
    r.add_argument("--stamp", default=datetime.date.today().isoformat())
    v = sub.add_parser("verify")
    v.add_argument("--shell", required=True)
    v.add_argument("--vanilla", help="also check data/ against the shell's vanilla-derived files")
    v.add_argument("--out")
    t = sub.add_parser("port")
    t.add_argument("--old-vanilla", required=True, help="the SSF2 install the patches were captured on")
    t.add_argument("--new-vanilla", required=True, help="the new SSF2 install to port the shell to")
    t.add_argument("--n2f", required=True)
    t.add_argument("--out", help="output folder for changed/ and report.md (default work/port)")
    a = p.parse_args(argv)
    {"build": cmd_build, "capture": cmd_capture, "rebaseline": cmd_rebaseline, "verify": cmd_verify,
     "pack": cmd_pack, "port": cmd_port}[a.cmd](a)


if __name__ == "__main__":
    main()
