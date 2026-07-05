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
SETTING = re.compile(r"(?i)^(dynamic range|d-range|highlight|shadow|colou?r(?! chrome)|noise reduction|high iso|sharp|clarity|grain|colou?r chrome|white balance|wb|iso|exposure|toning|tone curve|monochromatic|" + FILMISH[5:] + ")")


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


def clean_title(html: str) -> str | None:
    """Tên recipe từ og:title (fallback <title>) — TÊN CHUẨN thay cho URL slug. Xử nhiều format:
    'NAME — … Recipe' (lấy trước gạch dài); '… Recipe: NAME' (sau 'Recipe:'); '… + NAME …' (sau '+')."""
    m = re.search(r'<meta property="og:title" content="([^"]*)"', html)
    t = H.unescape(m.group(1)) if m and m.group(1).strip() else ""
    if not t:
        m = re.search(r"<title>(.*?)</title>", html, re.S)
        t = H.unescape(m.group(1)) if m else ""
    t = re.split(r"(?i)\s*\|\s*FUJI X WEEKLY", t)[0].strip()
    if re.search(r"(?i)recipes?\s*:", t):
        t = re.split(r"(?i)recipes?\s*:", t)[-1]
    else:
        t = re.split(r"\s+[–—]\s+", t)[0]
        if "+" in t:
            t = t.split("+")[-1]
    t = re.sub(r"(?i)\s*\(\s*(?:part \d+ of \d+|yes[^)]*)\)", "", t)   # bỏ cruft ngoặc "(Part 2 of 3)"/"(Yes, 7!)"
    t = re.sub(r"(?i)\bfilm simulation( recipes?)?\b", "", t)
    t = re.sub(r"(?i)\brecipes?\b", "", t)
    t = re.sub(r"(?i)\ba fujifilm\b", "", t)
    t = re.sub(r"(?i)fujifilm\s+x[\w.\-]*", "", t)
    t = re.sub(r"(?i)x100\w*|x-?pro\d\w*|x-?t\d+\w*|x-?e\d+\w*|x-?h\d+\w*|x-?s\d+\w*|x-?a\d+\w*", "", t)
    t = re.sub(r"(?i)\(?\s*x-?trans\s+(?:iv|v|iii)\s*\)?", "", t)
    t = re.sub(r"(?i)\bcameras?\b|\bfor\b|\b(?:new|my|not my)\b", "", t)
    t = re.sub(r"(?i)^\s*fujifilm\b", "", t)                            # "Fujifilm Noir" → "Noir"
    t = re.sub(r"^\s*\d{1,2}\s+", "", t)                                # bỏ số đếm đầu post gộp ("7 "), giữ năm 4 số (1960)
    t = re.sub(r"\s+", " ", t).strip(" -–—:•&,!.")
    return t or None


def sample_image(html: str) -> str | None:
    """URL ảnh mẫu: og:image (bỏ logo 'cropped-*'), đưa qua CDN i0.wp.com với ?w=800."""
    m = re.search(r'<meta property="og:image" content="([^"]+)"', html)
    url = m.group(1).strip() if m else ""
    if not url or "cropped-" in url:
        start = html.find("entry-content")
        body = html[start:] if start != -1 else html
        url = next((u for u in re.findall(
            r'https://i0\.wp\.com/fujixweekly\.com/wp-content/uploads/[^"\' ]+?\.(?:jpe?g|png)', body, re.I)
            if "cropped-" not in u), "")
        if not url:
            return None
    path = re.sub(r"^https?://(?:i0\.wp\.com/)?", "", url).split("?")[0].split("#")[0]
    return f"https://i0.wp.com/{path}?w=800"


def extract_block(lines: list[str]) -> list[str] | None:
    for i, l in enumerate(lines):
        if re.match(r"(?i)^(dynamic range|d-range)\b", l) and \
           any(re.match(r"(?i)^(grain|white balance|clarity|colou?r chrome|noise reduction)", lines[k])
               for k in range(max(0, i - 10), min(i + 18, len(lines)))):
            top = i                                    # quét LÊN: gom Film Sim/Grain/Color Chrome đứng TRƯỚC DR
            while top - 1 >= 0 and (SETTING.match(lines[top - 1]) or re.match(FILMISH, lines[top - 1])):
                top -= 1
            bot = i                                    # quét XUỐNG
            while bot < len(lines) and (SETTING.match(lines[bot]) or re.match(FILMISH, lines[bot])):
                bot += 1
            block = lines[top:bot]
            if not any(re.match(FILMISH, x) for x in block):   # film sim bị tách trên (vd dòng Toning chen) → tìm thêm
                for b in range(top - 1, max(-1, top - 12), -1):
                    if re.match(FILMISH, lines[b]):
                        block = [lines[b]] + block; break
            return block
    return None


def scrape_one(url: str) -> dict | None:
    html = fetch(url)
    block = extract_block(clean_lines(html))
    if not block:
        return None
    name = clean_title(html) or name_from_url(url)
    r = parse((name or "") + "\n" + "\n".join(block))
    if not r.get("film_simulation"):
        return None
    if name:                       # tên = tiêu đề trang (chuẩn), không dùng slug
        r["name"] = name
    r["author"] = "Fuji X Weekly"
    r["source"] = url
    r["sample_image"] = sample_image(html)
    return r


RECIPE_HREF = re.compile(r'href="(https?://fujixweekly\.com/\d{4}/\d{2}/\d{2}/[^"#?]+)"')


def _norm_url(u: str) -> str:
    return u.split("#")[0].split("?")[0].rstrip("/").lower()


def index_urls(idx: str) -> list[str]:
    """URL recipe theo ĐÚNG thứ tự xuất hiện trong nội dung chính của trang index
    (cắt sidebar/related/footer), dedupe giữ lần đầu. Đây là 'thứ tự web' người dùng muốn."""
    start = idx.find("entry-content")
    body = idx[start:] if start != -1 else idx
    for marker in ('class="entry-footer"', 'id="comments"', 'class="sharedaddy"', 'id="jp-post-flair"'):
        cut = body.find(marker)
        if cut != -1:
            body = body[:cut]
            break
    seen, urls = set(), []
    for u in RECIPE_HREF.findall(body):
        u = u.rstrip("/")
        if _norm_url(u) not in seen:
            seen.add(_norm_url(u))
            urls.append(u)
    if not urls or "kodachrome" not in urls[0].lower() or not (120 <= len(urls) <= 320):
        print(f"[CANH BAO] index_urls: {len(urls)} link, dau={urls[0] if urls else None!r} "
              f"— cau truc trang co the khac, kiem tra moc cat.")
    return urls


def reorder_existing():
    """Sắp lại recipes_bundled.json theo thứ tự trang index (dựa field 'source'),
    KHÔNG cào lại từng trang. URL không khớp → dồn về cuối (giữ tương đối, không xoá)."""
    idx = fetch(INDEX)
    order = {_norm_url(u): i for i, u in enumerate(index_urls(idx))}
    data = json.load(open(OUT, encoding="utf-8"))
    BIG = len(order) + len(data)
    rank = lambda r: order.get(_norm_url(r.get("source") or ""), BIG)
    data.sort(key=rank)   # sort ổn định → phần không khớp giữ nguyên thứ tự, nằm cuối
    json.dump(data, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    unmatched = [r["name"] for r in data if rank(r) == BIG]
    print(f"XONG reorder: {len(data)} recipe -> {OUT}")
    print(f"  10 dau : {[r['name'] for r in data[:10]]}")
    print(f"  Unmatched (don cuoi): {len(unmatched)} -> {unmatched[:12]}")


def main():
    idx = fetch(INDEX)
    urls = index_urls(idx)   # theo thứ tự trang (KHÔNG sort theo ngày như trước)
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
    if "--reorder" in sys.argv:
        reorder_existing()     # chỉ sắp lại JSON có sẵn theo thứ tự web (nhanh, không cào lại)
    else:
        main()
