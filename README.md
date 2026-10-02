# Expense OCR — mini-project Flutter

Ứng dụng chi tiêu cá nhân ưu tiên Android, OCR chạy ngay trên máy.

## Chạy qua USB

1. Mở thư mục chứa README này trong VS Code hoặc Android Studio.
2. Điện thoại Android 7.0 trở lên (API 24+): bật Developer options → USB debugging.
3. Cắm cáp truyền dữ liệu, mở khóa và chấp nhận hộp thoại RSA.
4. Chạy:

```powershell
flutter pub get
flutter devices
flutter run -d <device-id>
```

Nếu không thấy điện thoại, kiểm tra cáp, chế độ USB và driver của hãng. `android/local.properties` dùng SDK đã cài trên máy này; điều chỉnh nếu chuyển máy.

```powershell
flutter build apk --debug
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`. Bản debug dành cho demo; bản phát hành cần cấu hình ký riêng.

## Luồng sử dụng

- Quét hóa đơn: camera sau, bật/tắt đèn, chạm lấy nét; có lựa chọn ảnh từ thư viện.
- Cắt ảnh: kéo góc trên trái và góc dưới phải; Toàn ảnh khôi phục ảnh. Khung camera để căn ảnh; khung trên ảnh đã chụp quyết định vùng cắt thực tế.
- Review: sửa cửa hàng, số tiền nguyên VND, ngày, danh mục; xem ảnh, văn bản OCR và thời gian nhận dạng. Thiếu số tiền phải nhập; thiếu ngày gợi ý hôm nay và hiện thông báo.
- Giao diện màu teal, thẻ tổng quan, ảnh thu nhỏ và nút lưu cố định. Văn bản OCR thu gọn bên dưới form, tối đa 240 px khi mở. Chạm lấy nét có khung vàng/xanh và phản hồi rung; khung xanh cho biết camera đã nhận lệnh đặt điểm, không phải đo độ sắc nét.
- Lưu: SQLite lưu giao dịch/văn bản OCR; ảnh thu nhỏ tối đa 600 px chiều rộng trong documents/receipts. Ảnh chụp/cắt tạm được dọn sau review.
- Danh sách: chạm để xem/sửa; menu xóa có xác nhận và dọn ảnh tương ứng.
- Donut: toàn bộ giao dịch theo 5 danh mục. Cột: tuần hiện tại T2–CN. Chạm lát/nhãn hoặc cột để xem số tiền. CustomPainter, animation 700 ms, không có thư viện biểu đồ.
- Nút + trên thanh trên để nhập thủ công.

## Cấu trúc

```text
lib/
  main.dart
  models/expense.dart                     # model SQLite
  models/expense_category.dart            # 5 danh mục
  services/database_service.dart          # SQLite CRUD
  services/receipt_parser.dart            # regex/heuristic
  services/receipt_service.dart           # ML Kit, crop, cache
  screens/home/home_screen.dart           # danh sách/thống kê
  screens/expenses/add_expense_screen.dart # nhập/review/sửa
  screens/scan/scan_screen.dart            # camera/luồng OCR
  screens/scan/crop_screen.dart            # crop kéo góc
  widgets/expense_charts.dart              # donut/cột canvas
  utils/currency_utils.dart
test/
  receipt_parser_test.dart
  review_charts_test.dart
```

Giữ schema SQLite version 1 ban đầu, nên không xóa dữ liệu cũ. Không thêm framework state management để dễ giải thích khi bảo vệ. Camera đóng/mở tuần tự theo vòng đời, giải phóng khi vào thư viện/review.

## OCR và parser

Parser bỏ dấu để nhận nhãn Việt/Anh, ưu tiên tổng cộng/thanh toán; loại tạm tính, tiền khách/thừa, điện thoại/ngày. Hỗ trợ `150.000 đ`, `150,000 VND`, `150 000`, `150,000.00`; ngày DD/MM/YYYY kiểm tra ngày lịch. Tên cửa hàng lấy từ các dòng đầu, bỏ nhãn hóa đơn/địa chỉ/điện thoại. Heuristic có thể sai với bố cục lạ hoặc OCR sai, nên luôn review.

Parser giữ tọa độ từng dòng ML Kit để ghép tổng thanh toán với số tiền bên phải cùng hàng, kể cả khi OCR đọc theo cột. Chỉ nhận ký hiệu đ đứng riêng, không lấy nhầm số trong Địa chỉ. Trường hợp thiếu tọa độ và dữ liệu mơ hồ để trống thay vì chọn số lớn nhất. Danh mục gợi ý bằng từ khóa; nếu không xác định được, review yêu cầu chọn trước khi lưu. Ví dụ hóa đơn Quạt cây Mitsubishi: 4.000.000 VND, Thiết bị.

Model Latin đóng gói qua `com.google.mlkit:text-recognition:16.0.1`, không gọi OCR đám mây. Thử chế độ máy bay sau khi cài app. Tham khảo [plugin ML Kit](https://pub.dev/packages/google_mlkit_text_recognition) và [Google ML Kit Android](https://developers.google.com/ml-kit/vision/text-recognition/v2/android).

**Chưa chứng minh yêu cầu dưới 100 ms trên điện thoại thật.** Thời gian phụ thuộc máy, độ phân giải và lần khởi tạo. Review hiển thị thời gian nhận dạng thực bao gồm chi phí lần đầu; crop/lưu ảnh không nằm trong số đo OCR.

## Kiểm tra

```powershell
flutter analyze
flutter test
```

Test parser: tổng tiền/subtotal/khách đưa/thừa, tiền dòng kế, ký hiệu đ, ngày sai, điện thoại, văn bản rỗng, total sau VAT/HOTEL. Widget test: review điền và sửa trường; donut rỗng/chọn danh mục.

Trên điện thoại cần kiểm tra: cấp/từ chối quyền; flash/lấy nét; chụp/crop/thư viện; hủy review; lưu rồi đóng/mở app; sửa/xóa và ảnh; xuống nền/quay lại; OCR chế độ máy bay; đo nhiều hóa đơn. Android là mục tiêu; Windows/web/iOS chưa xác minh luồng OCR.

Nếu pub get trên Windows báo symlink, bật Windows Developer Mode để Flutter tạo liên kết cho các scaffold desktop có sẵn. Android không cần quyền quản lý file rộng trên điện thoại.
