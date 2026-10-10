#!/usr/bin/env python3
"""RPFM ile disari aktarilan building_levels tablosundan auto_build_data.lua uretir.

Kullanim:
    python3 generate_building_data.py building_levels.tsv -o auto_build_data.lua
    python3 generate_building_data.py building_levels.tsv --costs building_level_costs.tsv

RPFM: data.pack > db > building_levels_tables > sag tik > Export > TSV
"""

import argparse
import csv
import sys
from collections import defaultdict

KEY_COLUMNS = ("level_name", "key", "building_level_key", "building")
CHAIN_COLUMNS = ("building_chain", "chain", "chain_key")
LEVEL_COLUMNS = ("building_level", "level", "level_index")
COST_COLUMNS = ("cost", "construction_cost", "gold_cost", "treasury")


def find_column(header, candidates, required=True):
    lowered = [h.strip().lower() for h in header]
    for name in candidates:
        if name in lowered:
            return lowered.index(name)
    if required:
        sys.exit(f"Sutun bulunamadi: {candidates} (mevcut: {header})")
    return None


def read_tsv(path):
    """RPFM TSV'sini okur; '#' ile baslayan meta satirlarini atlar."""
    with open(path, encoding="utf-8-sig", newline="") as f:
        rows = [r for r in csv.reader(f, delimiter="\t") if r and not r[0].startswith("#")]
    if not rows:
        sys.exit(f"Bos dosya: {path}")
    return rows[0], rows[1:]


def to_number(value):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return None


def read_costs(path):
    header, rows = read_tsv(path)
    key_col = find_column(header, KEY_COLUMNS)
    cost_col = find_column(header, COST_COLUMNS)
    return {r[key_col]: to_number(r[cost_col]) for r in rows if len(r) > max(key_col, cost_col)}


def build_upgrades(header, rows, costs=None):
    key_col = find_column(header, KEY_COLUMNS)
    chain_col = find_column(header, CHAIN_COLUMNS)
    level_col = find_column(header, LEVEL_COLUMNS)
    cost_col = find_column(header, COST_COLUMNS, required=False)

    chains = defaultdict(list)
    for r in rows:
        if len(r) <= max(key_col, chain_col, level_col):
            continue
        level = to_number(r[level_col])
        if level is None:
            continue
        cost = None
        if costs and r[key_col] in costs:
            cost = costs[r[key_col]]
        elif cost_col is not None and len(r) > cost_col:
            cost = to_number(r[cost_col])
        chains[r[chain_col]].append((level, r[key_col], cost))

    upgrades = {}
    for chain, levels in chains.items():
        levels.sort()
        # Oyundaki seviye indeksi 0'dan baslayabilir; okunabilirlik icin 1'den numaralandir
        for i, (_, key, cost) in enumerate(levels):
            entry = {"level": i + 1, "chain": chain}
            if cost is not None:
                entry["cost"] = cost
            if i + 1 < len(levels):
                entry["next"] = levels[i + 1][1]
            upgrades[key] = entry
    return upgrades


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def to_lua(upgrades):
    lines = [
        "-- Otomatik uretildi: tools/generate_building_data.py",
        "-- [bina] = { next = sonraki seviye, level = seviye, cost = altin, chain = zincir }",
        "return {",
    ]
    for key in sorted(upgrades):
        e = upgrades[key]
        parts = []
        if "next" in e:
            parts.append(f"next = {lua_string(e['next'])}")
        parts.append(f"level = {e['level']}")
        if "cost" in e:
            parts.append(f"cost = {e['cost']}")
        parts.append(f"chain = {lua_string(e['chain'])}")
        lines.append(f"\t[{lua_string(key)}] = {{ {', '.join(parts)} }},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("building_levels", help="building_levels tablosunun TSV ciktisi")
    parser.add_argument("--costs", help="Maliyetler ayri tablodaysa onun TSV ciktisi (istege bagli)")
    parser.add_argument("-o", "--output", default="auto_build_data.lua")
    args = parser.parse_args()

    header, rows = read_tsv(args.building_levels)
    costs = read_costs(args.costs) if args.costs else None
    upgrades = build_upgrades(header, rows, costs)

    with open(args.output, "w", encoding="utf-8") as f:
        f.write(to_lua(upgrades))

    with_next = sum(1 for e in upgrades.values() if "next" in e)
    with_cost = sum(1 for e in upgrades.values() if "cost" in e)
    print(f"{len(upgrades)} bina yazildi ({with_next} yukseltilebilir, {with_cost} maliyetli) -> {args.output}")


if __name__ == "__main__":
    main()
