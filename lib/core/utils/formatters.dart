import 'package:intl/intl.dart';

class AppFormatters {
  // دالة لتنسيق الأرقام لتصبح مبالغ مالية (مثل: 70000 -> 70,000)
  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount);
  }

  // دالة لتنسيق التاريخ (مثل عرض 2024-05-25)
  static String formatDate(DateTime date) {
    final formatter = DateFormat('yyyy-MM-dd');
    return formatter.format(date);
  }

  // دالة لتنسيق الوقت والتاريخ معاً (مثل: 2024-05-25 10:30)
  static String formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    return formatter.format(dateTime);
  }
}
