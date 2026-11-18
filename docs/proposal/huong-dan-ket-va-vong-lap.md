# Đề xuất: Sửa lỗi hướng dẫn bị kẹt và lặp lại trên màn chụp

*18/11/2026 · Bản iOS · Chờ PO duyệt*

---

## 1. Đề bài

Màn chụp hướng dẫn người dùng đi qua từng bước cố định: xoay thẳng máy → khoảng cách → góc và độ cao máy → zoom →
bố cục → hướng người mẫu → dáng. Bước sau chỉ mở khi bước trước đã đạt.

Thứ tự này đã được kiểm lại và **giữ nguyên**: bước nào làm thay đổi số đo của các bước khác thì đứng trước. Vấn đề
không nằm ở thứ tự, mà ở chỗ **app xử lý kém những lúc nó không đo được một tiêu chí**.

### Người dùng gặp gì

1. **App đứng im, không nói gì.** Một tiêu chí lúc đo được lúc không (ví dụ đầu gối nằm sát mép khung, khi thấy khi
   không). App không tích xanh, không nhắc sửa, cũng không giải thích. Người dùng không biết đang chờ gì.
2. **App lặp mãi một câu.** Một tiêu chí hoàn toàn không đo được (ví dụ chân bị bàn ghế che). App nhắc *"không thấy
   chân, lùi ra một chút"* lặp đi lặp lại. Ở chế độ bấm tay, các bước phía sau không bao giờ được hướng dẫn.
3. **Đã bỏ qua thì không quay lại được.** Ở chế độ tự động, bước nào không đạt sau khoảng 6 giây sẽ bị bỏ qua. Sau đó
   dù người dùng muốn chỉnh cho khớp thì app cũng không kiểm mục đó nữa. Cách duy nhất là thoát màn chụp hoặc chọn
   lại ảnh mẫu, và như vậy mất luôn các bước đã đạt.

Lỗi 1 vi phạm nguyên tắc dự án *"không thất bại im lặng"*. Lỗi 2 và 3 làm người dùng bị kẹt mà không có lối ra.

---

## 2. Tóm tắt đề xuất

| # | Đề xuất | Sửa lỗi | Ưu tiên | Trạng thái |
|---|---|---|---|---|
| 1 | Chịu được số đo chập chờn | Lỗi 1 | Cao | Đã chứng minh lỗi, chờ duyệt |
| 2 | Không đo được quá lâu thì cho đi tiếp, cả ở chế độ bấm tay | Lỗi 2 | Cao | Chờ duyệt |
| 3 | Chạm vào mục đã bỏ qua để kiểm lại | Lỗi 3 | Trung bình | Chờ duyệt |

Cả ba không thêm tiêu chí mới và không đổi ngưỡng hiện có. Chỉ thêm **một hằng số thời gian** và **một thao tác chạm**.

Theo nguyên tắc dự án, phần logic hướng dẫn phải sửa ở bản Android trước, iOS làm theo, để hai bản luôn cho cùng kết
quả. Phần giao diện của đề xuất 3 thì mỗi bản tự làm theo cách của nền tảng mình.

---

## 3. Chi tiết từng đề xuất

### Đề xuất 1. Chịu được số đo chập chờn

**Vì sao xảy ra.** Mỗi tiêu chí có một bộ đếm giờ: phải đạt liên tục một lúc mới được tích xanh, phải lệch liên tục
một lúc mới bị nhắc. Hiện chỉ cần **một khung hình** không đo được là toàn bộ bộ đếm về 0. Ngược lại, chỉ cần **một
khung** đo được là bộ đếm "không đo được đã lâu" cũng về 0.

Kết quả: số đo chập chờn thì không bộ đếm nào chạy được tới đích.

**Đã kiểm chứng bằng test** (giả lập 15 khung/giây trong 20 giây, cứ vài khung thì hụt một khung):

| Thực tế người dùng đang | Mất 1/2 đến 1/4 số khung | Mất 1/6 số khung | Mất 1/10 số khung |
|---|---|---|---|
| Đúng | Không bao giờ tích xanh | Tích xanh | Tích xanh |
| Gần đúng | Im lặng mãi | Im lặng mãi | Im lặng mãi |
| Sai rõ | Không bao giờ nhắc | Không bao giờ nhắc | Nhắc |

Ở **mọi** trường hợp, câu giải thích *"không đo được"* không bao giờ hiện ra.

Trên bộ 114 ảnh mẫu, 9 trong 65 ảnh có dùng tiêu chí khoảng cách có điểm mốc nằm sát ngưỡng nhận diện. Khi chụp thật,
những ảnh mẫu này dễ rơi vào tình trạng chập chờn.

**Đề xuất.**

- **Hụt ngắn thì coi như vẫn đo được.** Nếu một tiêu chí mới mất số đo chưa quá **0,4 giây**, app dùng lại số đo gần
  nhất, gồm cả chiều lệch để câu nhắc không nói ngược hướng.
- **Đo lại được ổn định mới tính là hết "không đo được".** Phải đo được liên tục 0,4 giây thì bộ đếm "không đo được
  đã lâu" mới về 0.
- Mất dấu người hoàn toàn thì không giữ số cũ, xử lý như hiện nay.

**Sau khi sửa, kết quả mong đợi:**

| Thực tế người dùng đang | Mất một phần nhỏ số khung | Gần như không đo được |
|---|---|---|
| Đúng | Tích xanh | Giải thích sau 2,5 giây |
| Gần đúng | Nhắc sau 2,5 giây (như khi đo được đầy đủ) | Giải thích sau 2,5 giây |
| Sai rõ | Nhắc, đúng chiều | Giải thích sau 2,5 giây |

**Đánh đổi.** Trong 0,4 giây hụt, app dùng số đo hơi cũ. Con số này nhỏ hơn nhiều so với thời gian giữ một câu nhắc
(2 giây), nên người dùng không nhận ra.

**Cần đo thêm.** Con số 0,4 giây là đề xuất. Cần kiểm trên máy thật xem có đủ lấp các khoảng hụt thường gặp không.

---

### Đề xuất 2. Không đo được quá lâu thì cho đi tiếp

**Vì sao xảy ra.** App đã có cơ chế bỏ qua một bước không hội tụ, nhưng **chỉ bật ở chế độ tự động**. Ở chế độ bấm
tay, một tiêu chí không đo được sẽ chặn mọi bước phía sau mãi mãi.

**Đề xuất.** Bật cơ chế bỏ qua có sẵn **cả ở chế độ bấm tay**, nhưng chỉ cho một trường hợp: mọi tiêu chí còn lại
của bước hiện tại đều đang *"không đo được"* và đã được giải thích cho người dùng.

Diễn biến cho người dùng:

1. Khoảng 2,5 giây không đo được: app giải thích, ví dụ *"Không thấy chân, lùi ra một chút"*.
2. Khoảng 6 giây kể từ đầu bước mà vẫn không đo được: mục đó hiện nhãn **"bỏ qua"**, app chuyển sang bước tiếp theo.

Tiêu chí *đo được nhưng đang sai* vẫn chặn như hiện nay. App chỉ cho đi tiếp khi nó thật sự không có số liệu để hướng
dẫn.

**Khi chỗ chụp đang tối.** Thiếu sáng là lý do hay gặp khiến app mất điểm mốc trên người. Nếu tài liệu [cảnh báo
thiếu sáng](canh-bao-thieu-sang.md) được duyệt, trong lúc đang có cảnh báo tối:

- app **không** tự bỏ qua bước, vì người dùng bật đèn là đo được;
- câu giải thích nói lý do là ánh sáng, thay cho *"Không thấy chân, lùi ra một chút"*.

Hai tài liệu nên được duyệt cùng lúc.

**Vì sao không làm phức tạp hơn.** Đã cân nhắc thêm một trạng thái riêng *"không kiểm được"*, có chữ hiển thị riêng
và luật tự mở lại. Cách đó tốn hơn nhiều mà người dùng không được thêm gì rõ rệt. Nhãn "bỏ qua" và cơ chế bỏ qua đã
có sẵn, chỉ cần mở rộng điều kiện.

**Kết hợp với đề xuất 1.** Đề xuất này cần đề xuất 1 làm trước. Nếu số đo còn chập chờn thì bộ đếm "không đo được"
không bao giờ chạy đủ lâu để kích hoạt việc bỏ qua.

---

### Đề xuất 3. Chạm vào mục đã bỏ qua để kiểm lại

**Vì sao cần.** Sau đề xuất 2, việc bỏ qua xảy ra ở cả hai chế độ. Hiện mục đã bỏ qua nằm yên tới hết phiên. Người
dùng tự sửa được (ví dụ lùi ra cho thấy chân) nhưng app không xác nhận, không tích xanh.

**Đề xuất.** Trên danh sách tiêu chí, dòng có nhãn **"bỏ qua"** chạm được. Chạm vào thì:

- app kiểm lại mục đó từ đầu và quay về bước của mục đó;
- các bước đứng **trước** vẫn giữ nguyên trạng thái đạt;
- các bước đứng **sau** được xác nhận lại, nhưng mục nào vẫn đang đúng sẽ tích xanh lại gần như ngay lập tức.

Nên có gợi ý nhỏ cạnh nhãn, ví dụ *"Chạm để kiểm lại"*.

**Ưu điểm so với các cách khác đã xét:**

| Cách | Vấn đề |
|---|---|
| Không cho kiểm lại | Người dùng muốn sửa cũng không được ghi nhận |
| App tự mở lại khi đo được | Tự kéo người dùng lùi về bước trước trong lúc đang làm bước sau, gây nhảy bước, đúng kiểu lỗi đã từng phải sửa |
| Hiện hộp thoại hỏi "Kiểm lại không?" | Làm gián đoạn lúc đang giơ máy. Chế độ tự động không có ai trả lời |
| **Chạm để kiểm lại** | Người dùng chủ động, không gián đoạn, dùng được ở cả hai chế độ |

Nếu mục vẫn không đo được, sau vài giây nó lại bị bỏ qua như cũ. App không lặp, vì chỉ kiểm lại khi người dùng chạm.

**Vì sao làm ngay, trong khi các đề xuất trải nghiệm khác đang hoãn.** Tài liệu [nhập ảnh mẫu và tự nhận
diện](nhap-anh-mau-tu-nhan-dien.md) hoãn việc thêm nút "Sửa" trên màn chụp sang giai đoạn hoàn thiện trải nghiệm. Đề
xuất này khác: nó là **lối thoát khỏi lỗi bị kẹt**, đi kèm đề xuất 2. Không có nó thì việc bỏ qua ở chế độ bấm tay
không sửa lại được nếu bỏ nhầm.

**Ảnh hưởng tới chấm điểm.** Không có. Mục bị bỏ qua mà ảnh chụp ra vẫn đo được thì bước chấm ảnh sau khi chụp vẫn
tính độ lệch của mục đó như bình thường. Đề xuất này chỉ thêm cơ hội sửa ngay lúc chụp.

---

## 4. Thứ tự đề nghị

1. **Đề xuất 1** trước tiên. Lỗi đã chứng minh được, sửa nhỏ, và là điều kiện để đề xuất 2 hoạt động.
2. **Đề xuất 2**, ngay sau đề xuất 1.
3. **Đề xuất 3**, có thể làm song song với 2. Phần logic nhỏ; phần giao diện mỗi bản tự làm.

---

## 5. Đã xét nhưng không đưa vào

Ghi lại để không đề xuất lại khi chưa có thêm bằng chứng.

| Ý tưởng | Lý do chưa làm |
|---|---|
| Đổi thứ tự các bước, hoặc thêm bước "vào dáng sơ bộ" trước bước khoảng cách | Thứ tự hiện tại đúng về mặt vật lý. Thêm bước là quá tay so với số trường hợp bị ảnh hưởng |
| Không đo khoảng cách khi dáng người mẫu đang khác hẳn ảnh mẫu (chân chĩa về phía máy) | Giả lập trên 65 ảnh mẫu cho thấy có thể ảnh hưởng khoảng 22% ảnh mẫu, nhưng chưa chốt được ngưỡng khi chưa đo độ nhiễu trên máy thật. Sẽ quan sát khi test máy |
| Chốt một cách đo khoảng cách cho cả phiên (thân/cả chân hoặc thân/đùi) | Rủi ro mới là lý thuyết. Sẽ quan sát cùng lúc với mục trên |
| Chia tiêu chí "lõi" và "phụ", mục lõi không được tự bỏ qua | Không phải lỗi. Tự bỏ qua là thiết kế đã chọn để tránh kẹt vô hạn. Muốn đổi thì là câu hỏi sản phẩm riêng |
| Chống nhảy qua lại giữa hai bước | Chưa thấy xảy ra trên máy thật |

---

## 6. Câu hỏi còn mở

1. PO có đồng ý cho **chế độ bấm tay** cũng được bỏ qua tiêu chí không đo được (đề xuất 2) không?
2. Câu chữ cho gợi ý *"Chạm để kiểm lại"* (đề xuất 3), bản tiếng Việt và tiếng Anh.
3. Ai bên Android nhận sửa phần logic, để bản iOS làm theo?
4. Khi đang thiếu sáng, app có tạm dừng việc tự bỏ qua bước không? Câu hỏi này nằm ở tài liệu [cảnh báo thiếu
   sáng](canh-bao-thieu-sang.md), mục 5.

---

## 7. Nguồn số liệu

- **Bảng kết quả của đề xuất 1:** unit test chạy trực tiếp trên bộ đếm của một tiêu chí (`CriterionGate`) bản iOS,
  giống hệt bản Android. Giả lập 15 khung/giây trong 20 giây, với ba mức lệch (trong ngưỡng đạt, vùng đệm, lệch rõ)
  và nhiều tỉ lệ hụt khung.
- **Số ảnh mẫu có điểm mốc sát ngưỡng:** từ bộ số đo 114 ảnh mẫu của phase 6a (`docs/moc/6a-ios-anh-mau.tinh-ios.json`).
- **Con số 22% ở mục 5:** giả lập chiếu 3D từ khung xương của chính các ảnh mẫu đó, chưa phải số đo trên máy thật.

---

## Phụ lục: chi tiết kỹ thuật

Dành cho người sửa code. Tên file và dòng theo bản Android hiện tại (`guidance/`).

### A. Hằng số mới

Thêm vào `GuidanceTiming`, nơi duy nhất chứa ngưỡng:

```kotlin
/** Khoảng hụt số đo tối đa vẫn coi là "đo được". Tính theo ms, không theo số khung: nhịp nhận diện hai bản khác nhau. */
const val UNMEASURED_GAP_MS = 400L
```

### B. Đề xuất 1, phần giữ số đo qua khoảng hụt (`GuidanceEngine.kt`)

Đặt ở engine, **không** đặt trong gate. Nếu gate tự giữ trạng thái mà engine vẫn nhận độ lệch `null` thì:

- bộ lọc chọn câu nhắc (cần `deviation != null`) loại mục đó ra ở khung hụt, câu nhắc nhảy;
- `signedDelta` là `null` nên câu nhắc lấy chiều mặc định, nói sai hướng.

```kotlin
private val lastGood = mutableMapOf<Criterion, Triple<Double, Double?, Long>>() // độ lệch, có dấu, thời điểm

// Trong vòng tạo statuses, thay chỗ tính `trusted` và `signedDelta`:
val fresh = if (validFrames >= GuidanceTiming.MIN_VALID_FRAMES) deviation else null
val freshSigned = signedDelta(c, t, live, ...)
val held = lastGood[c]?.takeIf { nowMs - it.third <= GuidanceTiming.UNMEASURED_GAP_MS }
val (trusted, signed) = when {
    fresh != null -> { lastGood[c] = Triple(fresh, freshSigned, nowMs); fresh to freshSigned }
    held != null -> held.first to held.second
    else -> null to freshSigned
}
```

Xoá `lastGood` trong nhánh mất dấu người (`live == null`) và trong `reset()`.

### C. Đề xuất 1, phần bộ đếm "không đo được" (`CriterionGate.kt`)

```kotlin
private var measuredSinceMs: Long? = null

// Nhánh deviation == null (~dòng 99):
measuredSinceMs = null

// Thay `unmeasuredSinceMs = null` (~dòng 115):
val since = measuredSinceMs ?: nowMs.also { measuredSinceMs = it }
if (nowMs - since >= GuidanceTiming.UNMEASURED_GAP_MS) unmeasuredSinceMs = null

// reset(): measuredSinceMs = null
```

Đi kèm hai chỗ trong `GuidanceEngine.kt`, để câu giải thích không nhấp nháy ở những khung đo được lẻ tẻ:

- cờ `unmeasuredTooLong`: đổi điều kiện `state == UNMEASURED` thành `state != PASSING`;
- bộ lọc chọn câu nhắc: thêm nhánh `GREY -> it.unmeasuredTooLong`.

### D. Đề xuất 2 (`GuidanceEngine.kt`, khối bỏ qua bước ~dòng 391)

```kotlin
val onlyUnmeasuredLeft = currentStep.all { c ->
    val s = statuses.first { it.criterion == c }
    s.state == GateState.PASSING || s.unmeasuredTooLong
}
if ((!allowSkip && !onlyUnmeasuredLeft) || prepWarning != null) {
    currentStepSinceMs = null
} else {
    // giữ nguyên logic đếm AUTO_SKIP_AFTER_MS và bỏ qua hiện tại
}
```

### E. Đề xuất 3 (`GuidanceEngine.kt`, hàm public mới)

```kotlin
fun recheck(c: Criterion) {
    if (!skipped.remove(c)) return
    val i = steps.indexOfFirst { c in it }.takeIf { it >= 0 } ?: return
    gates[c]?.reset()
    currentStepIndex = minOf(currentStepIndex, i)
    currentStepSinceMs = null
    allGoodSinceMs = null
    presenter.reset()
}
```

Màn chụp gọi hàm này khi người dùng chạm vào dòng "bỏ qua" trên danh sách tiêu chí.

### F. Test cần có

- Bảng 3 mức lệch × nhiều tỉ lệ hụt khung, cho ra đúng bảng *"kết quả mong đợi"* ở đề xuất 1.
- Hụt một lần dài hơn `UNMEASURED_GAP_MS`: bộ đếm về 0 như hiện nay, không giữ số cũ.
- Mất dấu người: không giữ số cũ.
- Chế độ bấm tay: tiêu chí không đo được bị bỏ qua sau `AUTO_SKIP_AFTER_MS`. Tiêu chí đo được nhưng sai thì **không**
  bị bỏ qua.
- `recheck`: quay về đúng bước, các bước trước giữ trạng thái, mục vẫn không đo được thì lại bị bỏ qua.
