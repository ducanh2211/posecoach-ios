# Đề xuất: Gợi ý ảnh mẫu theo bối cảnh — xét thêm bố cục và góc máy

*17/11/2026 · Bản iOS · Chờ PO duyệt*

---

## 1. Đề bài

### Tính năng hoạt động thế nào

Người dùng cho app biết mình đang đứng ở đâu, bằng một trong bốn cách: chụp ảnh, quay video ngắn, chọn ảnh có sẵn,
hoặc gõ vài chữ mô tả. App gợi ý những ảnh mẫu hợp với chỗ đó. Cách xếp hạng hiện nay:

1. Mỗi ảnh tính là một góc nhìn. Video lấy tối đa 12 góc (khoảng 1 khung mỗi giây). Câu gõ tính là một góc.
2. Mỗi góc được gắn nhãn nội dung (ví dụ: bàn, ghế, bầu trời, toà nhà). App chỉ dùng 50 nhãn về cảnh, và chỉ giữ nhãn
   nào máy chắc từ 60% trở lên.
3. Mỗi ảnh mẫu cũng có sẵn bộ nhãn như vậy. Hai bên càng nhiều nhãn chung, nhãn càng chắc, thì điểm càng cao.
4. Với mỗi ảnh mẫu, lấy điểm của góc khớp nhất, rồi xếp từ cao xuống thấp. Thẻ ảnh mẫu ghi "Có: … / Thiếu: …".

### Giới hạn của cách hiện tại

App chỉ biết **trong ảnh có gì**, không biết không gian rộng hay hẹp, sáng hay tối, và máy có đặt được ở góc ảnh mẫu
cần hay không. Có ba kiểu gợi ý sai mà cách này không tránh được:

| Kiểu sai | Ví dụ | Vì sao |
|---|---|---|
| **Cùng đồ vật, khác không gian** | Đứng trong quán cà phê nhỏ, chật, app gợi ý ảnh mẫu ở sảnh khách sạn rộng vì cả hai đều có bàn, ghế | Nhãn chỉ nói *có hay không*, không nói rộng hay hẹp, gần hay xa |
| **Không có nhãn nào** | Bức tường graffiti, cầu thang, hành lang, ruộng bậc thang | Không nằm trong 50 nhãn nên không gợi ý gì, trừ khi người dùng gõ chữ |
| **Sai góc máy** | Đứng ở ban công hẹp (chỉ chụp ngang được), app gợi ý ảnh mẫu chụp từ dưới lên vì cùng có bầu trời, toà nhà | Không xét vị trí đặt máy |

Các giới hạn trên rút ra từ việc đọc cách app hoạt động. **Chưa đo trên bộ ảnh thật** xem mỗi kiểu sai gặp nhiều
đến đâu.

---

## 2. Tóm tắt đề xuất

| # | Đề xuất | Loại | Ưu tiên | Trạng thái |
|---|---|---|---|---|
| 1 | So độ giống tổng thể giữa ảnh bối cảnh và ảnh mẫu, cộng thêm vào điểm | Cách xếp hạng | Cao | Chờ duyệt |
| 2 | So góc máy của ảnh bối cảnh với góc máy ảnh mẫu, giảm điểm ảnh mẫu lệch góc | Cách xếp hạng | Trung bình | Chờ duyệt |
| 3 | Lưu thêm dữ liệu đi kèm ảnh mẫu để không phải tính lại | Lưu trữ | Cao (đi kèm #1) | Chờ duyệt |
| 4 | So bố cục từng vùng cảnh (trời, sàn, tường ở đâu) | Cách xếp hạng | Thấp | Chỉ làm khi cần |

**Giữ nguyên:** bốn cách nhập bối cảnh, giao diện luồng, 50 nhãn cảnh và mức 60%, cách lấy góc khớp nhất, câu
"Có: … / Thiếu: …" trên thẻ. Chỉ đổi cách tính điểm xếp hạng.

#1 đến #3 là **giai đoạn 1**: dùng thư viện đã có, chỉ thêm một file model nhỏ. #4 là **giai đoạn 2**, chỉ làm nếu
sau giai đoạn 1 vẫn còn nhiều ca sai vì bố cục.

Mọi đề xuất đều đổi kết quả gợi ý, nên theo nguyên tắc của dự án phải làm ở bản Android trước, iOS làm theo.

---

## 3. Chi tiết từng đề xuất

### Đề xuất 1. So độ giống tổng thể

**Đề xuất.** Dùng một model nhỏ biến mỗi ảnh thành một "dấu vân tay" (dãy số tóm tắt kiểu không gian, bố cục, tông
màu). Hai ảnh càng giống thì hai dấu vân tay càng gần nhau. Độ giống này được **cộng thêm** vào điểm nhãn hiện có.

- Ảnh mẫu tính dấu vân tay một lần rồi lưu lại (đề xuất 3).
- **Che người trong ảnh mẫu trước khi tính.** Ảnh mẫu luôn có người chiếm phần lớn khung, ảnh bối cảnh thường không
  có, nên nếu không che thì hai bên luôn bị coi là khác nhau. App đã biết vị trí người trong ảnh mẫu từ lúc nhập ảnh,
  chỉ cần tô vùng đó bằng màu trung tính. Che hay không che cho kết quả tốt hơn thì cần đo (mục 4, bước 2).
- **Ảnh mẫu không chung nhãn nào nhưng rất giống** (ví dụ tường graffiti) vẫn được gợi ý nếu độ giống vượt một mức
  nhất định. Thẻ ghi "Giống bối cảnh của bạn" thay cho dòng "Có: …".
- **Câu gõ** không có ảnh nên không có dấu vân tay. Góc đó chỉ dùng điểm nhãn như hiện nay, không bị trừ điểm.

**Lý do chọn.**
- *Bắt được cái nhãn bỏ sót:* không bị giới hạn bởi danh sách 50 nhãn, nên xử lý được kiểu sai "không có nhãn nào" và
  một phần kiểu "cùng đồ vật, khác không gian".
- *Hai bản đối chiếu được:* model này nằm trong cùng thư viện MediaPipe mà cả iOS và Android đang dùng, cùng phiên
  bản. Chỉ thêm một file model.
- *Nhẹ:* chạy nhanh hơn nhiều so với bước đọc góc máy, đủ nhanh cho cả 12 khung video. Thời gian thật cần đo ở bước 2.

**Phương án đã cân nhắc và loại.**
- *Công cụ có sẵn của Apple* (so ảnh, nhận đường chân trời, vùng nổi bật): Android không có bản tương đương, hai bản
  sẽ gợi ý khác nhau.
- *Thêm nhãn mới vào danh sách 50 nhãn:* model gắn nhãn chỉ có một bộ nhãn cố định, không thêm được nhãn kiểu
  "graffiti", "hành lang".

**Ảnh hưởng.**
- *Người dùng:* gợi ý sát với chỗ đang đứng hơn. Có thêm ảnh mẫu được gợi ý ở những chỗ trước đây không ra kết quả.
- *Sản phẩm:* thêm câu "Giống bối cảnh của bạn" trên thẻ. Dung lượng app tăng thêm bằng một file model nhỏ.
- *Rủi ro:* các mức cộng điểm và mức "rất giống" chưa có, phải đo trên bộ có đáp án. Nếu đặt sai, ảnh mẫu chỉ giống
  tông màu mà khác hẳn không gian có thể được đẩy lên.

### Đề xuất 2. So góc máy

**Đề xuất.** Với ảnh chụp bối cảnh, chạy bước đọc góc máy từ nền ảnh (cùng bước app đang dùng lúc nhập ảnh mẫu), rồi
xếp vào một trong ba mức: từ trên cao, ngang, từ dưới thấp, theo đúng mốc như lúc nhập ảnh mẫu. So với mức góc của
ảnh mẫu:

- Cùng mức: giữ nguyên điểm.
- Lệch mức: nhân điểm với một hệ số nhỏ hơn 1. **Không loại hẳn**, vì khi chụp thật người dùng vẫn có thể đổi cách cầm
  máy.
- Thẻ ảnh mẫu lệch góc ghi thêm câu nhắc, ví dụ *"Ảnh mẫu chụp từ dưới lên, bạn cần chỗ thấp hơn để chụp góc này"*.

**Không áp khi:** ảnh mẫu chưa có nhãn góc máy; góc bối cảnh nằm sát ranh giới giữa hai mức (cùng quy tắc "không
chắc" như lúc nhập ảnh mẫu); bối cảnh là video hoặc câu gõ.

**Chỉ chạy cho ảnh chụp, không cho video:** bước đọc góc máy mất vài giây mỗi ảnh, 12 khung video sẽ quá chậm.

**Lý do chọn.** Xử lý kiểu sai "sai góc máy". Không cần công cụ mới: bước đọc góc máy đã có sẵn trong app.

**Liên quan tới đề xuất nhập ảnh mẫu.** Đề xuất 1 trong tài liệu [nhập ảnh mẫu và tự nhận
diện](nhap-anh-mau-tu-nhan-dien.md) đề nghị lưu góc máy ảnh mẫu đúng như số đo thay vì ba mức. Nếu đề xuất đó được
duyệt, phần này nên so góc bằng độ thay vì so mức, và nên làm sau đề xuất đó. Khi đó, điều kiện "góc sát ranh giới"
ở trên cũng nên đổi thành mức chắc chắn của phép đọc góc (đề xuất 2 bên đó), vì ảnh bối cảnh cũng gặp các ca đọc sai
như cầu thang hay chúc gắt.

**Ảnh hưởng.**
- *Người dùng:* ít bị gợi ý ảnh mẫu không chụp được ở chỗ đang đứng. Màn xáo thẻ có thể chờ thêm vài giây khi nhập
  bằng ảnh chụp.
- *Rủi ro:* góc máy lúc người dùng chụp bối cảnh chưa chắc là góc họ sẽ chụp thật. Họ thường cầm ngang để "ghi lại
  nơi chụp". Vì vậy đây chỉ là hệ số giảm nhẹ, và cần kiểm ở bước 2 xem có làm kết quả tệ đi không.

### Đề xuất 3. Lưu thêm dữ liệu ảnh mẫu

**Đề xuất.** Mỗi ảnh mẫu lưu kèm nhãn (như hiện nay), dấu vân tay ở đề xuất 1, và phiên bản model đã dùng để tính.

- Đổi model sau này thì chỉ tính lại dấu vân tay, không phải gắn lại nhãn.
- Ảnh mẫu đã lưu theo cách cũ: giữ nhãn, chỉ tính bù dấu vân tay, rồi xoá tệp cũ để không để rác trong máy.

**Lý do chọn.** Tính dấu vân tay cho toàn bộ thư viện mỗi lần gợi ý sẽ chậm. Lưu kèm phiên bản model để biết lúc nào
cần tính lại.

**Ảnh hưởng.** Lần đầu mở bản mới, app tính bù cho các ảnh mẫu đã có. Thời gian này cần đo trên thư viện thật.

**Gộp với đề xuất nhập ảnh mẫu.** Đề xuất 1 của tài liệu [nhập ảnh mẫu và tự nhận diện](nhap-anh-mau-tu-nhan-dien.md)
cũng cần một chỗ lưu số đo góc máy đi kèm ảnh mẫu. Nên dùng chung một tệp cho cả hai, để ảnh mẫu cũ chỉ phải chuyển
đổi một lần.

### Đề xuất 4. So bố cục từng vùng cảnh (giai đoạn 2, chỉ làm khi cần)

**Đề xuất.** Nếu sau giai đoạn 1 vẫn còn nhiều ca sai vì **bố cục** (trời ở đâu, nền đất chiếm bao nhiêu, tường sát
hay xa), thêm một model chia ảnh thành từng vùng (trời, biển, tường, sàn, núi, cây…) để so bố cục giữa hai ảnh.

**Lựa chọn đã xem:**

| Lựa chọn | Thêm được | Hạn chế |
|---|---|---|
| **Model chia vùng 150 loại cảnh** (bộ ADE20K), chạy qua thư viện ONNX app đã có | Phủ cả phần nền: trời, biển, tường, sàn, núi, cây | Thêm khoảng chục MB; chậm hơn, cần đo trên máy thật |
| Model nhận đồ vật của MediaPipe (80 loại) | Vị trí, kích thước bàn, ghế, sofa, chậu cây, xe… | Không có phần nền (trời, biển, núi, tường) |
| Model chia vùng của MediaPipe (21 loại) | — | Không có trời, biển → **loại** |

Khuyến nghị nếu làm: model chia vùng 150 loại, vì phần nền mới là phần quyết định bối cảnh.

**Lý do chưa làm.** Nặng và chậm hơn hẳn giai đoạn 1. Chỉ đáng làm khi số đo cho thấy giai đoạn 1 chưa đủ. Nếu làm sẽ
viết đề xuất riêng.

---

## 4. Thứ tự đề nghị

| Bước | Việc | Bên làm | Đầu ra |
|---|---|---|---|
| 1 | PO duyệt hướng đi và phạm vi giai đoạn 1 (đề xuất 1–3) | PO | Quyết định ghi trong tài liệu dự án bên Android |
| 2 | **Lập bộ đo có đáp án.** Khoảng 20–30 bối cảnh thật, mỗi bối cảnh 3 ảnh + 1 video, kèm danh sách ảnh mẫu "hợp" do người chấm. Đo cách hiện tại sai kiểu nào; đo đề xuất 1 (có / không che người), đề xuất 2; đo thời gian chạy trên máy thật | Android + iOS | Bảng số liệu; các mức cộng điểm và hệ số giảm |
| 3 | Làm bên Android | Android | Code + kiểm tra tự động |
| 4 | Làm bên iOS theo đúng code Android | iOS | Xem phụ lục |
| 5 | Chạy lại bộ đo ở bước 2 trên cả hai bản, so với cách cũ. **Không tốt hơn rõ thì không phát hành** | Android + iOS | Bảng so sánh trước / sau |
| 6 | Quyết định có làm giai đoạn 2 không, dựa trên các ca còn sai ở bước 5 | PO | Đề xuất riêng nếu làm |

Nếu đề xuất "lưu góc máy đúng số đo" bên tài liệu nhập ảnh mẫu được duyệt, nên làm đề xuất đó trước đề xuất 2 ở đây.

## 5. Câu hỏi còn mở

- Thời gian chờ thêm bao nhiêu thì chấp nhận được? Đọc góc máy cho 3 ảnh chụp có thể thêm vài giây vào màn xáo thẻ.
- Ảnh mẫu chỉ khớp nhờ độ giống (không chung nhãn nào): hiện chung danh sách, hay tách thành mục "Có thể hợp" riêng?
- Che người trong ảnh mẫu: chờ số đo ở bước 2.
- Dung lượng app tăng thêm bao nhiêu thì chấp nhận được (file model giai đoạn 1; model chia vùng nếu làm giai đoạn 2)?

## 6. Nguồn số liệu

- Cách xếp hạng hiện tại (50 nhãn, mức 60%, lấy góc khớp nhất, tối đa 12 khung video): đọc từ code app.
- Ba kiểu gợi ý sai ở mục 1: suy ra từ cách xếp hạng, **chưa đo trên bộ ảnh thật**.
- Chưa có số đo về độ chính xác hay thời gian chạy của các đề xuất.

---

## Phụ lục: chi tiết kỹ thuật

**Công cụ:**
- Đề xuất 1: MediaPipe **ImageEmbedder** (`MPPImageEmbedder` trên iOS / `ImageEmbedder` trên Android, cùng gói
  `tasks-vision`), model MobileNetV3. Độ giống = cosine giữa hai vector, trong khoảng −1..1.
- Đề xuất 2: GeoCalib, dùng lại `GeoCalibGocMay.phanTich` → `pitchDeg`, đổi sang nhóm bằng `nhomTuGoc` (mốc ±15°).
  Ảnh mẫu lấy nhãn `GocMayNhan` (TREN / NGANG / DUOI) từ tên file.

**Công thức điểm một góc:**

    điểm = điểm nhãn + w × max(0, cosine − c₀)

- Ảnh mẫu không chung nhãn nào vẫn được gợi ý nếu `cosine ≥ c₁`.
- Lệch nhóm góc máy: nhân điểm với `k < 1`.
- `w`, `c₀`, `c₁`, `k` đặt trong `GuidanceConfig` (chỗ duy nhất chứa ngưỡng), giá trị chốt sau bước 2.

**Tệp lưu:** `scene-tags-v1.json` → `scene-tags-v2.json` (nhãn thô + vector + phiên bản model). Đọc được v1 thì giữ
nhãn, tính bù vector, xoá v1 sau khi ghi v2. Nếu đề xuất "lưu góc máy đúng số đo" bên nhập ảnh mẫu được duyệt, thêm
`pitchDeg`, độ bất định và độ rộng ống kính vào cùng tệp này, chốt định dạng một lần (cả Android lẫn iOS).

**Phần việc bên iOS (bước 4):** giữ tên type, tên hằng số và công thức như bản Kotlin.

- `PoseDomain/Scene/SceneMatch.swift`: công thức điểm mới + unit test (logic thuần, nhận vector và nhóm góc đã tính
  sẵn).
- `PoseDomain/Guidance/GuidanceConfig`: `w`, `c₀`, `c₁`, `k`.
- `Services/`: bọc `MPPImageEmbedder` cùng chỗ với các service MediaPipe khác; GeoCalib dùng lại `GeoCalibGocMay`.
- `Features/Scene/SceneRepository.swift`: tính vector cho góc bối cảnh và ảnh mẫu, tệp lưu v2, GeoCalib cho ảnh chụp.
- `Features/Scene/SceneSuggestView.swift`: câu "Giống bối cảnh của bạn", câu nhắc lệch góc.
- `Resources/`: file model embedder (lấy cùng file với Android).
- `Localizable.xcstrings`: câu mới tiếng Anh + tiếng Việt.
- `docs/PLAN_PORT_IOS.md`, `docs/CHECKLIST_KIEM_IPHONE.md`: thêm bước và mục kiểm.
