# X-S20 PTP/IP — Ghi chú giao thức (giải mã từ capture thật)

Nguồn: capture `D:\fuji-capture.pcapng` (FUJIFILM Tether App ↔ X-S20 qua Wi-Fi
tether), phân tích bằng `tshark`. Đây là **sự thật trên dây**, thay thế giả thuyết
ban đầu trong `xs20-recipe-reference.md` (mục opcode 0x2xxx là *API_CODE của SDK
desktop*, KHÔNG phải property code wire).

## Kết nối — tổng quan
- Máy ở **WIRELESS TETHER SHOOTING FIXED** (đèn cam chớp = đang chờ), join chung router,
  IP MANUAL `192.168.1.50`. Chỉ **1 kết nối** một lúc → phải gác máy (CloseSession +
  đóng socket) sạch, nếu không máy treo slot (báo `0x201D`/refused → phải tắt/bật).

## Bước 1 — Discovery "PCSS/1.0" (BẮT BUỘC)
Nếu nối thẳng 15740 mà bỏ bước này → **refused**. Trình tự:
1. PC mở **TCP listener cổng 51560**.
2. PC gửi **UDP** tới camera **:51562**:
   `DISCOVERY * HTTP/1.1\r\nHOST: <PC_ip>\r\nMX: 5\r\nSERVICE: PCSS/1.0\r\n\0`
3. Camera **nối ngược** vào PC:51560 gửi: `NOTIFY * HTTP/1.1` kèm `DSC: <cam_ip>`,
   `CAMERANAME: X-S20`, **`DSCPORT: 15740`**.
4. PC trả `HTTP/1.1 200 OK\r\n`. → máy mới mở/chấp nhận cổng PTP (DSCPORT).

## Bước 2 — Handshake PTP/IP (header 8 byte: `[len u32][type u32]`)
1. Client → `InitCommandRequest` (type `0x01`), **body 78 byte**:
   `GUID(16) + clientIP(4 = inet_aton đảo octet) + vùng-tên-54B(name UTF16LE NUL + đệm 0)`
   - ⚠️ Thiếu vùng đệm 54B → máy từ chối **`0x201D`**.
   - ⚠️ **GUID phải đã ĐĂNG KÝ/paired** với máy; GUID lạ → `0x201D` vĩnh viễn. Hiện
     prototype dùng GUID của Tether App đã pair (`--guid`). Pairing GUID riêng = TODO.
   - Lần đầu máy thường `InitFail 0x2019` (busy) → **retry** mới `InitCommandAck`.
2. Camera → `InitCommandAck` (type `0x02`): `connNum + GUID + Name("X-S20") + đệm`.

## Sau handshake → container kiểu PTP-USB (header 12 byte)
`[len u32][type u16][code u16][transactionID u32][payload]`
- type: `1`=Command, `2`=Data, `3`=Response, `4`=Event. Response OK = `0x2001`.
- Ngay sau ack: **OpenSession** = Command code `0x1002`, tid=1, param=`0x00000001`.
- **SetDevicePropValue**: Command code `0x1016` param1=propcode → Data (type 2) code
  `0x1016` payload=giá trị → đọc Response (type 3).
- **GetDevicePropValue**: Command code `0x1015` param1=propcode → Data trả giá trị.

## Property codes THẬT — 13/14 trường đã xác nhận (đẩy [OK] trên máy)
| Trường recipe | Wire code | Kiểu | Ghi chú giá trị |
|---|---|---|---|
| Film Simulation | `0xD001` | u16 | 1..0x14 (0x11=ClassicNeg); không có AUTO |
| Grain Effect | `0xD023` | u16 | 1=off,2=weak,3=strong,4=weak-large,5=strong-large,7=off-large |
| Color Chrome Effect | `0xD029` | u16 | 1=off,2=weak,3=strong |
| Color Chrome FX Blue | `0xD030` | u16 | 1=off,2=weak,3=strong |
| Noise Reduction | `0xD01C` | u16 | 0x0..0x8000 (bucket) |
| Dynamic Range | `0xD007` | u16 | 0xffff=AUTO,100,200,400 (X-S20 KHÔNG có 800) |
| White Balance | `0x5005` | u16 | enum WB (standard PTP) |
| WB Kelvin (Color Temp) | `0xD017` | u16 | số Kelvin (2500–10000) khi WB=ColorTemp — xác nhận trên máy |
| WB Shift Red | `0xD00B` | i16 | −9..9 (giá trị thô) |
| WB Shift Blue | `0xD00C` | i16 | −9..9 (giá trị thô) |
| Highlight Tone | `0xD320` | i16 | −20..40 step 5 (= −2.0..+4.0, value ×10) |
| Shadow Tone | `0xD321` | i16 | −20..40 step 5 |
| Color/Saturation | `0xD008` | i16 | −40..40 step 10 (×10) |
| Sharpness | `0x5015` | i16 | −40..40 step 10 (X-S20 max ±4, KHÁC SDK ±8) |
| Clarity | `0xD032` | i16 | −50..50 step 10 (×10) |
| Mono Color, Color Space | — | — | ⏳ niche; mono chỉ hiện khi film sim đen trắng |

### Cách đã map (tái sử dụng được)
1. `dump_props.py`: `GetDeviceInfo`(0x1001)→liệt kê 265 property→`GetDevicePropDesc`(0x1014)
   mỗi code→đối chiếu **chữ ký giá trị** (enum/range) với SDK.
2. Với enum[1,2,3] trùng nhau (grain/color chrome): `snapshot.py` chụp trước/sau khi
   đổi tay thông số đó trên máy → **diff** ra đúng code.
3. Đối chiếu thêm `libgphoto2 camlibs/ptp2` (`PTP_DPC_FUJI_*`) nếu cần.
