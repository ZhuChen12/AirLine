#!/usr/bin/env python3
"""
合并 data/bios/*.json（+ 种子范文）→ AirLine/Resources/city_bios.json

- 校验：每条必须含非空 tag/body；IATA 必须存在于 airports.min.json
- 同城副机场（worklist 的 sibling_of）自动复制主机场小传
- 报告：尚未覆盖的机场清单写入 tools/out/bio_missing.tsv（按度降序）

用法:
  python3 tools/build_bios.py            # 合并 + 报告
  python3 tools/build_bios.py --next 80  # 输出接下来 80 个待写机场（给撰写者）
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ROOT, "AirLine", "Resources", "airports.min.json")) as f:
    aps = json.load(f)["airports"]

# sibling 映射来自 worklist
siblings = {}
wl_rows = []
with open(os.path.join(ROOT, "tools", "out", "bio_worklist.tsv")) as f:
    for line in f:
        p = line.rstrip("\n").split("\t")
        wl_rows.append(p)
        if p[9]:
            siblings[p[0]] = p[9]

bios = {}
dup = []
for path in sorted(glob.glob(os.path.join(ROOT, "data", "bios", "*.json"))):
    with open(path) as f:
        batch = json.load(f)
    for iata, b in batch.items():
        if iata not in aps:
            print(f"!! {os.path.basename(path)}: 未知 IATA {iata}")
            sys.exit(1)
        if not b.get("tag") or not b.get("body"):
            print(f"!! {os.path.basename(path)}: {iata} tag/body 为空")
            sys.exit(1)
        if iata in bios:
            dup.append(iata)
        bios[iata] = {"tag": b["tag"].strip(), "body": b["body"].strip()}

# 种子范文优先级最高（人工校对过的口径）
seed_path = os.path.join(ROOT, "data", "bios_seed.json")
if os.path.exists(seed_path):
    with open(seed_path) as f:
        for iata, b in json.load(f).items():
            if iata in aps:
                bios[iata] = b

# 同城回填
filled = 0
for sub, primary in siblings.items():
    if sub not in bios and primary in bios:
        bios[sub] = bios[primary]
        filled += 1

missing = [p for p in wl_rows if p[0] not in bios]
out_missing = os.path.join(ROOT, "tools", "out", "bio_missing.tsv")
with open(out_missing, "w") as f:
    for p in missing:
        f.write("\t".join(p) + "\n")

if "--next" in sys.argv:
    n = int(sys.argv[sys.argv.index("--next") + 1])
    for p in missing[:n]:
        zh = f" zh={p[7]}" if p[7] else ""
        sib = " [sibling]" if p[9] else ""
        print(f"{p[0]}\t{p[1]}, {p[2]} ({p[4]}) deg={p[6]}{zh} dests={p[8]}{sib}")
    sys.exit(0)

out = os.path.join(ROOT, "AirLine", "Resources", "city_bios.json")
with open(out, "w") as f:
    json.dump(bios, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)

lens = sorted(len(b["body"]) for b in bios.values())
print(f"covered={len(bios)}/{len(aps)} (sibling 回填 {filled}, 重复覆盖 {len(dup)})")
print(f"missing={len(missing)} -> {out_missing}")
if lens:
    print(f"body 长度 min={lens[0]} med={lens[len(lens)//2]} max={lens[-1]}")
print(f"打包 -> {out} ({os.path.getsize(out)/1e6:.2f} MB)")
