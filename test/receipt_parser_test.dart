import 'package:flutter_test/flutter_test.dart';
import 'package:expense_ocr_app/services/receipt_parser.dart';

void main() {
  const invoice = '''Đơn vị bán hàng: CÔNG TY KẾ TOÁN THIÊN
ƯNG
Mã số thuế: 0108892073
Địa chỉ: Số 16, Ngõ 247 Định Công Thượng, Phường Định Công, TP Hà Nội
Tên người mua hàng:
Tên đơn vị: CÔNG TY KẾ TOÁN THIÊN ƯNG
STT
01
Tên hàng hóa dịch vụ
Quạt cây Mitsubishi LV16
Bộ
02
2.000.000
Cộng tiền hàng:
Tiền thuế GTGT:
Tổng tiền thanh toán:
Signature valid
Được ký bởi: CÔNG TY
Thành tiền
4.000.000
Ngày ký: 02/06/2026
4.000.000
Người bán hàng
4.000.000
KẾ TOÁN THIÊN ƯNG''';
  test(
    'actual screenshot regression: column text does not return address 247',
    () {
      final data = ReceiptParser.parse(invoice);
      expect(data.amount, 4000000);
      expect(data.merchant, 'CÔNG TY KẾ TOÁN THIÊN ƯNG');
      expect(data.date, DateTime(2026, 6, 2));
      expect(data.category?.name, 'device');
    },
  );
  test('same-row geometry beats column order, tax, and item price', () {
    final data = ReceiptParser.parse(
      invoice,
      layout: const [
        ReceiptLine('4.000.000', 650, 550, 100, 20),
        ReceiptLine('Tổng tiền thanh toán:', 400, 600, 200, 20),
        ReceiptLine('0', 650, 575, 100, 20),
        ReceiptLine('Tiền thuế GTGT:', 400, 575, 200, 20),
        ReceiptLine('4.000.000', 650, 600, 100, 20),
        ReceiptLine('2.000.000', 500, 450, 100, 20),
      ],
    );
    expect(data.amount, 4000000);
  });
  test(
    'geometry selects payable total even when larger values occur elsewhere',
    () {
      final data = ReceiptParser.parse(
        'SHOP\nTổng tiền thanh toán:\nĐịa chỉ: Ngõ 247 Định Công',
        layout: const [
          ReceiptLine('Tổng tiền thanh toán:', 10, 100, 150, 20),
          ReceiptLine('150.000', 200, 100, 80, 20),
          ReceiptLine('2.000.000', 200, 50, 80, 20),
        ],
      );
      expect(data.amount, 150000);
    },
  );
  test('address and ambiguous separated total stay empty', () {
    expect(
      ReceiptParser.parse('SHOP\nĐịa chỉ: Số 16 Ngõ 247 Định Công').amount,
      isNull,
    );
    expect(
      ReceiptParser.parse(
        'SHOP\nTổng tiền thanh toán:\nSignature valid\n2.000.000\n4.000.000',
      ).amount,
      isNull,
    );
  });
  test('Vietnamese total beats subtotal, tender and change', () {
    final data = ReceiptParser.parse(
      'HIGHLANDS COFFEE\nHÓA ĐƠN\nNgày 02/10/2026\nTạm tính 140.000 đ\nTổng cộng 150.000 VND\nTiền khách đưa 200.000 đ\nTiền thừa 50.000 đ',
    );
    expect(data.merchant, 'HIGHLANDS COFFEE');
    expect(data.amount, 150000);
    expect(data.date, DateTime(2026, 10, 2));
  });
  test('amount on following line and grouped spaces', () {
    expect(ReceiptParser.parse('SHOP\nTHANH TOÁN\n150 000').amount, 150000);
  });
  test('English decimal suffix and invalid calendar date', () {
    final data = ReceiptParser.parse(
      'SHOP\n31/02/2026\nGrand total 150,000.00\nCash 200,000.00',
    );
    expect(data.amount, 150000);
    expect(data.date, isNull);
  });
  test('do not mistake phone and dates for amounts', () {
    final data = ReceiptParser.parse('SHOP\nTel 0901234567\nDate 02/10/2026');
    expect(data.amount, isNull);
  });
  test('empty OCR requires manual fields', () {
    final data = ReceiptParser.parse('');
    expect(data.amount, isNull);
    expect(data.date, isNull);
    expect(data.merchant, isEmpty);
  });
  test('currency without explicit total supports dong symbol', () {
    expect(ReceiptParser.parse('SHOP\n150.000 đ').amount, 150000);
  });
  test('hotel name and total inclusive of VAT', () {
    final data = ReceiptParser.parse(
      'HOTEL SUN\nTổng tiền sau VAT 220.000 đ\nThuế VAT 20.000 đ',
    );
    expect(data.merchant, 'HOTEL SUN');
    expect(data.amount, 220000);
  });
}
