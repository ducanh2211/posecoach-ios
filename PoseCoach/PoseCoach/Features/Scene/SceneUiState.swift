import Foundation
import PhotosUI
import PoseDomain
import SwiftUI

/// Người dùng bắt đầu luồng đề xuất bằng cách nào — chọn ở màn chính. Port `SceneStart` của `KT/scene/SceneScreen.kt`.
enum SceneStart {
    case camera
    case media([PhotosPickerItem])
}

/// Một đầu vào ảnh/video. `captured` = app tự chụp. Port `SceneInput` của `KT/scene/SceneUiState.kt`.
///
/// Khác Android: `file` luôn là file TẠM trong `scene-capture/` — ảnh/video chọn từ thư viện cũng được chép vào đó
/// (Photo Picker của iOS không cho đọc thẳng như `content://`), xoá cả thư mục khi rời luồng.
struct SceneInput: Equatable, Identifiable {
    let id: Int64
    let file: URL
    let video: Bool
    let captured: Bool
}

/// TRẠNG THÁI LUỒNG ĐỀ XUẤT ẢNH MẪU (09/10/2026). Port `KT/scene/SceneUiState.kt`.
///
/// Đầu vào gồm nhiều ảnh/video CỘNG một câu gõ — người dùng thêm, bớt, sửa bất cứ lúc nào, mỗi lần đổi là đề xuất lại.
struct SceneUiState {
    var inputs: [SceneInput] = []
    /// Câu mô tả đã dùng để tìm. Rỗng = chưa gõ.
    var query = ""
    var analyzing = false
    var progress: UiText?
    var error: UiText?
    /// Đã đề xuất xong ít nhất một lần — mới phân biệt được "chưa tìm" với "không có".
    var analyzed = false
    /// Yếu tố bối cảnh nhận ra được, gộp từ mọi ảnh/video và câu gõ.
    var tags: [SceneTag] = []
    var selected: Set<String> = []
    var matches: [SceneMatch] = []
    /// Từ trong câu gõ mà app không hiểu — hiện ra, không im lặng bỏ qua.
    var unknownWords: [String] = []
    var templateCount = 0
    var unreadableTemplates = 0

    var hasInput: Bool { !inputs.isEmpty || !query.trimmingCharacters(in: .whitespaces).isEmpty }
}
