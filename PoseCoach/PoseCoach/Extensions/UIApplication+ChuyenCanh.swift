import UIKit

extension UIApplication {

    /// Chờ mọi màn đang MỞ / ĐÓNG dở chạy xong chuyển cảnh.
    ///
    /// ⚠️ SwiftUI bỏ qua lệnh mở màn / hộp mới khi hộp cũ còn đang đóng dở (xem `HomeViewModel.sauKhiDong`). Hộp nào có
    /// `onDismiss` thì dùng nó; chỗ này cho hộp KHÔNG có `onDismiss` — Photo Picker (`.photosPicker`): chọn xong là
    /// `selection` đổi ngay trong lúc bảng chọn còn đang trượt xuống. Chờ tối đa 2 giây rồi thôi, để không treo luồng.
    static func choChuyenCanhXong() async {
        for _ in 0..<40 {
            if !dangChuyenCanh() { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private static func dangChuyenCanh() -> Bool {
        let roots = shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
        for root in roots {
            var vc: UIViewController? = root
            while let v = vc {
                if v.transitionCoordinator != nil || v.isBeingPresented || v.isBeingDismissed { return true }
                vc = v.presentedViewController
            }
        }
        return false
    }
}
