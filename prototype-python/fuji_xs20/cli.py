"""CLI: nạp recipe JSON, áp xuống X-S20 qua PTP/IP thật (port 15740).

Chỉ những trường đã có wire property code mới được gửi; trường chưa map sẽ liệt kê
riêng (cần đối chiếu capture thêm). Hiện đã map: Film Simulation.

Ví dụ:
    python -m fuji_xs20.cli recipes/classic-neg-sample.json --dry-run
    python -m fuji_xs20.cli recipes/classic-neg-sample.json --ip 192.168.1.50
"""

from __future__ import annotations

import argparse
import sys

from .ptpip import DEFAULT_IP, DEFAULT_PORT, RC_OK, FujiCamera, FujiError
from .recipe import Recipe


def _utf8():
    for s in (sys.stdout, sys.stderr):
        try:
            s.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
        except (AttributeError, ValueError):
            pass


def main(argv: list[str] | None = None) -> int:
    _utf8()
    ap = argparse.ArgumentParser(description="Đẩy film recipe xuống Fujifilm X-S20")
    ap.add_argument("recipe", help="Đường dẫn file recipe .json")
    ap.add_argument("--ip", default=DEFAULT_IP, help=f"IP máy ảnh (mặc định {DEFAULT_IP})")
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    # Máy chỉ chấp nhận GUID đã "ghép đôi". Tạm dùng identity của Tether App đã pair
    # sẵn trên máy này. (Pairing cho GUID riêng = việc của giai đoạn sau.)
    ap.add_argument("--guid", default="f2e4538fada5485d87b27f0bd3d5ded0",
                    help="Client GUID (hex 32 ký tự) — phải là GUID đã đăng ký với máy")
    ap.add_argument("--name", default="DESKTOP-SGP1R6M", help="Tên client")
    ap.add_argument("--dry-run", action="store_true", help="Chỉ in, không kết nối")
    args = ap.parse_args(argv)

    try:
        recipe = Recipe.from_json(args.recipe)
    except (ValueError, OSError) as e:
        print(f"Lỗi đọc recipe: {e}", file=sys.stderr)
        return 2

    writes = recipe.to_property_writes()
    mapped = [w for w in writes if w.code is not None]
    pending = [w for w in writes if w.code is None]

    print(f"Recipe: {recipe.name}")
    print(f"  Sẽ gửi ({len(mapped)} trường đã có wire code):")
    for w in mapped:
        print(f"    SetProp(0x{w.code:04X}, {w.value}, {w.datatype})   # {w.label}")
    if pending:
        print(f"  ⏳ Chưa map ({len(pending)} trường, cần capture thêm — bỏ qua):")
        print("     " + ", ".join(w.label for w in pending))

    if not mapped:
        print("\nKhông có trường nào gửi được. Cần map thêm property code.")
        return 0
    if args.dry_run:
        print("\n[dry-run] Không kết nối camera.")
        return 0

    try:
        guid = bytes.fromhex(args.guid)
        with FujiCamera(args.ip, args.port, client_name=args.name, client_guid=guid) as cam:
            print(f"\nĐã kết nối {args.ip}:{args.port} (conn #{cam.connection_number}), "
                  "OpenSession OK. Đang áp recipe...")
            failed = 0
            for w in mapped:
                rc = cam.set_prop(w.code, w.value, w.datatype)
                ok = rc == RC_OK
                failed += 0 if ok else 1
                print(f"  [{'OK' if ok else f'FAIL 0x{rc:04X}'}] {w.label}")
            print("\nXong." if not failed else f"\nXong, {failed} trường lỗi.")
            return 0 if not failed else 1
    except (FujiError, OSError) as e:
        print(f"\nLỗi kết nối/giao thức: {e}", file=sys.stderr)
        print("Gợi ý: (1) máy đang ở WIRELESS TETHER SHOOTING FIXED và màn hình chờ "
              "kết nối; (2) ĐÃ ĐÓNG Tether App (máy chỉ cho 1 kết nối); (3) đúng IP.",
              file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
