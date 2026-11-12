import PoseDomain
import SwiftUI

/// MỘT LẦN CHỤP: trên cùng là cặp "Mẫu | Ảnh của bạn" đặt ngang nhau, bên dưới các ảnh còn lại theo điểm. Bấm ảnh nào là
/// mở toàn màn hình. Port `AlbumScreen` của `KT/library/LibraryScreen.kt`.
struct AlbumView: View {

    let album: ResultLibrary.Album
    let onDelete: () -> Void
    let onClose: () -> Void

    /// Trang bắt đầu khi xem toàn màn hình. `nil` = không xem.
    @State private var xemTu: XemTu?

    private struct XemTu: Identifiable {
        let id: Int
    }

    /// Danh sách xem toàn màn hình: ảnh mẫu (nếu có) rồi tới các ảnh chụp.
    private var trang: [URL] { (album.templateThumb.map { [$0] } ?? []) + album.photos }
    private var lechMau: Int { album.templateThumb != nil ? 1 : 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: onClose) {
                    Text(verbatim: "‹").font(.system(size: 26)).padding(.horizontal, 12).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(LocalizedStringKey("action_back")))
                Text(verbatim: LibraryViewModel.formatTime(album.createdAtMs))
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onDelete) {
                    Text(LocalizedStringKey("library_delete_session")).font(.system(size: 14)).foregroundStyle(Ds.dangerText)
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    // --- Cặp đối chiếu ---
                    if let t = album.templateThumb {
                        anhCoNhan(t, uiText("library_template")) { xemTu = XemTu(id: 0) }
                    }
                    if let best = album.photos.first {
                        anhCoNhan(best, Self.nhanAnh(album, best, laAnhTotNhat: true)) { xemTu = XemTu(id: lechMau) }
                    }
                }
                // --- Các ảnh còn lại, điểm thấp dần ---
                if album.photos.count > 1 {
                    Text(LocalizedStringKey("library_others"))
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Ds.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 16)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(Array(album.photos.dropFirst().enumerated()), id: \.element) { i, f in
                            anhCoNhan(f, Self.nhanAnh(album, f, laAnhTotNhat: false)) { xemTu = XemTu(id: lechMau + i + 1) }
                        }
                    }
                }
            }
            .contentMargins(12, for: .scrollContent)
        }
        .foregroundStyle(Ds.text)
        .background(Ds.bg)
        .fullScreenCover(item: $xemTu) { x in
            XemToanManView(trang: trang, batDau: x.id, album: album) { xemTu = nil }
        }
    }

    static func nhanAnh(_ album: ResultLibrary.Album, _ f: URL, laAnhTotNhat: Bool) -> UiText? {
        let diem = album.scoreOf(f)
        switch (laAnhTotNhat, diem) {
        case let (true, d?): return uiText("library_yours_score", .int(d))
        case (true, nil): return uiText("library_yours")
        case let (false, d?): return uiText("library_score", .int(d))
        case (false, nil): return nil
        }
    }

    private func anhCoNhan(_ file: URL, _ nhan: UiText?, _ onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            AsyncThumb(file: file)
                .aspectRatio(0.75, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    if let nhan {
                        Text(nhan)
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(argb: 0xCC000000), in: Capsule())
                            .padding(6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Ds.rSmall))
        }
        .buttonStyle(.plain)
    }
}
