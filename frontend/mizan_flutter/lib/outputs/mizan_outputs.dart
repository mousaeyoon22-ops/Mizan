import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/mizan_models.dart';
import '../engine/ifrs_engine.dart';

class CsvDryRunResult {
  final String fileName;
  final List<Map<String, String>> previewRows;
  final List<String> warnings;

  CsvDryRunResult({
    required this.fileName,
    required this.previewRows,
    required this.warnings,
  });
}

class MizanOutputs {
  /// Generates an A4 or 80mm Thermal PDF for any MizanDocument and shares/prints it.
  static Future<Uint8List> buildDocumentPdf({
    required MizanDocument doc,
    required String entityName,
    required String bookCurrency,
    bool thermal80mm = false,
    bool showStamp = true,
  }) async {
    final pdf = pw.Document();
    final pageFormat = thermal80mm
        ? const PdfPageFormat(80 * PdfPageFormat.mm, 210 * PdfPageFormat.mm, marginAll: 5 * PdfPageFormat.mm)
        : PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MIZAN v3.3 UNIVERSAL',
                        style: pw.TextStyle(
                          fontSize: thermal80mm ? 11 : 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        entityName,
                        style: pw.TextStyle(fontSize: thermal80mm ? 9 : 11),
                      ),
                    ],
                  ),
                  pw.Text(
                    doc.docNo,
                    style: pw.TextStyle(
                      fontSize: thermal80mm ? 9 : 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              pw.Text(
                'Type: ${doc.docType.name} | Cycle: ${doc.sectorCycle.name}',
                style: pw.TextStyle(fontSize: thermal80mm ? 8 : 10),
              ),
              pw.Text(
                'Date: ${doc.docDate.toIso8601String().substring(0, 10)} | Branch: ${doc.branchName}',
                style: pw.TextStyle(fontSize: thermal80mm ? 8 : 10),
              ),
              pw.Text(
                'Party: ${doc.partyName.isEmpty ? "Walk-in Cash Customer" : doc.partyName} | Currency: ${doc.currency} (FX ${doc.fxRate})',
                style: pw.TextStyle(fontSize: thermal80mm ? 8 : 10),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontSize: thermal80mm ? 7.5 : 9.5,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: pw.TextStyle(fontSize: thermal80mm ? 7.5 : 9),
                headers: ['Item / MGID', 'Unit', 'Qty', 'Price', 'Total'],
                data: doc.lines
                    .map((l) => [
                          '${l.itemName} (${l.mgid})',
                          l.unitName,
                          l.qty.toStringAsFixed(2),
                          l.unitPrice.toStringAsFixed(2),
                          l.lineTotal.toStringAsFixed(2),
                        ])
                    .toList(),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: pw.TextStyle(fontSize: thermal80mm ? 8.5 : 10)),
                  pw.Text('${doc.subtotal.toStringAsFixed(2)} ${doc.currency}',
                      style: pw.TextStyle(fontSize: thermal80mm ? 8.5 : 10)),
                ],
              ),
              if (doc.taxPercent > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tax (${doc.taxPercent}%):', style: pw.TextStyle(fontSize: thermal80mm ? 8.5 : 10)),
                    pw.Text(
                      '${(doc.subtotal * doc.taxPercent / 100).toStringAsFixed(2)} ${doc.currency}',
                      style: pw.TextStyle(fontSize: thermal80mm ? 8.5 : 10),
                    ),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontSize: thermal80mm ? 10 : 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    '${doc.totalAmount.toStringAsFixed(2)} ${doc.currency}',
                    style: pw.TextStyle(fontSize: thermal80mm ? 10 : 12, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Paid:', style: pw.TextStyle(fontSize: thermal80mm ? 8.5 : 10)),
                  pw.Text('${doc.paidAmount.toStringAsFixed(2)} ${doc.currency}',
                      style: pw.TextStyle(fontSize: thermal80mm ? 8.5 : 10)),
                ],
              ),
              if (showStamp) ...[
                pw.SizedBox(height: 14),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
                  child: pw.Text(
                    'VERIFIED BY MIZAN LEDGER · BOOK: $bookCurrency · STATUS: ${doc.status.name.toUpperCase()}',
                    style: pw.TextStyle(fontSize: thermal80mm ? 7 : 8.5),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<void> sharePdfToWhatsApp({
    required Uint8List bytes,
    required String fileName,
    required String caption,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: caption);
  }

  static Future<void> printPdfDocument({
    required Uint8List bytes,
    required String jobName,
  }) async {
    await Printing.layoutPdf(name: jobName, onLayout: (_) async => bytes);
  }

  /// Generates IFRS Financial Audit PDF Report.
  static Future<Uint8List> buildIfrsReportPdf({
    required FinancialAuditSnapshot snap,
    required String entityName,
    required String bookCurrency,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text('MIZAN v3.3 — IFRS / IAS AUDIT REPORT',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('$entityName | As Of: ${snap.asOfDate.toIso8601String().substring(0, 10)} | Book: $bookCurrency'),
          pw.Text('SHA-256 Chain Head: ${snap.latestChainHash}'),
          pw.Text('Ledger Trust Score: ${snap.trustScore.toStringAsFixed(1)} / 100 | Balanced: ${snap.isBalanced}'),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text('Trial Balance', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Account ID', 'Account', 'Debit', 'Credit', 'Net'],
            data: snap.trialBalance
                .map((r) => [
                      r.accountId,
                      r.accountName,
                      r.debit.toStringAsFixed(2),
                      r.credit.toStringAsFixed(2),
                      r.net.toStringAsFixed(2),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'IAS 1 Income Statement — Revenue: ${snap.totalRevenue.toStringAsFixed(2)} | Expense: ${snap.totalExpense.toStringAsFixed(2)} | Net Profit: ${snap.netProfit.toStringAsFixed(2)}',
          ),
          pw.Text(
            'Balance Sheet — Assets: ${snap.totalAssets.toStringAsFixed(2)} | Liabilities: ${snap.totalLiabilities.toStringAsFixed(2)} | Equity: ${snap.totalEquity.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
    return pdf.save();
  }

  /// Exports Items or Accounts to Excel-compatible UTF-8 BOM CSV and shares it.
  static Future<void> exportItemsCsv(List<MizanItem> items) async {
    final buf = StringBuffer('\uFEFFSKU,MGID,Name,BaseUnit,Warehouse,CostPrice,SalePrice,StockQty,Barcode\n');
    for (final it in items) {
      buf.writeln(
        '"${it.sku}","${it.mgid}","${it.name.replaceAll('"', '""')}","${it.baseUnit}","${it.warehouse}",${it.costPrice},${it.salePrice},${it.stockQty},"${it.barcode}"',
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/mizan_items_export.csv');
    await file.writeAsString(buf.toString(), encoding: utf8);
    await Share.shareXFiles([XFile(file.path)], text: 'Mizan v3.3 Inventory Excel/CSV Export');
  }

  /// Dry-Run CSV/Excel Importer: lets user pick a CSV file and previews rows before committing.
  static Future<CsvDryRunResult?> pickCsvForDryRun() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (picked == null || picked.files.isEmpty) return null;
    final path = picked.files.single.path;
    if (path == null) return null;
    final content = await File(path).readAsString();
    final lines = const LineSplitter().convert(content).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) {
      return CsvDryRunResult(
        fileName: picked.files.single.name,
        previewRows: [],
        warnings: ['الملف لا يحتوي على صفوف بيانات بعد العناوين.'],
      );
    }
    final headers = lines.first.split(',').map((h) => h.replaceAll('"', '').trim()).toList();
    final List<Map<String, String>> preview = [];
    final List<String> warnings = [];
    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',').map((c) => c.replaceAll('"', '').trim()).toList();
      if (cols.length < 2) {
        warnings.add('صف $i غير مكتمل وتم تجاهله.');
        continue;
      }
      final Map<String, String> row = {};
      for (int c = 0; c < headers.length && c < cols.length; c++) {
        row[headers[c]] = cols[c];
      }
      preview.add(row);
    }
    return CsvDryRunResult(
      fileName: picked.files.single.name,
      previewRows: preview,
      warnings: warnings,
    );
  }
}
