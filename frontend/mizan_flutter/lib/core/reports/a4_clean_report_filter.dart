/// Client-side A4 clean report filter ensuring empty rows and placeholder labels
/// are dynamically omitted before printing or exporting.
class A4CleanReportFilter {
  static const Set<String> _placeholders = {'', '-', '--', '---', 'n/a', 'tbd', 'placeholder', 'فارغ', 'اختياري'};

  static bool isMeaningful(String? label) =>
      label != null && !_placeholders.contains(label.trim().toLowerCase());

  static List<Map<String, dynamic>> filterEnteredSalesRows(
    List<Map<String, dynamic>> rawRows, {
    bool hideEmptyRows = true,
  }) {
    if (!hideEmptyRows) return rawRows;
    return rawRows.where((r) {
      final qty = (r['qty'] as num?) ?? 0;
      final total = (r['total'] as num?) ?? 0;
      return qty > 0 && total > 0 && (isMeaningful(r['customer'] as String?) || isMeaningful(r['item'] as String?));
    }).toList();
  }
}
