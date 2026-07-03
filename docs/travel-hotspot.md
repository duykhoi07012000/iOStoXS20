# Du lịch: nối iPhone ↔ X-S20 khi chỉ có 2 thiết bị (không PC/router)

Khi đi du lịch, dùng **Personal Hotspot của iPhone** làm mạng chung: máy ảnh join
hotspot, app trên iPhone nói chuyện với máy qua mạng đó.

## Các bước
1. **iPhone**: Settings → Personal Hotspot → **Allow Others to Join** (BẬT).
   - Ghi nhớ **tên hotspot** (thường là tên iPhone) + **mật khẩu Wi-Fi**.
   - Nên bật "Maximize Compatibility" (dùng 2.4GHz) cho máy ảnh dễ thấy.
2. **Máy ảnh X-S20**: MENU → NETWORK/USB SETTING → **NETWORK SETTING** →
   **WIRELESS ACCESS POINT SETTING** → chọn/nhập SSID = hotspot iPhone → nhập mật khẩu.
   - **WIRELESS IP ADDRESS SETTING = AUTO** (nhận IP từ hotspot).
3. Máy ảnh: **CONNECTION MODE → WIRELESS TETHER SHOOTING FIXED** → đợi **đèn cam chớp**.
4. **App**: mở recipe → **Apply Recipe**. App tự phát gói tìm máy (broadcast) trên
   mạng hotspot rồi flash — **không cần nhập IP**.
   - Lần đầu iOS hỏi quyền **Local Network** → **Cho phép** rồi bấm Apply lại.

## Vì sao không cần nhập IP
Trong mạng hotspot, IP máy có thể đổi mỗi lần. App gửi gói **DISCOVERY (PCSS/1.0)**
theo kiểu broadcast; máy trả **NOTIFY** kèm chính IP của nó → app dùng IP đó để nối.
(Chi tiết giao thức: `docs/protocol-notes.md`.)

## Nếu app không tìm thấy máy
- Kiểm tra máy đã **connected** vào hotspot (icon Wi-Fi trên máy) và đang ở
  **WIRELESS TETHER SHOOTING FIXED** (đèn cam chớp, chưa có app nào khác đang nối).
- iPhone: đảm bảo Personal Hotspot vẫn bật (iOS đôi khi tự tắt khi không có thiết bị
  → mở lại màn Personal Hotspot cho nó "thức").
- Tắt/bật lại CONNECTION MODE trên máy để nó phát lại.
- Một số hotspot chặn thiết bị thấy nhau ("client isolation") hiếm gặp trên iPhone;
  nếu vướng, thử tạo lại hotspot hoặc bật "Maximize Compatibility".
