import PoseDomain
import SwiftUI

/// THƯ VIỆN — mọi lần chụp đã lưu, xem lại bất cứ lúc nào. Port `KT/library/LibraryScreen.kt`.
///
/// Mỗi lần chụp mang theo ẢNH MẪU (17/10/2026, PO): mở ra là ảnh mẫu đặt NGANG ảnh giống mẫu nhất để đối chiếu, các ảnh
/// điểm thấp hơn xếp bên dưới; bấm ảnh nào là xem toàn màn hình.
///
/// ⚠️ Ở đây chỉ có **ảnh kết quả**. Video thô và loạt ảnh gốc đã bị xoá ngay sau khi lọc xong — luật cứng.
///
/// Khác Android: ảnh tải qua `ThumbnailCache` (thay Coil, D5). Chưa nạp xong lần đầu thì không hiện "thư viện trống".
struct LibraryView: View {

    @State private var vm = LibraryViewModel()

    var body: some View {
        Group {
            if vm.loaded && vm.albums.isEmpty {
                VStack(spacing: 6) {
                    Text(LocalizedStringKey("library_empty")).font(.system(size: 16, weight: .bold))
                    Text(LocalizedStringKey("library_empty_hint")).font(.system(size: 13)).foregroundStyle(Ds.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Ds.pageH)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                        ForEach(vm.albums, id: \.dir) { album in
                            Button { vm.open = album } label: { AlbumCell(album: album) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .foregroundStyle(Ds.text)
        .background(Ds.bg)
        .task { await vm.reload() }
        .fullScreenCover(item: openBinding) { album in
            AlbumView(album: album, onDelete: { vm.confirmDelete = album }, onClose: { vm.open = nil })
                // Hộp hỏi xoá gắn vào màn đang hiện (màn xem buổi) — gắn ở lưới thì bị lớp toàn màn hình che.
                .alert(LocalizedStringKey("library_delete_title"), isPresented: confirmBinding) {
                    Button(role: .destructive, action: vm.deleteConfirmed) { Text(LocalizedStringKey("action_delete")) }
                    Button(role: .cancel) { vm.confirmDelete = nil } label: { Text(LocalizedStringKey("action_keep")) }
                } message: {
                    let n = vm.confirmDelete?.count ?? 0
                    Text(UiText.plural("library_delete_body", count: n, [.int(n)]))
                }
        }
    }

    private var openBinding: Binding<ResultLibrary.Album?> {
        Binding(get: { vm.open }, set: { vm.open = $0 })
    }

    private var confirmBinding: Binding<Bool> {
        Binding(get: { vm.confirmDelete != nil }, set: { if !$0 { vm.confirmDelete = nil } })
    }
}

nonisolated extension ResultLibrary.Album: Identifiable {
    var id: URL { dir }
}

/// Ô lưới: ảnh mẫu ghép đôi với ảnh giống mẫu nhất — lướt là biết chụp theo mẫu nào.
private struct AlbumCell: View {

    let album: ResultLibrary.Album

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if let t = album.templateThumb { AsyncThumb(file: t) }
                    if let best = album.photos.first { AsyncThumb(file: best) }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .aspectRatio(1.2, contentMode: .fit)
            .background(.black)
            HStack {
                Text(verbatim: LibraryViewModel.formatTime(album.createdAtMs))
                Spacer()
                Text(UiText.plural("photos_n", count: album.count, [.int(album.count)]))
            }
            .font(.system(size: 11)).foregroundStyle(Ds.textMuted)
            .padding(8)
        }
        .background(Ds.surface)
        .clipShape(RoundedRectangle(cornerRadius: Ds.rSmall))
        .contentShape(RoundedRectangle(cornerRadius: Ds.rSmall))
    }
}
