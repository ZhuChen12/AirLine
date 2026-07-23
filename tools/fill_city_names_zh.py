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
    "ABB": "阿萨巴",
    "ABR": "阿伯丁",
    "ABZ": "阿伯丁",
    "AIA": "阿莱恩斯",
    "AJI": "阿勒",
    "APD": "瓦坦波内",
    "APO": "阿帕尔塔多",
    "AXP": "斯普林波因特",
    "BIH": "毕晓普",
    "BYO": "博尼图",
    "CKX": "奇金",
    "NOC": "诺克",
    "CLL": "大学城",
    "CIU": "苏圣玛丽",
    "CDB": "科尔德贝",
    "CDC": "锡达城",
    "CEC": "克雷森特城",
    "CSK": "斯基灵角",
    "CXY": "卡特礁",
    "DAV": "戴维",
    "DLE": "多勒",
    "DSE": "德西",
    "EAA": "伊格尔",
    "ELI": "伊利姆",
    "EQS": "埃斯克尔",
    "ESD": "伊斯特桑德",
    "EUQ": "安蒂克",
    "EWE": "埃韦尔",
    "FDE": "弗勒",
    "FNT": "弗林特",
    "GJT": "大章克申",
    "GCK": "加登城",
    "GCW": "皮奇斯普林斯",
    "GRB": "格林贝",
    "GTF": "大瀑布城",
    "GXF": "塞云",
    "HAS": "哈伊勒",
    "HNM": "哈纳",
    "HOT": "温泉城",
    "HPN": "怀特普莱恩斯",
    "IMP": "因佩拉特里斯",
    "IUI": "伊纳苏伊特",
    "IWD": "艾恩伍德",
    "JAU": "豪哈",
    "KAA": "卡萨马",
    "KAE": "凯克",
    "KAZ": "卡奥",
    "KBH": "卡哈马",
    "KIR": "凯里",
    "LAQ": "贝达",
    "LIO": "利蒙",
    "LOD": "隆加纳",
    "MFK": "马祖",
    "MJC": "曼",
    "MOB": "莫比尔",
    "MFA": "马菲亚岛",
    "MRV": "矿水城",
    "MUM": "穆利",
    "MXV": "木伦",
    "NNT": "难府",
    "OAG": "奥兰治",
    "OCC": "科卡",
    "PEE": "彼尔姆",
    "PGA": "佩吉",
    "PIZ": "波因特莱",
    "RIY": "里扬",
    "SIS": "锡申",
    "STC": "圣克劳德",
    "TEI": "特祖",
    "TME": "塔梅",
    "TRM": "瑟默尔",
    "TUF": "图尔",
    "TTA": "坦坦",
    "TWF": "特温福尔斯",
    "TVF": "锡夫里弗福尔斯",
    "VAN": "凡城",
    "WWP": "惠尔帕斯",
    "WZA": "瓦城",
    "WMO": "怀特芒廷",
    "XAU": "索尔",
    "XMY": "亚姆岛",
    "YAM": "苏圣玛丽",
    "YGG": "甘吉斯",
    "YIO": "庞德因莱特",
    "YOJ": "海莱沃",
    "YPL": "皮克尔湖",
    "YRB": "雷索卢特",
    "YRG": "里戈莱特",
    "YRL": "红湖市",
    "YSF": "斯托尼拉皮兹",
    "YTL": "大鳟鱼湖",
    "YUT": "纳奥亚特",
    "YYR": "古斯贝",
    "YZP": "桑兹皮特",
    "YZZ": "特雷尔",
    "ZEM": "伊斯特梅恩",
    "ZPB": "萨奇戈湖",
    "ZRJ": "韦加莫湖",
    "EIS": "比夫岛",
    "CRI": "克鲁克德岛",
}

FORBIDDEN_LITERAL_TRANSLATIONS = {
    "骨", "浅羽", "联盟", "农业", "公寓", "泉点", "鸡", "鹰", "花", "考", "松", "南",
    "手机", "白痴", "男人", "货车", "页面", "烫发", "橙色", "古董", "内衣", "旅游",
    "热学", "驯服", "鲸鱼通道", "佤族", "山药岛", "池塘入口", "高水平", "坚决",
    "弄臣", "踪迹", "东大街",
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
    literal = [
        (iata, airport["c"], airport["zh"])
        for iata, airport in airports.items()
        if airport["zh"] in FORBIDDEN_LITERAL_TRANSLATIONS
    ]
    if literal:
        raise RuntimeError(f"仍有普通词误译：{literal[:10]}")
    print(f"updated {len(airports)} airports; all city names contain Chinese characters")


if __name__ == "__main__":
    main()
