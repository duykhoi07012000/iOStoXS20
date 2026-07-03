# Giữ app sống không cần mở PC — dùng SideStore

App cài kiểu sideload (Apple ID free) có **chứng chỉ 7 ngày**. Với **AltStore** phải
mở PC + AltServer để gia hạn. **SideStore** làm việc gia hạn **ngay trên iPhone**
(OTA), sau khi cài đặt ban đầu **một lần** với PC — sau đó **không cần mở PC nữa**.

## Cài đặt một lần (cần PC)
1. Tải **SideStore** + công cụ pairing (theo hướng dẫn https://sidestore.io).
2. Trên PC, tạo **pairing file** (SideStore hướng dẫn qua Jitterbug/AltServer một lần).
3. Cài SideStore lên iPhone (giống AltStore: ký bằng Apple ID free).
4. Trong SideStore, nạp **pairing file** → bật **auto-refresh (background)**.

## Sau đó — không cần PC
- SideStore tự gia hạn chứng chỉ 7 ngày **qua Wi-Fi ngay trên máy**, không cần mở PC.
- Cài `.ipa` của app: mở SideStore → **My Apps → "+"** → chọn file `.ipa` (lấy từ
  GitHub Actions artifact như cũ — xem README).

## Lấy file .ipa mới
Mỗi lần code cập nhật, GitHub Actions build lại `.ipa`:
1. Vào **Actions** của repo → run mới nhất (xanh) → **Artifacts** →
   tải `RecipeFlash-unsigned-ipa` → giải nén lấy `.ipa`.
2. Đưa file `.ipa` vào iPhone (iCloud Drive / Files) → SideStore "+" cài đè.

## So sánh nhanh
| | AltStore | SideStore | Apple Dev $99 |
|---|---|---|---|
| Chi phí | free | free | $99/năm |
| Gia hạn 7 ngày | cần mở PC | **tự OTA, không cần PC** | cert 1 năm |
| Cài đặt ban đầu | vừa | phức tạp hơn chút | mua tài khoản |

→ Khuyến nghị cho trường hợp "không mở PC thường xuyên": **SideStore**.
