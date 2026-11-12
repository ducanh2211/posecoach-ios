# So sánh số đo ảnh mẫu iOS ↔ Android (bước 6a)

Mục tiêu: chứng minh bản iOS đo **giống hệt** bản Android, và đo được bao nhiêu phần lệch là do runtime (MediaPipe,
ML Kit, ONNX Runtime) chứ không phải do thuật toán.

Hai câu hỏi tách riêng:

| Câu hỏi | So cái gì | Kỳ vọng |
|---|---|---|
| **Thuật toán có giống không?** | Android tính số đo từ landmark Android ↔ iOS tính lại **từ đúng landmark đó** | **Trùng tuyệt đối** (`--tuyet-doi`, dung sai 0) |
| **Runtime lệch bao nhiêu?** | iOS chạy trên ảnh ↔ Android chạy trên ảnh | Ghi độ lệch; kiểm có đổi 🔴/🟡/🟢, lớp khung hình, nhóm góc máy không |

## Định dạng tệp (chung hai bên)

Một mảng JSON, mỗi phần tử là một ảnh mẫu cài sẵn. Mỗi phần tử gồm **phần thô** (bắt buộc) và **phần tính** (có thể
thiếu: công cụ tính lại sẽ ghi đè).

```jsonc
{
  "file": "mirror/mirror-ngang-female-001.jpg", // đường dẫn tương đối trong assets/templates — khoá ghép hai bên
  "runtime": "ios",                              // "ios" | "android"
  "w": 675, "h": 1200,                           // cỡ ảnh SAU khi dựng đúng chiều EXIF
  // --- phần thô ---
  "landmarks": [[x, y, visibility], ...],        // 33 điểm, x/y chuẩn hoá 0..1, y hướng XUỐNG; [] = không thấy người
  "world":     [[x, y, z], ...],                 // 33 điểm toạ độ thật (mét); [] nếu không có
  "face": {"yawDeg": 4.2, "eyesOpen": 0.93},     // ML Kit trên ảnh nguyên cỡ; null = không thấy mặt
  "geocalib": {"pitchDeg": 1.9, "rollDeg": 2.7, "vfovDeg": 45.6}, // null = không chạy được
  // --- phần tính ---
  "gate": {"level": "green|yellow|red", "framing": "full", "reason": "<key lý do từ chối>|null",
           "warnings": ["<key cảnh báo>", ...]},
  "measurement": {                               // null khi ảnh bị từ chối
    "framing": "full", "scale": 0.61, "centerX": 0.5, "tiltDeg": null, "elevationDeg": ..., "yawDeg": ...,
    "faceYawDeg": ..., "eyesOpen": ..., "anchorHeightMeters": ..., "elevationAnchorY": ..., "faceScale": ...,
    "tamThan": 2,
    "rollDeg": {"<RollSource>": độ}, "pitchCue": {"<PitchSource>": ...}, "perspectiveIndex": {"<PerspectiveSource>": ...},
    "poseAngles": {"<PoseGroup>": [độ | null, ...]} // NaN → null, GIỮ ĐỦ phần tử (FOOTGUNS 50)
  },
  "profile": {                                   // null khi ảnh bị từ chối
    "framing": "full",
    "active": ["huong", "xa_gan", ...],          // Criterion.key, đã sắp xếp
    "skipped": {"<Criterion.key>": "<key lý do>"},
    "poseGroups": ["spine", ...],                // đã sắp xếp
    "kieuChupTren": "<KieuChupTren>|null"
  }
}
```

- Tên trường = tên thuộc tính Kotlin (`PoseMeasurement`, `TemplateProfile`, `FaceInfo`, `GeoCalibGocMay.KetQua`).
- Tên enum (`framing`, khoá của `rollDeg` / `pitchCue` / `perspectiveIndex` / `poseAngles`, `poseGroups`,
  `kieuChupTren`) so theo **quy tắc 3b của AGENTS.md**: bỏ `_`, không phân biệt hoa thường — Android cứ ghi `FULL`,
  `BODY_3D`; iOS ghi `full`, `body3d`.
- Câu chữ (`reason`, `warnings`, `skipped`) ghi **mã câu** (`R.string.x` → tên `x`), không ghi chữ đã dịch.
- Số thực ghi đủ chữ số (không làm tròn) — so tuyệt đối cần đúng từng bit.
- Hồ sơ tiêu chí tính như màn Ảnh mẫu: `TemplateGate.check` → `TemplateProfile.from(frame, framing, CORE_VIS,
  face, gocMayNhan = MediaLibrary.gocMayTheoNhan(tên), kieuChupTren = MediaLibrary.kieuChupTrenTheoNhan(tên))`; chỉ
  dùng `face` khi ảnh qua cổng.

## Chạy

**1. iOS — xuất số liệu thô** (~3 phút, GeoCalib chiếm phần lớn). Ở thư mục `PoseCoach/`:

```bash
TEST_RUNNER_XUAT_6A=1 xcodebuild -workspace PoseCoach.xcworkspace -scheme PoseCoach \
  -destination 'platform=macOS,variant=Designed for iPad' -allowProvisioningUpdates \
  -only-testing:PoseCoachTests/XuatAnhMau6aTests test | grep XUAT_6A
# → XUAT_6A 114 ảnh → ~/Library/Containers/<…>/Data/tmp/6a-ios-anh-mau.json — chép về docs/moc/
```

Muốn số runtime của iPhone thật: chạy test đó trên iPhone, tải container (Xcode → Devices) lấy tệp ở `tmp/`.

**2. Android — xuất cùng định dạng** (D6, việc của bên Android): landmark từ `StillPoseAnalyzer` (IMAGE), mặt từ
`FaceAnalyzer` trên ảnh nguyên cỡ, GeoCalib từ `GeoCalibGocMay.phanTich`, phần tính bằng code Kotlin.

**3. Tính lại phần tính bằng code iOS** — từ landmark trong BẤT KỲ tệp nào. Ở `PoseCoach/Packages/PoseDomain`:

```bash
PARITY_6A=/duong/dan/6a-android.json swift test --filter Parity6aTest
# → 6a-android.tinh-ios.json cạnh tệp gốc
```

**4. So.** Ở thư mục gốc repo:

```bash
# Thuật toán — phải ra "Tổng khác biệt ở phần tính: 0"
python3 tools/so-sanh-parity/so_sanh.py 6a-android.json 6a-android.tinh-ios.json --tuyet-doi --ten-a Android --ten-b iOS

# Runtime — mỗi bên trên landmark của mình
python3 tools/so-sanh-parity/so_sanh.py docs/moc/6a-ios-anh-mau.tinh-ios.json 6a-android.json --ten-a iOS --ten-b Android
```

Báo cáo Markdown: (1) lệch số liệu thô — landmark, mặt, GeoCalib, **nhóm góc máy ±15° đổi**; (2) phân loại người
dùng thấy — cổng, lớp khung hình, cảnh báo, tiêu chí bật/bỏ; (3) từng trường số đo — lệch lớn nhất, số ảnh vượt dung
sai, số ảnh chỉ một bên đo được.

## Đã biết (12/11/2026)

- `docs/moc/6a-ios-anh-mau.json` + `.tinh-ios.json`: 114 ảnh, cổng 109 🟢 / 5 🟡 / 0 🔴 — khớp mốc 3a.
- ⚠️ **ML Kit Face Detection trên My Mac (Designed for iPad) KHÔNG ổn định giữa các lần mở app**: cùng 114 ảnh, số ảnh
  thấy mặt là 63, 51, 20, 13 tuỳ lần chạy (trong cùng một lần thì ổn định). Tệp xuất hiện tại có 13 ảnh thấy mặt.
  Phần `face` của iOS chạy trên Mac **không dùng để kết luận runtime**; phải kiểm trên iPhone (checklist mục G).
  Không ảnh hưởng phép so thuật toán (mặt là đầu vào, lấy từ tệp).
