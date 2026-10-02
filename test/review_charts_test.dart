import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_ocr_app/models/expense.dart';
import 'package:expense_ocr_app/models/expense_category.dart';
import 'package:expense_ocr_app/screens/expenses/add_expense_screen.dart';
import 'package:expense_ocr_app/services/receipt_parser.dart';
import 'package:expense_ocr_app/services/receipt_service.dart';
import 'package:expense_ocr_app/widgets/expense_charts.dart';
import 'package:expense_ocr_app/theme/app_theme.dart';

void main() {
  testWidgets(
    'modern review on narrow phone keeps corrected amount/category visible',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = ReceiptParser.parse(
        'Đơn vị bán hàng: CÔNG TY KẾ TOÁN THIÊN ƯNG\nĐịa chỉ: Ngõ 247 Định Công\nQuạt cây Mitsubishi LV16\nTổng tiền thanh toán: 4.000.000\nNgày ký: 02/06/2026',
      );
      const previewKey = Key('review-preview');
      await tester.pumpWidget(
        RepaintBoundary(
          key: previewKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: AddExpenseScreen(ocr: OcrResult(data, 193)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4000000'), findsOneWidget);
      expect(find.text('Thiết bị'), findsOneWidget);
      expect(find.text('247'), findsNothing);
      expect(find.text('Lưu giao dịch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('review fills editable OCR fields and shows elapsed time', (
    tester,
  ) async {
    final data = ReceiptParser.parse('SHOP\n02/10/2026\nTổng tiền 150.000 đ');
    await tester.pumpWidget(
      MaterialApp(home: AddExpenseScreen(ocr: OcrResult(data, 123))),
    );
    expect(find.text('SHOP'), findsOneWidget);
    expect(find.text('150000'), findsOneWidget);
    expect(find.textContaining('123 ms'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Cửa hàng sửa lại',
    );
    expect(find.text('Cửa hàng sửa lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('charts handle empty data and allow selecting a category', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ExpenseCharts(expenses: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có dữ liệu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final expenses = [
      Expense(
        merchant: 'SHOP',
        amount: 150000,
        transactionDate: DateTime.now(),
        category: ExpenseCategory.food,
        createdAt: DateTime.now(),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ExpenseCharts(expenses: expenses)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống: 150.000 đ'));
    await tester.pumpAndSettle();
    expect(find.text('Ăn uống\n100.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
