/// CÂU CHỮ CHƯA DỊCH — tầng logic trả về cái này thay vì chuỗi viết sẵn. Port từ `KT/ui/UiText.kt`.
///
/// App theo ngôn ngữ của máy (tiếng Anh mặc định, tiếng Việt khi máy đặt tiếng Việt). Tầng đo đạc và
/// hướng dẫn chỉ nói "câu số mấy, với số liệu gì", giao diện mới đổi ra chữ (Phase 4a).
///
/// Khác Android: Android dùng mã số `R.string.x` (`Int`), iOS dùng **key của String Catalog**
/// (`String`) — key = đúng tên resource Android (`Localizable.xcstrings` sinh từ `strings.xml`).
/// Các thuộc tính `…Res` của các type khác (vd. `FramingClass.labelRes`) cũng là key như vậy.
///
/// Tham số có thể lồng một `UiText` khác (vd. "Lùi lại %1$@" với "2 bước") — dịch trước rồi mới ghép.
public enum UiText: Equatable, Sendable {
    case res(String, [UiTextArg] = [])
    case plural(String, count: Int, [UiTextArg] = [])
    /// Ghép nhiều câu bằng một dấu ngăn, ví dụ danh sách tên tiêu chí.
    case join([UiText], separator: String)
    /// Chữ không cần dịch: số, tên file, lỗi gốc của hệ thống.
    case raw(String)
}

/// Tham số của `UiText`. Kotlin nhận `List<Any>`; iOS liệt kê đúng các kiểu Android đang truyền
/// (Int, Double, String, UiText lồng) để `UiText` so sánh được trong test.
public enum UiTextArg: Equatable, Sendable {
    case int(Int)
    case double(Double)
    case string(String)
    case text(UiText)
}

/// Tương đương `uiText(@StringRes id, vararg args)` của Kotlin.
public func uiText(_ key: String, _ args: UiTextArg...) -> UiText {
    .res(key, args)
}
