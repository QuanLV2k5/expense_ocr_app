import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/expense.dart';
import '../../models/expense_category.dart';
import '../../services/database_service.dart';
import '../../services/receipt_service.dart';
import '../../theme/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  final OcrResult? ocr;
  final String? imagePath;
  final Expense? existing;
  const AddExpenseScreen({super.key, this.ocr, this.imagePath, this.existing});
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  ExpenseCategory? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final data = widget.ocr?.data;
    _merchantController.text = existing?.merchant ?? data?.merchant ?? '';
    _amountController.text =
        (existing?.amount ?? data?.amount)?.toString() ?? '';
    _selectedDate = existing?.transactionDate ?? data?.date ?? DateTime.now();
    _selectedCategory =
        existing?.category ??
        (data == null ? ExpenseCategory.food : data.category);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _saveExpense() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }
    String? thumbnail;
    setState(() => _isSaving = true);
    try {
      if (widget.imagePath != null) {
        thumbnail = await ReceiptService.saveThumbnail(widget.imagePath!);
      }
      final expense = Expense(
        id: widget.existing?.id,
        merchant: _merchantController.text.trim(),
        amount: int.parse(_amountController.text),
        transactionDate: _selectedDate,
        category: _selectedCategory!,
        receiptImagePath: thumbnail ?? widget.existing?.receiptImagePath,
        rawOcrText: widget.ocr?.data.rawText ?? widget.existing?.rawOcrText,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      if (expense.id == null) {
        await DatabaseService.instance.insertExpense(expense);
      } else {
        await DatabaseService.instance.updateExpense(expense);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      await ReceiptService.deleteThumbnail(thumbnail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lưu giao dịch: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.imagePath ?? widget.existing?.receiptImagePath;
    final raw = widget.ocr?.data.rawText ?? widget.existing?.rawOcrText;
    final data = widget.ocr?.data;
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.ocr != null
                ? 'Kiểm tra hóa đơn'
                : widget.existing != null
                ? 'Chi tiết giao dịch'
                : 'Thêm chi tiêu',
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveExpense,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isSaving ? 'Đang lưu...' : 'Lưu giao dịch'),
            ),
          ),
        ),
        body: AbsorbPointer(
          absorbing: _isSaving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (image != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_rounded,
                                  color: AppTheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Hóa đơn của bạn',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                color: AppTheme.background,
                                child: Image.file(
                                  File(image),
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, error, stack) =>
                                      const SizedBox(
                                        height: 80,
                                        child: Center(
                                          child: Text('Ảnh không còn tồn tại'),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (data != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OCR offline · ${widget.ocr!.milliseconds} ms',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const Text(
                                  'Đã đọc hóa đơn. Kiểm tra thông tin trước khi lưu.',
                                  style: TextStyle(fontSize: 12),
                                ),
                                if (data.amount == null)
                                  const Text(
                                    'Chưa xác định được tổng tiền, hãy nhập thủ công.',
                                    style: TextStyle(
                                      color: Colors.deepOrange,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (data.date == null)
                                  const Text(
                                    'Chưa tìm thấy ngày, đang gợi ý ngày hôm nay.',
                                    style: TextStyle(
                                      color: Colors.deepOrange,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Thông tin giao dịch',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Bạn có thể chỉnh sửa mọi thông tin bên dưới.',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _merchantController,
                            maxLines: 2,
                            minLines: 1,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Tên cửa hàng',
                              prefixIcon: Icon(Icons.storefront_rounded),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Vui lòng nhập tên cửa hàng.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _amountController,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Tổng số tiền',
                              hintText: '0',
                              suffixText: 'VND',
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                            ),
                            validator: (value) {
                              final amount = int.tryParse(value ?? '');
                              return amount == null ||
                                      amount <= 0 ||
                                      amount > 1000000000000
                                  ? 'Nhập số tiền hợp lệ (VND).'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<ExpenseCategory>(
                            initialValue: _selectedCategory,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Danh mục',
                              prefixIcon: Icon(Icons.grid_view_rounded),
                            ),
                            hint: const Text('Chọn danh mục'),
                            items: ExpenseCategory.values
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Row(
                                      children: [
                                        Icon(
                                          AppTheme.categoryIcon(c),
                                          size: 18,
                                          color: AppTheme.categoryColor(c),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(c.label),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            validator: (value) => value == null
                                ? 'Vui lòng chọn danh mục.'
                                : null,
                            onChanged: (value) =>
                                setState(() => _selectedCategory = value),
                          ),
                          if (data != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                data.category == null
                                    ? 'Chọn danh mục phù hợp với giao dịch.'
                                    : 'Danh mục được gợi ý từ nội dung hóa đơn.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(16),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Ngày giao dịch',
                                prefixIcon: Icon(Icons.calendar_month_rounded),
                                suffixIcon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                              ),
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(_selectedDate),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (raw != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        leading: const Icon(
                          Icons.notes_rounded,
                          color: AppTheme.primary,
                        ),
                        title: const Text(
                          'Văn bản OCR gốc',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Mở để đối chiếu với dữ liệu',
                          style: TextStyle(fontSize: 12),
                        ),
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxHeight: 240),
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                raw.isEmpty
                                    ? 'Không nhận diện được văn bản.'
                                    : raw,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
