#!/usr/bin/env python3
"""
中档机场（deg≥5）小传兜底生成：保证全量覆盖。
若 data/bios/ 里已有同 IATA 的人工/agent 小传，build_bios.py 合并时以文件名排序后出现者为准；
本脚本输出 bios_mid_fallback.json（字母序靠后），仅在其它批次缺失该 IATA 时生效——
更稳妥做法：只为尚未被任何 bios_*.json 覆盖的 IATA 生成。
"""
from __future__ import annotations

import glob
import hashlib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from gen_bios_tail import COUNTRY, CONTINENT_LABEL, city_name, clean_airport, hindex  # noqa: E402


def make_mid_bio(row: dict) -> dict:
    place = city_name(row)
    cc = row.get("cc") or ""
    country_en = row.get("country") or ""
    country_zh, hook = COUNTRY.get(cc, (country_en or "当地", "区域航线正在把更多中等城市接进全球网络"))
    continent_zh = CONTINENT_LABEL.get(row.get("continent") or "", "世界")
    airport = clean_airport(row.get("airport") or "")
    deg = int(row.get("degree") or 0)
    dests = [d for d in (row.get("dests") or "").split(";") if d]
    dest_names = []
    for d in dests[:3]:
        m = re.match(r"(.+)\(([A-Z0-9]{3})\)$", d)
        dest_names.append(m.group(1) if m else d)

    tags = [
        f"{country_zh}航线上的实力派{place}",
        f"枢纽阴影外的{place}",
        f"{continent_zh}区域网络里的{place}",
        f"用{deg}条航线说话的{place}",
        f"被低估的{country_zh}起飞点",
        f"{place}：区域进出港的正经角色",
        f"首都之外的{country_zh}空中节点",
        f"把腹地送上天的{place}",
    ]
    tag = tags[hindex(row["iata"] + "mtag", len(tags))]
    if len(tag) > 20:
        tag = tag[:20]
    if len(tag) < 8:
        tag = f"{country_zh}的{place}"

    pos_opts = [
        f"{place}是{country_zh}的重要区域城市，城市规模未必能上全球榜单，却在国内分工里位置明确。",
        f"{place}位于{country_zh}，属于{continent_zh}航线网络中典型的「第二梯队」节点——服务本省/本州，也承接过境客流。",
        f"{place}是{country_zh}一座以区域连通见长的城市，机场吞吐量或许不及超级枢纽，但班次密度已经支撑日常商务与探亲。",
    ]
    pos = pos_opts[hindex(row["iata"] + "mpos", len(pos_opts))]

    mid_opts = [
        f"它的故事常常被更大都市盖过：{hook}。{place}恰好站在这条补给线上，名气不大，功能却很硬。",
        f"旅行宣传爱谈首都与网红目的地，可真正把腹地经济转起来的，往往是这类城市——{hook}。",
        f"刻板印象里它只是「路过」，本地人却靠它完成跨区域生活：{hook}。",
    ]
    mid = mid_opts[hindex(row["iata"] + "mmid", len(mid_opts))]

    facts = []
    if airport:
        facts.append(f"机场为{airport}（{row['iata']}）")
    facts.append(f"直飞连通度约{deg}条")
    if dest_names:
        facts.append("典型衔接方向包括" + "、".join(dest_names[:2]))
    end = "；".join(facts) + "。"

    body = pos + mid + end
    if len(body) > 220:
        body = body[:217] + "。"
    while len(body) < 120:
        body += f"{place}把有限的航班时刻表，过成了稳定的对外接口。"
        if len(body) > 220:
            body = body[:217] + "。"
            break
    return {"tag": tag, "body": body}


def existing_iatas() -> set[str]:
    found = set()
    for path in glob.glob(os.path.join(ROOT, "data", "bios", "*.json")):
        if os.path.basename(path) == "bios_mid_fallback.json":
            continue
        with open(path) as f:
            data = json.load(f)
        if isinstance(data, dict):
            found.update(data.keys())
    seed = os.path.join(ROOT, "data", "bios_seed.json")
    if os.path.exists(seed):
        with open(seed) as f:
            found.update(json.load(f).keys())
    return found


def main():
    batches = sorted(glob.glob(os.path.join(ROOT, "tools", "out", "bio_batches", "mid_*.json")))
    rows = []
    for p in batches:
        with open(p) as f:
            rows.extend(json.load(f))
    have = existing_iatas()
    out = {}
    for row in rows:
        if row["iata"] in have:
            continue
        out[row["iata"]] = make_mid_bio(row)
    path = os.path.join(ROOT, "data", "bios", "bios_mid_fallback.json")
    with open(path, "w") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print(f"mid fallback generated={len(out)} skipped_existing={len(rows)-len(out)} -> {path}")


if __name__ == "__main__":
    main()
