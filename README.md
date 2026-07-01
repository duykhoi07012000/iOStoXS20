# iOStoXS20 — Đẩy "film recipe" từ iPhone xuống Fujifilm X-S20

Dự án: app **iOS** chọn/biên tập một film recipe (Film Simulation, Grain, Color
Chrome, WB shift, Highlight/Shadow Tone, Sharpness, NR, Clarity…) rồi **ghi xuống
X-S20** qua Wi-Fi — thay vì gõ tay từng thông số trên thân máy.

Vì **Fujifilm không có SDK iOS**, dự án tự nói giao thức **PTP/IP qua Wi-Fi** (BLE
chỉ để đánh thức/bật Wi-Fi). SDK desktop có sẵn (`SDK13410/`) được dùng làm **nguồn
opcode chính xác**, không nhúng vào app.

## Trạng thái
| Phase | Nội dung | Trạng thái |
|---|---|---|
| 0 | Validate + capture giao thức | ✅ đã capture & giải mã |
| 1 | Prototype PTP/IP Python | ✅ **đẩy 14/14 trường recipe [OK] trên X-S20 thật** |
| 2 | Port lõi sang Swift `FujiKit` | ✅ code-complete (chờ compile/test cloud Mac) |
| 3 | BLE wake + pairing GUID riêng | ⬜ |
| 4 | App iOS SwiftUI | 🔶 UI + build config xong (chờ build) |
| 5 | Build cloud → cài SideStore | 🔶 workflow CI xong (chờ push) |

## Cấu trúc
```
docs/                        # ghi chú giao thức đã giải mã (protocol-notes.md…)
prototype-python/            # Phase 1: client PTP/IP chạy THẬT trên Windows (tham chiếu vàng)
swift/FujiKit/               # Phase 2: lõi Swift (port từ Python) cho iOS
ios/                         # Phase 4: app SwiftUI + project.yml (XcodeGen)
.github/workflows/ci.yml     # Phase 5: build cloud macOS → test + .ipa chưa ký
SDK13410/                    # FUJIFILM SDK (chỉ tra opcode; .gitignore, không commit)
```

## Bắt đầu nhanh (Windows, không cần Mac)
```bash
# Đẩy recipe THẬT xuống máy (máy ở WIRELESS TETHER SHOOTING FIXED, đèn cam):
cd prototype-python
python -m fuji_xs20.cli recipes/classic-neg-sample.json --ip 192.168.1.50
# Xem trước không cần máy:
python -m fuji_xs20.cli recipes/classic-neg-sample.json --dry-run
```

## Build app iOS (không cần Mac)
Push repo lên GitHub → Actions tự chạy `.github/workflows/ci.yml` trên macOS runner:
test `FujiKit` → build `.ipa` chưa ký → tải artifact → cài bằng **SideStore/AltStore**.

## Bối cảnh môi trường
- Máy phát triển: **Windows** (không có Mac).
- Compile iOS: **Mac đám mây free** (GitHub Actions runner macOS / Codemagic).
- Cài lên iPhone: **SideStore/AltStore** + Apple ID free (cert 7 ngày tự refresh).
- Chi tiết kế hoạch đầy đủ: xem file plan trong `~/.claude/plans/`.

## Tham khảo giao thức
- [gkoh/furble](https://github.com/gkoh/furble) — BLE Fuji (đã chạy X-S20)
- [hkr/fuji-cam-wifi-tool](https://github.com/hkr/fuji-cam-wifi-tool),
  [malc0mn/ptp-ip](https://github.com/malc0mn/ptp-ip) — PTP/IP Wi-Fi
- [libgphoto2 camlibs/ptp2](https://github.com/gphoto/libgphoto2),
  [fujihack](https://github.com/fujihack/fujihack) — đối chiếu property code

## Pháp lý
Dự án interoperability cá nhân với máy ảnh của chính người dùng. SDK Fujifilm chỉ
dùng tra cứu opcode; không phân phối lại DLL/redistributable của Fujifilm.
