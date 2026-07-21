#!/usr/bin/env python3
"""
AirLine 构建期数据管线。

输入:
  data/airline_routes.json          — Jonty/airline-route-data 周更快照
  /tmp/ne_50m_land.geojson          — Natural Earth 1:50m 陆地多边形
  data/city_names_zh.json           — 手工维护的 IATA→中文城市名映射（可选）

输出 (App 打包资源):
  AirLine/Resources/airports.min.json    — 精简机场+航线图
  AirLine/Resources/world_land.min.json  — 简化陆地轮廓 (量化坐标)
  tools/out/top_cities.txt               — 连通度 Top500 城市清单（供撰写中文名/审核用）
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "AirLine", "Resources")
OUT = os.path.join(ROOT, "tools", "out")
os.makedirs(RES, exist_ok=True)
os.makedirs(OUT, exist_ok=True)


def build_airports():
    with open(os.path.join(ROOT, "data", "airline_routes.json")) as f:
        raw = json.load(f)

    zh_path = os.path.join(ROOT, "data", "city_names_zh.json")
    zh = {}
    if os.path.exists(zh_path):
        with open(zh_path) as f:
            zh = json.load(f)

    carriers = {}  # code -> name (global dedup table)
    airports = {}
    for iata, a in raw.items():
        if a.get("latitude") is None or a.get("longitude") is None:
            continue
        routes = a.get("routes") or []
        rows = []
        for r in routes:
            dest = r.get("iata")
            km = r.get("km")
            mins = r.get("min")
            if not dest or dest not in raw or not km or not mins:
                continue
            if mins < 20 or km < 30:  # 数据噪声
                continue
            codes = []
            for c in (r.get("carriers") or [])[:4]:
                code, name = c.get("iata"), c.get("name")
                if not code or not name:
                    continue
                carriers.setdefault(code, name)
                codes.append(code)
            if not codes:
                continue
            rows.append({"d": dest, "k": km, "m": mins, "c": codes})
        airports[iata] = {
            "n": a["name"],
            "c": a["city_name"],
            "zh": zh.get(iata, ""),
            "co": a["country"] or "",
            "cc": a["country_code"] or "",
            "ct": a["continent"] or "",
            "la": round(float(a["latitude"]), 4),
            "lo": round(float(a["longitude"]), 4),
            "tz": a["timezone"] or "UTC",
            "r": rows,
        }

    # 剔除完全孤立的机场（无出入港航线）
    has_inbound = set()
    for a in airports.values():
        for r in a["r"]:
            has_inbound.add(r["d"])
    keep = {i for i, a in airports.items() if a["r"] or i in has_inbound}
    airports = {i: a for i, a in airports.items() if i in keep}
    for a in airports.values():
        a["r"] = [r for r in a["r"] if r["d"] in airports]

    out = {"carriers": carriers, "airports": airports}
    p = os.path.join(RES, "airports.min.json")
    with open(p, "w") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    n_routes = sum(len(a["r"]) for a in airports.values())
    print(f"airports.min.json: {len(airports)} airports, {n_routes} routes, "
          f"{len(carriers)} carriers, {os.path.getsize(p)/1e6:.1f} MB")

    # Top500 连通度城市清单（撰写中文名用）
    deg = sorted(airports.items(), key=lambda kv: -len(kv[1]["r"]))
    with open(os.path.join(OUT, "top_cities.txt"), "w") as f:
        for iata, a in deg[:500]:
            f.write(f"{iata}\t{a['c']}\t{a['co']}\t{len(a['r'])}\t{a['zh']}\n")
    missing = sum(1 for i, a in deg[:300] if not a["zh"])
    print(f"top300 缺中文名: {missing}")


def ring_area(ring):
    s = 0.0
    for i in range(len(ring) - 1):
        x1, y1 = ring[i]
        x2, y2 = ring[i + 1]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2.0


def simplify(ring, tol):
    """Douglas–Peucker（迭代实现，度为单位）"""
    if len(ring) < 5:
        return ring
    keep = [False] * len(ring)
    keep[0] = keep[-1] = True
    stack = [(0, len(ring) - 1)]
    while stack:
        a, b = stack.pop()
        if b <= a + 1:
            continue
        ax, ay = ring[a]
        bx, by = ring[b]
        dx, dy = bx - ax, by - ay
        norm = math.hypot(dx, dy)
        dmax, imax = -1.0, -1
        for i in range(a + 1, b):
            px, py = ring[i]
            if norm == 0:
                d = math.hypot(px - ax, py - ay)
            else:
                d = abs(dy * px - dx * py + bx * ay - by * ax) / norm
            if d > dmax:
                dmax, imax = d, i
        if dmax > tol:
            keep[imax] = True
            stack.append((a, imax))
            stack.append((imax, b))
    return [p for p, k in zip(ring, keep) if k]


def build_land():
    with open("/tmp/ne_50m_land.geojson") as f:
        gj = json.load(f)
    rings = []
    for feat in gj["features"]:
        geom = feat["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        for poly in polys:
            outer = poly[0]  # 忽略内环（湖泊在暗色风格里不需要）
            if ring_area(outer) < 0.03:  # 过滤 ~小于 300km² 的碎岛
                continue
            s = simplify(outer, 0.02)
            if len(s) < 4:
                continue
            rings.append([[round(x, 2), round(y, 2)] for x, y in s])
    p = os.path.join(RES, "world_land.min.json")
    with open(p, "w") as f:
        json.dump(rings, f, separators=(",", ":"))
    npts = sum(len(r) for r in rings)
    print(f"world_land.min.json: {len(rings)} rings, {npts} points, "
          f"{os.path.getsize(p)/1e6:.2f} MB")


if __name__ == "__main__":
    build_airports()
    build_land()
