#!/usr/bin/env python3
"""
生成城市小传撰写工作清单。

输出 tools/out/bio_worklist.tsv，按连通度降序，每行：
  iata  city  country  cc  continent  airport_name  degree  zh  top_dests  sibling_of

sibling_of 非空表示该机场与同城更大机场相距 <80km，小传由主机场复制，无需单独撰写。
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ROOT, "AirLine", "Resources", "airports.min.json")) as f:
    data = json.load(f)
aps = data["airports"]


def dist_km(a, b):
    la1, lo1 = math.radians(a["la"]), math.radians(a["lo"])
    la2, lo2 = math.radians(b["la"]), math.radians(b["lo"])
    h = (math.sin((la2 - la1) / 2) ** 2
         + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2)
    return 2 * 6371 * math.asin(min(1, math.sqrt(h)))


# 同城分组（城市名+国家一致且相距 <80km 才视为同城）
groups = {}
for iata, a in aps.items():
    groups.setdefault((a["c"].strip().lower(), a["cc"]), []).append(iata)

sibling_of = {}
for key, members in groups.items():
    if len(members) < 2:
        continue
    members.sort(key=lambda i: -len(aps[i]["r"]))
    primary = members[0]
    for m in members[1:]:
        if dist_km(aps[primary], aps[m]) < 80:
            sibling_of[m] = primary

rows = sorted(aps.items(), key=lambda kv: (-len(kv[1]["r"]), kv[0]))
out = os.path.join(ROOT, "tools", "out", "bio_worklist.tsv")
os.makedirs(os.path.dirname(out), exist_ok=True)
n_write = 0
with open(out, "w") as f:
    for iata, a in rows:
        dests = sorted(a["r"], key=lambda r: -r["k"])
        top = ";".join(f"{aps[r['d']]['c']}({r['d']})" for r in dests[:4] if r["d"] in aps)
        sib = sibling_of.get(iata, "")
        if not sib:
            n_write += 1
        f.write("\t".join([
            iata, a["c"], a["co"], a["cc"], a["ct"], a["n"],
            str(len(a["r"])), a["zh"], top, sib,
        ]) + "\n")

print(f"total={len(rows)} need_writing={n_write} siblings={len(sibling_of)}")
print(f"worklist -> {out}")
