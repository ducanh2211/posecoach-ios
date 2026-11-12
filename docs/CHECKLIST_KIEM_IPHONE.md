# Checklist kiểm trên iPhone thật

> Ghi 12/11/2026. Đã có máy để build nhưng **chưa chạy** — người dùng chưa có thời gian, cho làm tiếp 4c.
> Kiểm xong mục nào thì đánh dấu `[x]` ở đây, cập nhật mục "⏳ Việc chờ iPhone thật" trong `PLAN_PORT_IOS.md`.
> Mỗi lỗi ghi lại: ảnh chụp màn hình, cách tái hiện, đời máy và bản iOS. App sập → chạy từ Xcode, chép log ở khung debug.

## A. Cài app lên iPhone

1. Cắm iPhone vào Mac, mở khoá, bấm **Trust This Computer**.
2. iPhone: **Settings → Privacy & Security → Developer Mode** → bật (máy khởi động lại, chọn Turn On).
3. Mac: `cd PoseCoach && pod install` (nếu máy chưa có `Pods/`), mở **`PoseCoach.xcworkspace`** (không mở `.xcodeproj`).
4. Xcode: chọn đích là iPhone, **Signing & Capabilities** → Team = Personal Team `S7WPNU5HBB`, bấm ⌘R.
5. Lần đầu báo "Untrusted Developer": iPhone **Settings → General → VPN & Device Management** → Trust tài khoản dev, chạy
   lại. App ký Personal Team dùng được 7 ngày — hết hạn thì build lại.
6. Cho phép camera khi app hỏi.

**Vào màn chụp** (từ 4b không còn nút tạm "Start shooting"): tab Ảnh mẫu → bấm một ảnh mẫu → hộp tiêu chí →
**Bắt đầu chụp**. Nhóm ảnh mẫu quyết định camera mở trước: ảnh thường (người khác chụp) → camera sau; ảnh `selfie-…` →
camera trước. Nút xoay camera đổi qua lại.

## B. Camera 3b (commit `b7df6d3`, `f662454`)

### 1. Khung xương chồng khít người thật

| | Cầm dọc | Cầm ngang (cả 2 chiều xoay) |
|---|---|---|
| Camera sau | - [ ] | - [ ] |
| Camera trước | - [ ] | - [ ] ← dễ sai nhất |

- Camera trước cầm ngang mà khung xương **lộn 180°** = bảng `CaptureController.orientationForAnalysis` sai cho camera
  trước (đang giả định `videoRotationAngle` cùng nghĩa hai camera). Ghi lại xoay trái hay xoay phải.
- Lệch / lật gương → chụp màn hình.

### 2. Chụp và quay

- [ ] Chế độ Ảnh: một lần bấm ra đủ **8 ảnh**
- [ ] Chế độ Video: chưa đủ **3 s** thì không dừng được; tới **30 s** tự dừng

### 3. Ảnh và video ra đúng chiều

Chụp / quay vài lượt (mỗi camera, dọc + ngang). Xcode → **Window → Devices and Simulators** → chọn iPhone →
Installed Apps → PoseCoach → **⋯ → Download Container** → chuột phải file tải về → **Show Package Contents** →
`AppData/Library/Caches/`:

- [ ] `burst/`: ảnh đứng đúng chiều
- [ ] `recordings/`: video phát đúng chiều
- [ ] Camera trước: ảnh và video lật gương **giống khung xem trước** lúc quay

### 4–5. Dời sang 4c

- [ ] `verticalFovDeg` trên máy nhiều ống kính (giả định `videoFieldOfView` là góc ở `videoZoomFactor` 1 = ống 0,5x)
- [ ] Dấu `pitch` / `roll` của `DeviceTilt`

Chưa màn nào hiện hai số này (không thêm code debug tạm) — kiểm qua câu hướng dẫn góc máy sau khi xong 4c.

## C. Màn Ảnh mẫu 4b (commit `29f5830`)

- [ ] Lưới cuộn mượt, thumbnail hiện dần theo ô, lần mở đầu không trắng màn lâu
- [ ] Chip lọc đổi lưới theo nhóm; bấm lại chip đang chọn → về "Tất cả"
- [ ] Bấm ảnh: ô hiện "đang kiểm" ~1–2 s → hộp tiêu chí → **Bắt đầu chụp** vào được màn chụp
- [ ] Nhập ảnh — thử ~3 ảnh khác kiểu (selfie, chụp gương, người khác chụp toàn thân):
  - [ ] Popup % hiện **ngay** sau khi chọn ảnh ⚠️ chỗ dễ lỗi nhất: không hiện, hoặc kẹt không tắt
  - [ ] Ảnh app chắc chắn → vào thẳng màn chụp
  - [ ] Ảnh chưa chắc → bảng chỉ hỏi câu chưa chắc; **Sửa** hiện đủ câu; **Lưu** → hộp tiêu chí
  - [ ] Vuốt đóng bảng / Huỷ → ảnh **không** nằm lại trong lưới
- [ ] Nhập ảnh không có người (phong cảnh) → báo từ chối kèm lý do + gợi ý

## Còn treo bên Android (đã báo người dùng, chưa kiểm)

Ô xem trước DỌC khi giao diện ngang, trong khi khung đo cắt NGANG.
