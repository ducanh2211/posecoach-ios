import PhotosUI
import SwiftUI

/// LUỒNG ĐỀ XUẤT ẢNH MẪU THEO BỐI CẢNH (09/10/2026, theo flow PO). Port `SceneScreen` của `KT/scene/SceneScreen.kt`.
///
///     màn chính → chụp/quay HOẶC chọn ảnh/video → phân tích → màn ĐỀ XUẤT
///                      ↑                                         │
///                      └──── chụp thêm / thêm ảnh / sửa chữ ─────┘
///
/// Ảnh/video tự chụp (và bản chép của ảnh/video chọn từ thư viện) là file tạm — xoá khi rời luồng (`clear()`).
struct SceneView: View {

    private enum Step { case camera, suggest }

    /// Thư viện cho chọn tối đa chừng này ảnh/video mỗi lần — đủ cho một nơi chụp.
    static let chonToiDa = 10

    private let start: SceneStart
    private let onClose: () -> Void
    private let onPickTemplate: (URL) -> Void
    private let onImport: () -> Void

    @State private var vm = SceneViewModel()
    @State private var step: Step
    @State private var showPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var started = false

    init(start: SceneStart, onClose: @escaping () -> Void, onPickTemplate: @escaping (URL) -> Void,
         onImport: @escaping () -> Void) {
        self.start = start
        self.onClose = onClose
        self.onPickTemplate = onPickTemplate
        self.onImport = onImport
        if case .camera = start { _step = State(initialValue: .camera) } else { _step = State(initialValue: .suggest) }
    }

    var body: some View {
        Group {
            switch step {
            case .camera:
                SceneCameraView(
                    onDone: { files in
                        vm.addMedia(files, captured: true)
                        step = .suggest
                    },
                    onGallery: { showPicker = true },
                    // Chưa có đầu vào nào thì đóng camera là rời luồng luôn.
                    onClose: { if vm.state.inputs.isEmpty && vm.state.query.isEmpty { onClose() } else { step = .suggest } }
                )
            case .suggest:
                SceneSuggestView(
                    vm: vm,
                    onCapture: { step = .camera },
                    onGallery: { showPicker = true },
                    onClose: onClose,
                    onPickTemplate: onPickTemplate,
                    onImport: onImport
                )
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItems, maxSelectionCount: Self.chonToiDa,
                      matching: .any(of: [.images, .videos]), preferredItemEncoding: .compatible)
        .onChange(of: pickerItems) {
            if pickerItems.isEmpty { return }
            vm.addPicked(pickerItems)
            pickerItems = []
            step = .suggest
        }
        .task {
            if started { return }
            started = true
            if case let .media(items) = start { vm.addPicked(items) }
        }
        // Rời luồng: dừng phân tích, xoá ảnh/video tạm (FOOTGUNS 107.1).
        .onDisappear { vm.clear() }
    }
}
