import AVFoundation
import SwiftUI
import UIKit

/// Khung xem trước của camera — `AVCaptureVideoPreviewLayer` bọc cho SwiftUI.
///
/// Nằm ở `Services/` vì đây là nơi duy nhất được import AVFoundation; View chỉ truyền `CaptureController` / `SceneCamera`.
///
/// - Lấp đầy ô (`resizeAspectFill`, như `FILL_CENTER` của Android): ô đã đúng tỉ lệ khung người dùng chọn, hình cắt phần
///   giữa — đúng vùng mà phép đo (`croppedToAspect`) và ảnh ra cùng cắt, nên khung xương vẽ đè trong cùng ô sẽ khớp.
/// - Camera trước tự lật (mặc định của lớp xem trước), camera sau và gương không lật — như CameraX.
/// - Xoay theo HƯỚNG GIAO DIỆN (không phải hướng máy): giao diện xoay tới đâu thì hình xem trước phải dựng đứng theo đó.
struct CameraPreviewView: UIViewRepresentable {

    private let session: AVCaptureSession

    init(controller: CaptureController) { session = controller.session }

    init(camera: SceneCamera) { session = camera.session }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.applyRotation()
    }

    final class PreviewUIView: UIView {

        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }

        private var formatObserver: NSObjectProtocol?

        override init(frame: CGRect) {
            super.init(frame: frame)
            // Đổi camera / đổi chế độ thì kết nối xem trước được dựng lại với góc mặc định — đặt lại góc.
            formatObserver = NotificationCenter.default.addObserver(
                forName: AVCaptureInput.Port.formatDescriptionDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.applyRotation() }
            }
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        deinit {
            if let formatObserver { NotificationCenter.default.removeObserver(formatObserver) }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            applyRotation()
        }

        /// Góc xoay khung xem trước theo hướng giao diện — cùng quy ước `videoRotationAngle` với `CaptureController`.
        /// `UIInterfaceOrientation.landscapeRight` (nút Home bên phải) = máy quay đỉnh sang TRÁI = góc 0°.
        func applyRotation() {
            guard let connection = previewLayer.connection else { return }
            let angle: CGFloat
            switch window?.windowScene?.effectiveGeometry.interfaceOrientation {
            case .landscapeRight: angle = 0
            case .landscapeLeft: angle = 180
            case .portraitUpsideDown: angle = 270
            default: angle = 90
            }
            if connection.videoRotationAngle != angle, connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }
}
