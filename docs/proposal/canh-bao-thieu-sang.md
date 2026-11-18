# Đề xuất: Cảnh báo thiếu sáng trên màn chụp

*17/11/2026 · Bản iOS · Chờ PO duyệt*

---

## 1. Đề bài

Hiện app **bỏ qua ánh sáng**: không đo, không nhắc, không tính vào điểm. Đây là quyết định đã ghi trong tài liệu dự
án bên Android. Đề xuất này mở lại quyết định đó, nên cần PO chốt lại bằng văn bản.

### Chuyện gì xảy ra khi chụp trong chỗ tối

1. **Khung hình vẫn trông bình thường.** Camera tự bù sáng (tăng độ nhạy, phơi lâu hơn), nên người dùng không thấy tối.
   Cái giá là ảnh nhiễu hạt và dễ nhoè khi người mẫu cử động.
2. **App mất người.** Thiếu sáng nặng thì phần nhận diện khung xương không bắt được người. App báo "không thấy người"
   trong khi người đứng ngay trước máy, và người dùng không biết phải làm gì.
3. **Nhận ít ảnh đẹp mà không rõ lý do.** Sau khi chụp, app loại các tấm bị nhoè. Chụp trong tối thì bị loại nhiều,
   người dùng chỉ thấy kết quả ít đi.

Cả ba đều sửa được ngay nếu người dùng biết lý do: bật đèn, kéo rèm, quay mặt về phía cửa sổ.

### Bản thiết kế cũ định làm gì

Bản thiết kế v3 định đưa ánh sáng thành **tiêu chí chấm điểm**: đếm số điểm ảnh bị cháy trắng hoặc tối đen, so với
ảnh mẫu. Phần này chưa từng được làm. Mục 3 giải thích vì sao đề xuất này không đi theo hướng đó.

---

## 2. Tóm tắt đề xuất

| # | Đề xuất | Loại | Ưu tiên | Trạng thái |
|---|---|---|---|---|
| 1 | Hiện câu nhắc khi chỗ chụp quá tối. Chỉ nhắc, không tính điểm, không chặn chụp | Cảnh báo | Cao | Chờ duyệt |
| 2 | Đo độ sáng bằng thông số phơi sáng của camera, không đo điểm ảnh | Cách đo | Cao (đi kèm #1) | Chờ số liệu |
| 3 | Khi không thấy người mà chỗ chụp đang tối, nói rõ lý do là ánh sáng | Trải nghiệm | Trung bình | Chờ duyệt |
| 4 | Cảnh báo ngược sáng | Cách đo | Thấp | Hoãn |

Cả bốn đề xuất đều thêm hành vi mới cho màn chụp. Theo nguyên tắc của dự án, phải làm ở bản Android trước, iOS làm
theo, để hai bản luôn cho cùng kết quả.

---

## 3. Chi tiết từng đề xuất

### Đề xuất 1. Câu nhắc thiếu sáng

**Đề xuất.** Khi chỗ chụp tối dưới một mức nhất định, màn chụp hiện câu nhắc, đặt cùng chỗ với các câu nhắc cầm máy
hiện có. Câu nhắc luôn kèm việc cần làm, ví dụ: *"Hơi tối, ảnh dễ nhiễu và nhoè. Bật thêm đèn hoặc quay mặt về phía
nguồn sáng."*

- Chạy ở cả hai chế độ: cầm máy và đặt máy tự chụp.
- Không tính vào điểm, không ảnh hưởng việc chọn ảnh đẹp, không chặn nút chụp hay đếm ngược, không so với ảnh mẫu.
- **Không ẩn các câu nhắc tư thế.** Câu nhắc thiếu sáng hiện song song với hướng dẫn đang chạy. Cảnh báo cầm máy hiện
  có thì khác: khi nó hiện, app tạm ẩn hướng dẫn tư thế và chặn chụp. Thiếu sáng **không** đi theo cách đó.
- **Tạm dừng việc tự bỏ qua bước** trong lúc đang thiếu sáng (đề nghị, chờ PO chốt). Chỗ tối thì app hay mất điểm mốc
  trên người, và theo đề xuất 2 của tài liệu [hướng dẫn bị kẹt và lặp lại](huong-dan-ket-va-vong-lap.md), các tiêu chí
  không đo được sẽ bị bỏ qua sau khoảng 6 giây. Nếu không dừng lại, app sẽ bỏ qua các tiêu chí chỉ vì tối, trong khi
  người dùng bật đèn là đo được.
- **Không nhấp nháy:** câu nhắc hiện khi xuống dưới mức tối, nhưng chỉ tắt khi đã sáng hơn hẳn mức đó và giữ được 1–2
  giây. Camera tự chỉnh sáng liên tục, nếu bật/tắt ngay theo một mốc thì câu nhắc sẽ chớp liên hồi.

**Lý do chọn.**
- *Người dùng sửa được:* bật đèn, kéo rèm, đổi hướng đứng đều làm được ngay.
- *Không phạt cái người dùng không đổi được:* nếu ánh sáng tính vào điểm, người ở chỗ không có đèn tốt sẽ kẹt ở điểm
  thấp mà không có cách sửa. Dạng nhắc chỉ báo, không giữ ảnh lại.
- *Giải thích trước khi bất ngờ:* người dùng biết trước vì sao có thể nhận ít ảnh đẹp.
- *Hợp cách app đang làm:* app đã có nhóm câu nhắc cầm máy, chạy trước các tiêu chí chấm, không tính điểm. Thiếu sáng
  thuộc đúng nhóm này, vì cùng lý do: thiếu sáng nặng thì các tiêu chí phía sau không đo được nữa.

**Phương án đã cân nhắc và loại.**
- *Làm thành tiêu chí chấm điểm như bản v3:*
  - Ảnh mẫu không đo công bằng được. Ảnh mẫu thường là ảnh mạng, ảnh chụp màn hình, ảnh đã chỉnh màu. Ảnh mẫu còn có
    thể cố ý tối hoặc ngược sáng (ảnh bóng người, ảnh tông tối), chấm theo ngưỡng sẽ phạt đúng kiểu ảnh người dùng
    muốn bắt chước.
  - Thêm một mục vào điểm là chia lại trọng số. Điểm và thứ tự chọn ảnh đều đổi, phải làm lại toàn bộ bảng đối chiếu
    iOS–Android.
- *Chặn chụp khi tối:* người cố ý chụp trong tối sẽ không chụp được.

**Ảnh hưởng.**
- *Người dùng:* thêm một câu nhắc trên màn chụp khi chỗ tối. Không thay đổi gì khi chỗ đủ sáng.
- *Sản phẩm:* thêm câu chữ mới (tiếng Anh, tiếng Việt). Điểm số và cách chọn ảnh không đổi.
- *Máy:* gần như không tốn thêm gì (xem đề xuất 2). Không làm nặng thêm vấn đề nóng máy đang xử lý.
- *Android:* làm trước.

### Đề xuất 2. Đo độ sáng bằng thông số phơi sáng

**Đề xuất.** Không nhìn vào ảnh, mà đọc ba thông số camera đang dùng ở mỗi khung hình: độ mở ống kính, thời gian
phơi, độ nhạy sáng. Từ ba số này tính ra một con số chỉ độ sáng thật của chỗ chụp (gọi là EV, chỉ số phơi sáng chuẩn
trong nhiếp ảnh). EV thấp là chỗ tối. Công thức ở phụ lục.

Mức "quá tối" **chưa chốt**, phải đo trên máy thật (mục 4, bước 2).

**Lý do chọn.**
- *Đo đúng thứ cần đo:* camera tự bù sáng nên ảnh trông vẫn bình thường. Nhìn vào ảnh chỉ thấy tối khi camera đã chịu
  thua. Thông số phơi sáng thì cho biết camera đang phải gồng bao nhiêu.
- *Hai bản đối chiếu được:* Android và iPhone đều đọc được ba thông số này, cùng đơn vị, cùng công thức, nên chỉ cần
  một mức ngưỡng chung.
- *Gần như không tốn gì:* chỉ đọc ba con số có sẵn, không xử lý ảnh.

**Phương án đã cân nhắc và loại.**
- *Đo độ sáng điểm ảnh:* chỉ bắt được lúc camera đã chịu thua. Thêm nữa, dải giá trị điểm ảnh khác nhau tuỳ cách camera
  xuất hình (trên iPhone có chế độ chỉ dùng dải 16–235 thay vì 0–255), dễ đặt sai ngưỡng.
- *Dùng chỉ số độ sáng riêng của iPhone (trong thông tin ảnh):* Android không có số tương đương, hai bản sẽ phải dùng
  hai bộ ngưỡng không so được với nhau.

**Ảnh hưởng.**
- *Rủi ro:* mỗi dòng máy Android báo thông số phơi sáng có thể lệch nhau. Bước đo ở mục 4 cần thử trên vài máy Android
  khác nhau, không chỉ một máy.

### Đề xuất 3. Nói rõ lý do khi mất người trong chỗ tối

**Đề xuất.** Khi chỗ chụp đang tối mà app không đo được, câu nhắc nói rõ lý do là ánh sáng. Áp cho cả hai ca:

- **Mất người hoàn toàn:** thay câu chung "không thấy người".
- **Mất từng phần** (không thấy chân, không thấy tay…): thay các câu giải thích kiểu *"Không thấy chân, lùi ra một
  chút"* mà tài liệu [hướng dẫn bị kẹt và lặp lại](huong-dan-ket-va-vong-lap.md) đề xuất. Trong chỗ tối, bảo người
  dùng lùi ra là chỉ sai việc cần làm.

Quy tắc chung: **đang thiếu sáng thì câu "tối" được ưu tiên hơn mọi câu "không thấy …"**.

**Lý do chọn.** Đây là ca khó hiểu nhất với người dùng: người đứng ngay trước máy mà app báo không thấy. Nguyên tắc
của dự án là không để app thất bại im lặng, mọi lỗi phải nói rõ chuyện gì xảy ra và làm gì tiếp.

**Ảnh hưởng.**
- *Sản phẩm:* cần chốt câu "tối" **thay hẳn** câu "không thấy …", hay **hiện cả hai** (xem câu hỏi mở ở mục 5).
- *Liên quan:* đề xuất này và tài liệu hướng dẫn bị kẹt cùng sửa câu giải thích "không đo được". Nên duyệt cùng lúc.

### Đề xuất 4. Cảnh báo ngược sáng (hoãn)

**Đề xuất.** Nhắc khi người mẫu đứng quay lưng về phía nguồn sáng mạnh.

**Lý do hoãn.**
- Phải so độ sáng vùng mặt với nền, tức là phải đo trên điểm ảnh, tốn hơn và dính lại bẫy dải giá trị ở đề xuất 2.
- iPhone (và nhiều máy Android, cần kiểm ở bước 2) tự ưu tiên chỉnh sáng theo mặt, nên mặt thường vẫn đủ sáng. Cái
  hỏng chủ yếu là nền bị cháy trắng, tức chuyện thẩm mỹ, không làm hỏng phép đo tư thế.
- Chờ có số liệu thật cho thấy ngược sáng làm hỏng ảnh thường xuyên rồi mới quyết.

---

## 4. Thứ tự đề nghị

| Bước | Việc | Bên làm | Đầu ra |
|---|---|---|---|
| 1 | PO duyệt đề xuất 1–3. Vì việc này mở lại quyết định "bỏ qua ánh sáng", cần ghi lại quyết định mới trong tài liệu dự án bên Android | PO | Quyết định bằng văn bản |
| 2 | **Đo để chốt ngưỡng.** Ghi chỉ số EV ở các cảnh có đáp án: ngoài trời, phòng sáng, phòng đèn vàng, phòng tối, tối tới mức app mất người. Đo trên iPhone và vài máy Android | Android + iOS | Bảng số liệu, mức "quá tối" và khoảng chờ trước khi tắt |
| 3 | Làm bên Android: tính chỉ số, câu nhắc trên màn chụp, câu chữ đa ngôn ngữ, kiểm tra tự động | Android | Code + kiểm tra tự động |
| 4 | Làm bên iOS theo đúng code Android | iOS | Xem phụ lục |
| 5 | Kiểm trên máy thật cả hai bên: câu nhắc hiện đúng lúc, không nhấp nháy, không làm nóng máy thêm | Android + iOS | Ghi vào danh sách kiểm máy thật |

Đề xuất 4 chỉ xét lại khi đã chạy bản có đề xuất 1–3 và có số liệu về ảnh ngược sáng.

Nên duyệt cùng lúc với tài liệu [hướng dẫn bị kẹt và lặp lại](huong-dan-ket-va-vong-lap.md), vì hai bên cùng đụng
tới việc bỏ qua bước và câu giải thích "không đo được".

## 5. Câu hỏi còn mở

- Mức "quá tối" bao nhiêu: chờ số đo ở bước 2.
- **Khi đang thiếu sáng, app có tạm dừng việc tự bỏ qua bước không?** Đề nghị: có (xem đề xuất 1).
- **Câu "tối" thay hẳn các câu "không thấy người / không thấy chân…", hay hiện cả hai?** Đề nghị: thay hẳn (xem đề
  xuất 3).
- Có cần nút tắt cảnh báo cho người cố ý chụp trong tối không? Nếu có, tắt cảnh báo thì việc tự bỏ qua bước chạy lại
  như bình thường.

## 6. Nguồn số liệu

- Chưa có số đo nào. Mọi nhận định ở mục 1 rút ra từ việc đọc cách app hoạt động và cách camera tự bù sáng, **chưa
  kiểm trên iPhone thật**.
- Khoảng 16–235 của điểm ảnh: theo định dạng luồng camera iOS đang dùng.

---

## Phụ lục: chi tiết kỹ thuật

**Công thức:**

    EV100 = log2(N² / t) − log2(ISO / 100)

| Đại lượng | Android | iOS |
|---|---|---|
| N — độ mở ống kính | `LENS_APERTURE` | `AVCaptureDevice.lensAperture` |
| t — thời gian phơi (giây) | `SENSOR_EXPOSURE_TIME` (ns → s) | `AVCaptureDevice.exposureDuration` |
| ISO | `SENSOR_SENSITIVITY` | `AVCaptureDevice.iso` |

**Phần việc bên iOS (bước 4):** giữ tên type, tên hằng số và công thức như bản Kotlin.

- `PoseDomain/Guidance/<tên theo Kotlin>.swift`: logic thuần (nhận EV100, trả mã câu nhắc, có độ trễ bật/tắt) + unit
  test.
- `GuidanceConfig`: ngưỡng EV100 và khoảng Δ để tắt (chỗ duy nhất chứa ngưỡng).
- `Services/Camera`: đọc `lensAperture`, `exposureDuration`, `iso` mỗi khung, tính EV100.
- `Features/Capture`: câu nhắc đặt cùng chỗ hiển thị với cảnh báo của `CameraPrep`, nhưng **không** truyền vào
  `GuidanceEngine` qua `prepWarning`. `prepWarning != nil` làm engine ẩn câu nhắc, dừng đếm `AUTO_SKIP_AFTER_MS` và
  chặn cổng chụp (`GuidanceEngine.swift` ~dòng 323, 411, 433). Cần một tham số riêng (vd. `thieuSang`), chỉ dừng đếm
  bỏ qua bước và đổi câu giải thích "không đo được".
- `Localizable.xcstrings`: câu nhắc tiếng Anh + tiếng Việt.
- `docs/PLAN_PORT_IOS.md`, `docs/CHECKLIST_KIEM_IPHONE.md`: thêm bước và mục kiểm.
