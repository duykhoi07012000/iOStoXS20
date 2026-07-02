"""Parse text recipe kiểu Fuji X Weekly → dict recipe chuẩn hoá.

Bản tham chiếu Python (test được cục bộ) để chốt logic trước khi port sang Swift
(RecipeParser.swift). Trả về dict với tên enum khớp FujiKit + số + notes.

Chịu được các ca thực tế: tên recipe đứng trước tên film sim, film sim xuống dòng
("Classic"/"Negative"), decimal kiểu châu Âu ("+2,5"), lỗi OCR ("t1 Red"=+1), nhiễu
ký tự lạ ("の"), header ghép ("NOISE REDUCTION/HIGH ISO NR").
"""

from __future__ import annotations

import re
import unicodedata

# --- Header: (các alias CHÍNH XÁC sau chuẩn hoá, field key). Thứ tự: cụ thể → chung.
_HEADERS: list[tuple[list[str], str]] = [
    (["FILM SIMULATION", "FILM SIM"], "film"),
    (["DYNAMIC RANGE", "D RANGE", "DR"], "dr"),
    (["GRAIN EFFECT", "GRAIN"], "grain"),
    (["COLOR CHROME EFFECT BLUE", "COLOR CHROME FX BLUE", "COLOR CHROME BLUE",
      "COLOUR CHROME FX BLUE"], "cc_blue"),
    (["COLOR CHROME EFFECT", "COLOR CHROME FX", "COLOR CHROME", "COLOUR CHROME"], "cc_effect"),
    (["WHITE BALANCE", "WB"], "wb"),
    (["HIGHLIGHT TONE", "HIGHLIGHT", "HIGH LIGHT"], "highlight"),
    (["SHADOW TONE", "SHADOW"], "shadow"),
    (["SHARPNESS", "SHARPENING"], "sharpness"),
    (["NOISE REDUCTION/HIGH ISO NR", "NOISE REDUCTION", "HIGH ISO NR", "NR"], "nr"),
    (["CLARITY"], "clarity"),
    (["COLOR", "COLOUR"], "color"),
    (["ISO"], "iso"),
    (["EXPOSURE COMPENSATION", "EXP COMPENSATION", "EXP. COMPENSATION", "EXP COMP", "EV"], "exp_comp"),
]

# --- Film simulation aliases → tên enum FujiKit. Dài trước (greedy đúng).
_FILM: list[tuple[str, str]] = [
    ("ETERNA BLEACH BYPASS", "eternaBleachBypass"),
    ("BLEACH BYPASS", "eternaBleachBypass"),
    ("ETERNA CINEMA", "eterna"), ("ETERNA", "eterna"),
    ("CLASSIC NEGATIVE", "classicNeg"), ("CLASSIC NEG", "classicNeg"),
    ("NOSTALGIC NEGATIVE", "nostalgicNeg"), ("NOSTALGIC NEG", "nostalgicNeg"),
    ("CLASSIC CHROME", "classicChrome"),
    ("PRO NEG HI", "proNegHi"), ("PRO NEG. HI", "proNegHi"), ("PRONEG HI", "proNegHi"),
    ("PRO NEG STD", "proNegStd"), ("PRO NEG. STD", "proNegStd"),
    ("REALA ACE", "realaAce"), ("REALA", "realaAce"),
    ("ACROS+YE", "acrosYe"), ("ACROS+R", "acrosR"), ("ACROS+G", "acrosG"), ("ACROS", "acros"),
    ("MONOCHROME+YE", "monochromeYe"), ("MONOCHROME+R", "monochromeR"),
    ("MONOCHROME+G", "monochromeG"), ("MONOCHROME", "monochrome"),
    ("PROVIA/STANDARD", "provia"), ("PROVIA", "provia"), ("STANDARD", "provia"),
    ("VELVIA/VIVID", "velvia"), ("VELVIA", "velvia"),
    ("ASTIA/SOFT", "astia"), ("ASTIA", "astia"),
    ("SEPIA", "sepia"),
]

_WB_MODE: list[tuple[str, str]] = [
    ("COLOR TEMPERATURE", "colorTemp"), ("COLOUR TEMPERATURE", "colorTemp"), ("KELVIN", "colorTemp"),
    ("AUTO WHITE PRIORITY", "autoWhitePriority"), ("WHITE PRIORITY", "autoWhitePriority"),
    ("AUTO AMBIENCE", "autoAmbiencePriority"), ("AMBIENCE", "autoAmbiencePriority"),
    ("DAYLIGHT", "daylight"), ("SHADE", "shade"),
    ("INCANDESCENT", "incandescent"), ("UNDERWATER", "underwater"),
    ("FLUORESCENT 1", "fluorescent1"), ("FLUORESCENT 2", "fluorescent2"),
    ("FLUORESCENT 3", "fluorescent3"),
    ("AUTO", "auto"),
]

_NR_MAP = {-4: "m4", -3: "m3", -2: "m2", -1: "m1", 0: "std", 1: "p1", 2: "p2", 3: "p3", 4: "p4"}


def _norm(s: str) -> str:
    s = unicodedata.normalize("NFKC", s).upper().strip()
    s = re.sub(r"[：:]+$", "", s).strip()          # bỏ ':' cuối
    s = re.sub(r"\s+", " ", s)
    return s


def _match_header(line: str) -> str | None:
    n = _norm(line)
    for aliases, key in _HEADERS:
        if n in aliases:
            return key
    return None


def _num(s: str):
    """Số đầu tiên trong s, hỗ trợ dấu và decimal ',' hoặc '.'. None nếu không có."""
    m = re.search(r"[+-]?\d+(?:[.,]\d+)?", s)
    if not m:
        return None
    v = float(m.group().replace(",", "."))
    return int(v) if v == int(v) else v


def _clean_name(s: str) -> str:
    # bỏ ký tự không phải chữ Latin/số/space (nhiễu OCR như 'の'), gọn khoảng trắng
    s = "".join(ch for ch in s if ch.isascii() or ch.isspace())
    return re.sub(r"\s+", " ", s).strip(" -–—:·")


def parse(text: str) -> dict:
    # 1) tách section theo header; lines trước header đầu = preamble (tên recipe kiểu tiêu đề)
    sections: dict[str, list[str]] = {}
    preamble: list[str] = []
    current: str | None = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        key = _match_header(line)
        if key:
            current = key
            sections.setdefault(key, [])
        elif current:
            sections[current].append(line)
        else:
            preamble.append(line)

    out: dict = {"name": None, "notes": {}}

    # 2) FILM SIMULATION + tên recipe (giữ nguyên hoa/thường của tên)
    if "film" in sections:
        orig = " ".join(sections["film"])
        norm = _norm(orig)
        film, alias_found, idx = None, None, -1
        for alias, enum in _FILM:
            p = norm.rfind(alias)           # ưu tiên xuất hiện CUỐI (film sim đứng sau tên)
            if p != -1 and p >= idx:
                film, alias_found, idx = enum, alias, p
        out["film_simulation"] = film
        if alias_found:
            pat = re.compile(r"\s+".join(re.escape(w) for w in alias_found.split(" ")), re.I)
            matches = list(pat.finditer(orig))
            if matches:
                out["name"] = _clean_name(orig[:matches[-1].start()]) or None

    # tên kiểu tiêu đề đứng đầu (nếu section film không cho tên)
    if not out["name"] and preamble:
        out["name"] = _clean_name(" ".join(preamble)) or None

    # 3) DR
    if "dr" in sections:
        t = _norm(" ".join(sections["dr"]))
        if "AUTO" in t:
            out["dynamic_range"] = "auto"
        else:
            n = _num(t)
            out["dynamic_range"] = {100: "dr100", 200: "dr200", 400: "dr400"}.get(int(n)) if n else None

    # 4) GRAIN
    if "grain" in sections:
        t = _norm(" ".join(sections["grain"]))
        if "OFF" in t:
            out["grain"] = "offLarge" if "LARGE" in t else "off"
        else:
            strong = "STRONG" in t
            large = "LARGE" in t
            out["grain"] = {(False, False): "weakSmall", (True, False): "strongSmall",
                            (False, True): "weakLarge", (True, True): "strongLarge"}[(strong, large)]

    # 5) COLOR CHROME EFFECT / BLUE
    def _chrome(t: str) -> str:
        t = _norm(t)
        if "STRONG" in t: return "strong"
        if "WEAK" in t: return "weak"
        return "off"
    if "cc_effect" in sections:
        out["color_chrome_effect"] = _chrome(" ".join(sections["cc_effect"]))
    if "cc_blue" in sections:
        out["color_chrome_blue"] = _chrome(" ".join(sections["cc_blue"]))

    # 6) WB: mode + kelvin + shift R/B
    if "wb" in sections:
        t = _norm(" ".join(sections["wb"]))
        km = re.search(r"(\d{4,5})\s*K", t)
        if km:
            out["wb_kelvin"] = int(km.group(1))
            out["white_balance"] = "colorTemp"
        else:
            for alias, enum in _WB_MODE:
                if alias in t:
                    out["white_balance"] = enum
                    break
        mr = re.search(r"([+-]?\d+)\s*RED", t) or re.search(r"RED\s*([+-]?\d+)", t)
        mb = re.search(r"([+-]?\d+)\s*BLUE", t) or re.search(r"BLUE\s*([+-]?\d+)", t)
        if mr: out["wb_shift_red"] = int(mr.group(1))
        if mb: out["wb_shift_blue"] = int(mb.group(1))

    # 7) tones / color / sharp / clarity
    for key, field in [("highlight", "highlight_tone"), ("shadow", "shadow_tone")]:
        if key in sections:
            out[field] = _num(" ".join(sections[key]))
    for key, field in [("color", "color"), ("sharpness", "sharpness"), ("clarity", "clarity")]:
        if key in sections:
            n = _num(" ".join(sections[key]))
            out[field] = int(n) if n is not None else None

    # 8) NR số → enum
    if "nr" in sections:
        n = _num(" ".join(sections["nr"]))
        if n is not None:
            out["noise_reduction"] = _NR_MAP.get(int(n))

    # 9) ISO / EXP COMP → notes
    if "iso" in sections:
        out["notes"]["iso"] = " ".join(sections["iso"]).strip()
    if "exp_comp" in sections:
        out["notes"]["exposure_compensation"] = " ".join(sections["exp_comp"]).strip()

    return out
