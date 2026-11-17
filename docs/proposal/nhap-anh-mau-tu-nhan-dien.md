# Đề xuất cải tiến: Nhập ảnh mẫu và tự nhận diện

*17/11/2026 · Bản iOS*

---

## 1. Đề bài

> "Kiểm tra phần import ảnh, để hiểu những tiêu chí nào phải gán thủ công và tiêu chí nào model có thể tự detect
> được. Test xem còn giới hạn gì khi model check tiêu chí với cam sau không."

### Tính năng hoạt động thế nào

Người dùng chọn một ảnh trong thư viện ảnh của máy để làm ảnh mẫu. Trong vài giây, app làm ba việc:

1. **Tìm người trong ảnh** và kiểm xem ảnh có dùng làm mẫu được không. Ảnh không có người, người quá nhỏ hay đang nằm
   thì bị từ chối, kèm lý do.
2. **Gắn nhãn nội dung ảnh** (ví dụ: trong ảnh có điện thoại không, có giống ảnh selfie không).
3. **Đọc góc máy từ nền ảnh**: đường chân trời, cạnh tường, mặt sàn. Từ đó suy ra máy đang chúc xuống, ngửa lên hay để
   ngang, và ống kính rộng hay hẹp.

Từ ba nguồn này, app tự đoán các thông tin cần thiết. Nếu chắc chắn hết, app mở thẳng màn chụp. Nếu chưa chắc điều gì,
app mở một bảng nhỏ, **chỉ hỏi đúng điều đó**, và đã chọn sẵn câu trả lời app đoán.

### Phần nào phải gán, phần nào app tự đo

Có **ba thông tin** app không tự đo được từ ảnh một cách chắc chắn. App đoán trước, rồi chỉ hỏi khi không chắc:

| Thông tin | Dùng để làm gì | App đoán dựa vào | Khi nào phải hỏi |
|---|---|---|---|
| **Ai chụp**: người khác chụp, selfie, chụp gương, hay đặt máy tự chụp | Mở camera trước hay sau, cách nói câu hướng dẫn | Trong ảnh có điện thoại không, có giống selfie không, tay có ra ngoài khung không | Các dấu hiệu mâu thuẫn nhau. Riêng "đặt máy tự chụp" thì app chưa bao giờ tự đoán ra, luôn phải chọn tay |
| **Góc máy**: từ trên cao, ngang, hay từ dưới thấp | Hướng dẫn người chụp chúc/ngửa máy và đặt máy cao/thấp | Góc đọc được từ nền ảnh | Nền ảnh không đọc được, hoặc góc nằm sát ranh giới giữa hai mức |
| **Kiểu chụp từ trên cao**: đứng gần giơ máy lên, hay đứng xa rồi zoom | Hướng dẫn zoom và khoảng cách | Độ rộng ống kính, đầu to hơn chân bao nhiêu | Không thấy rõ chân và ống kính không rộng hẳn. Trên bộ ảnh thử thì khoảng 1/4 số ảnh phải hỏi |

Các tiêu chí còn lại **app tự đo** từ người trong ảnh, không cần ai gán: mẫu quay hướng nào, đứng xa hay gần, lệch trái
hay phải, dáng tay chân, và độ méo phối cảnh (chỉ với ảnh thấy chân). Máy cầm có thẳng không thì đo bằng cảm biến lúc
chụp. Độ nét, ảnh có cắt ngang khớp không, mắt có mở không thì chấm sau khi chụp.

### Giới hạn khi chấm với camera sau

Các giới hạn dưới đây rút ra từ việc đọc cách app hoạt động. **Chưa kiểm trên iPhone thật.**

1. **Góc máy bị làm tròn quá thô.** App đọc được góc khá chính xác (ví dụ chúc 20°), nhưng chỉ lưu lại một trong ba
   mức: trên cao (coi là chúc 35°), ngang (0°), dưới thấp (ngửa 25°). Ảnh chúc 20° vì thế bị coi là chúc 35°, lệch 15°.
   Mức lệch này còn lớn hơn khoảng sai cho phép khi hướng dẫn, nên người chụp có thể bị bảo "chúc thêm" dù đã giống
   ảnh mẫu.
2. **Độ rộng ống kính của ảnh mẫu bị giả định.** App đọc được độ rộng thật nhưng không dùng tới, mà coi mọi ảnh mẫu
   như chụp bằng ống kính thường. Ảnh mẫu chụp góc rộng 0.5x vì thế bị lệch khi so độ cao máy.
3. **Ảnh chụp từ trên cao hoặc dưới thấp mất hướng dẫn "lùi/tiến".** Vì góc bị làm tròn thành mức gắt, app tắt luôn
   phép đo độ méo cho mọi ảnh thuộc hai nhóm này, kể cả ảnh chỉ hơi chúc.
4. **Ảnh có điện thoại dễ bị nhận nhầm là chụp gương.** Nếu người mẫu cầm điện thoại khi được người khác chụp, app có
   thể coi là ảnh chụp gương, mở thẳng màn chụp ở chế độ gương mà không hỏi.
5. **Người dùng không biết app đã đoán gì, và không sửa được.** Khi app tự tin và mở thẳng màn chụp, người dùng không
   thấy app đã gán gì. Ảnh đã lưu thì không có chỗ đổi lại nhãn, muốn sửa phải xoá rồi nhập lại.
6. **Ảnh mẫu selfie mà chuyển sang camera sau** thì hướng dẫn khoảng cách vẫn theo kiểu selfie (tầm tay), không hợp
   với việc một người khác đứng xa cầm máy.
7. **Đọc góc từ nền ảnh có lúc sai nặng:** ảnh chúc rất gắt (gần như chỉ thấy sàn), ảnh có cầu thang (có lần đọc
   ngược hẳn, chụp từ trên xuống thành từ dưới lên), ảnh selfie sát mặt (nền ít đường thẳng).
8. **Nhiều ngưỡng và quy tắc đoán chưa được kiểm trên đủ dữ liệu.** Các quy tắc đoán "ai chụp" và "kiểu chụp từ trên
   cao" mới được chọn trên khoảng 15–17 ảnh. Phần lớn ngưỡng hướng dẫn chưa đo trên máy thật.

---

## 2. Tóm tắt đề xuất

| # | Đề xuất | Loại | Ưu tiên | Trạng thái |
|---|---|---|---|---|
| 1 | Lưu góc máy và độ rộng ống kính đúng như số đo, không làm tròn về 3 mức | Cách đo | Cao | Chờ duyệt |
| 2 | Cho app biết khi nào việc đọc góc từ nền ảnh không đáng tin, để hỏi lại người dùng | Cách đo | Cao (đi kèm #1) | Chờ duyệt |
| 3 | Ảnh có điện thoại thì hỏi xác nhận, không mặc định là chụp gương | Quy tắc đoán | Trung bình | Chờ số liệu |
| 4 | Tự đoán ảnh "đặt máy tự chụp" | Quy tắc đoán | Thấp | Chờ dữ liệu ảnh |
| 5 | Chạy song song hai bước phân tích để nhập ảnh nhanh hơn | Tốc độ | — | **Đã làm** |
| 6 | Cho người dùng thấy app đã tự nhận ra gì, kèm nút sửa | Trải nghiệm | Sau | Hoãn |
| 7 | Cho sửa thông tin ảnh đã nhập ngay trong thư viện | Trải nghiệm | Sau | Hoãn |
| 8 | Nhắc khi chuyển sang camera sau với ảnh mẫu selfie | Trải nghiệm | Sau | Hoãn |

Các đề xuất #1 đến #4 thay đổi cách đo hoặc cách đoán. Theo nguyên tắc của dự án, những thay đổi này phải làm ở bản
Android trước, để hai bản luôn cho cùng kết quả. #5 chỉ thay đổi tốc độ, không đổi kết quả, nên làm riêng ở iOS được.
#6 đến #8 thuộc trải nghiệm người dùng, để dành cho giai đoạn hoàn thiện UX.

---

## 3. Chi tiết từng đề xuất

### Đề xuất 1. Lưu góc máy đúng như số đo

**Đề xuất.** Khi nhập ảnh, app giữ nguyên góc máy đọc được từ nền ảnh (ví dụ "chúc 20°") và độ rộng ống kính, thay vì
làm tròn về ba mức trên cao, ngang, dưới thấp. Người dùng vẫn xác nhận khi app không chắc (xem đề xuất 2). Bộ ảnh mẫu
có sẵn trong app, nếu không đọc được góc, vẫn dùng ba mức như hiện nay.

**Lý do chọn.**
- Giải quyết trực tiếp giới hạn 1, 2 và 3.
- Đo trên 28 khung hình có đáp án từ cảm biến, cách đọc góc từ nền ảnh sai trung bình khoảng **4,6°**, và 25/28 khung
  lệch không quá 10°. Trong khi đó, chỉ riêng việc làm tròn đã gây lệch 5–15°. Mức sai 4,6° nằm gọn trong khoảng sai
  cho phép khi hướng dẫn (10–12°).
- Nhóm Android đã đi tới cùng kết luận khi đo: ba mức gộp nhầm hai việc khác nhau. Ví dụ một ảnh được gán "dưới thấp"
  thực ra máy đặt thấp nhưng không ngửa lên, và việc đọc từ nền ảnh cho kết quả đúng.
- Không cần thêm công cụ mới: app đã đọc góc này mỗi lần nhập ảnh, chỉ là đang bỏ phí kết quả.

**Phương án đã cân nhắc và loại.**
- *Tăng lên 5–7 mức:* giảm sai số làm tròn nhưng không hết, mà lại phải hỏi người dùng nhiều hơn.
- *Giữ 3 mức, nới khoảng sai cho phép:* che lỗi chứ không sửa, làm giảm độ chính xác với cả những ảnh vốn đúng mức.

**Ảnh hưởng.**
- *Người dùng:* ít bị bảo "chúc thêm, ngửa thêm" khi đã chụp giống mẫu. Ảnh chụp từ trên cao hoặc dưới thấp có lại
  hướng dẫn lùi/tiến.
- *Sản phẩm:* bảng xác nhận lúc nhập ảnh đổi từ "chọn 1 trong 3 mức" sang "app đo được chúc khoảng X°, đúng không?".
  Cần thêm một chỗ lưu số đo đi kèm ảnh mẫu.
- *Hướng dẫn khi chụp:* khi số đo phía ảnh mẫu chính xác hơn, có thể siết lại khoảng sai cho phép của hai mục góc máy.
  Hiện hai mục này đang được nới rộng chính vì phía ảnh mẫu kém chính xác. Cần đo trên máy thật trước khi siết.
- *Android:* làm trước, cùng cách lưu.
- *Rủi ro:* giới hạn 7 (cầu thang, chúc gắt) vẫn còn. Nếu tin hoàn toàn số đo thì những ca sai nặng sẽ lọt qua mà
  không được hỏi. **Vì vậy đề xuất này chỉ an toàn khi làm cùng đề xuất 2.**

### Đề xuất 2. Biết khi nào việc đọc góc không đáng tin

**Đề xuất.** Ngoài con số góc máy, app lấy thêm mức độ chắc chắn của chính phép đọc đó (model gốc có sẵn thông tin
này). Khi mức chắc chắn thấp, hoặc góc quá gắt, app vẫn mở bảng hỏi người dùng. Mốc đề nghị: độ bất định từ 8° trở
lên (theo đề xuất của nhóm Android), hoặc góc chúc/ngửa từ khoảng 45° trở lên (phỏng đoán, cần đo lại).

**Lý do chọn.** Đây là điều kiện để đề xuất 1 không bỏ sót những ca hiện đang được hỏi. Hiện app chỉ nhận con số góc,
không có cách nào biết khi nào phép đọc đang đoán non tay.

**Ảnh hưởng.**
- *Người dùng:* một phần ảnh đang vào thẳng màn chụp sẽ phải xác nhận thêm một bước.
- *Giới hạn còn lại:* không bắt được ca cầu thang. Trong lần đo của Android, ca này đọc ngược hẳn mà model vẫn báo là
  khá chắc.

### Đề xuất 3. Ảnh có điện thoại thì hỏi xác nhận

**Đề xuất.** Khi trong ảnh có điện thoại, app vẫn chọn sẵn "chụp gương", nhưng chỉ coi là chắc chắn khi có thêm dấu
hiệu khác (ví dụ tay cầm máy ra ngoài khung, hoặc ảnh bị lật ngược trái phải). Không có thì hỏi người dùng.

**Lý do chọn.** Đây là ca đoán sai dễ gặp nhất (giới hạn 4), mà hậu quả lại nặng: mở sai chế độ, hướng dẫn trái/phải bị
đảo, và người dùng không hiểu vì sao (giới hạn 5).

**Ảnh hưởng.**
- *Người dùng:* một phần ảnh chụp gương thật sẽ phải bấm xác nhận thêm.
- *Cần làm trước:* nên đếm xem trên bộ ảnh thật có bao nhiêu ảnh bị nhầm và bao nhiêu ảnh sẽ phải hỏi thêm, rồi mới
  chốt.

### Đề xuất 4. Tự đoán ảnh "đặt máy tự chụp"

**Đề xuất.** Thêm cách nhận ra ảnh đặt máy tự chụp: không có tay cầm máy, không có điện thoại, máy đặt ngang, người
đứng xa.

**Lý do chọn.** Hiện app không bao giờ tự đoán ra loại này. Người dùng nhập ảnh đặt máy gần như luôn bị xếp vào "người
khác chụp" (mở camera sau), trừ khi tự bấm sửa.

**Ảnh hưởng.** Dễ nhầm với "người khác chụp" vì hai loại nhìn rất giống nhau trên ảnh, nên có lẽ chỉ nên chọn sẵn để
người dùng xác nhận. **Chưa làm được ngay:** chưa có bộ ảnh đặt máy có đáp án để thử.

### Đề xuất 5. Nhập ảnh nhanh hơn ✅ Đã làm (17/11/2026)

**Đề xuất.** Bước gắn nhãn nội dung ảnh và bước đọc góc từ nền ảnh không phụ thuộc nhau, nên cho chạy cùng lúc thay vì
lần lượt.

**Lý do chọn.** Rút ngắn thời gian chờ khi nhập ảnh khoảng 0,6 giây (ước tính) mà kết quả nhận diện không đổi chút nào.

**Ảnh hưởng.**
- *Người dùng:* chờ ngắn hơn một chút. Thanh tiến độ bớt một nấc.
- *Máy:* trong vài giây đó máy làm hai việc cùng lúc nên có thể ấm hơn chút. Cần xem trên iPhone thật.
- *Android:* không bắt buộc làm theo, vì đây chỉ là cách chạy chứ không phải kết quả.
- *Kiểm chứng:* toàn bộ kiểm tra tự động của app đều qua (68/68, 17/11/2026). Thời gian thực tế trên iPhone chưa đo.

### Đề xuất 6, 7, 8. Trải nghiệm người dùng (hoãn)

| # | Đề xuất | Giải quyết |
|---|---|---|
| 6 | Ở màn chụp, hiện vài giây dòng "Tự nhận: người khác chụp · từ trên cao", kèm nút **Sửa** | Người dùng không biết app đã đoán gì (giới hạn 5) |
| 7 | Trong thư viện, nhấn giữ ảnh đã nhập để sửa thông tin | Không sửa được sau khi lưu (giới hạn 5) |
| 8 | Nhắc khi chuyển sang camera sau với ảnh mẫu selfie | Hướng dẫn khoảng cách không hợp (giới hạn 6) |

Hoãn vì app đang ở giai đoạn phát triển và kiểm tính năng, chưa tối ưu trải nghiệm.

**Lưu ý cho người test:** khi chưa có đề xuất 6, nếu thấy hướng dẫn sai thì khó biết là do app *đoán sai thông tin
ảnh* hay do *phần hướng dẫn lúc chụp sai*. Cách tạm: xem tên của ảnh sau khi nhập. Thông tin app đã gán nằm ngay trong
tên ảnh (ví dụ `selfie-tren-…`).

---

## 4. Thứ tự đề nghị

1. **Đề xuất 1 và 2:** gửi nhóm Android như một gói, vì đề xuất 1 cần đề xuất 2 mới an toàn.
2. **Đề xuất 3:** khi đã có số liệu về tỉ lệ nhầm ảnh chụp gương.
3. **Đề xuất 6, 7, 8:** ở giai đoạn hoàn thiện trải nghiệm.
4. **Đề xuất 4:** khi có bộ ảnh đặt máy tự chụp.

## 5. Nguồn số liệu

- Số đo độ chính xác khi đọc góc từ nền ảnh: tài liệu phân tích của nhóm Android, đo ngày 07–08/10/2026, trên 28 khung
  hình có đáp án từ cảm biến và 30 ảnh mẫu gán nhãn bằng mắt.
- Số liệu đoán kiểu chụp từ trên cao: 17 ảnh thử của nhóm Android.
- Mọi giới hạn ở mục 1 rút ra từ việc đọc cách app hoạt động, chưa kiểm trên iPhone thật.
