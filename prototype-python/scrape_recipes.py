"""Cào toàn bộ recipe X-Trans IV từ Fuji X Weekly → JSON cho app.

Tải trang index, lấy hết link recipe, tải từng trang, bóc block settings, chạy qua
RecipeParser, xuất ios/RecipeFlash/Resources/recipes_bundled.json.
Lịch sự: User-Agent + delay nhỏ. Ghi kèm nguồn (author + url) tôn trọng tác giả.
"""

from __future__ import annotations

import html as H
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from fuji_xs20.recipe_parser import parse

INDEX = "https://fujixweekly.com/fujifilm-x-trans-iv-recipes/"
OUT = Path(__file__).parent.parent / "ios" / "RecipeFlash" / "Resources" / "recipes_bundled.json"

UA = {"User-Agent": "Mozilla/5.0 (recipe-import; personal use)"}
FILMISH = r"(?i)^(film simulation|classic|provia|velvia|astia|acros|eterna|pro ?neg|monochrome|sepia|nostalgic|reala|standard)"
SETTING = re.compile(r"(?i)^(dynamic range|d-range|highlight|shadow|colou?r(?! chrome)|noise reduction|sharp|clarity|grain|colou?r chrome|white balance|wb|iso|exposure|toning|tone curve|" + FILMISH[5:] + ")")


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers=UA)
    return urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")


def clean_lines(html: str) -> list[str]:
    t = re.sub(r"<(script|style)[^>]*>.*?</\1>", "", html, flags=re.S)
    t = re.sub(r"<[^>]+>", "\n", t)
    t = H.unescape(t)
    return [l.strip() for l in t.splitlines() if l.strip()]


def name_from_url(url: str) -> str:
    """Tên recipe lấy từ URL slug — sạch & nhất quán. Lọc boilerplate trên slug CÓ
    dấu gạch trước khi đổi thành khoảng trắng (để bắt được 'x-t30', 'x-trans-iv'…)."""
    slug = url.rstrip("/").split("/")[-1].lower()
    for pat in [r"\bmy-", r"\bnot-my-", r"\bnot-", r"\bnew-", r"\bthe-", r"\ba-different-approach-",
                r"fujifilm-?", r"-?film-simulation", r"-?recipes?", r"-?settings?",
                r"x-?pro\d\w*", r"x-?t\d+\w*", r"x-?e\d+\w*", r"x-?h\d+\w*", r"x-?s\d+\w*",
                r"x-?a\d+\w*", r"x100\w*", r"gfx\w*", r"x-?trans-?(iv|iii|v)?",
                r"-a-for-", r"-for-fujifilm", r"-cameras?", r"part-\d+-of-\d+"]:
        slug = re.sub(pat, "-", slug)
    slug = re.sub(r"-+", " ", slug).strip()
    slug = re.sub(r"\b(a|for|cameras?|edition|yes)\b", " ", slug)
    slug = re.sub(r"^\d+\s+", " ", slug)               # bỏ số đầu (list-cruft)
    slug = re.sub(r"(?i)\s+(v|iv|iii)$", "", slug)      # bỏ v/iv/iii đuôi
    slug = re.sub(r"\s+", " ", slug).strip(" -")
    return " ".join(w if any(c.isupper() for c in w[1:]) else w.capitalize()
                    for w in slug.split()) if slug else ""


def recipe_name(html: str) -> str:
    m = re.search(r"<title>(.*?)</title>", html, re.S)
    title = H.unescape(m.group(1)).strip() if m else ""
    title = re.split(r"[–—|-]\s*FUJI X WEEKLY", title)[0]
    title = re.sub(r"(?i)\bfilm simulation recipe\b", "", title)
    title = re.sub(r"(?i)\brecipe\b", "", title)
    title = re.sub(r"(?i)\b(my|not my|new)\b", "", title)
    title = re.sub(r"(?i)fujifilm\s+x[\w.-]*", "", title)
    title = re.sub(r"(?i)x-?trans\s+iv", "", title)
    return re.sub(r"\s+", " ", title).strip(" -–—:•")


def extract_block(lines: list[str]) -> list[str] | None:
    for i, l in enumerate(lines):
        if re.match(r"(?i)^(dynamic range|d-range)\b", l) and \
           any(re.match(r"(?i)^(grain|white balance|clarity|colou?r chrome)", lines[k]) for k in range(i, min(i + 18, len(lines)))):
            block: list[str] = []
            for b in range(i - 1, max(-1, i - 4), -1):   # film sim line phía trên
                if re.match(FILMISH, lines[b]):
                    block.append(lines[b]); break
            j = i
            while j < len(lines) and (SETTING.match(lines[j]) or re.match(FILMISH, lines[j])):
                block.append(lines[j]); j += 1
            return block
    return None


def scrape_one(url: str) -> dict | None:
    html = fetch(url)
    block = extract_block(clean_lines(html))
    if not block:
        return None
    name = name_from_url(url) or recipe_name(html)
    r = parse(name + "\n" + "\n".join(block))
    if not r.get("film_simulation"):
        return None
    if name:                       # tên = URL slug (sạch, tránh trộn film sim vào tên)
        r["name"] = name
    r["author"] = "Fuji X Weekly"
    r["source"] = url
    return r


def main():
    idx = fetch(INDEX)
    urls = sorted(set(re.findall(r'href="(https?://fujixweekly\.com/\d{4}/\d{2}/\d{2}/[^"#]+)"', idx)))
    urls = [u.rstrip("/") for u in urls]
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else len(urls)
    urls = urls[:limit]
    print(f"Tong {len(urls)} link. Bat dau cao...")
    out, ok, fail = [], 0, 0
    for n, u in enumerate(urls, 1):
        try:
            rec = scrape_one(u)
            if rec and rec.get("name"):
                out.append(rec); ok += 1
            else:
                fail += 1
        except Exception:
            fail += 1
        if n % 25 == 0:
            print(f"  {n}/{len(urls)}  ok={ok} fail={fail}")
        time.sleep(0.15)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    # bỏ trùng theo tên
    seen, uniq = set(), []
    for r in out:
        key = r["name"].lower()
        if key not in seen:
            seen.add(key); uniq.append(r)
    json.dump(uniq, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(f"XONG: {len(uniq)} recipe (ok={ok} fail={fail}) -> {OUT}")


if __name__ == "__main__":
    main()
