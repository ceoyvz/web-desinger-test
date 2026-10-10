#!/usr/bin/env python3
"""Testleri Lua 5.1 ile calistirir (Attila'nin Lua surumu). Gereksinim: pip install lupa"""

import os
import subprocess
import sys
import tempfile

from lupa import lua51

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SCRIPT_DIR = os.path.join(ROOT, "pack", "campaign", "main_attila")


def run_lua_tests():
    lua = lua51.LuaRuntime()
    lua.execute(f'package.path = "{SCRIPT_DIR}/?.lua;" .. package.path')
    with open(os.path.join(HERE, "test_auto_build.lua"), encoding="utf-8") as f:
        return int(lua.execute(f.read()))


def run_generator_test():
    tsv = (
        "#building_levels_tables;12\n"
        "level_name\tbuilding_chain\tbuilding_level\tcost\n"
        "farm_b\tfarm\t1\t900\n"
        "farm_a\tfarm\t0\t400\n"
        "temple_a\ttemple\t0\t300\n"
    )
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "levels.tsv")
        out = os.path.join(tmp, "auto_build_data.lua")
        with open(src, "w", encoding="utf-8") as f:
            f.write(tsv)
        subprocess.run(
            [sys.executable, os.path.join(ROOT, "tools", "generate_building_data.py"), src, "-o", out],
            check=True,
        )
        lua = lua51.LuaRuntime()
        with open(out, encoding="utf-8") as f:
            data = lua.execute(f.read())
    ok = (
        data["farm_a"]["next"] == "farm_b"
        and data["farm_a"]["level"] == 1
        and data["farm_b"]["cost"] == 900
        and data["farm_b"]["next"] is None
        and data["temple_a"]["next"] is None
    )
    print("Uretec testi:", "gecti" if ok else "BASARISIZ")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(1 if run_lua_tests() + run_generator_test() else 0)
