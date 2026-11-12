# Checklist kiểm trên iPhone thật

> Ghi 12/11/2026. Đã có máy để build nhưng **chưa chạy** — người dùng chưa có thời gian, cho làm tiếp 4c. Mục D thêm sau 4c.
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

### 4–5. Dời sang 4c — xem mục D

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

## D. Màn chụp 4c (hướng dẫn, tự động, chấm điểm)

Vào màn chụp như mục A. Chọn ảnh mẫu toàn thân "người khác chụp" cho các mục chung.

- [ ] Có màn chờ "đang phân tích ảnh mẫu" 1–2 s trước khi vào camera; ảnh mẫu hỏng → dòng ⚠ đỏ, không treo
- [ ] Dòng trạng thái góc trên trái đổi "thấy / không thấy mẫu"; bấm vào → bảng số liệu (Template, Landmarks…)
- [ ] Danh sách tiêu chí + % giống mẫu **sống**: dấu tích đổi khi di chuyển; mỗi lúc chỉ **một** câu hướng dẫn
- [ ] **Dấu góc máy (`DeviceTilt`)**: giơ máy cao chúc xuống → câu bảo HẠ máy; hạ thấp ngửa lên → câu bảo NÂNG máy. Ngược
  là dấu `pitch` sai. Nghiêng máy sang một bên → câu chỉnh nghiêng đúng chiều (dấu `roll`)
- [ ] **`verticalFovDeg`** (máy nhiều ống kính): đứng yên, đổi zoom 0.5x ↔ 1x ↔ 2x — câu cao/thấp không được nhảy lung
  tung chỉ vì đổi zoom
- [ ] Cầm ngang khi ảnh mẫu dọc → cảnh báo xoay máy chặn trước mọi câu khác; zoom lệch → cảnh báo, bấm vào → về 1x
- [ ] Chip zoom 0.5 / 1 / 2; kéo ngang trên dãy chip → thước chi tiết, thả tay ~1,6 s thì thu lại; chụm hai ngón zoom được
- [ ] Nút Khung 3:4 → 9:16 → 1:1 → Full (khoá khi đang quay); nút Lưới bật/tắt 3×3
- [ ] Xong các bước góc máy → vạch đặt người hiện ra + câu "đặt người vào vạch" vài giây; chấm chạm vạch thì xanh
- [ ] Tự động: đủ điều kiện → giữ ~0,8 s → đếm 3-2-1 → tự chụp; rung tay ngắn không huỷ đếm; nút chụp tay vẫn bấm được
- [ ] Chụp liên tục → màn "Đang xử lý" có % → sang màn xem lại (mục E). Container: `Library/Caches/burst/` **trống**
- [ ] Quay video ≥ 3 s → dừng → xử lý → `Library/Caches/recordings/` **trống** (video thô đã xoá)
- [ ] Ảnh mẫu selfie → mở camera trước; ảnh `mirror-…` → camera sau chế độ gương; ảnh `tripod-…` → camera trước, **tự
  động bật sẵn**, có giai đoạn đặt máy (đặt máy đúng góc trước, rồi mới mời ra đứng vào khung)
- [ ] Ảnh mẫu chân dung (mặt to): hướng mặt được hướng dẫn (đường nhận diện mặt live), camera trước không bị ngược chiều
  trái/phải
- [ ] Chụp liên tục mà không có người trong khung → báo lỗi rõ ràng, **chụp lại được ngay** (không bị khoá nút)

## E. Màn xem lại 4d

Chụp liên tục hoặc quay video như mục D → tự sang màn "Kết quả".

- [ ] ≤ 5 ảnh trong dải ngang, tấm đầu được chọn sẵn; bấm ảnh → xem to; nhãn "Khớp mẫu tốt nhất  <điểm>" góc ảnh to
- [ ] Bấm ô tròn góc ảnh → tích / bỏ tích; nút "Lưu ảnh đã chọn (n)" đếm đúng, khoá khi n = 0
- [ ] Bảng điểm: bấm → mở các dòng mục + "Không áp dụng với ảnh mẫu này: …"; ảnh ít mốc đo → dòng vàng
- [ ] Mẫu quay LƯNG khi ảnh mẫu quay MẶT (hoặc ngược lại) → hộp đỏ "Chưa tấm nào đạt Hướng mẫu" + lời khuyên, **không**
  có nhãn "Khớp mẫu tốt nhất" (FOOTGUNS 24)
- [ ] "Lưu tất cả" → sang tab Thư viện; container `Library/Application Support/thu-vien/buoi-…/` có `_mau.jpg`,
  `anh-01…`, `_diem.txt`; `Library/Caches/shots/` **trống**
- [ ] "Xoá" → hỏi lại → Xoá → về **màn chụp** cùng ảnh mẫu, chụp tiếp được; "Giữ lại" → ở lại màn
- [ ] Nút "‹" → hộp "Lưu ảnh vào thư viện?": Lưu tất cả / Không lưu → **đóng hẳn** về tab Ảnh mẫu (kiểm kỹ: lớp toàn
  màn hình phải đóng dù hộp thoại vừa đóng); Huỷ → ở lại
- [ ] Vào chụp lại lần nữa sau khi thoát → **không** tự nhảy về màn kết quả cũ (FOOTGUNS 114)

## F. Phase 5 — Thư viện, Bối cảnh, Cài đặt

- [ ] Tab Thư viện: sau khi "Lưu tất cả" ở mục E có ô mới (ảnh mẫu | ảnh giống nhất, giờ, số ảnh); mở → cặp "Mẫu | Ảnh
  của bạn · giống N%" + "Các ảnh khác"; bấm ảnh → toàn màn hình, vuốt chuyển ảnh, chụm phóng to (đang phóng thì không
  chuyển trang); "Xoá buổi này" → hỏi → xoá, ô biến mất
- [ ] Home → "Đề xuất ảnh mẫu theo bối cảnh" → bảng 2 lựa chọn
- [ ] **Chụp / quay bối cảnh**: hỏi quyền camera nếu chưa có; dòng nhắc đổi theo số tấm (3 tấm gợi ý); "Xong (n)" → màn
  đề xuất. Chế độ Video: quay < 2 s bấm dừng không ăn; di máy nhanh → "Chậm lại" vàng; tự dừng ~59,5 s; zoom 0.5/1/2x;
  lật camera
- [ ] **Chọn ảnh/video có sẵn** (thử cả video): chọn xong luồng bối cảnh **phải mở ra** (không đứng ở Home) → màn xáo thẻ
  (nếu phân tích > 0,3 s) → dừng ở hạng 1–3 có % → danh sách; chạm khi đang dừng thẻ thì bỏ qua
- [ ] Màn đề xuất: bỏ chọn yếu tố → danh sách đổi ngay; gõ "bãi biển" → Đề xuất lại; từ lạ → "Chưa hiểu từ: …"; ✕ trên
  ảnh đầu vào → đề xuất lại; chọn một mẫu → đóng luồng, hiện hộp cổng kiểm của mẫu đó
- [ ] Không có mẫu hợp → nút "Import ảnh mẫu của bạn" → đóng luồng, mở Photo Picker nhập ảnh
- [ ] Rời luồng → container `Library/Caches/scene-capture/` **không còn** (đã xoá)
- [ ] Tab Cài đặt: "Theo ngôn ngữ của máy" mở trang Cài đặt iOS của app; đổi ngôn ngữ ở đó → app ra đúng tiếng

## G. Phase 6 — đo trên máy thật

Làm SAU khi các mục A–F đạt. Máy sàn chưa chốt (D3 — đề xuất iPhone 11); ghi đời máy + iOS vào mỗi kết quả. Số đo
**chỉ báo cáo** — không tự sửa `GuidanceConfig` (ngưỡng chung hai nền tảng, PO quyết).

### 6a — runtime trên iPhone
- [ ] Chạy `XuatAnhMau6aTests` trên iPhone (lệnh ở `tools/so-sanh-parity/README.md`, đích là iPhone), tải container
  lấy `tmp/6a-ios-anh-mau.json` → `docs/moc/6a-ios-iphone.json`
- [ ] **ML Kit mặt có ổn định không**: chạy 3 lần (mở lại app giữa các lần), so số ảnh có `face` — trên Mac dao động
  13–63/114. iPhone cũng dao động = lỗi phải điều tra trước khi phát hành (ảnh chân dung lấy hướng mẫu từ mặt)

### 6b — độ nhiễu số đo (σ)
- [ ] Máy trên chân máy, người đứng yên 20 s, lần lượt **5 lớp** khung hình (toàn thân, 3/4, nửa người, ngực, chân dung).
  Mở bảng số liệu (bấm dòng trạng thái góc trên trái), quay màn hình 20 s. Ghi σ của từng đại lượng đang đạt/chưa đạt
  (cao/thấp, xa/gần, trái/phải, hướng mẫu, dáng). So với dung sai `accept` hiện tại: `accept ≥ 3σ` thì ổn

### 6c — hiệu năng (G1, Spike Q2 / Q5)
- [ ] Màn chụp chạy 5 phút liên tục: "Per frame … ms" ở bảng số liệu (đổi ra fps ≈ 1000 / ms); Xcode → Debug Navigator
  ghi CPU / nhiệt (Energy Impact). Đạt: **≥ 8 fps**, không bị hệ thống bóp (máy không nóng tới mức tắt camera)
- [ ] Trễ câu hướng dẫn: quay màn hình 120 fps, di máy đột ngột → đếm khung tới lúc câu đổi. Đạt: **< 350 ms**
- [ ] Chấm điểm sau quay: video 15 s → thời gian từ lúc dừng tới màn xem lại (Spike Q2: ≤ 5 s); burst 8 tấm
- [ ] Ghi `thermalState` nếu thấy máy nóng (Implementation_Guide §6 — iOS có, Android không; **chỉ báo, không port**)

### 6d — rủi ro #1: mẫu xoay đủ vòng
- [ ] Mẫu xoay chậm 360° trước camera (hoặc phát video người xoay trên màn hình khác, KHÔNG tua): khung xương có bám
  suốt vòng không, hướng mẫu (mục 1) đổi đúng lúc quay lưng / quay mặt. Android: 280/280 khung giữ được. Đếm khung mất

### 6e — ảnh cắt từ video / burst có đẹp bằng ảnh chụp thường (Spike Q1)
- [ ] Cùng cảnh: quay video → giữ 1 ảnh; chụp liên tục → giữ 1 ảnh; 1 ảnh bằng app Camera của iPhone. Cho 5 người xem mù,
  hỏi "ảnh nào đăng mạng được". Đạt: ≥ 70% nói ảnh từ app "tương đương / chấp nhận được"

### 6f — các điểm Android ghi "chưa kiểm trên máy thật"
- [ ] Dấu roll (FG 112): nghiêng máy trái → câu bảo nghiêng ngược lại đúng chiều (trùng mục D)
- [ ] Chiều camera trước khi đặt máy (FG 113): ảnh mẫu `tripod-…`, máy dựng trên bàn, khung xương không lộn
- [ ] Mốc nhãn ML Kit (FG 105): nhập 3 ảnh gương (có điện thoại trong ảnh) → tự nhận "gương"; 3 ảnh selfie
- [ ] 35°/s (FG 107): camera bối cảnh, quay di máy nhanh/chậm — "Chậm lại" hiện đúng lúc nhoè hình (trùng mục F)
- [ ] `hieuChinhGocAnh` khi ngửa > +15° (FG 87): ảnh mẫu chụp từ dưới lên → câu cao/thấp không đòi hạ máy sai
- [ ] Dấu trái/phải hướng mẫu (`PoseGeometry.kt:289`): mẫu xoay người sang trái của mẫu → câu bảo xoay đúng chiều
- [ ] Sai số góc xoay ở 0° / 45° / 90° (TONG_QUAN §10.3 #4) và theo chiều cao mẫu (#5): 2 người khác chiều cao

### 6g — chuẩn nghiệm thu tài liệu gốc
Bảng đầy đủ + cái nào còn áp dụng: `PLAN_PORT_IOS.md` → Phase 6 → **6g**. Phần cần người / máy:
- [ ] G2 (hướng mẫu ≥ 80% đúng, trước/sau ≥ 97%) và G6 (lặp lại với áo rộng + khoanh tay, suy giảm ≤ 12 điểm %) — dùng
  bộ quay của 6d
- [ ] G3 (cao/thấp ≥ 80% đúng ở 5 tầm máy, 2 người) · G4 (lớp khung hình ≥ 85% đúng ở 0,8 / 2 / 4 m)
- [ ] G5 (người lạ, 3 ảnh mẫu: góc cao / tựa tường / đứng nghiêng): vào đủ tiêu chí ≤ 45 s ở ≥ 7/10 lần
- [ ] Spike Q4 (bộ nhớ): 20 lần chụp (10 burst + 10 video), lưu hết → dung lượng app (Cài đặt → Cài đặt chung → Dung
  lượng iPhone) ≤ 500 MB, `Library/Caches/` gần như trống
- [ ] Spike Q3 (máy chọn trùng gu người): 20 lần chụp, 5 người tự chọn tấm ưng nhất trong mọi ứng viên → % lần top-5
  của app chứa tấm đó (≥ 70% đạt) — cần lưu cả ứng viên, bàn với PO cách làm trước

## Còn treo bên Android (đã báo người dùng, chưa kiểm)

Ô xem trước DỌC khi giao diện ngang, trong khi khung đo cắt NGANG.
