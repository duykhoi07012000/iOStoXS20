# Phase 0 — Hướng dẫn Validate & Capture giao thức (Windows)

Mục tiêu: dùng **SDK desktop + máy thật** để (1) xác nhận X-S20 chấp nhận ghi
recipe qua Wi-Fi, và (2) **bắt gói** để biết chính xác byte của PTP/IP — nguồn sự
thật để chốt các "giả thuyết" trong `prototype-python/`. **Cần camera thật.**

## A. Validate bằng SDK desktop (chứng minh ghi recipe được)

1. Cài Visual Studio (C++ workload) hoặc dùng mẫu C# trong
   `SDK13410/SDK13410/SAMPLES/Windows/`.
2. Copy DLL từ `SDK13410/SDK13410/REDISTRIBUTABLES/Windows/64bit/` cạnh file .exe.
3. Kết nối X-S20 qua Wi-Fi (hoặc USB để thử nhanh trước).
4. Trong code mẫu, sau `XSDK_OpenEx` + `XSDK_SetPriorityMode(PC)`, gọi thử:
   - `XSDK_SetFilmSimulationMode(h, XS20_FILMSIMULATION_CLASSICNEG)`
   - `XSDK_SetProp`/`SetWhiteBalanceTune`, `SetGrainEffect`…
5. Nhìn màn hình máy / menu IQ xác nhận giá trị đổi. ✅ Nếu đổi được → firmware
   chấp nhận ghi recipe qua kênh này.

## B. Capture gói Wi-Fi (PTP/IP) bằng Wireshark

1. Cài [Wireshark](https://www.wireshark.org/). PC join AP Wi-Fi của máy ảnh.
2. Bắt trên interface Wi-Fi đó. Filter: `tcp.port == 55740` (hoặc `15740`).
3. Chạy lại bước A để sinh traffic.
4. Cần ghi lại:
   - **Handshake**: gói `Init Command Request/Ack`, `Init Event Request/Ack`, và
     **mọi gói lạ trước OpenSession** (bước "đăng ký" riêng của Fuji — nếu có).
   - **SetDevicePropValue**: với mỗi lệnh set, ghi lại:
     - `operation code` (kỳ vọng `0x1016`)
     - `property code` thực tế trong tham số → **so với bảng `Prop` trong
       `opcodes.py`** (vd Film Sim có đúng `0x2121` không?).
     - phần **data payload** (số byte + giá trị) → xác nhận kiểu `u16/i16/u32`.
5. Đối chiếu định dạng container với `ptpip.py`. Tinh chỉnh nếu lệch.

> Mẹo: đặt mỗi lần chỉ đổi **một** thuộc tính để dễ tách gói tương ứng.

## C. Capture BLE (bước wake / bật Wi-Fi) — phục vụ Phase 3

iOS không log BLE dễ; dùng **Android** để bắt:
1. Android: Developer options → bật **Bluetooth HCI snoop log**.
2. Dùng app **FUJIFILM XApp** kết nối X-S20 (pair + "connect").
3. Tắt log, lấy file `btsnoop_hci.log` (qua `adb bugreport` hoặc đường dẫn máy).
4. Mở bằng Wireshark → lọc theo địa chỉ máy ảnh. Ghi lại:
   - GATT **service/characteristic UUID** dùng để đánh thức & ra lệnh bật Wi-Fi.
   - Chuỗi byte ghi vào characteristic đó.
5. Đối chiếu [gkoh/furble](https://github.com/gkoh/furble) (đã chạy trên X-S20) để
   xác nhận → dùng cho lớp `FujiBLE` ở Phase 3.

## Output của Phase 0
- ✅/❌ kết luận: ghi recipe qua Wi-Fi được hay không.
- File `.pcapng` + bảng "property code thực tế ↔ trường recipe".
- (Nếu có) sequence đăng ký Fuji trước OpenSession.
- UUID + byte lệnh BLE wake/Wi-Fi.

→ Cập nhật `opcodes.py` (bảng `Prop`), `ptpip.py` (`FUJI-TODO`), `recipe.py`
(đóng gói WB/mono) cho khớp thực tế, rồi chạy lại `cli.py` (bỏ `--dry-run`).
