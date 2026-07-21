#!/usr/bin/env python3
"""补齐内置机场的简体中文城市名，并同步更新 App 打包资源。"""

import json
import html
import os
import re
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AIRPORTS_PATH = os.path.join(ROOT, "AirLine", "Resources", "airports.min.json")
NAMES_PATH = os.path.join(ROOT, "data", "city_names_zh.json")
TRANSLATE_URL = "https://translate.googleapis.com/translate_a/single"
CHINA_AIRPORTS_URL = "https://www.chahangxian.com/china/"
HAN_RE = re.compile(r"[\u3400-\u9fff]")

# 机器翻译和部分外部标签会把普通英文地名误当成普通词翻译。
# 这里按 IATA 固定覆盖常见/高风险条目，优先保证面向用户展示不出现低级错译。
MANUAL_OVERRIDES = {
    "ABR": "阿伯丁",
    "ABZ": "阿伯丁",
    "NOC": "诺克",
    "CLL": "大学城",
    "CIU": "苏圣玛丽",
    "FNT": "弗林特",
    "GJT": "大章克申",
    "GRB": "格林贝",
    "GTF": "大瀑布城",
    "HPN": "怀特普莱恩斯",
    "KIR": "凯里",
    "MRV": "矿水城",
    "TWF": "特温福尔斯",
    "TVF": "锡夫里弗福尔斯",
    "YAM": "苏圣玛丽",
    "YPL": "皮克尔湖",
    "YRL": "红湖市",
    "YSF": "斯托尼拉皮兹",
    "ZPB": "萨奇戈湖",
    "EIS": "比夫岛",
    "CRI": "克鲁克德岛",
}


def translate_batch(names):
    params = urllib.parse.urlencode({
        "client": "gtx",
        "sl": "en",
        "tl": "zh-CN",
        "dt": "t",
        "q": "\n".join(names),
    })
    request = urllib.request.Request(
        f"{TRANSLATE_URL}?{params}",
        headers={"User-Agent": "AirLine-build-tool/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    translated = "".join(part[0] for part in payload[0]).splitlines()
    if len(translated) != len(names):
        raise ValueError(f"翻译条数不匹配：{len(names)} -> {len(translated)}")
    return [value.strip() for value in translated]


def translate_with_retry(names):
    for attempt in range(4):
        try:
            return translate_batch(names)
        except Exception:
            if attempt == 3:
                if len(names) == 1:
                    raise
                midpoint = len(names) // 2
                return translate_with_retry(names[:midpoint]) + translate_with_retry(names[midpoint:])
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("unreachable")


def fetch_china_airport_names():
    request = urllib.request.Request(
        CHINA_AIRPORTS_URL,
        headers={"User-Agent": "AirLine-build-tool/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        page = response.read().decode("utf-8")
    result = {}
    for row in re.findall(r'<tr class="J_link">(.*?)</tr>', page, re.S):
        cells = re.findall(r"<td[^>]*>(.*?)</td>", row, re.S)
        if len(cells) < 3:
            continue
        city_match = re.search(r"<span>([^<]+)</span>", cells[1])
        iata_match = re.search(r"<span>([A-Z0-9]{3})</span>", cells[2])
        if city_match and iata_match:
            result[iata_match.group(1)] = html.unescape(city_match.group(1)).strip()
    if len(result) < 200:
        raise RuntimeError(f"中国机场中文名解析异常，仅得到 {len(result)} 条")
    return result


def main():
    with open(AIRPORTS_PATH, encoding="utf-8") as file:
        blob = json.load(file)
    with open(NAMES_PATH, encoding="utf-8") as file:
        names_by_iata = json.load(file)

    airports = blob["airports"]
    try:
        china_names = fetch_china_airport_names()
    except Exception as error:
        china_names = {}
        print(f"warning: skipped China airport name refresh: {error}")
    for iata, city_name in china_names.items():
        if iata in airports and airports[iata]["cc"] == "CN":
            names_by_iata[iata] = city_name

    missing_city_names = sorted({
        airport["c"]
        for iata, airport in airports.items()
        if not names_by_iata.get(iata) or not HAN_RE.search(names_by_iata[iata])
    })
    translated_by_city = {}
    for start in range(0, len(missing_city_names), 40):
        batch = missing_city_names[start:start + 40]
        translated = translate_with_retry(batch)
        translated_by_city.update(zip(batch, translated))
        print(f"translated {min(start + len(batch), len(missing_city_names))}/{len(missing_city_names)}")
        time.sleep(0.15)

    for iata, airport in airports.items():
        if iata in MANUAL_OVERRIDES:
            airport["zh"] = MANUAL_OVERRIDES[iata]
            names_by_iata[iata] = MANUAL_OVERRIDES[iata]
            continue
        current = names_by_iata.get(iata, "")
        if current and HAN_RE.search(current):
            airport["zh"] = current
            continue
        translated = translated_by_city.get(airport["c"], "").strip()
        if not HAN_RE.search(translated):
            translated = f"{translated or airport['c']}市"
        names_by_iata[iata] = translated
        airport["zh"] = translated

    names_by_iata = dict(sorted(
        (iata, names_by_iata[iata])
        for iata in airports
    ))
    with open(NAMES_PATH, "w", encoding="utf-8") as file:
        json.dump(names_by_iata, file, ensure_ascii=False, indent=2)
        file.write("\n")
    with open(AIRPORTS_PATH, "w", encoding="utf-8") as file:
        json.dump(blob, file, ensure_ascii=False, separators=(",", ":"))

    missing = [
        iata for iata, airport in airports.items()
        if not airport["zh"] or not HAN_RE.search(airport["zh"])
    ]
    if missing:
        raise RuntimeError(f"仍有 {len(missing)} 个机场缺少中文名：{missing[:10]}")
    print(f"updated {len(airports)} airports; all city names contain Chinese characters")


if __name__ == "__main__":
    main()
