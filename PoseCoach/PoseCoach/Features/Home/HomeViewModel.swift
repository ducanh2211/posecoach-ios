import CoreGraphics
import Foundation
import Observation
import os
import PhotosUI
import PoseDomain
import SwiftUI

/// ViewModel màn Ảnh mẫu. Port phần trạng thái + thao tác của `KT/home/HomeScreen.kt`.
///
/// Hai điểm khác bản iOS cũ (giữ như Android):
///  1. Lưới đọc THẬT từ thư viện.
///  2. **CỔNG KIỂM ẢNH 3 MỨC** chạy TRƯỚC khi vào màn camera — không có đường vào camera nào khác.
@Observable @MainActor final class HomeViewModel {

    nonisolated private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "HomeViewModel")

    /// Kết quả cổng kiểm của một ảnh mẫu, để hiện hộp thoại.
    struct Gate: Identifiable {
        let id = UUID()
        let file: URL
        let verdict: TemplateVerdict
        /// Hồ sơ tiêu chí suy từ chính ảnh mẫu này. `nil` khi ảnh bị từ chối.
        let profile: TemplateProfile?
        /// Mô tả dáng và độ khó — chuyện CÂU CHỮ cho người đọc, không nhét vào `TemplateProfile` (tầng đo).
        let poseGuide: [UiText]
        let difficulty: PoseDescriber.Difficulty?
    }

    /// Ảnh vừa nhập, đang chờ gắn nhãn trong `NhapAnhSheet`.
    struct Nhap: Identifiable {
        let id = UUID()
        let file: URL
        /// Kết quả tự nhận diện — đưa vào bảng để khỏi phân tích lại.
        let truoc: KetQuaNhap
        var preview: CGImage?
    }

    private(set) var templates: [MediaLibrary.Template] = []
    /// Nhóm đang lọc. `nil` = tất cả. Lựa chọn xem tạm của một lần mở màn hình.
    var filter: MediaLibrary.TemplateKind?
    /// Lần nạp đầu chưa xong (gồm cả việc chép bộ ảnh cài sẵn lần đầu) — hiện "đang chuẩn bị".
    private(set) var dangChuanBi = true

    // --- Cổng kiểm ---
    private(set) var checking: URL?
    var gate: Gate?
    var importError: UiText?

    // --- Nhập ảnh ---
    private(set) var importing = false
    /// Mở bộ chọn ảnh của hệ thống. Photo Picker KHÔNG cần xin quyền đọc thư viện ảnh.
    var showPicker = false
    var pickerItem: PhotosPickerItem?
    var nhap: Nhap?
    /// Đang tự nhận diện ảnh vừa nhập — hiện lớp chờ có phần trăm.
    private(set) var dangNhanDien = false
    /// Bước tiến độ mới nhất: từ, tới, ước bao lâu (ms), bắt đầu lúc nào. Xem `TienDo`.
    private(set) var buocTienDo: (tu: Float, den: Float, ms: Int, batDau: Date) = (0, 0, 0, .distantPast)

    // --- Đề xuất ảnh mẫu theo bối cảnh ---
    /// Bảng chọn cách bắt đầu (chụp/quay hoặc chọn ảnh/video có sẵn).
    var showSceneStart = false
    /// Photo Picker nhiều mục cho luồng bối cảnh.
    var showScenePicker = false
    var scenePickerItems: [PhotosPickerItem] = []
    /// Luồng bối cảnh đang mở. `nil` = đóng.
    var sceneStart: SceneStart?

    /// Chọn xong ảnh mẫu (đã qua cổng kiểm) → vào màn chụp. Màn gốc gán.
    @ObservationIgnored var onPickTemplate: (URL) -> Void = { _ in }

    /// Việc chờ hộp đang mở ĐÓNG HẲN rồi mới làm. Khác Android: SwiftUI bỏ qua lệnh mở màn / hộp mới khi hộp cũ còn đang
    /// đóng dở — mở thẳng là người dùng bấm "Bắt đầu chụp" mà không vào được màn chụp. View gọi `modalDaDong()` ở
    /// `onDismiss` của mọi hộp.
    @ObservationIgnored private var sauKhiDong: (() -> Void)?

    /// Các nhóm thư viện thật sự có. Chỉ hiện hàng lọc khi có hơn một nhóm.
    var kinds: [MediaLibrary.TemplateKind] {
        let have = Set(templates.map(\.kind))
        // Giữ thứ tự khai báo trong enum cho ổn định giữa các lần mở.
        return MediaLibrary.TemplateKind.allCases.filter { have.contains($0) }
    }

    var shown: [MediaLibrary.Template] {
        guard let filter else { return templates }
        return templates.filter { $0.kind == filter }
    }

    var busy: Bool { importing || checking != nil }

    // MARK: - Thư viện

    /// Nạp lại thư viện. Gọi lại được — nhập ảnh mới thì lưới phải hiện ngay.
    func reloadLibrary() async {
        // Chép bộ ảnh cài sẵn ở LUỒNG NỀN (chỉ thật sự chép một lần mỗi khi bộ ảnh đổi) — chép trong lúc mở app làm
        // trắng màn hình lần đầu (FOOTGUNS 111).
        templates = await Task.detached {
            MediaLibrary.seedBuiltInTemplates()
            return MediaLibrary.templates()
        }.value
        dangChuanBi = false
    }

    // MARK: - Cổng kiểm

    /// Bấm một ô ảnh mẫu: phân tích MỘT LẦN rồi dùng cho cả cổng kiểm lẫn hồ sơ tiêu chí.
    func selectTemplate(_ file: URL) {
        guard checking == nil else { return }
        checking = file
        Task {
            let (anh, kq) = await Task.detached { () -> (URL, PhanTichAnhMau) in
                let kq = phanTichAnhMau(file)
                // Ảnh nhập cũ chưa có nhãn góc thì gắn bù — xem `boSungNhanGoc`.
                return (boSungNhanGoc(file, kq), kq)
            }.value
            checking = nil
            if anh != file {
                ThumbnailCache.shared.remove(file)
                await reloadLibrary()
            }
            hienKetQua(anh, kq)
        }
    }

    /// Hiện hộp thoại tiêu chí. Luôn hiện khi NHẬN, kể cả không có cảnh báo: người dùng cần biết ảnh mẫu sẽ được chấm
    /// theo tiêu chí nào TRƯỚC khi vào màn camera.
    private func hienKetQua(_ file: URL, _ kq: PhanTichAnhMau) {
        let ten = file.deletingPathExtension().lastPathComponent
        gate = Gate(
            file: file, verdict: kq.verdict,
            profile: kq.hoSo(MediaLibrary.gocMayTheoNhan(ten), MediaLibrary.kieuChupTrenTheoNhan(ten)),
            poseGuide: kq.poseGuide, difficulty: kq.difficulty
        )
    }

    /// Bấm "Bắt đầu chụp" ở hộp thoại nhận. 🔴 Từ chối thì không có nút này — không có đường vào camera.
    func proceed() {
        guard let g = gate, case .accepted = g.verdict else { return }
        sauKhiDong = { [weak self] in self?.onPickTemplate(g.file) }
        gate = nil
    }

    /// Hộp đang mở đã đóng hẳn — làm việc đang chờ (nếu có).
    func modalDaDong() {
        let f = sauKhiDong
        sauKhiDong = nil
        f?()
    }

    // MARK: - Đề xuất theo bối cảnh (port phần `SceneStart` / `SceneStartSheet` của `KT/home/HomeScreen.kt`)

    func sceneChonCamera() {
        sauKhiDong = { [weak self] in self?.sceneStart = .camera }
        showSceneStart = false
    }

    func sceneChonThuVien() {
        sauKhiDong = { [weak self] in self?.showScenePicker = true }
        showSceneStart = false
    }

    /// Chọn xong ảnh/video trong Photo Picker → mở luồng bối cảnh khi bảng chọn đã đóng hẳn.
    func scenePicked() {
        let items = scenePickerItems
        if items.isEmpty { return }
        scenePickerItems = []
        Task {
            await UIApplication.choChuyenCanhXong()
            sceneStart = .media(items)
        }
    }

    /// Chọn một ảnh mẫu đề xuất → đóng luồng rồi chạy cổng kiểm như bấm ô lưới.
    func scenePickTemplate(_ file: URL) {
        sauKhiDong = { [weak self] in self?.selectTemplate(file) }
        sceneStart = nil
    }

    /// Không có ảnh mẫu hợp → đóng luồng rồi mở nhập ảnh mẫu.
    func sceneImport() {
        sauKhiDong = { [weak self] in self?.showPicker = true }
        sceneStart = nil
    }

    // MARK: - Nhập ảnh

    /// Ảnh người dùng vừa chọn trong Photo Picker.
    func importPicked() {
        guard let item = pickerItem else { return }
        pickerItem = nil
        importing = true
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let copied: URL? = await Task.detached { data.flatMap { Self.copyIntoLibrary($0) } }.value
            importing = false
            guard let copied else {
                importError = uiText("import_err_read")
                return
            }
            // TỰ NHẬN DIỆN TRƯỚC (08/10/2026): đủ chắc mọi câu thì gắn nhãn và vào thẳng màn chụp; thiếu chắc câu nào
            // mới mở bảng chọn — đã điền sẵn những gì đoán được. Cổng kiểm vẫn chạy (nằm trong nhận diện).
            dangNhanDien = true
            buocTienDo = (0, 0, 0, Date())
            let kq = await Task.detached {
                nhanDienNhap(copied) { tu, den, ms in
                    Task { @MainActor in self.buocTienDo = (tu, den, ms, Date()) }
                }
            }.value
            if kq.duChac {
                let luu = MediaLibrary.ganNhan(copied, kq.kieu, kq.goc, kq.canKieuTren ? kq.kieuTren : nil)
                await reloadLibrary()
                let pick = onPickTemplate
                sauKhiDong = { pick(luu) }
            } else {
                // Vòng tham chiếu VM → việc chờ → VM tự gỡ ở `modalDaDong`.
                sauKhiDong = { self.moBangNhap(copied, kq) }
            }
            // Đóng lớp chờ SAU CÙNG — việc tiếp theo chạy khi nó đóng hẳn (`modalDaDong`).
            dangNhanDien = false
        }
    }

    private func moBangNhap(_ file: URL, _ kq: KetQuaNhap) {
        nhap = Nhap(file: file, truoc: kq)
        Task {
            let preview = await Task.detached { UprightImage.decode(file, shortSide: 720) }.value
            if nhap?.file == file { nhap?.preview = preview }
        }
    }

    /// Huỷ bảng gắn nhãn — xoá file tạm.
    func nhapHuy() {
        guard let n = nhap else { return }
        try? FileManager.default.removeItem(at: n.file)
        nhap = nil
    }

    /// Ảnh bị từ chối trong bảng → chọn ảnh khác.
    func nhapChonAnhKhac() {
        sauKhiDong = { [weak self] in self?.showPicker = true }
        nhapHuy()
    }

    /// Bấm "Lưu" trong bảng: đổi tên theo nhãn rồi hiện hộp thoại tiêu chí như ảnh cài sẵn.
    func nhapLuu(_ kieu: MediaLibrary.TemplateKind, _ goc: MediaLibrary.GocMayNhan?, _ kieuTren: KieuChupTren?) {
        guard let n = nhap else { return }
        let chot = MediaLibrary.ganNhan(n.file, kieu, goc, kieuTren)
        sauKhiDong = { [weak self] in self?.hienKetQua(chot, n.truoc.phanTich) }
        nhap = nil
        Task { await reloadLibrary() }
    }

    /// Chép ảnh người dùng chọn vào thư viện ảnh mẫu.
    ///
    /// Phải CHÉP chứ không giữ tham chiếu của Photo Picker: quyền đọc ảnh gốc không bền qua các lần mở app. Chép vào
    /// `templates/` để ảnh đi đúng đường của ảnh soạn sẵn — không có nhánh riêng cho ảnh nhập.
    ///
    /// Tên tự đặt, không lấy tên gốc (có thể có dấu, khoảng trắng, trùng tên). Photo Picker đã đổi sang JPEG
    /// (`preferredItemEncoding: .compatible`).
    nonisolated private static func copyIntoLibrary(_ data: Data) -> URL? {
        let dest = MediaLibrary.templatesDir()
            .appendingPathComponent("\(MediaLibrary.tienToNhap)\(Int64(Date().timeIntervalSince1970 * 1000)).jpg")
        do {
            try data.write(to: dest, options: .atomic)
        } catch {
            log.warning("Không chép được ảnh vừa chọn: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        // Kiểm giải mã được NGAY tại đây — chép file rác rồi để lưới tự vấp về sau thì lỗi hiện ở chỗ chẳng liên quan.
        if UprightImage.decode(dest, shortSide: 64) == nil {
            try? FileManager.default.removeItem(at: dest)
            return nil
        }
        return dest
    }
}
