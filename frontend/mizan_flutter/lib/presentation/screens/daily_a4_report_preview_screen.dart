import 'package:flutter/material.dart';
import '../../core/reports/a4_clean_report_filter.dart';

/// Clean A4 Daily Report Preview Screen — dynamically strips empty rows & placeholder labels.
class DailyA4ReportPreviewScreen extends StatelessWidget {
  final bool isArabic;
  final bool hideEmptyRows;

  const DailyA4ReportPreviewScreen({
    super.key,
    this.isArabic = true,
    this.hideEmptyRows = true,
  });

  @override
  Widget build(BuildContext context) {
    final rawSales = <Map<String, dynamic>>[
      {'customer': 'بقالة الأمل', 'item': 'عبوة مياه 20 لتر', 'qty': 50, 'total': 100.0},
      {'customer': '', 'item': '', 'qty': 0, 'total': 0.0},
      {'customer': 'TBD', 'item': '---', 'qty': 0, 'total': 0.0},
      {'customer': 'سوبرماركت النور', 'item': 'عبوة مياه 20 لتر', 'qty': 30, 'total': 60.0},
    ];

    final rows = A4CleanReportFilter.filterEnteredSalesRows(rawSales, hideEmptyRows: hideEmptyRows);
    final total = rows.fold<double>(0.0, (sum, r) => sum + ((r['total'] as num).toDouble()));

    return Scaffold(
      appBar: AppBar(title: Text(isArabic ? 'معاينة التقرير اليومي A4 (صفوف مدخلة فقط)' : 'Clean A4 Daily Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.teal.shade50,
            child: ListTile(
              leading: const Icon(Icons.print_outlined),
              title: Text(isArabic ? 'إخفاء الصفوف الفارغة والتسميات الوهمية مفعّل' : 'Empty rows & placeholders stripped'),
              subtitle: Text('${isArabic ? 'الصفوف المعروضة' : 'Rendered rows'}: ${rows.length} / ${rawSales.length}'),
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map((r) => Card(
                child: ListTile(
                  title: Text('${r['customer']} — ${r['item']}'),
                  subtitle: Text('${isArabic ? 'الكمية' : 'Qty'}: ${r['qty']}'),
                  trailing: Text('${(r['total'] as num).toStringAsFixed(2)} USD', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )),
          const Divider(height: 24),
          ListTile(
            title: Text(isArabic ? 'الإجمالي اليومي' : 'Daily Total', style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text('${total.toStringAsFixed(2)} USD', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
        ],
      ),
    );
  }
}
