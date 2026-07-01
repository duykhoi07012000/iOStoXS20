# Prototype Python — đẩy film recipe xuống Fujifilm X-S20 (Phase 1)

Mục tiêu: chứng minh giao thức PTP/IP **ngay trên Windows** (không cần Mac/iPhone),
trước khi port sang Swift/iOS. Chỉ dùng **thư viện chuẩn** của Python (không cần
cài gì để chạy).

## Cấu trúc
```
fuji_xs20/
  opcodes.py   # PTP property code + value enum, trích từ SDK (xem docs/xs20-recipe-reference.md)
  recipe.py    # Model Recipe + chuyển thành chuỗi SetDevicePropValue
  ptpip.py     # Tầng truyền tải PTP/IP (handshake + OpenSession + SetDevicePropValue)
  cli.py       # CLI áp recipe
recipes/       # recipe mẫu (.json)
tests/         # test mapping (cần pytest)
```

## Chạy thử KHÔNG cần camera (xác minh mapping recipe → opcode)
```bash
python -m fuji_xs20.cli recipes/classic-neg-sample.json --dry-run
```
In ra đúng chuỗi `SetDevicePropValue(0x….)` sẽ gửi.

## Áp recipe lên máy thật
1. Trên X-S20: bật chế độ kết nối Wi-Fi (Connection Setting → tethering / remote).
2. Cho PC join AP Wi-Fi của máy (hoặc cùng mạng), xác định IP máy (thường `192.168.0.1`).
3. Chạy:
```bash
python -m fuji_xs20.cli recipes/classic-neg-sample.json --ip 192.168.0.1
```

## Định dạng recipe (.json)
Chỉ cần khai trường muốn đổi (trường bỏ trống → không gửi). Enum dùng **tên**:
```json
{
  "name": "My Recipe",
  "film_simulation": "CLASSIC_NEG",
  "highlight_tone": 1.5,
  "shadow_tone": 2.0,
  "color": 4,
  "wb_shift_red": 2,
  "wb_shift_blue": -5,
  "noise_reduction": "M4"
}
```
Tên enum hợp lệ: xem `fuji_xs20/opcodes.py` (FilmSimulation, GrainEffect, ColorChrome,
NoiseReduction, DynamicRange, WhiteBalance, ColorSpace).

## ⚠️ Phần CẦN xác nhận bằng capture Phase 0
Code này hiện dựa trên **giả thuyết** (PTP property code == API_CODE của SDK; layout
WB shift & mono color; có/không bước đăng ký Fuji). Trước khi tin tuyệt đối, làm
theo `docs/phase0-capture-guide.md`. Khi capture xong, thường chỉ cần sửa:
- `opcodes.py` → bảng `Prop` (nếu property code khác).
- `ptpip.py` → mục `FUJI-TODO` trong `connect()` (sequence đăng ký).
- `recipe.py` → cách đóng gói WB shift / mono color.

## Chạy test
```bash
pip install pytest   # chỉ cần cho test
pytest -q
```
