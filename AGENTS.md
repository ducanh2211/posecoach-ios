# AGENTS.md — PoseCoach (iOS Native)

> File cấu hình cho AI agent (Codex, Claude Code). `CLAUDE.md` chỉ import file này — **sửa ở đây**.
> Bản gọn: chỉ chứa phần riêng của iOS. Sản phẩm, thuật toán, ngưỡng → đọc trong `shared/posecoach/`.
> Mâu thuẫn giữa các mục: mục dưới thắng mục trên.

---

## 🔒 `shared/` LÀ CHỈ ĐỌC — KHÔNG BAO GIỜ SỬA

`shared/posecoach/` là git submodule trỏ tới repo Android (`BNNam299/posecoach`, nhánh
`phuong-an-tich-hop`). Đây là **nguồn sự thật** về sản phẩm và thuật toán.

- ❌ Không tạo / sửa / xoá / đổi tên bất kỳ file nào trong `shared/`.
- ❌ Không chạy `git commit`, `git checkout`, `git reset`, `git stash`… bên trong `shared/posecoach`.
- ❌ Không chạy script / build tool trong `shared/` làm sinh file ra đó.
- ✅ Chỉ được: đọc file, `git log` / `git show` / `git diff` để xem lịch sử. Đọc bằng `cat` / `grep` / `awk` —
  `sed` (kể cả `sed -n`) bị luật chặn ghi `shared/**` chặn luôn.
- ✅ Kéo bản Android mới **chỉ khi người dùng yêu cầu**: `git submodule update --remote shared/posecoach`
  (thao tác này chỉ đổi con trỏ commit ở repo iOS, không sửa nội dung submodule).
- Cần tài nguyên từ shared (vd. `pose_landmarker_full.task`, ảnh mẫu) → **chép sang
  `PoseCoach/`** hoặc tham chiếu khi build, không sửa tại chỗ. Hỏi người dùng cách làm trước.
- Thấy lỗi / tài liệu sai trong shared → **báo người dùng**, không tự sửa.

Claude Code bị chặn cứng `Edit`/`Write` vào `shared/**` qua `.claude/settings.json`. Lệnh shell
không bị chặn — vẫn phải tự giữ quy tắc này.

---

## Đọc gì trước

Theo thứ tự, trước khi động vào code:

1. `docs/PLAN_PORT_IOS.md` — kế hoạch, tiến độ, và mục **"Nguồn sự thật"**: khi tài liệu Android nói khác code,
   **code Kotlin thắng** (plan có bảng các chỗ lệch đã biết).
2. `shared/posecoach/CLAUDE.md` — mục **"THÔNG TIN DỰ ÁN — PoseCoach"**: hiện trạng bản Android,
   ràng buộc cứng, quy tắc riêng. ⚠️ Đọc `CLAUDE.md`, **không** đọc `AGENTS.md` trong shared —
   bản `AGENTS.md` ở đó đã cũ (thiếu các thay đổi từ 05/09/2026).
3. `shared/posecoach/THAY_DOI_NHANH_THUAT_TOAN.md` — mô tả hành vi gần code nhất.
4. `shared/posecoach/FOOTGUNS.md` — bẫy đã gặp bên Android (nhiều mục áp dụng cả iOS). Plan ghi số mục cần đọc cho
   từng bước port.
5. `shared/posecoach/TONG_QUAN_DU_AN.md`, `NGUONG_VA_GOC_QUY_CHIEU.md` — đọc để hiểu **mục đích và lý do** thiết kế.
   ⚠️ Nhiều thuật toán / ngưỡng / thứ tự trong hai file này **đã lỗi thời** so với code.

Tài liệu Android nhắc tới `legacy-ios/` (code Swift cũ) — **thư mục đó không có trong repo này**.
Đừng đi tìm; nguồn để port là code Kotlin trong `shared/posecoach/app/app/src/main/java/com/example/posecoach/`.

---

## Việc đang làm: port bản Android sang iOS

Android là bản tham chiếu. iOS **viết lại theo code Kotlin**, giữ đúng hành vi.

- **Giữ nguyên công thức, thứ tự phép tính, tên hằng số, giá trị ngưỡng** khi dịch Kotlin → Swift.
  Không "cải tiến" trong lúc port — mọi khác biệt làm mất khả năng đối chiếu khi kết quả sai.
  Muốn đổi thuật toán → đề xuất cho người dùng, việc đó phải làm bên Android trước.
- Giao diện, camera, cảm biến, lưu trữ: viết theo cách tự nhiên của iOS (không dịch Compose sang SwiftUI từng dòng).
- **Kế hoạch, thứ tự, tiến độ: `docs/PLAN_PORT_IOS.md`.** Đọc bảng Trạng thái trước khi làm; xong bước nào cập nhật bước đó.
  Port theo thứ tự tầng: đo đạc → hướng dẫn → services → giao diện.
- Mỗi bước có điểm dừng xin duyệt — không tự code xuyên nhiều bước.

### Ràng buộc cứng (chi tiết ở `shared/posecoach/CLAUDE.md`, nhắc lại vì hay sai)

1. **"Cùng một hàm"** — ảnh mẫu, khung camera, khung video đi qua **đúng một hàm đo**.
2. **FramingClass suy MỘT LẦN từ ảnh mẫu**, áp nguyên xi cho live và video.
3. **Một hàm chuẩn hoá toạ độ duy nhất** ở lớp bọc nhận diện — không rải phép đổi trục.
4. **Một chỗ duy nhất chứa ngưỡng** (tương đương `GuidanceConfig.kt`). Không tự chỉnh ngưỡng cho "có vẻ đúng".
5. **Không đo được → bỏ mục đó, chia lại trọng số**, không trừ điểm.
6. **Ảnh mẫu qua cổng kiểm 3 mức** trước khi vào màn camera.
7. **Không thất bại im lặng** — mọi nhánh lỗi phải báo người dùng chuyện gì xảy ra, làm gì tiếp.
8. **Chống rác máy 4 lớp** — xoá khung thừa, video thô, dọn mồ côi lúc mở app.

---

## Stack đã chốt (11/11/2026)

| Mảng | Chốt | Ghi chú |
|---|---|---|
| Ngôn ngữ | **Swift**, language mode **Swift 5** | Không bật Swift 6 strict khi chưa hỏi |
| Giao diện | **SwiftUI** | Không dùng UIKit/Storyboard cho màn mới; chỉ `UIViewRepresentable` khi bắt buộc (vd. preview camera) |
| iOS tối thiểu | **17.0** (mọi target) | Không dùng API chỉ có ở 18+ nếu thiếu `if #available` |
| Kiến trúc | **MVVM + `@Observable`** | Xem mục dưới |
| Nhận diện khung xương | **MediaPipe Pose Landmarker** (`MediaPipeTasksVision` **1.0.0**, model `full`) | **Cùng version và model với Android** → ngưỡng đối chiếu được. Đổi version phải đổi cả hai bên. 3 running mode: IMAGE = ảnh mẫu, VIDEO = chấm khung sau quay, LIVE_STREAM = camera |
| Camera | **AVFoundation** | |
| Cảm biến | **CoreMotion** (gravity + gyro) | Tương đương `TYPE_GRAVITY` + `TYPE_GYROSCOPE` bên Android |
| Góc mặt / nhãn ảnh | **ML Kit** `GoogleMLKit/FaceDetection` + `GoogleMLKit/ImageLabeling` 8.0.0 | Cùng engine với Android (`mlkit-face-detection`, `mlkit-image-labeling`) |
| Góc máy từ nền ảnh (GeoCalib) | **ONNX Runtime** `onnxruntime-objc` **1.30.0** (CocoaPods) | Cùng version `onnxruntime-android` (plan D2) | Model `geocalib-mang-int8.onnx` đọc thẳng từ `shared/` |
| Đa ngôn ngữ | **String Catalog** (`Localizable.xcstrings`), tiếng Anh mặc định + tiếng Việt | Không viết chữ hiển thị thẳng vào code. Tầng logic trả mã câu + số liệu, View mới đổi ra chữ |
| Backend | **Không có** — offline hoàn toàn | Không tự thêm |
| Quản lý thư viện | **CocoaPods cho thư viện ML** (MediaPipe, ML Kit, ONNX Runtime) · **SPM** cho phần còn lại (hiện chỉ có local package `PoseDomain`) | ❌ **Không dùng MediaPipe qua SPM**: SPM chỉ có từ 1.1.0 (lệch Android) và do `unsafeFlags` chỉ ghim được theo commit. Ghim **đúng version** trong `PoseCoach/Podfile`. Luôn mở / build bằng **`PoseCoach.xcworkspace`**, không dùng `.xcodeproj`. `Pods/` không commit; sau khi clone chạy `pod install` trong `PoseCoach/` |

**Trước khi thêm bất kỳ dependency nào → hỏi người dùng.** Kiểm repo còn sống / chưa archived trước khi đề xuất.

## Kiến trúc: MVVM + `@Observable`

- Mỗi màn hình: `<Ten>View.swift` + `<Ten>ViewModel.swift`.
- ViewModel: `@Observable @MainActor final class`. Hàm public đặt theo thao tác (`selectTemplate(_:)`, `startRecording()`…).
- View không gọi thẳng camera / MediaPipe / file system — đi qua ViewModel hoặc service.
- Logic thuần (đo đạc, chấm điểm, gate, buffer) nằm trong package **`PoseDomain`**, **không import SwiftUI / framework phần cứng**, để unit test được.
- Không tạo protocol / abstraction chỉ để "sau này dùng" — chỉ khi có ≥ 2 cài đặt thật hoặc cần thay khi test.

## Cấu trúc thư mục

Project dùng **file-system synchronized groups** (Xcode 16+): thêm file `.swift` vào thư mục là
tự vào target, **không cần sửa `project.pbxproj`**.

App target chứa giao diện + service; logic thuần tách thành **local SPM package `PoseDomain`**
(không dependency nào, test bằng `swift test` trên Mac — không cần simulator, không dính pod ML Kit).
Màn hình chia **theo tính năng**, phần lõi chia **theo tầng**:

```
PoseCoach/
├── PoseCoach/               app target
│   ├── App/                 PoseCoachApp, RootView (tab / điều hướng gốc)
│   ├── Features/            mỗi màn một thư mục: View + ViewModel + view con chỉ màn đó dùng
│   │   ├── Home/
│   │   ├── Capture/
│   │   ├── Result/
│   │   ├── Library/
│   │   ├── Scene/
│   │   └── Settings/
│   ├── Services/            bọc framework / phần cứng — nơi DUY NHẤT import MediaPipe, AVFoundation, CoreMotion, Vision
│   │   ├── PoseLandmarker/
│   │   ├── Camera/
│   │   ├── Motion/
│   │   ├── FaceDetection/
│   │   ├── GeoCalib/
│   │   └── Media/
│   ├── DesignSystem/        token màu / font / khoảng cách + component dùng ở ≥ 2 màn (GuidanceOverlay…)
│   ├── Extensions/          mở rộng type hệ thống, tên file Type+MucDich.swift (vd. CGPoint+Geometry.swift)
│   └── Resources/           Localizable.xcstrings, pose_landmarker_full.task, ảnh mẫu soạn sẵn
├── Packages/
│   └── PoseDomain/          local SPM package — iOS 17 + macOS 14, không dependency
│       ├── Package.swift
│       ├── Sources/PoseDomain/      logic thuần — CHỈ Foundation / CoreGraphics / simd
│       │   ├── Pose/                PoseGeometry, FramingClass, model landmark của app
│       │   ├── Measure/             PoseMeasurement (hàm đo DUY NHẤT), ShotScore, MocLuoi
│       │   ├── Guidance/            GuidanceConfig (chỗ DUY NHẤT chứa ngưỡng), CriterionGate, CuePresenter, GuidanceEngine…
│       │   ├── Template/            TemplateGate, TemplateProfile…
│       │   ├── Shot/                BestShotBuffer, TiLeKhung
│       │   ├── Text/                UiText (chỉ dữ liệu: key + tham số; đổi ra chữ ở app)
│       │   ├── Face/                FaceInfo
│       │   ├── Scene/               SceneMatch, SceneVocabulary
│       │   └── GeoCalib/            GiaiPhoiCanh (phần toán; chạy model ở Services/GeoCalib)
│       └── Tests/PoseDomainTests/   Swift Testing, cấu trúc giống Sources/PoseDomain/
├── PoseCoachTests/          test cần app (service, tích hợp) — chạy trên My Mac / iPhone thật
├── PoseCoachUITests/        UI test — chỉ iPhone thật
├── Podfile                  MediaPipe + ML Kit + ONNX Runtime (ghim đúng version)
└── PoseCoach.xcworkspace    LUÔN mở file này
```

### Quy tắc đặt file

1. **`PoseDomain` không import SwiftUI, UIKit, AVFoundation, CoreMotion, Vision, MediaPipe, ML Kit.** Cần dữ liệu
   từ framework → `Services/` đổi sang model của `PoseDomain` trước. Đây là cách giữ ràng buộc "cùng một hàm đo".
   Package không có dependency nên MediaPipe / ML Kit bị compiler chặn; framework hệ thống thì không — kiểm bằng
   lệnh `grep` ở mục "Build & test".
2. **`Services/PoseLandmarker` là chỗ duy nhất đổi kết quả MediaPipe sang model landmark của app** —
   hàm chuẩn hoá toạ độ nằm ở `PoseDomain/Pose/PoseGeometry`, service gọi nó, không tự đổi trục.
2b. **`public` chỉ cho những gì app (`Services/`, `Features/`) gọi tới.** Helper nội bộ để `internal`;
   test dùng `@testable import PoseDomain` nên vẫn thấy `internal`.
3. **Tên type và tên file giữ đúng như Kotlin** (kể cả tên tiếng Việt như `MocLuoi`, `DatMayGate`).
   Mỗi file một type chính. Tìm cặp tương ứng bằng tên, không cần nhớ thư mục.
3b. **Hằng số và case enum đổi sang lowerCamel theo một quy tắc cố định:** bỏ `_`, viết thường, viết hoa chữ đầu
   mỗi từ trừ từ đầu (`LEFT_SHOULDER` → `leftShoulder`, `BA_BON` → `baBon`, `BODY_3D` → `body3d`). Tên hàm / thuộc tính
   Kotlin đã là camelCase → giữ nguyên. Tìm cặp: `grep -rni` tên đã bỏ `_` (vd. `grep -rni leftshoulder`).
   Thuộc tính `…Res` của Kotlin (mã `R.string`) giữ tên nhưng là **key String Catalog** (`String`).
4. View dùng ở **1 màn** → `Features/<Man>/`; dùng ở **≥ 2 màn** → `DesignSystem/`.
5. Repository chỉ 1 màn dùng → `Features/<Man>/`; dùng chung → `Services/`. Chỉ tạo `Data/` khi có ≥ 2 repository dùng chung.
6. Trong `Features/<Man>/` để phẳng; quá ~8 file mới tách thêm `Views/`.
7. Thư mục PascalCase. Chỉ tạo thư mục khi có file đầu tiên cho nó.

### Ánh xạ gói Kotlin → thư mục iOS

Chỉ ghi các gói không đi thẳng 1-1 (còn lại: `home/` → `Features/Home`, `guidance/` / `measure/` / `template/` → `PoseDomain/Guidance` / `Measure` / `Template`…).

| Kotlin | iOS |
|---|---|
| `pose/` | Hình học → `PoseDomain/Pose` · bọc MediaPipe (`PoseDetector`, `StillPoseAnalyzer`, `VideoPoseAnalyzer`, `MediaPipeGuard`) → `Services/PoseLandmarker` |
| `capture/` | Màn hình, overlay, `ShotSession` (cầm ảnh + kho file) → `Features/Capture` · `BestShotBuffer`, `TiLeKhung` → `PoseDomain/Shot` · `ShotStore`, `Sharpness` → `Services/Media` |
| File trộn logic + framework | Tách: `FaceInfo` (từ `FaceAnalyzer.kt`), phần đọc tên file của `MediaLibrary.kt`, `groupRows` (từ `GuidanceOverlay.kt`), phần dữ liệu `UiText` → `PoseDomain`; phần còn lại → `Services/` / app. Chi tiết từng file: `docs/PLAN_PORT_IOS.md` |
| `camera/` · `sensors/` · `face/` · `geocalib/` · `media/` | `Services/Camera` · `Motion` · `FaceDetection` · `GeoCalib` · `Media` |
| `core/` | Theo quy tắc 5. `LanguageRepository` có thể không cần — iOS có sẵn ngôn ngữ riêng từng app trong Cài đặt; chốt khi port Settings |
| `ui/` | `DesignSystem/`. `UiText` → key trong String Catalog |
| `MainActivity.kt` | `App/` |

⚠️ Kotlin `core/` (repository) **không** tương ứng với `PoseDomain` của iOS — đừng đặt nhầm.

## Build & test

⚠️ **App KHÔNG chạy được trên simulator.** Pod ML Kit loại arm64 khỏi simulator
(`EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`), Mac chip Apple không còn đích simulator nào.
Đích chạy app: **My Mac (Designed for iPad)** hoặc **iPhone thật**.

Chạy ở thư mục `PoseCoach/`:

```bash
# 1. Test logic PoseDomain — dùng thường xuyên nhất, chạy thẳng trên Mac
(cd Packages/PoseDomain && swift test)

# 2. Kiểm PoseDomain không import framework cấm — phải ra rỗng
grep -rnE '^[[:space:]]*import ' Packages/PoseDomain/Sources | grep -vE 'import (Foundation|CoreGraphics|simd)$'

# 3. Build app
xcodebuild -workspace PoseCoach.xcworkspace -scheme PoseCoach \
  -destination 'platform=macOS,variant=Designed for iPad' -allowProvisioningUpdates build

# 4. Test cần app (PoseCoachTests): như lệnh 3, thay `build` bằng `-only-testing:PoseCoachTests test`
```

- Có thể dùng MobileBuildMCP (nạp skill `mobilebuildmcp-cli` trước) thay `xcodebuild`.
- Ký app: Personal Team, automatic signing. `-allowProvisioningUpdates` để xcodebuild tự tạo profile.
- `ENABLE_USER_SCRIPT_SANDBOXING = NO` ở app target là **bắt buộc** — bật lên thì bước nhúng framework của
  CocoaPods bị chặn (`rsync … Operation not permitted`).
- **Ký app: `DEVELOPMENT_TEAM = S7WPNU5HBB`** (Personal Team trên máy dev). Không commit team khác.
- `Test crashed with signal kill before establishing connection` trên My Mac = **Gatekeeper chặn** app ký bằng
  Personal Team (log: `syspolicyd … Gatekeeper rejection`), không phải lỗi code. Chạy test từ terminal/VS Code
  → app thừa hưởng "nguồn gốc" của tiến trình đó → phải bật nó trong **System Settings → Privacy & Security →
  Developer Tools** rồi mở lại. Từ Xcode (⌘U) thì không bị. Xem log: `/usr/bin/log show` (zsh có lệnh `log` riêng).
- **Không để test bundle link lại pod.** MediaPipe ép `-force_load libMediaPipeTasksCommon_*_graph.a` vào mọi
  target dùng pod → test link bản thứ hai → crash `FlowLimiterCalculator already registered`. `post_install`
  trong `Podfile` xoá `OTHER_LDFLAGS` của `Pods-PoseCoachTests` — **giữ đoạn đó**; symbol lấy từ app qua `BUNDLE_LOADER`.
  Ngoại lệ: `onnxruntime_objc` là framework tĩnh, symbol ẩn → test gọi ORT thì tự link bản riêng (vô hại, chỉ khi test).
- **15 class GTM trùng là đã biết và chấp nhận** (`GTMLog*`, `GTMSessionFetcher*`…): MediaPipe 1.0.0 nhúng sẵn GTM
  trong graph lib, ML Kit lại kéo pod GTM riêng. Liên kết tĩnh (`:linkage => :static`) đã thử → `1181 duplicate symbols`.
  Danh sách cho phép nằm trong `testNoDuplicateObjCClasses`; class trùng **mới** vẫn làm test đỏ — điều tra, đừng thêm
  vào danh sách khi chưa hỏi.
- Logic điều khiển (gate, đếm giờ, buffer) → unit test trong `PoseDomain`. Con số đo đạc → **chỉ tin khi đo trên máy thật**.
- Camera / cảm biến chỉ kiểm được trên iPhone thật.

---

## Vai trò & nguyên tắc làm việc

Kỹ sư iOS senior, ưu tiên kiến trúc tối giản, hiệu năng cao. Người vận hành là **developer**:
trả lời ngắn, đi thẳng vào quyết định kỹ thuật và trade-off, dùng diff/snippet kèm vị trí sửa.
Nhiều cách giải → liệt kê ngắn kèm trade-off để dev quyết.

1. **Clean & minimal** — không thêm tính năng / abstraction ngoài yêu cầu (YAGNI).
2. **Một file một trách nhiệm.**
3. **Không sửa ngoài phạm vi** — không tự refactor phần không liên quan.
4. **Không để code dở dang** — không flag tạm, không mock cho việc quan trọng. Thiếu thông tin → hỏi.
5. **Không hard-code giá trị nhạy cảm.**
6. **Theo pattern có sẵn** của repo này trước khi tạo cấu trúc mới.
7. **Kiểm chứng nguồn tham khảo** (repo tồn tại? archived? cập nhật gần nhất?) trước khi dùng làm mẫu.
8. **Tiết kiệm context** — đọc đúng-đủ file liên quan, gộp lượt đọc, không dán lại cả file khi chỉ sửa nhỏ,
   không viết `// ... giữ nguyên`.

---

## ⏳ Việc chờ iPhone thật

Checklist kiểm camera 3b chưa chạy (chưa có máy, 12/11/2026) — xem mục **"⏳ Việc chờ iPhone thật"** trong
`docs/PLAN_PORT_IOS.md`. Nhắc người dùng ngay khi họ nói đã có iPhone / sắp test máy thật.

## ⏰ Việc treo — nhắc lại khi nói tới phát hành / TestFlight / App Store

- **Bundle ID** hiện là `com.anhtran.PoseCoach` (mặc định lúc tạo project). Xác nhận định danh
  thật trước khi lên App Store Connect — đổi sau khi phát hành = app mới, mất toàn bộ người dùng.
- **Ghi công giấy phép CC BY 4.0** cho GeoCalib (cvg, ECCV 2024) và bộ dữ liệu Laval Indoor HDR — bắt buộc trước
  khi phát hành (plan Phase 5, màn Cài đặt).
- **Không còn code `⚠️ TẠM` / debug** nào trên màn chụp (plan D7).
