import CoreGraphics
import Foundation
import onnxruntime_objc
import os
import PoseDomain

/// ĐO GÓC MÁY TỪ NỀN ẢNH bằng GeoCalib, chạy ngay trên điện thoại. Port từ `KT/geocalib/GeoCalibGocMay.kt`.
///
/// Mô hình đọc NỀN (chân trời, cạnh tường, mặt sàn), nên không bị dáng người làm sai như cách đọc trục thân (FOOTGUNS
/// 91). Hai phần: mạng nơ-ron (ONNX int8 29 MB trong `geocalib/`) sinh bản đồ phối cảnh, rồi `GiaiPhoiCanh` (PoseDomain)
/// giải ra độ chúc / vẹo / góc mở.
///
/// Android đo trên máy tính, 28 khung có đáp án cảm biến: sai trung bình 4,6°. ⚠️ CHƯA đo trên điện thoại; yếu ở ảnh
/// chúc rất gắt và cầu thang.
///
/// Trọng số GeoCalib: CC BY 4.0 — phải ghi công (cvg/GeoCalib, Laval Indoor HDR) trong app khi phát hành.
///
/// Chặn luồng, vài giây — gọi từ luồng nền. Dùng chung một phiên mô hình.
///
/// Khác Android: đọc model thẳng từ bundle (Android phải chép ra `filesDir`). Thu nhỏ bằng Core Graphics song tuyến,
/// vẫn từng nấc một nửa như Android — chênh nhỏ so với `createScaledBitmap(filter = true)`, đo ở 6a.
nonisolated enum GeoCalibGocMay {

    struct KetQua: Equatable {
        let pitchDeg: Double
        let rollDeg: Double
        let vfovDeg: Double
        let thoiGianMs: Int64
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PoseCoach", category: "GeoCalib")
    private static let tenTep = "geocalib-mang-int8"
    /// Cạnh ngắn sau khi thu nhỏ — đúng như GeoCalib gốc.
    private static let canhNgan = 320
    private static let boiSo = 32

    private static let khoa = NSLock()
    private nonisolated(unsafe) static var phien: ORTSession?
    private nonisolated(unsafe) static var hong = false

    private static func layPhien() -> ORTSession? {
        khoa.lock()
        defer { khoa.unlock() }
        if let phien { return phien }
        if hong { return nil }
        let url = Bundle.main.url(forResource: tenTep, withExtension: "onnx", subdirectory: "geocalib")
            ?? Bundle.main.url(forResource: tenTep, withExtension: "onnx")
        phien = taoPhien(url)
        if phien == nil { hong = true }
        return phien
    }

    /// Tạo phiên mô hình. `nil` (đã ghi log) khi không có file hoặc ONNX Runtime không nạp được.
    static func taoPhien(_ url: URL?) -> ORTSession? {
        guard let url else {
            log.error("Không nạp được mô hình GeoCalib: không có file \(tenTep).onnx trong bundle")
            return nil
        }
        do {
            let env = try ORTEnv(loggingLevel: .warning)
            let tuyChon = try ORTSessionOptions()
            // 2 luồng: chạy được song song với nhận diện khung xương mà không làm giật màn chụp.
            try tuyChon.setIntraOpNumThreads(2)
            return try ORTSession(env: env, modelPath: url.path, sessionOptions: tuyChon)
        } catch {
            log.error("Không nạp được mô hình GeoCalib: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// `nil` khi không nạp được mô hình hoặc ảnh quá nhỏ. Không bao giờ ném lỗi.
    static func phanTich(_ anh: CGImage) -> KetQua? {
        guard let s = layPhien() else { return nil }
        return phanTich(anh, s)
    }

    static func phanTich(_ anh: CGImage, _ s: ORTSession) -> KetQua? {
        let bd = ProcessInfo.processInfo.systemUptime
        guard let (chw, h, w) = tienXuLy(anh) else { return nil }
        do {
            let data = chw.withUnsafeBufferPointer { NSMutableData(bytes: $0.baseAddress, length: $0.count * MemoryLayout<Float>.size) }
            let vao = try ORTValue(tensorData: data, elementType: .float, shape: [1, 3, NSNumber(value: h), NSNumber(value: w)])
            // Thứ tự đầu ra như Kotlin `ra.get(0..3)`: up, độ tin up, vĩ độ, độ tin vĩ độ.
            let ten = try s.outputNames()
            guard ten.count >= 4 else {
                log.warning("GeoCalib chạy hỏng: mô hình có \(ten.count) đầu ra, cần 4")
                return nil
            }
            let ra = try s.run(withInputs: ["image": vao], outputNames: Set(ten), runOptions: nil)
            func mang(_ i: Int) throws -> [Float] {
                guard let v = ra[ten[i]] else { throw NSError(domain: "GeoCalib", code: 1) }
                let d = try v.tensorData() as Data
                return d.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
            }
            let cam = GiaiPhoiCanh.giai(try mang(0), try mang(1), try mang(2), try mang(3), h, w)
            return KetQua(pitchDeg: cam.pitchDeg, rollDeg: cam.rollDeg, vfovDeg: cam.vfovDeg,
                          thoiGianMs: Int64((ProcessInfo.processInfo.systemUptime - bd) * 1000))
        } catch {
            log.warning("GeoCalib chạy hỏng: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Giống `ImagePreprocessor` của GeoCalib: cạnh ngắn = 320, cắt giữa về bội số 32, RGB trong [0, 1], bố cục
    /// [3, h, w]. Không trừ trung bình — mạng tự chuẩn hoá.
    ///
    /// Thu nhỏ từng nấc một nửa trước khi tới cỡ đích, để gần với thu nhỏ có khử răng cưa của bản gốc — thu thẳng một lần
    /// từ ảnh to thì mất chi tiết đường thẳng.
    static func tienXuLy(_ goc: CGImage) -> ([Float], Int, Int)? {
        if min(goc.width, goc.height) < boiSo { return nil }
        let k = Double(canhNgan) / Double(min(goc.width, goc.height))
        let nw = Int((Double(goc.width) * k).rounded())
        let nh = Int((Double(goc.height) * k).rounded())
        var b = goc
        while b.width / 2 >= nw && b.height / 2 >= nh {
            guard let next = scaled(b, b.width / 2, b.height / 2) else { return nil }
            b = next
        }
        if b.width != nw || b.height != nh {
            guard let next = scaled(b, nw, nh) else { return nil }
            b = next
        }
        let w = (nw / boiSo) * boiSo
        let h = (nh / boiSo) * boiSo
        let x0 = (nw - w) / 2
        let y0 = (nh - h) / 2
        guard let px = rgba(b) else { return nil }
        var ra = [Float](repeating: 0, count: 3 * w * h)
        let m = w * h
        for y in 0..<h {
            for x in 0..<w {
                let src = ((y0 + y) * nw + (x0 + x)) * 4
                let i = y * w + x
                ra[i] = Float(px[src]) / 255
                ra[m + i] = Float(px[src + 1]) / 255
                ra[2 * m + i] = Float(px[src + 2]) / 255
            }
        }
        return (ra, h, w)
    }

    /// Thu nhỏ song tuyến (tương đương `createScaledBitmap(…, filter = true)`).
    private static func scaled(_ img: CGImage, _ w: Int, _ h: Int) -> CGImage? {
        guard let ctx = context(w, h, nil) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    /// Điểm ảnh RGBA 8 bit, hàng đầu tiên là đỉnh ảnh.
    private static func rgba(_ img: CGImage) -> [UInt8]? {
        var px = [UInt8](repeating: 0, count: img.width * img.height * 4)
        let ok = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = context(img.width, img.height, buf.baseAddress) else { return false }
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
            return true
        }
        return ok ? px : nil
    }

    private static func context(_ w: Int, _ h: Int, _ data: UnsafeMutableRawPointer?) -> CGContext? {
        CGContext(
            data: data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    }
}
