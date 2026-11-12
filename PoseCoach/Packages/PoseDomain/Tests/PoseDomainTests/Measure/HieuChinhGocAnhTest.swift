import Testing
@testable import PoseDomain

/// Port từ `KTT/HieuChinhGocAnhTest.kt` — GÓC SUY TỪ ẢNH PHẢI ĐỔI RA GÓC MÁY THẬT (video test 15/09/2026).
///
/// Camera đọc góc bằng cảm biến, ảnh mẫu đọc bằng trục thân 3D. Không đổi thang thì ảnh mẫu chụp thẳng đọc
/// ra −16° và app bắt người chụp chúc máy theo.
struct HieuChinhGocAnhTest {

    @Test("đi qua đúng ba mốc đo được")
    func diQuaDungBaMoc() {
        #expect(isClose(Measurer.hieuChinhGocAnh(-50.0), -49.0, 1e-9))
        #expect(isClose(Measurer.hieuChinhGocAnh(-20.0), -14.0, 1e-9))
        #expect(isClose(Measurer.hieuChinhGocAnh(-8.0), 5.0, 1e-9))
    }

    @Test("ảnh cầm máy thẳng đọc ra quanh 0 độ sau khi đổi")
    func camMayThangQuanh0() {
        // Video: cảm biến −6 … −1° thì ảnh đọc −16 … −11°.
        let v = Measurer.hieuChinhGocAnh(-13.0)
        #expect((-8.0...2.0).contains(v), "\(v)")
    }

    @Test("ngoài khoảng đã đo thì chỉ tịnh tiến, không phóng đại")
    func ngoaiKhoangChiTinhTien() {
        #expect(isClose(Measurer.hieuChinhGocAnh(-60.0), -59.0, 1e-9))
        #expect(isClose(Measurer.hieuChinhGocAnh(2.0), 15.0, 1e-9))
    }

    @Test("giữ đúng thứ tự, ảnh chúc hơn thì góc thật cũng chúc hơn")
    func giuDungThuTu() {
        var truoc = -Double.infinity
        for i in -80...40 {
            let v = Measurer.hieuChinhGocAnh(Double(i))
            #expect(v > truoc)
            truoc = v
        }
    }
}
