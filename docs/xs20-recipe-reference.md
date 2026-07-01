# X-S20 Recipe Reference (trích từ FUJIFILM Camera Remote SDK 1.34)

Tài liệu này trích trực tiếp từ các header trong `SDK13410/SDK13410/HEADERS/`
(`XAPIOpt.H`, `XAPI.H`, `X-S20.h`). Đây là **xương sống** của toàn dự án: bảng
opcode + giá trị hợp lệ mà X-S20 chấp nhận.

> ⚠️ **Lưu ý mức tin cậy.** Các `API_CODE` (0x2xxx) là *function code của SDK
> desktop*. Khi gửi qua Wi-Fi, Fuji dùng PTP `SetDevicePropValue` (op 0x1016) với
> **device property code**. Giả thuyết hiện tại: property code PTP == API_CODE của
> SDK (vì SDK là lớp mỏng bọc PTP). **Phải xác nhận lại bằng capture Wireshark ở
> Phase 0** trước khi tin tuyệt đối. Xem `docs/phase0-capture-guide.md`.

## 1. Opcode (Set) cho các trường recipe

| Trường recipe (menu máy) | API_CODE | Hằng giá trị | Kiểu |
|---|---|---|---|
| Film Simulation | `0x2121` | `SDK_FILMSIMULATION_*` | uint16 |
| Grain Effect | `0x2152` | `SDK_GRAIN_EFFECT_*` | uint16 |
| Color Chrome FX Blue | `0x2168` | `SDK_COLORCHROME_BLUE_*` | uint16 |
| Color Chrome Effect (thường) | `0x2154` *(?)* | `SDK_SHADOWING_*` | uint16 |
| Monochromatic Color (WC + R/G) | `0x216A` | `SDK_MONOCHROMATICCOLOR_*` | int (cặp) |
| Clarity | `0x216C` | `SDK_CLARITY_*` (-50..+50) | int (×10) |
| Highlight Tone | `0x2141` | `SDK_HIGHLIGHT_TONE_*` | int (×10) |
| Shadow Tone | `0x2143` | `SDK_SHADOW_TONE_*` | int (×10) |
| Color (độ bão hòa) | `0x2105` | `SDK_COLOR_*` (-40..+40) | int (×10) |
| Sharpness | `0x2103` | `SDK_SHARPNESS_*` (-40..+80) | int (×10) |
| Noise Reduction | `0x2131` | `SDK_NOISEREDUCTION_*` | uint16 |
| Dynamic Range | `0x2156` (`SetWideDynamicRange`) | `SDK_DRANGE_*` | uint16 |
| White Balance Mode | `0x2301` | `SDK_WB_*` | uint16 |
| WB Shift (R) | (kèm `0x2304` `SetWhiteBalanceTune`) | -9..+9 | int |
| WB Shift (B) | (kèm `0x2304` `SetWhiteBalanceTune`) | -9..+9 | int |
| Color Space | `0x2127` | `SDK_COLORSPACE_*` | uint16 |
| Custom Setting Auto Update | `0x218C` | (Phase 6 – ghi C1..C7) | uint16 |

> Lưu ý đơn vị: nhiều trường (-2..+4 tone, ±4 color/sharp, ±5 clarity) được lưu
> dạng **×10** (vd +2.0 = `20`, -1.5 = `-15`). Xem từng bảng dưới.

## 2. Film Simulation (`0x2121`)

| Tên | Giá trị | | Tên | Giá trị |
|---|---|---|---|---|
| PROVIA / STD | `1` | | ACROS | `0x0C` |
| Velvia | `2` | | ACROS+Ye | `0x0D` |
| ASTIA | `3` | | ACROS+R | `0x0E` |
| PRO Neg. Hi | `4` | | ACROS+G | `0x0F` |
| PRO Neg. Std | `5` | | ETERNA | `0x10` |
| Monochrome | `6` | | Classic Neg. | `0x11` |
| Monochrome+Ye | `7` | | Eterna Bleach Bypass | `0x12` |
| Monochrome+R | `8` | | Nostalgic Neg. | `0x13` |
| Monochrome+G | `9` | | REALA ACE | `0x14` |
| Sepia | `10` | | (AUTO) | `0x8000` |
| Classic Chrome | `11` | | | |

## 3. Grain Effect (`0x2152`)

| Tên | Giá trị |
|---|---|
| Off | `0x01` |
| Weak / Small | `0x02` |
| Strong / Small | `0x03` |
| Weak / Large | `0x04` |
| Strong / Large | `0x05` |
| Off / Large | `0x07` |

(X-S20 có Size = Small/Large; ánh xạ Weak/Strong × Small/Large theo bảng trên.)

## 4. Color Chrome FX Blue (`0x2168`) & Color Chrome Effect (`0x2154` ?)

| Tên | Giá trị |
|---|---|
| Off | `0x01` |
| Weak | `0x02` |
| Strong | `0x03` |

> `0x2154 SetShadowing` có cùng bộ giá trị Off/Weak/Strong → **giả thuyết** đây là
> "Color Chrome Effect" thường. Cần xác nhận Phase 0.

## 5. Tone — Highlight (`0x2141`) & Shadow (`0x2143`)

Lưu dạng ×10. Dải −2.0 … +4.0, bước 0.5:

| Hiển thị | Giá trị | | Hiển thị | Giá trị |
|---|---|---|---|---|
| +4 | `40` | | 0 | `0` |
| +3.5 | `35` | | −0.5 | `-5` |
| +3 | `30` | | −1 | `-10` |
| +2.5 | `25` | | −1.5 | `-15` |
| +2 | `20` | | −2 | `-20` |
| +1.5 | `15` | | | |
| +1 | `10` | | | |
| +0.5 | `5` | | | |

## 6. Color / Saturation (`0x2105`) — ×10, dải −4..+4

`+4=40, +3=30, +2=20, +1=10, 0=0, −1=-10, −2=-20, −3=-30, −4=-40`

## 7. Sharpness (`0x2103`) — ×10, dải −4..+8

`+8=80 … +4=40, +3=30, +2=20, +1=10, 0=0, −1=-10 … −4=-40`

## 8. Clarity (`0x216C`) — ×10, dải −5..+5

`+5=50, +4=40, +3=30, +2=20, +1=10, 0=0, −1=-10 … −5=-50`

## 9. Noise Reduction (`0x2131`) — bucket uint16

| Hiển thị | Giá trị | | Hiển thị | Giá trị |
|---|---|---|---|---|
| +4 (Extra High) | `0x5000` | | −1 (Med Low) | `0x3000` |
| +3 (Super High) | `0x6000` | | −2 (Low) | `0x4000` |
| +2 (High) | `0x0000` | | −3 (Super Low) | `0x7000` |
| +1 (Med High) | `0x1000` | | −4 (Extra Low) | `0x8000` |
| 0 (Standard) | `0x2000` | | | |

## 10. Dynamic Range (`0x2156`)

| Tên | Giá trị |
|---|---|
| AUTO | `0xFFFF` |
| DR100 | `100` |
| DR200 | `200` |
| DR400 | `400` |
| DR800 | `800` |

## 11. White Balance (`0x2301`) + WB Shift (`0x2304`)

Mode (uint16): `AUTO=0x0002`, `AUTO White Priority=0x8020`, `AUTO Ambience=0x8021`,
`Daylight=0x0004`, `Incandescent=0x0006`, `Underwater=0x0008`,
`Fluorescent1/2/3=0x8001/0x8002/0x8003`, `Shade=0x8006`, `ColorTemp(K)=0x8007`,
`Custom1..5=0x8008..0x800C`.

Color Temp (K) khi mode = ColorTemp: 2500…10000 (danh sách bước rời, xem header).

**WB Shift**: Red −9..+9, Blue −9..+9 (`SDK_WB_R/B_SHIFT_MIN/MAX = ∓9`). Đặt kèm
qua `SetWhiteBalanceTune` (`0x2304`, nhận 3 tham số: mode + R + B).

## 12. Monochromatic Color (`0x216A`) — chỉ khi film sim mono/ACROS

Hai trục, mỗi trục −180..+180 (bước 10):
- **WC** (Warm–Cool): `SDK_MONOCHROMATICCOLOR_WC_*`
- **R/G** (Red–Green): `SDK_MONOCHROMATICCOLOR_RG_*`

## 13. Custom Settings bank (Phase 6)

`SDK_CUSTOM_SETTING_CUSTOM1..7 = 1..7`. Liên quan `0x218C SetCustomSettingAutoUpdate`.
Cần điều tra thêm xem ghi trực tiếp vào bank được không.

---

### Nguồn
- `SDK13410/SDK13410/HEADERS/XAPIOpt.H` (dòng ~180–500 opcode; ~630–968 giá trị)
- `SDK13410/SDK13410/HEADERS/X-S20.h` (param + enum dành riêng X-S20)
- `SDK13410/SDK13410/HEADERS/XAPI.H` (DynamicRange, khung chung)
