import CoreGraphics
import PoseDomain
import SwiftUI

/// BẢNG GẮN NHÃN ẢNH VỪA NHẬP — hiện khi tự nhận diện chưa đủ chắc. Port `KT/home/NhapAnhSheet.kt`.
///
/// Xem ảnh → chọn nhãn → **"Lưu"** mới vào thư viện; từ đó ảnh tự nhập đi đúng đường của ảnh cài sẵn. Huỷ hoặc vuốt đóng
/// thì xoá file tạm (FOOTGUNS 86).
///
/// Khác Android: luôn nhận kết quả tự nhận diện có sẵn (`truoc`) — Home lúc nào cũng chạy `nhanDienNhap` trước khi mở
/// bảng, nên nhánh "tự phân tích lại khi không có `truoc`" của Kotlin không bao giờ chạy và không port. Đổi tên file do
/// ViewModel làm (View không đụng file).
struct NhapAnhSheet: View {

    let nhap: HomeViewModel.Nhap
    let onHuy: () -> Void
    let onChonAnhKhac: () -> Void
    let onLuu: (MediaLibrary.TemplateKind, MediaLibrary.GocMayNhan?, KieuChupTren?) -> Void

    @State private var kieu: MediaLibrary.TemplateKind
    @State private var goc: MediaLibrary.GocMayNhan?
    @State private var kieuTren: KieuChupTren?
    /// Người dùng bấm "Sửa" để xem lại cả những câu app đã tự trả lời.
    @State private var suaHet = false

    init(nhap: HomeViewModel.Nhap, onHuy: @escaping () -> Void, onChonAnhKhac: @escaping () -> Void,
         onLuu: @escaping (MediaLibrary.TemplateKind, MediaLibrary.GocMayNhan?, KieuChupTren?) -> Void) {
        self.nhap = nhap
        self.onHuy = onHuy
        self.onChonAnhKhac = onChonAnhKhac
        self.onLuu = onLuu
        _kieu = State(initialValue: nhap.truoc.kieu)
        _goc = State(initialValue: nhap.truoc.goc)
    }

    private var truoc: KetQuaNhap { nhap.truoc }
    private var hoiKieuTren: Bool { kieu == .photographer && goc == .tren }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(LocalizedStringKey("sheet_title"))
                    .font(.system(size: 20, weight: .bold))
                ZStack {
                    Ds.surfaceMuted
                    if let p = nhap.preview {
                        Image(decorative: p, scale: 1).resizable().scaledToFit()
                    } else {
                        ProgressView()
                    }
                }
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.top, 12)
                .padding(.bottom, 14)

                switch truoc.phanTich.verdict {
                case let .rejected(r):
                    Text(LocalizedStringKey("gate_rejected_title"))
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Ds.dangerText)
                    Text(r.reason).font(.system(size: 13)).padding(.top, 4)
                    Text(r.hint).font(.system(size: 13)).foregroundStyle(Ds.textMuted)
                    HStack(spacing: 10) {
                        Button(action: onHuy) { Text(LocalizedStringKey("action_cancel")).frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered)
                        Button(action: onChonAnhKhac) { Text(LocalizedStringKey("action_pick_other")).frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 16)
                case .accepted:
                    accepted
                }
            }
            .foregroundStyle(Ds.text)
            .padding(.horizontal, Ds.pageH)
            .padding(.vertical, 24)
        }
        .background(Ds.surface)
        .tint(Ds.primary)
        // Câu kiểu chụp từ trên cao hiện ra lúc nào thì chọn sẵn lúc đó (người dùng có thể đổi góc qua lại).
        .onChange(of: hoiKieuTren, initial: true) {
            if hoiKieuTren && kieuTren == nil, let g = truoc.kieuTren { kieuTren = g }
        }
    }

    // ⚠️ CHỈ HIỆN CÂU APP CHƯA CHẮC (08/10/2026). PO: câu đã tự trả lời mà vẫn hiện thì người dùng hiểu nhầm là phải chọn
    // tay. Câu đã chắc gom vào một dòng tóm tắt, bấm "Sửa" mới mở ra.
    @ViewBuilder
    private var accepted: some View {
        let chacKieu = truoc.kieuChac && !suaHet
        let chacGoc = truoc.gocChac && !suaHet
        let chacKieuTren = hoiKieuTren && truoc.kieuTren != nil && !suaHet
        let daNhan: [String] = [
            chacKieu ? tenKieu(kieu) : nil,
            chacGoc ? truoc.geo.map { moTaGoc($0.pitchDeg) } : nil,
            chacKieuTren ? kieuTren.map { UiText.res($0.nhanRes).resolved().lowercased() } : nil,
        ].compactMap { $0 }
        if !daNhan.isEmpty {
            HStack {
                Text(uiText("sheet_auto_detected", .string(daNhan.joined(separator: " · "))))
                    .font(.system(size: 13))
                Spacer()
                Button(LocalizedStringKey("action_edit")) { suaHet = true }
            }
        }
        if !chacKieu { chonKieu }
        if !chacGoc { chonGoc.padding(.top, 14) }
        if hoiKieuTren && !chacKieuTren { chonKieuTren.padding(.top, 14) }
        HStack(spacing: 10) {
            Button(action: onHuy) { Text(LocalizedStringKey("action_cancel")).frame(maxWidth: .infinity) }
                .buttonStyle(.bordered)
            Button { onLuu(kieu, goc, hoiKieuTren ? kieuTren : nil) } label: {
                Text(LocalizedStringKey("sheet_save")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(goc == nil || (hoiKieuTren && kieuTren == nil))
        }
        .padding(.top, 18)
    }

    /// Câu 1 — chụp kiểu gì. Thiếu là mở sai camera.
    private var chonKieu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("sheet_q_kind")).font(.system(size: 14, weight: .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MediaLibrary.TemplateKind.allCases, id: \.self) { k in
                        Button { kieu = k } label: {
                            Text(LocalizedStringKey(k.labelRes)).font(.system(size: 13))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(kieu == k ? Ds.primary.opacity(0.15) : Ds.surfaceMuted, in: Capsule())
                                .overlay(Capsule().stroke(kieu == k ? Ds.primary : .clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Câu 2 — máy đặt ở đâu. Hiện với MỌI ảnh: suy góc máy từ khung xương không tin được (FOOTGUNS 91). GeoCalib đo được
    /// thì chọn sẵn, người dùng vẫn xác nhận hoặc đổi.
    private var chonGoc: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey("sheet_q_angle")).font(.system(size: 14, weight: .bold))
            Group {
                if let g = truoc.geo {
                    Text(uiText("sheet_angle_measured", .string(moTaGoc(g.pitchDeg))))
                } else {
                    Text(LocalizedStringKey("sheet_angle_unknown"))
                }
            }
            .font(.system(size: 12)).foregroundStyle(Ds.textMuted)
            .padding(.bottom, 6)
            // KHUNG QUY CHUẨN nhận biết góc máy bằng mắt. Người dùng chọn, app không đoán bằng mặt/cổ/vai (trúng 59%).
            dongChon(goc == .tren, "angle_opt_high", "angle_opt_high_hint") { goc = .tren }
            dongChon(goc == .ngang, "angle_opt_level", "angle_opt_level_hint") { goc = .ngang }
            dongChon(goc == .duoi, "angle_opt_low", "angle_opt_low_hint") { goc = .duoi }
            if goc == nil {
                Text(LocalizedStringKey("sheet_pick_angle"))
                    .font(.system(size: 12)).foregroundStyle(Ds.warning).padding(.top, 4)
            }
        }
    }

    /// Câu 3 — kiểu chụp từ trên cao. Chỉ với ảnh người khác chụp, góc trên cao (FOOTGUNS 100).
    private var chonKieuTren: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey("sheet_q_high")).font(.system(size: 14, weight: .bold))
            Group {
                if let g = truoc.kieuTren {
                    Text(uiText("sheet_high_guess", .text(uiText(g.nhanRes))))
                } else {
                    Text(LocalizedStringKey("sheet_high_unknown"))
                }
            }
            .font(.system(size: 12)).foregroundStyle(Ds.textMuted)
            .padding(.bottom, 6)
            ForEach(KieuChupTren.allCases, id: \.self) { k in
                dongChon(kieuTren == k, k.nhanRes, k.goiYRes) { kieuTren = k }
            }
            if kieuTren == nil {
                Text(LocalizedStringKey("sheet_pick_high"))
                    .font(.system(size: 12)).foregroundStyle(Ds.warning).padding(.top, 4)
            }
        }
    }

    /// Một dòng chọn có nút tròn, tên và gợi ý nhận biết.
    private func dongChon(_ chon: Bool, _ ten: String, _ goiY: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: chon ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(chon ? Ds.primary : Ds.textMuted)
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey(ten)).font(.system(size: 14, weight: .semibold))
                    Text(LocalizedStringKey(goiY)).font(.system(size: 12)).foregroundStyle(Ds.textMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(chon ? Ds.primary.opacity(0.10) : Ds.surfaceMuted, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .accessibilityAddTraits(chon ? .isSelected : [])
    }

    private func moTaGoc(_ pitchDeg: Double) -> String {
        let d = Int(abs(pitchDeg).rounded())
        if pitchDeg <= -3 { return uiText("angle_desc_down", .int(d)).resolved() }
        if pitchDeg >= 3 { return uiText("angle_desc_up", .int(d)).resolved() }
        return uiText("angle_desc_level").resolved()
    }

    private func tenKieu(_ k: MediaLibrary.TemplateKind) -> String {
        switch k {
        case .photographer: uiText("kind_photographer_inline").resolved()
        case .selfie: uiText("kind_selfie_inline").resolved()
        case .mirror: uiText("kind_mirror_inline").resolved()
        case .tripod: uiText("kind_tripod_inline").resolved()
        }
    }
}
