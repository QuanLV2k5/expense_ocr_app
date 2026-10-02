import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/expense.dart';
import '../../models/expense_category.dart';
import '../../services/database_service.dart';
import '../../services/receipt_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/expense_charts.dart';
import '../../utils/currency_utils.dart';
import '../expenses/add_expense_screen.dart';
import '../scan/scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Expense> _expenses = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final expenses = await DatabaseService.instance.getExpenses();

      if (!mounted) {
        return;
      }

      setState(() {
        _expenses = expenses;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Không tải được dữ liệu: $e';
        });
      }
    }
  }

  Future<void> _openScan() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (result == true && mounted) {
      await _loadExpenses();
    }
  }

  Future<void> _editExpense(Expense expense) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(existing: expense)),
    );
    if (result == true && mounted) {
      await _loadExpenses();
    }
  }

  Future<void> _openAddExpense() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
    );

    if (result == true) {
      await _loadExpenses();
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    if (expense.id == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa giao dịch'),
          content: Text(
            'Bạn có chắc muốn xóa giao dịch tại '
            '"${expense.merchant}" không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await DatabaseService.instance.deleteExpense(expense.id!);
      await ReceiptService.deleteThumbnail(expense.receiptImagePath);
      if (mounted) {
        await _loadExpenses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không xóa được giao dịch: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _expenses.fold(0, (sum, expense) => sum + expense.amount);
    final now = DateTime.now();
    final month = _expenses
        .where(
          (e) =>
              e.transactionDate.year == now.year &&
              e.transactionDate.month == now.month,
        )
        .fold(0, (sum, e) => sum + e.amount);
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Ví chi tiêu'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Thêm thủ công',
            onPressed: _openAddExpense,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: _loadExpenses,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _expenses.length + 1,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF103A45), Color(0xFF087F8C)],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.insights_rounded,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'TỔNG CHI TIÊU',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyUtils.formatVnd(total),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Container(height: 1, color: Colors.white24),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Tháng này',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          CurrencyUtils.formatVnd(month),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Giao dịch',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_expenses.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _openScan,
                                icon: const Icon(
                                  Icons.document_scanner_rounded,
                                ),
                                label: const Text('Quét hóa đơn'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 54,
                              width: 54,
                              child: IconButton.filledTonal(
                                tooltip: 'Nhập thủ công',
                                onPressed: _openAddExpense,
                                icon: const Icon(Icons.edit_note_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Bức tranh chi tiêu',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ExpenseCharts(expenses: _expenses),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Giao dịch gần đây',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              '${_expenses.length} mục',
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_expenses.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(
                                        alpha: .08,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_rounded,
                                      size: 40,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Bắt đầu với hóa đơn đầu tiên',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Quét hóa đơn hoặc nhập thủ công để theo dõi chi tiêu mỗi ngày.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  }
                  final expense = _expenses[index - 1];
                  final color = AppTheme.categoryColor(expense.category);
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _editExpense(expense),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: expense.receiptImagePath != null
                                    ? Image.file(
                                        File(expense.receiptImagePath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, error, stack) =>
                                            _categoryTile(expense, color),
                                      )
                                    : _categoryTile(expense, color),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.merchant,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${expense.category.label} · ${DateFormat('dd/MM').format(expense.transactionDate)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    CurrencyUtils.formatVnd(expense.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) => value == 'delete'
                                  ? _deleteExpense(expense)
                                  : _editExpense(expense),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Sửa / xem hóa đơn'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Xóa'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _categoryTile(Expense expense, Color color) => Container(
    color: color.withValues(alpha: .1),
    child: Icon(
      AppTheme.categoryIcon(expense.category),
      color: color,
      size: 23,
    ),
  );
}
