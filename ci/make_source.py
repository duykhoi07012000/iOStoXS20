"""Sinh apps.json (AltStore/SideStore source) từ biến môi trường VER, SIZE.

Dùng trong CI sau khi đóng gói .ipa (xem .github/workflows/ci.yml). Ghi ra đường dẫn
argv[1] (mặc định 'apps.json'). Người dùng thêm URL source vào SideStore để cài +
auto-update 1 chạm, khỏi tải .ipa tay (tránh lỗi 'data isn't in the correct format').
"""
import datetime
import json
import os
import sys

REPO = "duykhoi07012000/iOStoXS20"
VER = os.environ.get("VER", "1.0.0")
SIZE = int(os.environ.get("SIZE", "0"))
NOW = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
IPA = f"https://github.com/{REPO}/releases/download/latest/RecipeFlash-unsigned.ipa"
ICON = f"https://raw.githubusercontent.com/{REPO}/main/docs_UI/appicon.png"
DESC = ("Quản lý & đẩy film recipe (Fuji X Weekly) xuống máy Fujifilm X-S20 qua Wi-Fi. "
        "Nhập recipe từ text hoặc từ ảnh (OCR on-device, offline).")

app = {
    "name": "Fuji Recipe Flash",
    "bundleIdentifier": "com.iostoxs20.recipeflash",
    "developerName": "iOStoXS20",
    "subtitle": "Đẩy film recipe xuống Fujifilm X-S20",
    "localizedDescription": DESC,
    "iconURL": ICON,
    "tintColor": "2EA078",
    "category": "photography",
    "screenshotURLs": [],
    "versions": [{
        "version": VER,
        "date": NOW,
        "localizedDescription": "Build tự động từ commit mới nhất.",
        "downloadURL": IPA,
        "size": SIZE,
        "minOSVersion": "16.0",
    }],
    # Khoá legacy cho AltStore/SideStore bản cũ (đọc trực tiếp trên app, không qua versions[]).
    "version": VER,
    "versionDate": NOW,
    "versionDescription": "Build tự động từ commit mới nhất.",
    "downloadURL": IPA,
    "size": SIZE,
}
source = {
    "name": "Fuji Recipe Flash (iOStoXS20)",
    "identifier": "com.iostoxs20.source",
    "sourceURL": f"https://github.com/{REPO}/releases/download/latest/apps.json",
    "apps": [app],
    "news": [],
}

out = sys.argv[1] if len(sys.argv) > 1 else "apps.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(source, f, ensure_ascii=False, indent=2)
print(f"Wrote {out}: version={VER} size={SIZE}")
