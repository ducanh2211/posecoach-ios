import Foundation
import Testing
@testable import PoseDomain

/// `gocMayTuCamBien` — đoạn thay góc máy suy từ ảnh bằng số CẢM BIẾN trong `CaptureViewModel.onLiveFrame` (Kotlin).
struct GocMayCamBienTest {

    private func doAnh(anchorY: Double?) -> PoseMeasurement {
        PoseMeasurement(
            framing: .full, scale: 0.6, centerX: 0.5, tiltDeg: -14, elevationDeg: -20, yawDeg: 3,
            faceYawDeg: nil, eyesOpen: nil, anchorHeightMeters: nil,
            rollDeg: [:], pitchCue: [.gocMay: -14], perspectiveIndex: [:], poseAngles: [:],
            elevationAnchorY: anchorY
        )
    }

    @Test func thayDoNghiengNguonGocMayVaTinhLaiGocNhin() {
        let m = doAnh(anchorY: 0.3).gocMayTuCamBien(-8, 60)
        #expect(m.tiltDeg == -8)
        #expect(m.pitchCue[.gocMay] == -8)
        #expect(m.elevationDeg == Measurer.gocNhin(-8, 0.3, 60))
        // Các số đo khác giữ nguyên.
        #expect(m.scale == 0.6 && m.yawDeg == 3)
    }

    @Test func khongCoMocThiGocNhinTheoHamGocNhin() {
        let m = doAnh(anchorY: nil).gocMayTuCamBien(5, 60)
        #expect(m.tiltDeg == 5)
        #expect(m.elevationDeg == Measurer.gocNhin(5, nil, 60))
    }
}
