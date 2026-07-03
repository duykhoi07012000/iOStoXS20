import SwiftUI

struct MainTabView: View {
    @StateObject private var store = RecipeStore()
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "square.stack.3d.up.fill") }
            StubView(title: "Sync", icon: "arrow.triangle.2.circlepath",
                     note: "Đồng bộ recipe (chưa làm).")
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }
            StubView(title: "Explore", icon: "safari",
                     note: "Khám phá recipe online (chưa làm).")
                .tabItem { Label("Explore", systemImage: "safari") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .environmentObject(store)
        .tint(Theme.active)
    }
}

struct StubView: View {
    let title: String; let icon: String; let note: String
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 48)).foregroundColor(Theme.textSoft)
                Text(note).font(Theme.mono(14)).foregroundColor(Theme.textSoft)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .fujiBackground().navigationTitle(title)
        }
    }
}

struct SettingsView: View {
    @AppStorage("cameraIP") private var cameraIP = "192.168.1.50"
    var body: some View {
        NavigationStack {
            Form {
                Section("Máy ảnh") {
                    TextField("IP máy ảnh", text: $cameraIP)
                        .font(Theme.mono(15)).keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                    Text("Nhập IP máy khi biết. Khi du lịch dùng hotspot, xem hướng dẫn bên dưới.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Section("Kết nối") {
                    NavigationLink { HelpView.travel } label: { Label("Du lịch: nối qua hotspot iPhone", systemImage: "personalhotspot") }
                    NavigationLink { HelpView.sideStore } label: { Label("Giữ app sống bằng SideStore", systemImage: "arrow.down.app") }
                }
                Section {
                    Text("Fuji Recipe Flash • v0.2").font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

enum HelpView {
    static var travel: some View { helpScroll("Nối khi du lịch (chỉ iPhone + máy)", """
    1. iPhone: Settings → Personal Hotspot → BẬT (nhớ tên + mật khẩu).
    2. Máy ảnh: NETWORK SETTING → WIRELESS ACCESS POINT → chọn/nhập SSID hotspot của iPhone → nhập mật khẩu.
    3. CONNECTION MODE → WIRELESS TETHER SHOOTING FIXED (đèn cam chớp).
    4. Trong app, bấm Apply Recipe — app tìm máy trên mạng hotspot và flash.

    Lưu ý: lần đầu iOS hỏi quyền "Local Network" → Cho phép.
    """) }

    static var sideStore: some View { helpScroll("Giữ app sống bằng SideStore", """
    App cài kiểu sideload dùng Apple ID free hết hạn 7 ngày. Để KHỎI phải mở PC:

    1. Cài SideStore (một lần, cần PC lấy pairing file).
    2. Sau đó SideStore tự gia hạn NGAY TRÊN iPhone qua Wi-Fi — không cần mở PC nữa.
    3. Mở app → SideStore → My Apps → Refresh nếu cần.

    File .ipa lấy từ GitHub Actions (artifact) như cũ.
    """) }

    private static func helpScroll(_ title: String, _ body: String) -> some View {
        ScrollView { Text(body).font(Theme.mono(14)).foregroundColor(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading).padding() }
        .fujiBackground().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
