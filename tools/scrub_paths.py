"""Remove build-machine paths from compiled SWF, SWC, ANE and DLL files.

A debug compile stores each source file as a `debugfile` string in the ABC
constant pool ("C:\\...\\src;com\\pkg;File.as"). Only those strings change;
bytecode refers to them by index, so the code is untouched.

    python tools/scrub_paths.py [--check] FILE...
"""
import argparse
import io
import re
import struct
import sys
import zipfile
import zlib
from pathlib import Path

DRIVE_PATH = re.compile(rb"[A-Za-z]:[\\/](?:Users|Documents and Settings)[\\/][^;\x00\"<>|]*")


def read_u30(b, i):
    v = 0
    shift = 0
    while True:
        byte = b[i]
        i += 1
        v |= (byte & 0x7F) << shift
        shift += 7
        if not byte & 0x80 or shift >= 35:
            return v, i


def write_u30(v):
    out = bytearray()
    while True:
        byte = v & 0x7F
        v >>= 7
        if v:
            out.append(byte | 0x80)
        else:
            out.append(byte)
            return bytes(out)


def clean_string(s):
    """`C:\\Users\\x\\proj\\src;com\\pkg;File.as` -> `src;com\\pkg;File.as`."""
    if ";" in s:
        head, rest = s.split(";", 1)
        if re.match(r"[A-Za-z]:[\\/]", head):
            return head.replace("\\", "/").rstrip("/").split("/")[-1] + ";" + rest
    if re.match(r"[A-Za-z]:[\\/](Users|Documents and Settings)[\\/]", s):
        return s.replace("\\", "/").split("/")[-1]
    return s


def scrub_abc(abc):
    i = 4  # minor, major
    for _pool in range(2):  # int pool, uint pool
        n, i = read_u30(abc, i)
        for _ in range(max(n - 1, 0)):
            _, i = read_u30(abc, i)
    n, i = read_u30(abc, i)
    i += 8 * max(n - 1, 0)  # double pool
    head = abc[:i]
    n, i = read_u30(abc, i)
    out = bytearray(head) + write_u30(n)
    changed = 0
    for _ in range(max(n - 1, 0)):
        ln, i = read_u30(abc, i)
        s = abc[i:i + ln]
        i += ln
        text = s.decode("utf-8", "surrogateescape")
        new = clean_string(text)
        if new != text:
            changed += 1
            s = new.encode("utf-8", "surrogateescape")
        out += write_u30(len(s)) + s
    out += abc[i:]
    return bytes(out), changed


def scrub_swf(data):
    sig = data[:3]
    if sig == b"CWS":
        body = zlib.decompress(data[8:])
    elif sig == b"FWS":
        body = data[8:]
    else:
        raise ValueError("not a SWF (LZMA is not supported)")
    nbits = body[0] >> 3
    i = (5 + 4 * nbits + 7) // 8 + 4
    out = bytearray(body[:i])
    changed = 0
    while i < len(body):
        code_len = struct.unpack_from("<H", body, i)[0]
        code, ln = code_len >> 6, code_len & 0x3F
        hdr = 2
        if ln == 0x3F:
            ln = struct.unpack_from("<I", body, i + 2)[0]
            hdr = 6
        payload = body[i + hdr:i + hdr + ln]
        i += hdr + ln
        if code == 64:  # EnableDebugger2: drop it
            changed += 1
            continue
        if code in (72, 82):  # DoABC, DoABC2
            pre = b""
            if code == 82:
                end = payload.index(b"\x00", 4) + 1
                pre, payload = payload[:end], payload[end:]
            abc, n = scrub_abc(payload)
            changed += n
            payload = pre + abc
        out += struct.pack("<HI", (code << 6) | 0x3F, len(payload)) + payload
        if code == 0:
            break
    body = bytes(out)
    total = 8 + len(body)
    if sig == b"CWS":
        return b"CWS" + data[3:4] + struct.pack("<I", total) + zlib.compress(body, 9), changed
    return b"FWS" + data[3:4] + struct.pack("<I", total) + body, changed


def scrub_zip(data):
    src = zipfile.ZipFile(io.BytesIO(data))
    buf = io.BytesIO()
    changed = 0
    with zipfile.ZipFile(buf, "w") as dst:
        for info in src.infolist():
            raw = src.read(info)
            new, n = scrub_bytes(info.filename, raw)
            changed += n
            dst.writestr(info, new, compress_type=info.compress_type)
    return buf.getvalue(), changed


def scrub_binary(data):
    """Same-length overwrite for PE files (the PDB path in the debug directory)."""
    changed = 0

    def repl(m):
        nonlocal changed
        changed += 1
        name = re.split(rb"[\\/]", m.group(0))[-1]
        return name + b"\x00" * (len(m.group(0)) - len(name))

    return DRIVE_PATH.sub(repl, data), changed


def scrub_bytes(name, data):
    lower = name.lower()
    if lower.endswith(".swf"):
        return scrub_swf(data)
    if lower.endswith((".swc", ".ane", ".zip")):
        return scrub_zip(data)
    if lower.endswith((".dll", ".exe")):
        return scrub_binary(data)
    return data, 0


def leftover(data):
    if data[:3] == b"CWS":
        data = zlib.decompress(data[8:])
    elif data[:2] == b"PK":
        z = zipfile.ZipFile(io.BytesIO(data))
        return sum(leftover(z.read(n)) for n in z.namelist())
    return len(DRIVE_PATH.findall(data))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="only count paths left")
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()
    bad = 0
    for f in map(Path, a.files):
        data = f.read_bytes()
        if not a.check:
            new, n = scrub_bytes(f.name, data)
            if new != data:
                f.write_bytes(new)
            data = new
            print(f"[scrub] {f} changed={n} bytes={len(data)}")
        left = leftover(data)
        bad += left
        print(f"[scrub] {f} paths_left={left}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
