import CoreGraphics
import Foundation
import PoseDomain

/// TỰ NHẬN DIỆN ẢNH VỪA NHẬP — để vào thẳng màn chụp khi không cần hỏi gì (08/10/2026). Port `KT/home/NhanDienNhap.kt`.
///
/// PO: *"nếu k cần tự chọn gì thì nhảy vào trong màn camera luôn, còn nếu case ảnh k xác định được mới mở bảng chọn"*.
///
/// | Câu hỏi | Nguồn | Chắc khi |
/// |---|---|---|
/// | Kiểu chụp | ML Kit gắn nhãn ("Mobile phone", "Selfie") + lớp khung hình | nhãn rõ, hoặc toàn thân không có dấu hiệu tự chụp |
/// | Góc máy | GeoCalib (đọc nền) | đo được và không sát mốc ±15° |
/// | Kiểu chụp từ trên cao | GeoCalib góc mở + đầu so với chân | `DoanKieuTren` trả kết quả |
///
/// ⚠️ Các mốc của luật kiểu chụp CHƯA đo trên bộ ảnh nào — phải kiểm trên điện thoại. Ngưỡng nằm trong file này như
/// Kotlin (D8), không đưa vào `GuidanceConfig`.
///
/// Chặn luồng, vài giây — gọi từ luồng nền.
nonisolated struct KetQuaNhap {
    let phanTich: PhanTichAnhMau
    let geo: GeoCalibGocMay.KetQua?
    let kieu: MediaLibrary.TemplateKind
    let kieuChac: Bool
    let goc: MediaLibrary.GocMayNhan?
    let gocChac: Bool
    let kieuTren: KieuChupTren?

    /// Có phải hỏi thêm câu "chụp từ trên cao kiểu nào" không.
    var canKieuTren: Bool { kieu == .photographer && goc == .tren }

    /// Đủ chắc để vào thẳng màn chụp, không mở bảng chọn.
    var duChac: Bool {
        guard case .accepted = phanTich.verdict else { return false }
        return kieuChac && gocChac && goc != nil && (!canKieuTren || kieuTren != nil)
    }
}

/// Nhãn "Mobile phone" từ mức này: chụp gương. Ảnh gương gần như luôn thấy điện thoại.
private let nhanGuong: Float = 0.5
/// Nhãn "Selfie" từ mức này: selfie cam trước.
private let nhanSelfie: Float = 0.6
/// Dưới mức này coi như "không có". Giữa hai mốc là vùng không chắc.
private let nhanKhong: Float = 0.3
/// Góc GeoCalib cách mốc ±15° ít hơn chừng này thì không chắc là nhóm nào.
private let cachMocGoc = 4.0

/// Báo tiến độ: đi từ `tu` tới `den` (0..1), ước chừng `uocMs` mili giây. Giao diện tự chạy mượt trong khoảng đó —
/// bước GeoCalib mất vài giây mà không báo được tiến độ bên trong.
typealias TienDo = @Sendable (_ tu: Float, _ den: Float, _ uocMs: Int) -> Void

nonisolated func nhanDienNhap(_ file: URL, _ tienDo: TienDo = { _, _, _ in }) -> KetQuaNhap {
    tienDo(0, 0.35, 1500)
    let pt = phanTichAnhMau(file)
    var bmp: CGImage?
    if case .accepted = pt.verdict { bmp = UprightImage.decode(file) }
    tienDo(0.35, 0.45, 600)
    let nhan = bmp.map { ImageLabels.of($0) } ?? [:]
    tienDo(0.45, 0.97, 4000)
    let geo = bmp.flatMap { GeoCalibGocMay.phanTich($0) }

    let dienThoai = nhan["Mobile phone"] ?? 0
    let selfie = nhan["Selfie"] ?? 0
    let tayNgoai = pt.coTayNgoaiKhung
    let canh = pt.framing == .head || pt.framing == .chest
    // Thứ tự quan trọng: thấy ĐIỆN THOẠI là chụp gương dù tay ra ngoài khung hay không.
    let (kieu, kieuChac): (MediaLibrary.TemplateKind, Bool)
    if dienThoai >= nhanGuong {
        (kieu, kieuChac) = (.mirror, true)
    } else if selfie >= nhanSelfie {
        (kieu, kieuChac) = (.selfie, true)
    } else if tayNgoai == 2 && pt.framing != .full {
        // Tự cầm máy: cả hai cổ tay ra ngoài khung (đo: selfie 5/7, người khác chụp 0/8).
        (kieu, kieuChac) = (.selfie, true)
    } else if tayNgoai == 0 && dienThoai < nhanKhong && selfie < nhanKhong {
        // Hai tay thấy trọn, không điện thoại, không giống selfie → người khác chụp (đo: 6/8, selfie 0/7).
        (kieu, kieuChac) = (.photographer, true)
    } else if tayNgoai == 1 && canh {
        // Không chắc: đoán gần đúng, bảng chọn mở ra để xác nhận.
        (kieu, kieuChac) = (.selfie, false)
    } else if canh {
        (kieu, kieuChac) = (.selfie, false)
    } else {
        (kieu, kieuChac) = (.photographer, false)
    }

    let goc = geo.map(nhomGoc)
    let gocChacV = geo.map(gocChac) ?? false

    let kieuTren: KieuChupTren? = (kieu == .photographer && goc == .tren) ? DoanKieuTren.doan(geo?.vfovDeg, pt.taiChan) : nil

    tienDo(0.97, 1, 150)
    return KetQuaNhap(phanTich: pt, geo: geo, kieu: kieu, kieuChac: kieuChac, goc: goc, gocChac: gocChacV, kieuTren: kieuTren)
}

/// Góc GeoCalib → một trong ba nhãn. Mốc ±15° nằm giữa nhãn "ngang" (0°) và "trên/dưới" (−35°/+25°).
nonisolated func nhomGoc(_ geo: GeoCalibGocMay.KetQua) -> MediaLibrary.GocMayNhan { nhomTuGoc(geo.pitchDeg) }

/// `nhomTuGoc` của `NhapAnhSheet.kt` — cùng mốc với `nhomGoc`.
nonisolated func nhomTuGoc(_ pitchDeg: Double) -> MediaLibrary.GocMayNhan {
    if pitchDeg <= -15 { return .tren }
    if pitchDeg >= 15 { return .duoi }
    return .ngang
}

private nonisolated func gocChac(_ geo: GeoCalibGocMay.KetQua) -> Bool { abs(abs(geo.pitchDeg) - 15.0) >= cachMocGoc }

/// GẮN BÙ NHÃN GÓC cho ảnh tự nhập từ TRƯỚC khi có bước tự đoán (10/10/2026).
///
/// Ảnh nhập từ trước không có nhãn góc thì hồ sơ bỏ hai mục góc máy (FOOTGUNS 91). Đoán bằng đúng cách bước nhập ảnh
/// đang dùng, CHỈ khi chắc; rồi đổi tên file để lần sau khỏi đoán lại. Không chắc thì để nguyên — gắn sai nhóm tệ hơn
/// không gắn.
///
/// Chặn luồng vài giây. Trả file mới (hoặc nguyên file).
nonisolated func boSungNhanGoc(_ file: URL, _ pt: PhanTichAnhMau) -> URL {
    if !MediaLibrary.laAnhNhap(file) { return file }
    let ten = file.deletingPathExtension().lastPathComponent
    if MediaLibrary.gocMayTheoNhan(ten) != nil { return file }
    guard case .accepted = pt.verdict else { return file }
    guard let bmp = UprightImage.decode(file), let geo = GeoCalibGocMay.phanTich(bmp) else { return file }
    if !gocChac(geo) { return file }
    let goc = nhomGoc(geo)
    let kind = MediaLibrary.TemplateKind.of(file.lastPathComponent)
    let kieuTren: KieuChupTren? = (kind == .photographer && goc == .tren) ? DoanKieuTren.doan(geo.vfovDeg, pt.taiChan) : nil
    return MediaLibrary.ganNhan(file, kind, goc, kieuTren)
}
