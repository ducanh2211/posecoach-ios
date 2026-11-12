import SwiftUI

@main
struct PoseCoachApp: App {

    init() {
        // Dọn rác của lần chạy trước. Phải gọi lúc MỞ app: lúc đóng thì app đã bị hệ điều hành giết, code dọn không bao
        // giờ chạy tới (như `MainActivity.onCreate`). Chép ảnh mẫu soạn sẵn thì chạy ở luồng nền trong tab Ảnh mẫu (4b).
        ShotStore.sweepOrphans()
        ShotStore.sweepRecordings()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
