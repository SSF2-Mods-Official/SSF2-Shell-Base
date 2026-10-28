"""Checks StudioHomeStages.homeStageFor against the JSON embedded in that class."""
import json
import re
import pathlib

SRC = pathlib.Path(__file__).resolve().parents[1] / "src" / "com" / "sbxmod" / "paletteMaker" / "StudioHomeStages.as"
text = SRC.read_text(encoding="utf-8")
m = re.search(r"HOME_JSON:String =\s*(.*?);", text, re.S)
if not m:
    raise SystemExit("HOME_JSON string not found")
parts = re.findall(r"'([^']*)'", m.group(1))
data = json.loads("".join(parts))

def home_stage_for(name, data):
    if not name:
        return ""
    stages = data.get("stages") or {}
    if stages.get(name):
        return stages[name]
    vanilla = data.get("vanilla") or []
    leftovers = data.get("leftovers") or []
    if name not in vanilla:
        return ""
    idx = vanilla.index(name)
    missing = 0
    for i in range(idx):
        if not stages.get(vanilla[i]):
            missing += 1
    if missing >= len(leftovers):
        return "restarea"
    return leftovers[missing]

expect = {
    "mario": "kingdom1",
    "luigi": "kingdom2",
    "peach": "galaxytours",
    "bowser": "mushroomkingdom3",
    "waluigi": "emeraldcave",
    "link": "hyrulecastle64",
    "zelda": "hylianskies",
    "sheik": "hyruletemple",
    "ganondorf": "palaceoftwilight",
    "pikachu": "saffroncity",
    "pichu": "lakeofrage",
    "jigglypuff": "pokemoncolosseum",
    "lucario": "snowpointtemple",
    "kirby": "dreamland",
    "dedede": "dededearena",
    "metaknight": "butterbuilding",
    "bandanadee": "rainbowroute",
    "fox": "sectorz",
    "falco": "meteovoyage",
    "krystal": "krazoapalace",
    "samus": "phase8",
    "zamus": "crateria",
    "captainfalcon": "sandocean",
    "sonic": "greenhillzone",
    "tails": "casinonightzone",
    "sora": "theworldthatneverwas",
    "naruto": "konohavillage",
    "sandbag": "restarea",
    "yoshi": "yoshisstory",
    "wario": "warioware",
}
for name, stage in expect.items():
    got = home_stage_for(name, data)
    if got != stage:
        raise SystemExit(name + " got " + got + " wanted " + stage)
seen = {}
for name in data["vanilla"]:
    got = home_stage_for(name, data)
    if not got:
        raise SystemExit("missing " + name)
    if got in seen:
        raise SystemExit(name + " shares " + got + " with " + seen[got])
    seen[got] = name
if home_stage_for("custommod", data) != "":
    raise SystemExit("custom")
# A vanilla id removed from the series map gets its own leftover, not a series stage.
stripped = json.loads(json.dumps(data))
del stripped["stages"]["tails"]
got = home_stage_for("tails", stripped)
if got in stripped["stages"].values() or not got:
    raise SystemExit("leftover " + str(got))
print("OK")
