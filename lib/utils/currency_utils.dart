import 'package:intl/intl.dart';

class CurrencyUtils {
  static final NumberFormat _currencyFormat = NumberFormat.decimalPattern(
    'vi_VN',
  );

  static String formatVnd(int amount) {
    return '${_currencyFormat.format(amount)} đ';
  }
}
