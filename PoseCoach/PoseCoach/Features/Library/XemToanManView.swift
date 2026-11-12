import PoseDomain
import SwiftUI

/// XEM TOÀN MÀN HÌNH: vuốt ngang chuyển ảnh, chụm hai ngón phóng to, "‹" để đóng. Port `XemToanMan` + `AnhPhongTo` của
/// `KT/library/LibraryScreen.kt`.
///
/// Khác Android: trang cuộn bằng `ScrollView` phân trang (iOS 17) thay `HorizontalPager`; đang phóng to thì khoá cuộn
/// trang, như `userScrollEnabled = !dangPhong`.
struct XemToanManView: View {

    let trang: [URL]
    let album: ResultLibrary.Album
    let onClose: () -> Void

    @State private var trangHienTai: Int?
    @State private var dangPhong = false

    init(trang: [URL], batDau: Int, album: ResultLibrary.Album, onClose: @escaping () -> Void) {
        self.trang = trang
        self.album = album
        self.onClose = onClose
        _trangHienTai = State(initialValue: batDau)
    }

    var body: some View {
        let i = min(max(trangHienTai ?? 0, 0), max(trang.count - 1, 0))
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(trang.enumerated()), id: \.offset) { k, f in
                        AnhPhongTo(file: f, onPhong: { if k == i { dangPhong = $0 } })
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(k)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $trangHienTai)
            .scrollIndicators(.hidden)
            .scrollDisabled(dangPhong)
            .ignoresSafeArea()

            HStack(spacing: 0) {
                Button(action: onClose) {
                    Text(verbatim: "‹").font(.system(size: 28)).padding(.horizontal, 12).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(LocalizedStringKey("action_back")))
                Group {
                    if let n = nhan(i) { Text(n) } else { Text(verbatim: "") }
                }
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: "\(i + 1)/\(trang.count)")
                    .font(.system(size: 13)).foregroundStyle(Color(argb: 0xB3FFFFFF))
            }
            .foregroundStyle(.white)
            .padding(8)
        }
        .statusBarHidden()
    }

    private func nhan(_ i: Int) -> UiText? {
        guard i < trang.count else { return nil }
        let f = trang[i]
        if f == album.templateThumb { return uiText("library_template") }
        return album.scoreOf(f).map { uiText("library_score", .int($0)) }
    }
}

/// Ảnh phóng to được bằng hai ngón (1–5 lần). Một ngón chỉ kéo ảnh khi ĐANG phóng to — lúc ảnh vừa khít màn hình thì
/// nhường cử chỉ vuốt cho việc chuyển ảnh.
private struct AnhPhongTo: View {

    let file: URL
    let onPhong: (Bool) -> Void

    @State private var image: CGImage?
    @State private var ti: CGFloat = 1
    @State private var tiBatDau: CGFloat?
    @State private var dich: CGSize = .zero
    @State private var dichBatDau: CGSize?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFit()
                        .scaleEffect(ti)
                        .offset(dich)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(phong)
            .simultaneousGesture(keo, including: ti > 1 ? .all : .subviews)
            .task(id: file) {
                let side = max(Int(min(geo.size.width, geo.size.height) * displayScale), 320)
                let f = file
                image = await Task.detached { UprightImage.decode(f, shortSide: side) }.value
            }
        }
    }

    private var phong: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                let goc = tiBatDau ?? ti
                tiBatDau = goc
                ti = min(max(goc * v.magnification, 1), 5)
                if ti <= 1 { dich = .zero }
                onPhong(ti > 1)
            }
            .onEnded { _ in tiBatDau = nil }
    }

    private var keo: some Gesture {
        DragGesture()
            .onChanged { v in
                let goc = dichBatDau ?? dich
                dichBatDau = goc
                dich = CGSize(width: goc.width + v.translation.width, height: goc.height + v.translation.height)
            }
            .onEnded { _ in dichBatDau = nil }
    }
}
