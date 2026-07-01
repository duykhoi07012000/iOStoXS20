# FujiKit (Swift) — lõi đẩy film recipe xuống X-S20 cho iOS

Port trung thực từ `prototype-python/` (đã kiểm chứng trên máy thật). Dùng
`Network.framework` (iOS 14+/macOS 11+).

> ⚠️ Chưa compile được trên Windows (không có Swift + `Network.framework` chỉ có trên
> Apple platforms). **Byte layout đã đối chiếu 1:1 với bản Python** qua unit test
> (`Tests/FujiKitTests`). Build + test thật chạy trên **cloud Mac** (GitHub Actions
> `macos` runner / Codemagic) — xem Phase 5.

## Cấu trúc
```
Sources/FujiKit/
  Opcodes.swift        # wire property codes + enum (đã xác nhận trên máy)
  Recipe.swift         # struct Recipe -> danh sách PropertyWrite (scale ×10, clamp)
  PTPCodec.swift       # đóng/mở gói PTP (init 78B, container PTP-USB) — có test hex
  NetworkHelpers.swift # TCPConn async/await, UDP, IP LAN (en0)
  PCSSDiscovery.swift  # discovery PCSS/1.0 (listener 51560 + UDP 51562)
  FujiCamera.swift     # API: connect -> apply(recipe) -> close
Tests/FujiKitTests/    # đối chiếu byte với Python (chạy trên Mac)
```

## Dùng thử (Swift)
```swift
import FujiKit

var r = Recipe()
r.name = "Classic Neg"
r.filmSimulation = .classicNeg
r.dynamicRange = .dr400
r.highlightTone = 1.5
r.shadowTone = 2.0
r.color = 4
r.whiteBalance = .auto
r.wbShiftRed = 2; r.wbShiftBlue = -5
r.noiseReduction = .m4

let cam = FujiCamera(cameraIP: "192.168.1.50")   // GUID mặc định = identity đã pair
try await cam.connect()
for (label, ok) in try await cam.apply(r) { print(ok ? "OK" : "FAIL", label) }
await cam.close()
```

## Build & test trên Mac
```bash
cd swift/FujiKit
swift build
swift test          # chạy EncodingTests — phải PASS trước khi tin bản port
```

## Lưu ý iOS (khi ghép vào app)
- Cần quyền **Local Network** (`NSLocalNetworkUsageDescription`) + khai báo Bonjour nếu dùng.
- App phải join Wi-Fi của máy ảnh (`NEHotspotConfiguration` hoặc hướng dẫn user).
- `localIPAddress()` lấy IPv4 của `en0` (Wi-Fi).

## TODO đã biết (mang từ Phase 1)
- **Pairing GUID riêng** cho app (hiện mượn identity Tether App) — Phase 3.
- JSON recipe: hiện enum Codable theo raw số; để chia sẻ file với bản Python cần
  map theo TÊN — sẽ thống nhất sau.
- Mono Color, Color Space chưa map.
