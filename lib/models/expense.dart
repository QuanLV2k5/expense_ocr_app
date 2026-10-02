import 'expense_category.dart';

class Expense {
  final int? id;
  final String merchant;
  final int amount;
  final DateTime transactionDate;
  final ExpenseCategory category;
  final String? receiptImagePath;
  final String? rawOcrText;
  final DateTime createdAt;

  const Expense({
    this.id,
    required this.merchant,
    required this.amount,
    required this.transactionDate,
    required this.category,
    this.receiptImagePath,
    this.rawOcrText,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String(),
      'category': category.name,
      'receipt_image_path': receiptImagePath,
      'raw_ocr_text': rawOcrText,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      merchant: map['merchant'] as String,
      amount: map['amount'] as int,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      category: ExpenseCategory.values.firstWhere(
        (category) => category.name == map['category'],
        orElse: () => ExpenseCategory.food,
      ),
      receiptImagePath: map['receipt_image_path'] as String?,
      rawOcrText: map['raw_ocr_text'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Expense copyWith({
    int? id,
    String? merchant,
    int? amount,
    DateTime? transactionDate,
    ExpenseCategory? category,
    String? receiptImagePath,
    String? rawOcrText,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      transactionDate: transactionDate ?? this.transactionDate,
      category: category ?? this.category,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
