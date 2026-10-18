#!/usr/bin/env python3
"""Packs data/raw/<id>.json (mainnet CITADEL metadata) into data/citadel-traits.bin for CitadelNFT.setTraits.

Each CITADEL is 6 bytes: generation, sekt, shield, engine, weapon, tech.
Enum order must match src/lib/Traits.sol.

Fetch the raw metadata first (slowly; the Pinata gateway rate-limits):
  for i in $(seq 0 1023); do curl -sL "https://gateway.pinata.cloud/ipfs/QmXXC2PHUeiFtUFVdLNnYodWUNdZnK2jbT8prE6R51mGT6/$i" -o data/raw/$i.json; sleep 0.5; done
"""
import json, pathlib, sys

SEKT = ["RELIK", "DROTH XYL", "IONSLAUGHT", "ELEKT"]
SHIELD = ["DAG SGIATH", "XZCID MAGH", "TELUM RATIO", "UNGARDROTHH", "DSGRILL RATIO", "DASKENWAFT", "MYSTERIUM", "MARBHADH GREINE"]
ENGINE = ["HAG GOTOR", "CHOBAKK", "TELUM MAK", "STROGOTHT", "FULTACHT MAK", "GLUASAD", "DSGILL MAK", "DREADNAUGHT"]
WEAPON = ["RRAKATAKHT FUROR", "AG HALMAHHER", "TELUM FUROR", "HALMAHHER FUROR", "DAG VERSTACKT", "VEERDACHT MAGH", "MARBHADH GHXST", "DEI IUDICIUM"]
TECH = ["PRESERVATIVE ALGORITHMS", "MILITANT ALGORITHMS", "ANTIMATTER ANNIHILATION", "PROPULSION", "POSTHUMANISM", "ECOLOGICAL EXTRACTION", "TECHNOCRACY", "PROGINATOR PSI"]

root = pathlib.Path(__file__).resolve().parent.parent / "data"
out, table = bytearray(), {}
for i in range(1024):
    try:
        a = {x["trait_type"]: x["value"] for x in json.loads((root / "raw" / f"{i}.json").read_text())["attributes"]}
        rec = [int(a["GENERATION"]), SEKT.index(a["SEKT"]), SHIELD.index(a["SHIELD"]), ENGINE.index(a["ENGINE"]),
               WEAPON.index(a["WEAPONS"]), TECH.index(a["TECH"])]
    except Exception as e:
        sys.exit(f"CITADEL {i}: {e!r} — re-download data/raw/{i}.json")
    out += bytes(rec)
    table[i] = a
(root / "citadel-traits.bin").write_bytes(out)
(root / "citadel-traits.json").write_text(json.dumps(table, indent=1))
print(f"packed {len(out) // 6} CITADEL -> data/citadel-traits.bin")
