enum ExpenseCategory { food, study, travel, device, entertainment }

extension ExpenseCategoryExtension on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.food:
        return 'Ăn uống';
      case ExpenseCategory.study:
        return 'Học tập';
      case ExpenseCategory.travel:
        return 'Du lịch';
      case ExpenseCategory.device:
        return 'Thiết bị';
      case ExpenseCategory.entertainment:
        return 'Giải trí';
    }
  }
}
