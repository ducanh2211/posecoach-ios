# PLAN — Port PoseCoach từ Android sang iOS

> Lập 11/11/2026 trên Android commit `ea3d869` (`shared/posecoach`, nhánh `phuong-an-tich-hop`).
> Bản 2 (cùng ngày): bổ sung sau khi đọc hết tài liệu Android (FOOTGUNS, TONG_QUAN, NGUONG, THAY_DOI, tài liệu
> GeoCalib / 3D, `tai-lieu-goc/`) và kiểm chéo với code.
> Quy tắc chung, stack, cấu trúc thư mục: `AGENTS.md`. File này nói **làm gì, theo thứ tự nào, xong khi nào**.

## Cách dùng file này

- Làm **đúng thứ tự phase / bước**. Mỗi bước kết thúc ở **⏸ điểm dừng** — báo kết quả, chờ duyệt rồi mới sang bước sau.
- Xong một bước: tick checklist, cập nhật bảng **Trạng thái**, ghi ngày. Commit theo bước.
- Gặp việc lệch plan → **dừng, báo**, sửa plan trước rồi mới làm.
- Android cập nhật (kéo submodule mới) → `git diff <commit cũ>..<commit mới> -- app/` bên shared, ghi vào mục cuối.

Viết tắt: **PD/** = `PoseCoach/Packages/PoseDomain/Sources/PoseDomain/` · **PDT/** = `…/PoseDomain/Tests/PoseDomainTests/`
· **App/** = `PoseCoach/PoseCoach/` · **KT/** = `shared/posecoach/app/app/src/main/java/com/example/posecoach/`
· **KTT/** = `shared/posecoach/app/app/src/test/java/com/example/posecoach/` · **FG n** = mục n của `shared/posecoach/FOOTGUNS.md`

## Trạng thái

| Phase | Nội dung | Trạng thái | Ngày |
|---|---|---|---|
| 0 | Nền: tài nguyên, đa ngôn ngữ, quyền, khung app | ⬜ | |
| 1 | PoseDomain — hình học, đo đạc, hồ sơ ảnh mẫu | ⬜ | |
| 2 | PoseDomain — hướng dẫn, cổng kiểm, chọn ảnh | ⬜ | |
| 3 | Services — MediaPipe, camera, cảm biến, ML Kit, GeoCalib, media | ⬜ | |
| 4 | Luồng chính — Home / nhập ảnh → cổng kiểm → Capture → Result | ⬜ | |
| 5 | Phần phụ — Library, Scene, Settings | ⬜ | |
| 6 | Đối chiếu với Android + đo trên máy thật | ⬜ | |

Ký hiệu: ⬜ chưa làm · 🔶 đang làm · ✅ xong · ⛔ bị chặn (ghi lý do)

---

## Nguồn sự thật — tin cái gì khi chúng nói khác nhau

1. **Code Kotlin đang chạy** (không phải comment — comment trong code có chỗ đã cũ, vd. `GuidanceConfig.kt:174` ghi
   `ELEVATION -> 6.0` nhưng `theoLop(...)` ghi đè thành 10°; `TemplateProfile.kt` vừa ghi ROLL "xuống cuối" vừa "đặt đầu").
2. **Test Kotlin** — khoá hành vi.
3. `shared/posecoach/THAY_DOI_NHANH_THUAT_TOAN.md` — mô tả hành vi gần code nhất (16/09 → 10/2026).
4. `shared/posecoach/FOOTGUNS.md` — các mục bị mục sau thay: 7, 34, 55, 61, 62, 63, 70, 74, 87, 89, 97 (xem từng mục).
5. `shared/posecoach/CLAUDE.md` (mục thông tin dự án).
6. `TONG_QUAN_DU_AN.md`, `NGUONG_VA_GOC_QUY_CHIEU.md` — **nhiều chỗ lỗi thời** (xem bảng "Lệch giữa tài liệu và code").
   Còn giá trị ở: mục đích sản phẩm, lý do thiết kế, bài học bản iOS cũ (§4–6).
7. `tai-lieu-goc/*.docx` — đề bài gốc, chỉ dùng làm **chuẩn nghiệm thu** ở Phase 6. `tai-lieu-goc/BestShotSelector.swift`
   là prototype Vision cũ — **không đọc để port**.

**Ngoài phạm vi port** (Android không có trong app — đừng tự thêm vào iOS): công cụ 3D template fitter
(`TAI_LIEU_POSECOACH_3D_TEMPLATE_FITTER.md` — chỉ là đặc tả dự phòng), nhánh Depth Anything, auto-crop, tự nắn thẳng
ảnh, lọc khung theo tốc độ góc khi chọn ảnh, motion blur / cháy sáng / thiếu sáng / face capture quality, phát hiện
tay che mặt, khoá chủ thể nhiều người, trạng thái `ACQUIRING`.

---

## Quyết định còn mở

| # | Câu hỏi | Đề xuất | Chặn |
|---|---|---|---|
| D1 | Lấy tài nguyên thế nào? | ✅ **Chốt 11/11/2026: tham chiếu thẳng** từ `shared/…/assets/` vào Copy Bundle Resources (chỉ đọc lúc build) | — |
| D2 | Thêm `onnxruntime-objc` **1.30.0** (CocoaPods, Microsoft) chạy GeoCalib — cùng version Android | Đồng ý. Kiểm ngay ở Phase 0: pod cài được, nạp được model int8, không xung đột với MediaPipe / ML Kit | **Phase 0** (kiểm) · 3c · 4b |
| D3 | Máy sàn iOS + mục tiêu hiệu năng | iPhone 11 (A13, theo tài liệu gốc); ≥ 8–10 fps vòng đo, trễ cue < 350 ms | Phase 6 (chốt sớm để có máy) |
| D4 | Chọn ngôn ngữ trong app hay dùng ngôn ngữ riêng từng app của iOS? | **Của hệ thống** — Settings chỉ có nút mở Cài đặt, bỏ `LanguageRepository` | Phase 5 |
| D5 | Thư viện tải ảnh cho lưới ảnh mẫu (Android dùng Coil) | **Không thêm** — ImageIO thumbnail + `NSCache` | Phase 4 |
| D6 | Dữ liệu đối chiếu từ Android (JSON số đo cho cùng bộ ảnh) | Nhờ bên Android thêm lệnh xuất | Phase 6 |
| D7 | Code đánh dấu `⚠️ TẠM` bên Android: GeoCalib chạy trên màn chụp (`CaptureScreen.kt:335`, `CaptureViewModel.kt:212`) + `debugDo` / `debugGocMay` (`CaptureViewModel.kt:388–455`) | **Không port** — tài liệu ghi phải gỡ trước khi phát hành | Phase 4 |
| D8 | Ngưỡng nằm ngoài `GuidanceConfig` (`NhanDienNhap.kt`: `nhomGoc` ±15°, `CACH_MOC_GOC = 4`, nhãn ML Kit 0,2 / 0,5; hằng số trong `CaptureScreen.kt`) | Port **đúng chỗ Android đặt** để đối chiếu được; ghi danh sách ở bước port | Phase 4 |

---

## Nguyên tắc port (áp dụng mọi phase)

0. **Đọc hết trước khi viết.** Đầu mỗi bước: đọc **toàn bộ** file Kotlin và file test Kotlin của bước đó, cùng các mục
   FOOTGUNS ghi ở bước. Plan lập từ cấu trúc code + tài liệu; logic bên trong có thể lộ phụ thuộc mới → dừng, báo, sửa plan.
1. **Test trước.** Port test Kotlin sang Swift Testing → đỏ → port code → xanh. Giữ **đúng số liệu đầu vào và kỳ vọng**.
   Tên test giữ ý (dùng `@Test("…")` cho tên tiếng Việt).
2. **Giữ nguyên công thức, thứ tự phép tính, tên hằng số, tên type, giá trị hằng số** — kể cả hằng số đang không dùng
   (vd. `PITCH_FACE_ACCEPT`, `PITCH_SPINE_ACCEPT_DEG`) để đối chiếu được. Không "cải tiến", không "sửa cho đúng tài liệu".
3. **Tách phần thuần khỏi framework.** Logic → `PD/`, phần framework → `App/Services/` (Phase 3).
4. **`public` chỉ cho thứ app gọi** (AGENTS.md quy tắc 2b).
5. **Đọc shared bằng `cat` / `grep` / `awk`** — `sed` bị luật chặn ghi `shared/**` chặn luôn.
6. **Không thất bại im lặng** — chỗ nào Android chỉ `Log.e` rồi trả `null` (vd. `GeoCalibGocMay.phanTich`) thì iOS vẫn
   giữ hành vi trả `nil`, nhưng phải có log rõ và đường báo người dùng nếu luồng đó dừng.

### Bẫy Kotlin → Swift đã biết

| Kotlin | Swift tương đương đúng | Bẫy |
|---|---|---|
| `x.roundToInt()` / `Math.round(x)` | `Int((x + 0.5).rounded(.down))` | Kotlin làm tròn **nửa lên +∞** (−2,5 → −2); `rounded()` Swift làm tròn **xa 0** (−2,5 → −3). Code Kotlin có 19 chỗ làm tròn |
| `kotlin.math.round(x)` | `x.rounded(.toNearestOrEven)` | Hàm này làm tròn **nửa về số chẵn**, khác `roundToInt` |
| `a % b` (Double, số âm) | `a.truncatingRemainder(dividingBy: b)` | Không dùng `remainder(dividingBy:)` (làm tròn về gần nhất) |
| `x.coerceIn(lo, hi)` | `min(max(x, lo), hi)` | |
| `minWith(compareByDescending…)` / `maxWith` | Đọc kỹ comparator rồi viết lại bằng `min(by:)` / `max(by:)` **đúng chiều** | FG 21: Android từng lấy nhầm phần tử tốt nhất thay vì kém nhất |
| `listOfNotNull(...)` cho danh sách góc | Giữ đủ phần tử, dùng `Double.nan` | FG 50: danh sách góc phải ổn định vị trí; bỏ phần tử làm lệch cặp so sánh |
| `Math.toDegrees` / `toRadians` | `* 180 / .pi` | Giữ đúng thứ tự nhân chia để khớp tới chữ số cuối |
| `String.format("%.2f", x)`, `"%.1fx"` | `String(format:, locale: Locale(identifier: "en_US_POSIX"), …)` | Máy tiếng Việt in dấu phẩy → hỏng CSV (`LocaleCsvTest`) và nhãn zoom "1,5x" (FG 51, 106) |
| `plurals` | Variations của String Catalog | FG 106: số ít/nhiều phải đủ cả en và vi |
| `data class` | `struct …: Equatable` | So `Double.nan == .nan` luôn `false` ở cả hai — test có NaN phải đọc kỹ |
| `object X` | `enum X { static … }` | |
| `sealed interface` / `when` | `enum` có associated value / `switch` đủ case | |

Phát hiện bẫy mới → thêm dòng.

---

## Phase 0 — Nền

**Mục tiêu:** đủ tài nguyên, đa ngôn ngữ, quyền, khung điều hướng rỗng; xác nhận các pod chạy chung được.

| Việc | Chi tiết |
|---|---|
| Tài nguyên (D1) | Tham chiếu `pose_landmarker_full.task`, `geocalib/geocalib-mang-int8.onnx` (30,7 MB), `templates/` (**114 ảnh**: 13 ở gốc + `mirror/` 51, `photographer/` 44, `selfie/` 6). Giữ nguyên cây thư mục. **Nhóm ảnh đọc từ tiền tố tên file, không từ thư mục** — code phải quét đệ quy |
| String Catalog | Script `tools/strings-xml-to-xcstrings/` (repo iOS) đọc `res/values/strings.xml` + `values-vi/strings.xml` (477 chuỗi + 3 plurals mỗi bên) → `App/Resources/Localizable.xcstrings`. **Key = tên resource Android.** `%1$s` → `%1$@`, `%1$d` → `%1$lld`. Plurals → variations |
| Ngôn ngữ dự án | Thêm `vi` vào `knownRegions`; tiếng Anh là ngôn ngữ phát triển |
| Info.plist | `NSCameraUsageDescription`; `NSPhotoLibraryAddUsageDescription` (thiếu là crash — lỗi bản iOS cũ); `UIRequiredDeviceCapabilities` = `gyroscope` (FG 2). **Không cần micro** — Android quay không tiếng. Nhập ảnh bằng `PhotosPicker` → không cần quyền đọc thư viện |
| Pod (D2) | Thêm `onnxruntime-objc` 1.30.0 vào Podfile; `pod install`; build My Mac. Kiểm **trùng symbol khi link** giữa MediaPipe + ML Kit + ONNX Runtime |
| Khung app | `App/App/PoseCoachApp.swift` + `RootView.swift`: 3 tab theo `MainActivity.kt` — **Ảnh mẫu · Thư viện · Cài đặt**. Xoá `ContentView.swift` mẫu |

**Tiêu chí xong:**
- [ ] Build My Mac xanh; app mở thấy 3 tab rỗng
- [ ] Test trong `PoseCoachTests`: đọc được model, file onnx, và đủ 114 ảnh mẫu từ bundle (quét đệ quy)
- [ ] Test: khởi tạo `PoseLandmarker`, `FaceDetector`, `ImageLabeler`, `ORTSession` cùng lúc — log không có `Class … is implemented in both`
- [ ] `Localizable.xcstrings` đủ 477 + 3 key, mỗi key đủ `en` và `vi`; script chạy lại được khi Android thêm chuỗi

⏸ **Điểm dừng 0**

---

## Phase 1 — PoseDomain: hình học, đo đạc, hồ sơ ảnh mẫu

**Mục tiêu:** "một hàm đo duy nhất" (`Measurer`) và hồ sơ tiêu chí ảnh mẫu chạy đúng trên Mac. ~2.900 dòng, **66 test**.
`ShotScore` ↔ `TemplateProfile` phụ thuộc vòng nên cùng phase.

### Bước 1a — Kiểu nền · FG 4, 14, 16, 42

| Kotlin | Dòng | Swift | Ghi chú |
|---|---|---|---|
| `ui/UiText.kt` | 52 | `PD/Text/UiText.swift` | **Chỉ dữ liệu**: `res(key, args)` · `plural(key, count, args)` · `join(parts, sep)` · `raw(String)`. Key = tên resource Android. `resolve` ở app (4a) |
| `pose/PoseGeometry.kt` | 360 | `PD/Pose/PoseGeometry.swift` | `P2`, `P3`, `Lm`, `PoseFrame`, `Box`. **Tách**: hàm dựng từ MediaPipe (~dòng 339) → 3a. Giữ phép lật gương `P3(-x, y, z)` của world landmark (~dòng 184). Neck/root suy từ trung điểm (FG 4) |
| `pose/FramingClass.kt` | 158 | `PD/Pose/FramingClass.swift` | Thấy cổ chân/gối thì tin thẳng; ngưỡng đáy 0,97/0,80/0,72/0,55, cao 0,30 chỉ để suy khi mốc bị che (FG 14, 42). Keypoint phải **đủ tin cậy VÀ y trong 0…1** — thêm test cho điểm ngoại suy ngoài khung |
| `face/FaceAnalyzer.kt` → `FaceInfo` | ~35 | `PD/Face/FaceInfo.swift` | Chỉ `data class FaceInfo`. `FaceAnalyzer` → 3c |
| `measure/MocLuoi.kt` | 23 | `PD/Measure/MocLuoi.swift` | |
| `capture/TiLeKhung.kt` | 38 | `PD/Shot/TiLeKhung.swift` | |
| `template/KieuChupTren.kt` | 33 | `PD/Template/KieuChupTren.swift` | |
| `template/DoanKieuTren.kt` | 61 | `PD/Template/DoanKieuTren.swift` | `VFOV_RONG = 75`, `TAI_CHAN_GAN = 0.45`, `TAI_CHAN_XA = 0.35` |

Test: `AspectCropTest` (6) · `TiLeKhungTest` (4) · `DoanKieuTrenTest` (5) + `KTT/TestStrings.kt` → `PDT/Support/TestStrings.swift`.

- [ ] Xanh · `grep` import (AGENTS.md) rỗng

⏸ **Điểm dừng 1a**

### Bước 1b — Tầng đo đạc · FG 13, 26, 35–38, 50, 64, 66, 79–82, 88, 91, 99

| Kotlin | Dòng | Swift | Ghi chú |
|---|---|---|---|
| `measure/PoseMeasurement.kt` | 1.175 | `PD/Measure/PoseMeasurement.swift` (tách nhiều file theo nhóm hàm nếu cần) | `Measurer` là **điểm vào duy nhất** cho ảnh mẫu / live / video. Góc máy ảnh mẫu **lấy từ nhãn tên file** (`boGocMayTuAnh`, ~dòng 296), camera lấy từ cảm biến. `ELEVATION = tilt + (0,5 − y_mốc) × vFOV`, ảnh mẫu dùng `VFOV_ANH_MAU = 65`. Port cả `hieuChinhGocAnh` (~dòng 604, **vẫn được gọi** ở ~577 dù FG 91 ghi "đã thay"). `MAX_OUT_OF_PLANE_DEG = 40` (FG 38), `MOC_LECH_TAM_TOI_DA = 0.15` (FG 79). Phối cảnh: giữ cả map `PerspectiveSource`, chỉ so cặp cùng nguồn (FG 26, 35, 36). `worldLandmarks` chỉ dùng cho hướng (FG 64) |

Test: `PerspectiveValueTest` (5) · `HieuChinhGocAnhTest` (4).

- [ ] Xanh
- [ ] Đối chiếu tay 3 phép đo: cùng input → in kết quả Swift, so với kỳ vọng trong test Kotlin tới chữ số cuối

⏸ **Điểm dừng 1b**

### Bước 1c — Chấm điểm + hồ sơ tiêu chí · FG 6, 25, 27, 28, 67, 77

| Kotlin | Dòng | Swift | Ghi chú |
|---|---|---|---|
| `measure/ShotScore.kt` | 544 | `PD/Measure/ShotScore.swift` | `ShotScorer`, `deviation` — **cùng hàm** engine đọc ở Phase 2. Một trung bình có trọng số (hình học ×5,5, dáng 1,0, nét 2,0, cắt cụt 1,5, mắt 0,6), **hướng mẫu là hệ số nhân** `0,12 + 0,88·hướng` (`DIRECTION_FLOOR`), `VUNG_DAT = 0.10`. Cắt cụt: dải `EDGE_BAND = 0.06` 4 mép. Không đo được → bỏ, chia lại trọng số (FG 6) |
| `template/TemplateProfile.kt` | 468 | `PD/Template/TemplateProfile.swift` | `Criterion` (8 mục hướng dẫn + mục hậu kỳ), `Stage` (`GUIDANCE` / `SELECTION` dùng chung hồ sơ — FG 25), `Criterion.reference` |

Test: `ShotScorerTest` (24) · `GocMayTest` (18).

- [ ] Xanh — tổng Phase 1: **66 test**
- [ ] Không có hàm đo thứ hai ngoài `Measurer` (grep tên hàm tính góc / tỉ lệ)

⏸ **Điểm dừng 1c = hết Phase 1**

---

## Phase 2 — PoseDomain: hướng dẫn, cổng kiểm, chọn ảnh

**Mục tiêu:** toàn bộ logic điều khiển chạy trên Mac. ~3.700 dòng, **192 test**.

**Engine là máy trạng thái theo bước** (`GuidanceEngine.kt:18–37`), mỗi lúc một bước hoạt động:
`ROLL` (xoay thẳng máy) → `PERSPECTIVE` (khoảng cách) → `ELEVATION` + `PITCH` (góc máy) → `SCALE` (zoom) → `CENTER`
(bố cục) → `YAW` (hướng mẫu) → `POSE` (dáng). Bước xong thì khoá, mở lại khi vượt `unlock`. **Không có `ACQUIRING`.**

### Bước 2a — Lõi hướng dẫn · FG 39, 40, 43, 45–48, 52–54, 56, 72, 73, 75, 76, 78, 80–85, 93, 94, 96, 106, 112, 113

| Kotlin | Dòng | Swift | Ghi chú |
|---|---|---|---|
| `guidance/ShootMode.kt` | 88 | `PD/Guidance/ShootMode.swift` | **4 chế độ**: `NGUOI_KHAC` · `TU_CHUP_GUONG` · `TU_CHUP_CAM_TRUOC` · `DAT_MAY`. Camera trước: dịch ngang không đảo, xoay có (FG 54, 78); đảo dấu cảm biến (FG 80) |
| `guidance/GuidanceConfig.kt` | 400 | `PD/Guidance/GuidanceConfig.swift` | **Chỗ DUY NHẤT chứa ngưỡng hướng dẫn.** Giữ đúng thứ tự `theoLop(...) ?: acceptFor(...)` — nhánh `acceptFor` ELEVATION 6,0 / PITCH 0,105 bị `theoLop` che. `CUE_MIN_DISPLAY_MS = 2000`, `STALL_TIMEOUT_MS = 2500` |
| `guidance/CriterionGate.kt` | 257 | `PD/Guidance/CriterionGate.swift` | Chống kẹt so với `band.enter`, không so `accept` (FG 52–53). Lệch dưới sàn đủ `STALL_TIMEOUT_MS` thì tính ĐẠT (FG 109) |
| `guidance/DistanceEstimator.kt` | 150 | `PD/Guidance/DistanceEstimator.swift` | Nhận `zoomRatio` |
| `guidance/PoseDescriber.kt` | 379 | `PD/Guidance/PoseDescriber.swift` | Câu theo **góc nhìn người mẫu**; gương: `hint.mirrored()` đổi `Side` trước khi chọn câu (FG 48, 106) |
| `guidance/CuePresenter.kt` | 597 | `PD/Guidance/CuePresenter.swift` | |
| `guidance/DatMayGate.kt` | 75 | `PD/Guidance/DatMayGate.swift` | Hai giai đoạn của chế độ đặt máy (FG 113) |
| `guidance/CameraPrep.kt` | 66 | `PD/Guidance/CameraPrep.swift` | Cảnh báo cầm máy chỉ khi phối cảnh không đo được (FG 41, 57) |

Test: `CriterionGateTest` (12) · `CuePresenterTest` (17) · `DatMayTest` (6) · `PerspectiveTest` (9) ·
`LimbTowardLensTest` (13) · `RollCriterionTest` (11) · `DuoiSanDatTest` (4) · `VideoTest1909Test` (3).

Thời gian truyền vào bằng tham số (`nowMs`) như test Kotlin — không dùng `Date()` thật.

⏸ **Điểm dừng 2a**

### Bước 2b — Engine + cổng kiểm + đồng hồ tự động · FG 19, 41, 57, 68, 92

| Kotlin | Dòng | Swift | Ghi chú |
|---|---|---|---|
| `guidance/GuidanceEngine.kt` | 807 | `PD/Guidance/GuidanceEngine.swift` | Máy trạng thái theo bước (trên). `ROLL` từ cảm biến, tắt khi \|pitch\| ≥ 60° (`DEVICE_ROLL_TRUST_PITCH_DEG`), `DEVICE_ROLL_BLAME_DEG = 3.0`. `AUTO_SKIP_AFTER_MS = 6000` (chỉ chế độ tự động), `READY_PERCENT = 85`, `MODEL_CUE_FREEZE_MS = 4000`, `CHO_DAT_MAY_MS = 1000`, `minValidFrames = 3`. `readyToPose` phải kèm `stuckUnmeasured.isEmpty()` (FG 93–94) |
| `template/TemplateGate.kt` | 231 | `PD/Template/TemplateGate.swift` | 🔴 từ chối: không thấy vai **và** không thấy mặt; trục thân > 60° (min 2D/3D — FG 19). 🟡: thiếu hông, thân > 35°, chân chĩa ống kính, chân dung không mặt. `MIN_VIS 0.5`, `AUX_VIS 0.4`, `MIN_SUBJECT_HEIGHT 0.25` |
| `ui/GuidanceOverlay.kt` → `groupRows` | — | `PD/Guidance/GroupRows.swift` | Tách hàm thuần nhóm dòng checklist. Phần vẽ → 4a |
| `media/MediaLibrary.kt` → phần tên file | ~100 | `PD/Template/TemplateKind.swift` | `TemplateKind` (**4 nhóm**: `selfie-` · `mirror-` · `tripod-` · không tiền tố = người khác chụp), nhãn góc = từ đầu sau tiền tố (`tren` −35° · `ngang` 0° · `duoi` +25° · không có → bỏ 2 mục góc máy), nhãn kiểu = từ thứ hai khi `tren` + người khác chụp (`gan` / `xa`; `rong` cũ → `gan`), tên hiển thị, `TIEN_TO_NHAP = "toi-chon-"`, `laAnhNhap`, `ganNhan`. Đuôi nhận: jpg, jpeg, png, webp, jfif |
| `capture/CaptureScreen.kt` → vòng đồng hồ tự động (~dòng 495–525) | ~30 | `PD/Guidance/AutoCountdown.swift` | Android để trong UI, `AutoCountdownTest` **chép lại** máy đó. iOS đưa vào PD để test code thật. Hai lớp giữ ổn định: engine `DWELL_MS 800` → `readyToCapture`; màn hình thêm `AUTO_STABLE_MS 800` → đếm `AUTO_COUNTDOWN_SEC 3` → `shoot()`; tụt ngắn chịu được `AUTO_CANCEL_GRACE_MS 500`; đang quay / xử lý thì không đếm |

Test: `HuongDanTuanTuTest` (3) · `MatchPercentTest` (5) · `MirrorSelfieTest` (16) · `MocLuoiTest` (3) ·
`SilentDeadlockTest` (3) · `ThoiQuenChupTest` (8) · `VideoTest1309Test` (15) · `CamMayThangTest` (4) ·
`KieuChupTrenTest` (11) · `CongKiemVaHuongMayTest` (7) · `AnhNhapTest` (5) · `AutoCountdownTest` (4).

⏸ **Điểm dừng 2b**

### Bước 2c — Chọn ảnh, phối cảnh nền, cảnh · FG 21, 102, 103

| Kotlin | Dòng | Swift | Ghi chú |
|---|---|---|---|
| `capture/BestShotBuffer.kt` | 211 | `PD/Shot/BestShotBuffer.swift` | 12 khung, `minGapMs 900` **và** `minPoseDistance 0.12`. Comparator `minWith` (~dòng 93) — FG 21 |
| `geocalib/GiaiPhoiCanh.kt` | 174 | `PD/GeoCalib/GiaiPhoiCanh.swift` | Bộ giải LM, lưới thưa `BUOC_LUOI = 4` |
| `scene/SceneMatch.kt` | 84 | `PD/Scene/SceneMatch.swift` | |
| `scene/SceneVocabulary.kt` | 163 | `PD/Scene/SceneVocabulary.swift` | `MAX_WORDS = 3`; so tiếng Việt có/không dấu (FG 107) |

Test: `BestShotBufferTest` (13) · `GiaiPhoiCanhTest` (5) · `SceneMatchingTest` (7) · `SceneVocabularyTest` (8).

- [ ] Xanh — tổng Phase 1 + 2: **258 test** · `grep` import rỗng

⏸ **Điểm dừng 2c = hết Phase 2**

---

## Phase 3 — Services

**Mục tiêu:** mọi thứ chạm framework, trả về **kiểu của PoseDomain**. Ảnh tĩnh / video kiểm trên My Mac; camera,
cảm biến kiểm trên iPhone.

### Bước 3a — Nhận diện khung xương (MediaPipe 1.0.0) · FG 3, 5, 11, 17

| Kotlin | Swift (`App/Services/PoseLandmarker/`) | Ghi chú |
|---|---|---|
| `pose/PoseGeometry.kt` (hàm dựng từ MediaPipe) | `PoseFrame+MediaPipe.swift` | **Chỗ DUY NHẤT** đổi landmark → `PoseFrame`. Gốc trên-trái, Y xuống — giống Android, **không** đảo như Vision (FG 3) |
| `pose/StillPoseAnalyzer.kt` | `StillPoseAnalyzer.swift` | IMAGE — ảnh mẫu. Dùng lại một bộ nhận diện |
| `pose/VideoPoseAnalyzer.kt` | `VideoPoseAnalyzer.swift` | VIDEO — có bám. Đọc khung **tuần tự, không tua** (FG 18) |
| `pose/PoseDetector.kt` | `PoseDetector.swift` | LIVE_STREAM. `MPImage(sampleBuffer:orientation:)` với **hướng thật** (lỗi `.right` đóng cứng của iOS cũ — FG 5) |
| `pose/MediaPipeGuard.kt` | `MediaPipeGuard.swift` | Khoá tạo / huỷ. Giải phóng chỉ sau khi dừng session và queue phân tích đã xả (FG 11, 17) |

Tuỳ chọn giữ như Android: `numPoses = 1`, CPU delegate, `minPoseDetectionConfidence` / `minPosePresenceConfidence` /
`minTrackingConfidence` = 0,5.

Test (`PoseCoachTests`, My Mac): IMAGE trên **114 ảnh mẫu** → `PoseFrame` 33 điểm hoặc lý do rõ; qua `TemplateGate`
ra 🔴/🟡/🟢 — lưu bảng kết quả làm mốc cho Phase 6a.

⏸ **Điểm dừng 3a**

### Bước 3b — Camera + cảm biến (cần iPhone) · FG 2, 10, 12, 29, 33, 49, 65, 69, 95, 98, 104, 109, 115

| Kotlin | Swift | Ghi chú |
|---|---|---|
| `camera/CaptureController.kt` (680) | `App/Services/Camera/CaptureController.swift` | Xem dưới |
| `sensors/DeviceTilt.kt` (115) | `App/Services/Motion/DeviceTilt.swift` | `CMMotionManager.deviceMotion` gravity + rotationRate. Android: `pitch = asin(-gz/|g|)`, `roll = atan2(-gx, gy)` với vector gravity hướng lên — **chiều trục CoreMotion khác**, phải kiểm dấu trên iPhone. Cảm biến chỉ để định tuyến, không để chấm (FG 45, 112) |

`CaptureController` phải có:
- **Hai chế độ `VIDEO` / `BURST`, burst là mặc định** (`CaptureUiState.kt:156`): 8 ảnh cách 500 ms, cạnh ngắn 3024,
  JPEG 95 → `AVCapturePhotoOutput`. Video Full HD (fallback HD), 3–30 s, không tiếng → `AVAssetWriter` từ chính luồng
  `AVCaptureVideoDataOutput`.
- **Luồng phân tích ~640 px, bỏ khung trễ** (`alwaysDiscardsLateVideoFrames`) — tương đương `KEEP_ONLY_LATEST`.
- **Hướng cầm máy từ gravity CoreMotion + giữ 400 ms** (`GIU_HUONG_MS`, FG 69) — không tin thẳng `UIDevice.orientation`
  (có `faceUp`/`faceDown`). Cập nhật cả nhận diện, video, ảnh burst (FG 10, 95). Không dựng lại session khi xoay (FG 12).
- **Camera trước**: preview `isVideoMirrored`; khung phân tích lật **một lần** ở đầu vòng; ảnh / video ghi ra cũng lật (FG 49).
- **Tỉ lệ khung áp cùng lúc 4 chỗ** (FG 98): `videoGravity` của preview, `PoseFrame.croppedToAspect`, `verticalFovDeg`,
  cắt ảnh + khung xương. Video 16:9 khi khung hẹp hơn 3:4, còn lại 4:3.
- **`verticalFovDeg`**: `videoFieldOfView` của iOS là góc **ngang** → đổi sang dọc theo tỉ lệ khung.
- **Zoom stop + ghim**: preview iOS không tự pinch; nếu thêm cử chỉ thì kéo về mức ghim khi lệch > 5% (FG 29, 65, 115).
- `setShootMode` **trước** `start()` (FG 104).

- [ ] iPhone: khung xương chồng khít ở cầm dọc **và** ngang, camera trước và sau
- [ ] Burst 8 ảnh đúng hướng; video 3–30 s đúng hướng, xoá được
- [ ] Dấu `pitch` / `roll` khớp quy ước Android (in số khi ngửa / chúc / vẹo máy)

⏸ **Điểm dừng 3b**

### Bước 3c — Mặt, GeoCalib, media · FG 18, 30, 32, 44, 51, 71, 102, 103

| Kotlin | Swift | Ghi chú |
|---|---|---|
| `face/FaceAnalyzer.kt` (112) | `App/Services/FaceDetection/FaceAnalyzer.swift` | ML Kit, `performanceMode = fast` (FG 82 thay FG 70). Gọi theo nhịp, có cờ "đang chạy", số > 600 ms thì bỏ (FG 30, 71) |
| `geocalib/GeoCalibGocMay.kt` (127) | `App/Services/GeoCalib/GeoCalibGocMay.swift` | ONNX Runtime (D2). Tiền xử lý: cạnh ngắn 320, cắt giữa về bội số 32, RGB [0,1], tensor `[1,3,h,w]`, input `"image"`, 4 output. Android co ảnh **từng nấc một nửa** có lọc (`createScaledBitmap(filter=true)`, ~dòng 98–110) — iOS dùng song tuyến, chênh nhỏ đo ở 6a. Đọc model thẳng từ bundle (Android phải chép ra `filesDir` — không cần) |
| `media/UprightBitmap.kt` (103) | `App/Services/Media/UprightImage.swift` | **Nơi DUY NHẤT đọc file ảnh**: `CGImageSource` + EXIF orientation (FG 44) |
| `media/VideoFrameSource.kt` (106) | `App/Services/Media/VideoFrameSource.swift` | `AVAssetReader` tuần tự (FG 18) |
| `media/MediaLibrary.kt` (phần file) | `App/Services/Media/MediaLibrary.swift` | Quét đệ quy ảnh mẫu trong bundle + ảnh tự nhập (chép vào Application Support, không giữ đường dẫn gốc). Nhóm / nhãn đọc bằng `TemplateKind`. Ảnh người dùng xoá không tự mọc lại (FG 32) |
| `media/ResultLibrary.kt` (169) | `App/Services/Media/ResultLibrary.swift` | Lưu ảnh giữ lại + ảnh mẫu + `_diem.txt` (FG 114); Photos chỉ cần quyền **thêm** |
| `capture/ShotStore.kt` (238) | `App/Services/Media/ShotStore.swift` | Kho ảnh tạm + **chống rác 4 lớp** (`sweepOrphans`, `sweepRecordings` lúc mở app). CSV theo `en_US_POSIX` |
| `capture/Sharpness.kt` (102) | `App/Services/Media/Sharpness.swift` | Laplacian **toàn khung**, thu bề ngang về 160 px (Accelerate) — giữ đúng cách thu nhỏ |

Test (`PoseCoachTests`): `LocaleCsvTest` (3) · `LuuAlbumTest` (2) + mới: ảnh EXIF xoay vào đúng chiều; `FaceAnalyzer` ra
`FaceInfo` trên ảnh chân dung; GeoCalib chạy trên 5 ảnh mẫu, ghi `pitch` / `vfov` làm mốc cho 6a; model không nạp được →
có log + trả `nil`, không treo.

⏸ **Điểm dừng 3c = hết Phase 3**

---

## Phase 4 — Luồng chính

**Mục tiêu:** chạy trọn chuỗi trên iPhone:
`ảnh mẫu / nhập ảnh → CỔNG KIỂM → màn chụp (hướng dẫn → burst hoặc video) → 5 ảnh khớp nhất → giữ 1`.
Giao diện viết theo SwiftUI, **không dịch Compose từng dòng**; hành vi và chữ giữ như Android.

### Bước 4a — Nền giao diện

| Kotlin | Swift |
|---|---|
| `ui/theme/Color.kt`, `Type.kt`, `Theme.kt`, `DesignTokens.kt` | `App/DesignSystem/` |
| `ui/UiText.kt` (phần `resolve`) | `App/Extensions/UiText+Resolve.swift` — qua String Catalog |
| `ui/GuidanceOverlay.kt` (300, phần vẽ) | `App/DesignSystem/GuidanceOverlay.swift` — câu chính + 1 câu phụ, **checklist sống** bám `CriterionGate` |
| `MainActivity.kt` (điều hướng) | `App/App/RootView.swift` |

Test: `StringsParityTest` → mới trong `PoseCoachTests`: mọi key có `en` + `vi`, **cùng số / kiểu tham số**.

⏸ **Điểm dừng 4a**

### Bước 4b — Home + nhập ảnh + cổng kiểm · FG 20, 86, 100, 105, 111

| Kotlin | Dòng | Swift (`App/Features/Home/`) | Ghi chú |
|---|---|---|---|
| `home/HomeScreen.kt` | 802 | `HomeView.swift` + `HomeViewModel.swift` | Lưới 114 ảnh theo nhóm, mỗi ô tự tải thumbnail (FG 111, D5); hộp thoại cổng kiểm |
| `home/NhapAnhSheet.kt` | 366 | `NhapAnhSheet.swift` | `PhotosPicker`; hiện gợi ý "chúc khoảng X°" từ GeoCalib; hỏi kiểu chụp + góc máy khi chưa chắc |
| `home/NhanDienNhap.kt` | 157 | `NhanDienNhap.swift` | Gọi **3 thứ**: `PhanTichAnhMau` + **ML Kit ImageLabeling** (nhãn ≥ 0,2; "Mobile phone" ≥ 0,5 → gương) + **GeoCalib**. Chắc chắn (`abs(abs(pitch) − 15) ≥ 4`) → vào thẳng, không hỏi. Ngưỡng giữ trong file này (D8) |
| `home/PhanTichAnhMau.kt` | 81 | `PhanTichAnhMau.swift` | Ảnh mẫu → `TemplateProfile` (một lần) |

- [ ] 🔴 bị chặn có lý do + việc cần làm; 🟡 vào được kèm cảnh báo; **không đường nào vào camera mà không qua cổng**
- [ ] Ảnh tự nhập và ảnh soạn sẵn đi qua **cùng một cổng**; ảnh nhập được đổi tên theo nhãn (`ganNhan`)

⏸ **Điểm dừng 4b**

### Bước 4c — Màn chụp · FG 23, 30, 31, 90, 104, 110, 114

| Kotlin | Dòng | Swift (`App/Features/Capture/`) | Ghi chú |
|---|---|---|---|
| `capture/CaptureUiState.kt` | 192 | `CaptureUiState.swift` | **Bỏ** `debugDo`, `debugGocMay` (D7) |
| `capture/CaptureViewModel.kt` | 491 | `CaptureViewModel.swift` | VM mới mỗi lần vào màn, `startFresh()`, xoá cờ đã xử lý, báo cờ hướng ngay khi `start()` (FG 23, 90, 114) |
| `capture/CaptureScreen.kt` | 1.735 | `CaptureView.swift` + view con | Tách view theo vùng màn hình. **Bỏ** GeoCalib chạy trên màn chụp (D7). Hằng số: `SCORE_STEP_MS 500`, `FINAL_SHORT_SIDE 1440`, `BURST_FINAL_SHORT_SIDE 3024`, `FACE_NHIP_MS 300` |
| `capture/MocLuoiOverlay.kt` | 166 | `MocLuoiOverlay.swift` | Mốc lưới hiện **sau** các bước góc máy (FG 110) |
| `capture/ShotSession.kt` | 270 | `ShotSession.swift` | Nối đo → chấm → giữ → xoá. Face chạy ở độ phân giải cao trong `finish()` trên ≤ 12 khung (FG 30) |

- [ ] Hướng dẫn đi đúng thứ tự bước; mỗi lúc 1 câu; nút chụp tay **luôn hiện**
- [ ] Chip Tự động / Thủ công; tự động: đủ điều kiện → giữ ổn định → đếm 3 s → **chụp / quay khi đếm xong**
- [ ] Mục không đo được quá 2,5 s → câu "chưa đo được"; chế độ tự động bỏ qua bước kẹt sau 6 s
- [ ] Nút Khung 3:4 → 9:16 → 1:1 → Full, lưới 3×3, zoom 0.5x/1x/2x
- [ ] Bốn chế độ chụp chạy được, chế độ đặt máy có hai giai đoạn
- [ ] Video thô bị xoá ngay sau khi cắt xong ảnh

⏸ **Điểm dừng 4c**

### Bước 4d — Màn xem lại · FG 24, 114

| Kotlin | Dòng | Swift (`App/Features/Result/`) |
|---|---|---|
| `result/ResultUiState.kt` | 138 | `ResultUiState.swift` |
| `result/ResultViewModel.kt` | 153 | `ResultViewModel.swift` |
| `result/ResultScreen.kt` | 439 | `ResultView.swift` |

Test: `FailedCriteriaTest` (6) — phần thuần đặt ở `PD/` nếu không chạm framework.

- [ ] 5 ảnh cạnh ảnh mẫu + bảng phân tích; "không tấm nào đạt" khi điểm gần 0 (FG 24)
- [ ] Rời màn → hỏi "Lưu ảnh vào thư viện?", chặn quay lại màn chụp cũ; giữ 1 → xoá cả thư mục phiên (FG 114)

⏸ **Điểm dừng 4d = hết Phase 4**

---

## Phase 5 — Phần phụ · FG 107

| Kotlin | Dòng | Swift | Ghi chú |
|---|---|---|---|
| `library/LibraryScreen.kt` | 337 | `App/Features/Library/LibraryView.swift` | Ảnh đã giữ + xem đối chiếu với ảnh mẫu |
| `scene/SceneScreen.kt`, `SceneViewModel.kt`, `SceneUiState.kt`, `SceneAction.kt` | 590 | `App/Features/Scene/` | MVI → MVVM: `SceneAction` thành hàm của ViewModel. Xoá trạng thái khi mở và khi rời |
| `scene/SceneCameraScreen.kt`, `SceneCamera.kt` | 482 | `App/Features/Scene/` | Dùng lại `CaptureController` nếu được. Video tối đa 60 s; cảnh báo "Chậm lại" khi quay > 35°/s |
| `scene/XaoTheOverlay.kt` | 237 | `App/Features/Scene/XaoTheOverlay.swift` | |
| `core/data/SceneRepository.kt` | 215 | `App/Features/Scene/SceneRepository.swift` | ML Kit ImageLabeling, ngưỡng 0,6, ≤ 12 khung trải đều. Nhãn lưu `scene-tags-v1.json`, khoá theo tên + mtime + size. File tự chụp ở cache, xoá khi rời luồng |
| `settings/SettingsScreen.kt` + `core/data/LanguageRepository.kt` | 190 | `App/Features/Settings/` | **Chờ D4**. Thêm mục **ghi công CC BY 4.0** (GeoCalib — cvg, ECCV 2024; bộ dữ liệu Laval Indoor HDR) |

Test: `AppLanguageTest` (2) — chỉ port nếu D4 giữ chọn ngôn ngữ trong app.

⏸ **Điểm dừng 5 = hết Phase 5**

---

## Phase 6 — Đối chiếu với Android + đo trên máy thật

| Bước | Việc | Kết quả |
|---|---|---|
| 6a | **Đối chiếu số đo.** iOS xuất JSON cho 114 ảnh mẫu: landmark, `PoseMeasurement`, `TemplateProfile`, cổng kiểm, GeoCalib `pitch` / `vfov`. Android xuất cùng định dạng (D6). Script `tools/so-sanh-parity/` | Cùng landmark → số đo **trùng tuyệt đối**. Landmark / GeoCalib lệch do runtime → ghi độ lệch, kiểm có làm đổi 🔴/🟡/🟢, lớp khung hình, nhóm góc không |
| 6b | **Đo ngưỡng.** Tripod, đứng yên 20 s, cả **5 lớp**, đo σ từng đại lượng, `accept ≥ 3σ` | Báo cáo số. **Không tự sửa `GuidanceConfig`** — ngưỡng chung hai nền tảng, PO quyết |
| 6c | **Hiệu năng** trên máy sàn (D3): fps vòng đo, trễ cue, nhiệt sau 5 phút, CPU vs GPU delegate. Ghi nhận `thermalState` (gợi ý riêng iOS trong `Implementation_Guide` §6 — Android không có, **không port**, chỉ báo) | Đạt / không |
| 6d | **Rủi ro #1:** mẫu xoay đủ vòng, tracking có giữ không (Android 280/280). Phát video liên tục, không tua | Giữ / cắt nhóm ảnh mẫu quay lưng |
| 6e | Khung cắt từ video / burst có đẹp bằng ảnh chụp thường không | So cạnh nhau |
| 6f | **Các điểm Android ghi "chưa kiểm trên máy thật"**: dấu roll (FG 112), chiều camera trước khi đặt máy (FG 113), mốc nhãn ML Kit (FG 105), mốc 35°/s (FG 107), `hieuChinhGocAnh` khi ngửa > +15° (FG 87), dấu trái/phải hướng mẫu (`PoseGeometry.kt:289`), sai số góc xoay ở 0° / 45° / 90° và chiều cao mẫu (TONG_QUAN §10.3 số #4, #5) | Bảng đúng / sai |
| 6g | **Chuẩn nghiệm thu tài liệu gốc:** `Implementation_Guide` §7 G1–G6; `Phan_Lop_Khung_Hinh` §9; `Spike_Brief` Q1 / Q2 / Q4 / Q5 | Bảng đạt / rớt |

⏸ **Điểm dừng 6 = hoàn tất port**

---

## Tổng hợp test Android → iOS

| Phase | Test Kotlin | `@Test` | Chạy ở |
|---|---|---|---|
| 1 | AspectCrop, TiLeKhung, DoanKieuTren, PerspectiveValue, HieuChinhGocAnh, ShotScorer, GocMay | 66 | `swift test` |
| 2 | CriterionGate, CuePresenter, DatMay, Perspective, LimbTowardLens, RollCriterion, DuoiSanDat, VideoTest1909, HuongDanTuanTu, MatchPercent, MirrorSelfie, MocLuoi, SilentDeadlock, ThoiQuenChup, VideoTest1309, CamMayThang, KieuChupTren, CongKiemVaHuongMay, AnhNhap, AutoCountdown, BestShotBuffer, GiaiPhoiCanh, SceneMatching, SceneVocabulary | 192 | `swift test` |
| 3 | LocaleCsv, LuuAlbum | 5 | `PoseCoachTests` (My Mac) |
| 4 | FailedCriteria, StringsParity | 7 | `swift test` / `PoseCoachTests` |
| 5 | AppLanguage (tuỳ D4) | 2 | `PoseCoachTests` |
| — | `ExampleUnitTest`, `ExampleInstrumentedTest` | — | Bỏ |

---

## Lệch giữa tài liệu và code Android

**Port theo code**, ghi ở đây, báo người dùng. Sửa bên nào là việc của PO / bên Android.

| # | Tài liệu nói | Code làm | Vị trí code |
|---|---|---|---|
| L1 | Ghi **ngay từ lúc bắt đầu đếm** (TQ §3.2, §3.7) | Chụp / quay **khi đếm xong**, chỉ ở chế độ tự động | `capture/CaptureScreen.kt` ~510–520 |
| L2 | Comment "5 giây" | `AUTO_COUNTDOWN_SEC = 3`; `AutoCountdownTest` mô phỏng 5 s | `CaptureScreen.kt:144` |
| L3 | 6 tiêu chí | 8 tiêu chí hướng dẫn + mục hậu kỳ | `template/TemplateProfile.kt` |
| L4 | Hướng mẫu kiểm **đầu tiên** và dừng hẳn; `[0a] hướng máy → [0b] ACQUIRING → 1…6` | ROLL → PERSPECTIVE → ELEVATION/PITCH → SCALE → CENTER → **YAW (bước 6)** → POSE | `guidance/GuidanceEngine.kt:18–37` |
| L5 | `ACQUIRING`; mất người > 1,5 s quay về; kẹt > 20 s "Góc này cũng ổn, chụp thử nhé?"; "Đưa mẫu vào khung" | **Không có.** Thay bằng: không đo được > 2,5 s → "chưa đo được"; tự động bỏ qua bước kẹt sau 6 s | `CriterionGate.kt:78–82`, `GuidanceEngine.kt:443–470, 669` |
| L6 | Điểm 0,55 hình học / 0,35 chất lượng / 0,10 dáng | Trung bình có trọng số (≈ 0,52 / 0,39 / 0,09), hướng là hệ số nhân 0,12–1 | `TemplateProfile.kt:225–263`, `ShotScore.kt` |
| L7 | ELEVATION 6/6/4/3°, PITCH 5/5/4/3° theo lớp; góc máy 5 mức | 10° và 12° mọi lớp (đường chân 0,105); góc ảnh mẫu 3 nhãn −35 / 0 / +25 | `GuidanceConfig.kt:112–113, 292` |
| L8 | Dáng tách trục thân / khớp / đầu theo lớp | Một mục `POSE` 15° / sàn 12° | `GuidanceConfig.kt:235, 272` |
| L9 | `cueMinDisplay` 1,2 s | 2000 ms | `GuidanceConfig.kt:375` |
| L10 | `countdownGrace` 1,0 s | 500 ms | `CaptureScreen.kt:160` |
| L11 | `actionFloor` khoảng cách tính bằng mét | Tỉ lệ 0,05 / 0,045 / 0,03 / 0,02 | `GuidanceConfig.kt:258–263` |
| L12 | Hướng mẫu bằng `acos` + vùng chết 0,93 + lọc `r` | `atan2` trên world landmarks, không lọc | `PoseGeometry.kt:272–291` |
| L13 | Cổng kiểm từ chối khi không thấy vai và hông; cảnh báo nhiều người / không đoán được góc máy | Từ chối khi không thấy vai **và** không thấy mặt; thiếu hông chỉ cảnh báo; không có cảnh báo nhiều người | `TemplateGate.kt:117–193` |
| L14 | Máy vẹo: không hướng dẫn, ảnh < 3° tự nắn | Có bước ROLL (cảm biến, 6°); không nắn | `GuidanceConfig.kt:214`, `GuidanceEngine.kt` |
| L15 | Khoá zoom theo mẫu, không cho tự zoom | Nút 0.5x/1x/2x + kéo; có `targetZoom` | `CaptureScreen.kt:705`, `CameraPrep.kt` |
| L16 | Độ nét: ROI chủ thể 640 px, Laplacian + gradient | Laplacian toàn khung, bề ngang 160 px | `Sharpness.kt:36` |
| L17 | Quay video 4K, 15–30 s | **Burst 8 ảnh mặc định**; video Full HD 3–30 s | `CaptureUiState.kt:156, 177–183`, `CaptureController.kt:425` |
| L18 | Cắt vào khớp: dải y 0,93…1,02 → điểm × 0,80 | Mục cắt cụt cộng vào điểm, dải 0,06 ở 4 mép | `ShotScore.kt:490–544` |
| L19 | GeoCalib chạy một lần trên máy tính, không lên điện thoại (`TAI_LIEU_PHAN_TICH_DA_CONG_CU.md:95`) | Chạy trên điện thoại lúc nhập ảnh | `home/NhanDienNhap.kt:81` |
| L20 | Lưu `pitchDeg` liên tục + độ tin cậy vào hồ sơ ảnh | Quy về 3 nhãn, đổi tên file | `NhanDienNhap.kt:113–143`, `MediaLibrary.kt:189` |
| L21 | FG 31: bước lấy mẫu 250 ms | `SCORE_STEP_MS = 500` | `CaptureScreen.kt:129` |
| L22 | FG 91: `hieuChinhGocAnh` đã bị thay | Vẫn được gọi | `PoseMeasurement.kt:577, 604` |
| L23 | `templates/README.txt`: bộ ảnh v8 | Mốc nạp `v10` (không ảnh hưởng iOS — đọc thẳng bundle) | `MediaLibrary.kt` |

---

## Việc phát sinh khi Android cập nhật

*(Ghi ở đây: commit Android mới, file Kotlin thay đổi, phase bị ảnh hưởng.)*
