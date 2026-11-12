import Foundation

/// Trạng thái + thao tác màn Thư viện. Port phần `remember { … }` của `KT/library/LibraryScreen.kt` (Kotlin không có
/// ViewModel riêng cho màn này).
@Observable @MainActor final class LibraryViewModel {

    private(set) var albums: [ResultLibrary.Album] = []
    /// Đã nạp xong ít nhất một lần — chưa nạp thì chưa được nói "thư viện trống".
    private(set) var loaded = false
    /// Buổi đang mở xem.
    var open: ResultLibrary.Album?
    /// Buổi đang chờ xác nhận xoá.
    var confirmDelete: ResultLibrary.Album?

    /// Nạp lại từ đĩa. Gọi mỗi lần tab hiện ra — vừa lưu ở màn xem lại thì phải thấy ngay.
    func reload() async {
        albums = await Task.detached { ResultLibrary.albums() }.value
        loaded = true
    }

    /// Xoá hẳn buổi đã xác nhận, đóng màn xem buổi, nạp lại.
    func deleteConfirmed() {
        guard let album = confirmDelete else { return }
        ResultLibrary.delete(album)
        album.photos.forEach { ThumbnailCache.shared.remove($0) }
        confirmDelete = nil
        open = nil
        Task { await reload() }
    }

    /// Ngày giờ theo thói quen của ngôn ngữ máy — "10/9 14:30" ở Việt Nam, "9/10 2:30 PM" ở Mỹ.
    static func formatTime(_ ms: Int64) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("dMMjmm")
        return f.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }
}
