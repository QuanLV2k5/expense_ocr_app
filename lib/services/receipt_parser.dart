import 'dart:math' as math;

import '../models/expense_category.dart';

class ReceiptData {
  final String merchant;
  final int? amount;
  final DateTime? date;
  final ExpenseCategory? category;
  final String rawText;
  const ReceiptData({
    required this.merchant,
    this.amount,
    this.date,
    this.category,
    required this.rawText,
  });
}

/// Plain geometry keeps the parser independent of ML Kit and easy to test.
class ReceiptLine {
  final String text;
  final double left, top, width, height;
  const ReceiptLine(this.text, this.left, this.top, this.width, this.height);
  double get centerY => top + height / 2;
}

class ReceiptParser {
  static final _datePattern = RegExp(
    r'\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})\b',
  );
  static final _totalPattern = RegExp(
    r'tong tien thanh toan|tong cong|tong tien|grand total|total amount|amount due|thanh toan|phai tra|can tra|\btotal\b|\btong\b',
  );
  static final _excluded = RegExp(
    r'dia chi|address|dien thoai|phone|\btel\b|mst|ma so|so hoa don|invoice no|tam tinh|subtotal|tien khach|khach dua|tien thua|change|\bcash\b|giam gia|discount|so tien viet bang chu',
  );

  static String normalize(String text) {
    const groups = [
      'àáạảãâầấậẩẫăằắặẳẵ',
      'èéẹẻẽêềếệểễ',
      'ìíịỉĩ',
      'òóọỏõôồốộổỗơờớợởỡ',
      'ùúụủũưừứựửữ',
      'ỳýỵỷỹ',
      'đ',
    ];
    const letters = ['a', 'e', 'i', 'o', 'u', 'y', 'd'];
    var result = text.toLowerCase();
    for (var i = 0; i < groups.length; i++) {
      for (final rune in groups[i].runes) {
        result = result.replaceAll(String.fromCharCode(rune), letters[i]);
      }
    }
    return result;
  }

  static int _score(String text) {
    final line = normalize(text);
    if (_excluded.hasMatch(line) || _datePattern.hasMatch(line)) {
      return 0;
    }
    if (RegExp(r'tong tien thanh toan|grand total|amount due|phai tra|can tra')
        .hasMatch(line)) {
      return 130;
    }
    if (RegExp(r'tong cong|tong tien|total amount|thanh toan').hasMatch(line)) {
      return 110;
    }
    if (_totalPattern.hasMatch(line)) {
      return 90;
    }
    // Match standalone currency only: the đ in Địa chỉ/Định Công is not currency.
    if (RegExp(r'\b(?:vnd|dong)\b').hasMatch(line) ||
        RegExp(
          r'(?:\s|\d)(?:đ|₫)(?=\s|$|[.,])',
          caseSensitive: false,
        ).hasMatch(text)) {
      return 20;
    }
    return 0;
  }

  static ReceiptData parse(String text, {List<ReceiptLine> layout = const []}) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    DateTime? date;
    // Prefer transaction date, then accept other dates (such as signature date).
    final dateLines = [
      ...lines.where(
        (e) =>
            RegExp(r'ngay (?:giao dich|lap|hoa don)|transaction date')
                .hasMatch(normalize(e)),
      ),
      ...lines,
    ];
    for (final line in dateLines) {
      for (final match in _datePattern.allMatches(line)) {
        final day = int.parse(match[1]!),
            month = int.parse(match[2]!),
            year = int.parse(match[3]!);
        final candidate = DateTime(year, month, day);
        if (year >= 2000 &&
            year <= 2100 &&
            candidate.day == day &&
            candidate.month == month) {
          date = candidate;
          break;
        }
      }
      if (date != null) {
        break;
      }
    }
    var merchant = '';
    for (var i = 0; i < lines.length; i++) {
      if (RegExp(
        r'^(?:don vi ban hang|ten (?:don vi|cua hang)|nguoi ban|seller)\s*:',
      ).hasMatch(normalize(lines[i]))) {
        merchant = lines[i].substring(lines[i].indexOf(':') + 1).trim();
        // Append OCR-wrapped company name (e.g. THIÊN / ƯNG), stop at next label.
        if (i + 1 < lines.length &&
            RegExp(r'^[A-ZÀ-ỸĐ\s]{2,30}$').hasMatch(lines[i + 1]) &&
            !_excluded.hasMatch(normalize(lines[i + 1]))) {
          merchant += ' ${lines[i + 1]}';
        }
        if (merchant.isNotEmpty) {
          break;
        }
      }
    }
    if (merchant.isEmpty) {
      merchant =
          lines.take(8).where((line) {
            final lower = normalize(line);
            return RegExp(r'[a-z]').hasMatch(lower) &&
                !_excluded.hasMatch(lower) &&
                !_totalPattern.hasMatch(lower) &&
                !_datePattern.hasMatch(line) &&
                !RegExp(
                  r'hoa don|receipt|invoice|ngay|\bdate\b|nhan vien|cashier|ten nguoi mua',
                ).hasMatch(lower);
          }).firstOrNull ??
          '';
    }

    int? amount;
    var bestScore = 0;
    void accept(int? value, int score) {
      if (value != null && value > 0 && score > bestScore) {
        amount = value;
        bestScore = score;
      }
    }

    // Text reading order can be column-major. Match the value to the right of
    // a total label on the same physical row before using sequential text.
    for (final label in layout) {
      final score = _score(label.text);
      if (score < 90) {
        continue;
      }
      final inline = _inlineAmount(label.text);
      if (inline != null) {
        accept(inline, score + 40);
        continue;
      }
      final right =
          layout
              .where(
                (value) =>
                    value.left >= label.left + label.width - label.height &&
                    (value.centerY - label.centerY).abs() <=
                        math.max(label.height, value.height) * .65 &&
                    _numericOnly(value.text) != null,
              )
              .toList()
            ..sort((a, b) => a.left.compareTo(b.left));
      if (right.isNotEmpty) {
        accept(_numericOnly(right.last.text), score + 40);
      }
    }
    for (var i = 0; i < lines.length; i++) {
      final score = _score(lines[i]);
      if (score == 0) {
        continue;
      }
      accept(_inlineAmount(lines[i]), score);
      if (score >= 90 && i + 1 < lines.length) {
        accept(_numericOnly(lines[i + 1]), score - 5);
      }
    }
    // Conservative fallback for column-major text without geometry: require
    // repeated grouped amounts following a total label, never use an address.
    if (amount == null && lines.any((e) => _score(e) >= 90)) {
      final counts = <int, int>{};
      final start = lines.indexWhere((e) => _score(e) >= 90);
      for (final line in lines.skip(start + 1)) {
        final value = _numericOnly(line);
        if (value != null && RegExp(r'\d[., ]\d{3}').hasMatch(line)) {
          counts[value] = (counts[value] ?? 0) + 1;
        }
      }
      final repeated = counts.entries.where((e) => e.value >= 2).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (repeated.isNotEmpty &&
          (repeated.length == 1 || repeated.first.value > repeated[1].value)) {
        amount = repeated.first.key;
      }
    }
    return ReceiptData(
      merchant: merchant,
      amount: amount,
      date: date,
      category: suggestCategory(text),
      rawText: text,
    );
  }

  static ExpenseCategory? suggestCategory(String text) {
    final value = text
        .split('\n')
        .where(
          (line) =>
              !RegExp(r'dia chi|ma so thue|dien thoai\s*:|\b(?:tel|phone)\s*:')
                  .hasMatch(normalize(line)),
        )
        .map(normalize)
        .join('\n');
    final rules = <ExpenseCategory, String>{
      ExpenseCategory.device: r'quat cay|quat dien|mitsubishi|dien may|dien thoai|laptop|may tinh|thiet bi',
      ExpenseCategory.study:
          r'nha sach|van phong pham|hoc phi|giao trinh|but bi',
      ExpenseCategory.travel:
          r'khach san|\bhotel\b|ve may bay|hang khong|taxi|du lich',
      ExpenseCategory.entertainment: r'rap chieu|cinema|cgv|karaoke|giai tri',
      ExpenseCategory.food:
          r'coffee|cafe|ca phe|nha hang|quan an|tra sua|highlands|thuc an',
    };
    for (final rule in rules.entries) {
      if (RegExp(rule.value).hasMatch(value)) {
        return rule.key;
      }
    }
    return null;
  }

  static int? _inlineAmount(String text) {
    final normalized = normalize(text);
    final label = _totalPattern.firstMatch(normalized);
    return _amounts(label == null ? text : text.substring(label.end))
        .lastOrNull;
  }

  static int? _numericOnly(String text) {
    final value = normalize(text)
        .replaceAll(RegExp(r'\b(?:vnd|dong|d)\b|₫'), '')
        .trim();
    if (!RegExp(r'^\d[\d.,\s]*$').hasMatch(value)) {
      return null;
    }
    return _amounts(value).singleOrNull;
  }

  static List<int> _amounts(String line) {
    final result = <int>[];
    for (final match in RegExp(
      r'\d+(?:[., ]\d{3})*(?:[.,]\d{2})?',
    ).allMatches(line)) {
      var value = match[0]!.trim();
      if (RegExp(r'[.,]\d{2}$').hasMatch(value)) {
        if (!value.endsWith('00')) {
          continue;
        }
        value = value.substring(0, value.length - 3);
      }
      final number = int.tryParse(value.replaceAll(RegExp(r'\D'), ''));
      if (number != null && number >= 0 && number <= 1000000000000) {
        result.add(number);
      }
    }
    return result;
  }
}
