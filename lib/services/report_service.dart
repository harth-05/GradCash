import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/payment_model.dart';
import '../models/expense_model.dart';
import '../models/sponsor_model.dart';
import '../utils/helpers.dart';
import 'package:http/http.dart' as http;

class ReportService {
  static final ReportService instance = ReportService._init();

  ReportService._init();

  // Robust font loading for Arabic (using Noto Sans Arabic for best compatibility)
  Future<pw.Font> _loadArabicFont() async {
    return await PdfGoogleFonts.notoSansArabicRegular();
  }

  Future<pw.Font> _loadArabicBoldFont() async {
    return await PdfGoogleFonts.notoSansArabicBold();
  }

  // --- PDF Reports ---

  // 1. Student account statement (كشف حساب طالب)
  Future<Uint8List> generateStudentStatementPdf(
    Map<String, dynamic> studentData,
    List<Payment> payments,
    String ceremonyName,
  ) async {
    final pdf = pw.Document();
    final font = await _loadArabicFont();
    final boldFont = await _loadArabicBoldFont();

    final name = studentData['name'] as String;
    final uniId = studentData['university_id'] as String;
    final dept = studentData['department'] as String;
    final req = (studentData['required_amount'] as num).toDouble();
    final paid = (studentData['paid_amount'] as num).toDouble();
    final rem = req - paid;
    final pct = req == 0 ? 0 : (paid / req) * 100;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    ceremonyName,
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'كشف حساب طالب',
                    style: const pw.TextStyle(fontSize: 18, color: PdfColors.grey700),
                  ),
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 20),

                // Student Details Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    children: [
                      _pdfRow('اسم الطالب:', name),
                      _pdfRow('الرقم الجامعي:', uniId),
                      _pdfRow('القسم:', dept),
                      pw.Divider(),
                      _pdfRow('المبلغ المطلوب:', Helpers.formatCurrency(req)),
                      _pdfRow('المبلغ المدفوع:', Helpers.formatCurrency(paid)),
                      _pdfRow('المبلغ المتبقي:', Helpers.formatCurrency(rem)),
                      _pdfRow('نسبة السداد:', '${pct.toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 25),

                // Payments list header
                pw.Text(
                  'سجل الدفعات:',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),

                // Payments Table
                pw.TableHelper.fromTextArray(
                  headers: ['المبلغ', 'طريقة الدفع', 'التاريخ', 'الوقت', 'ملاحظات'],
                  data: payments.map((p) => [
                    Helpers.formatCurrency(p.amount),
                    p.paymentMethod,
                    p.date,
                    p.time,
                    p.notes ?? '',
                  ]).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey200),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                  cellAlignment: pw.Alignment.center,
                  cellPadding: const pw.EdgeInsets.all(6),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // 2. Financial Summary & List Reports (Students, Expenses, Sponsors)
  Future<Uint8List> generateFinancialReportPdf(
    Map<String, dynamic> stats,
    List<Map<String, dynamic>> students,
    List<Expense> expenses,
    List<Sponsor> sponsors,
    String ceremonyName,
  ) async {
    final pdf = pw.Document();
    final font = await _loadArabicFont();
    final boldFont = await _loadArabicBoldFont();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Title
                  pw.Center(
                    child: pw.Text(
                      ceremonyName,
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'التقرير المالي العام والحساب الختامي',
                      style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
                    ),
                  ),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 15),

                  // Financial Stats Grid
                  pw.Text('الملخص المالي:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      children: [
                        _pdfRow('إجمالي المبالغ المطلوبة:', Helpers.formatCurrency(stats['totalRequired'])),
                        _pdfRow('إجمالي المبالغ المدفوعة:', Helpers.formatCurrency(stats['totalPaid'])),
                        _pdfRow('إجمالي الدعم المالي للداعمين:', Helpers.formatCurrency(stats['totalSponsors'])),
                        _pdfRow('إجمالي المصروفات:', Helpers.formatCurrency(stats['totalExpenses'])),
                        pw.Divider(),
                        _pdfRow(
                          'صافي الرصيد الحالي:', 
                          Helpers.formatCurrency(stats['netBalance']),
                          isBold: true,
                        ),
                        _pdfRow('إجمالي المتبقي غير المحصل:', Helpers.formatCurrency(stats['totalRemaining'])),
                        _pdfRow('عدد الطلاب مكتملي السداد:', stats['completedCount'].toString()),
                        _pdfRow('عدد الطلاب المتبقي عليهم:', stats['remainingCount'].toString()),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  
                  pw.Text('ملخص حركة الصرف (المصروفات):', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                ],
              ),
            ),
            
            // Expenses table
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.TableHelper.fromTextArray(
                headers: ['البند / المادة', 'المستلم', 'التصنيف', 'المبلغ', 'التاريخ'],
                data: expenses.map((e) => [
                  e.item,
                  e.recipient,
                  e.category,
                  Helpers.formatCurrency(e.amount),
                  e.date,
                ]).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey200),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                cellAlignment: pw.Alignment.center,
                cellPadding: const pw.EdgeInsets.all(6),
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Text('قائمة الطلاب وحالة السداد:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),

            // Students table
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.TableHelper.fromTextArray(
                headers: ['الطالب', 'القسم', 'المطلوب', 'المدفوع', 'المتبقي'],
                data: students.map((s) {
                  final req = (s['required_amount'] as num).toDouble();
                  final paid = (s['paid_amount'] as num).toDouble();
                  return [
                    s['name'] as String,
                    s['department'] as String,
                    Helpers.formatCurrency(req),
                    Helpers.formatCurrency(paid),
                    Helpers.formatCurrency(req - paid),
                  ];
                }).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey200),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                cellAlignment: pw.Alignment.center,
                cellPadding: const pw.EdgeInsets.all(5),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  // --- Excel Reports Export ---

  CellValue? _toCellValue(dynamic val) {
    if (val == null) return null;
    if (val is String) return TextCellValue(val);
    if (val is double) return DoubleCellValue(val);
    if (val is int) return IntCellValue(val);
    if (val is bool) return BoolCellValue(val);
    return TextCellValue(val.toString());
  }

  // Export Complete Financial Data to Excel sheet and share
  Future<bool> exportFinancialExcel(
    Map<String, dynamic> stats,
    List<Map<String, dynamic>> students,
    List<Expense> expenses,
    List<Sponsor> sponsors,
    String ceremonyName,
  ) async {
    try {
      var excel = Excel.createExcel();
      
      // 1. Sheet: Summary
      var summarySheet = excel['الملخص المالي'];
      summarySheet.appendRow(['اسم الحفل:', ceremonyName].map(_toCellValue).toList());
      summarySheet.appendRow(<CellValue?>[]);
      summarySheet.appendRow(['البيان', 'القيمة'].map(_toCellValue).toList());
      summarySheet.appendRow(['إجمالي المبالغ المطلوبة للطلاب', stats['totalRequired']].map(_toCellValue).toList());
      summarySheet.appendRow(['إجمالي المبالغ المدفوعة للطلاب', stats['totalPaid']].map(_toCellValue).toList());
      summarySheet.appendRow(['إجمالي الدعم المالي للداعمين', stats['totalSponsors']].map(_toCellValue).toList());
      summarySheet.appendRow(['إجمالي المصروفات', stats['totalExpenses']].map(_toCellValue).toList());
      summarySheet.appendRow(['صافي الرصيد الحالي', stats['netBalance']].map(_toCellValue).toList());
      summarySheet.appendRow(['المبالغ المتبقية للتحصيل', stats['totalRemaining']].map(_toCellValue).toList());
      summarySheet.appendRow(['عدد الطلاب مكتملي السداد', stats['completedCount']].map(_toCellValue).toList());
      summarySheet.appendRow(['عدد الطلاب المتعثرين / المتبقي عليهم', stats['remainingCount']].map(_toCellValue).toList());

      // 2. Sheet: Students
      var studentsSheet = excel['كشف الطلاب'];
      studentsSheet.appendRow(['الاسم', 'الرقم الجامعي', 'القسم', 'المطلوب', 'المدفوع', 'المتبقي', 'نسبة الإنجاز'].map(_toCellValue).toList());
      for (var s in students) {
        final req = (s['required_amount'] as num).toDouble();
        final paid = (s['paid_amount'] as num).toDouble();
        final rem = req - paid;
        final pct = req == 0 ? 0.0 : (paid / req) * 100;
        studentsSheet.appendRow([
          s['name'],
          s['university_id'],
          s['department'],
          req,
          paid,
          rem,
          '${pct.toStringAsFixed(1)}%'
        ].map(_toCellValue).toList());
      }

      // 3. Sheet: Expenses
      var expensesSheet = excel['كشف المصروفات'];
      expensesSheet.appendRow(['ماذا تم شراؤه', 'المبلغ', 'الشخص/الجهة المستلمة', 'التصنيف', 'التاريخ', 'الوقت', 'تفاصيل'].map(_toCellValue).toList());
      for (var e in expenses) {
        expensesSheet.appendRow([
          e.item,
          e.amount,
          e.recipient,
          e.category,
          e.date,
          e.time,
          e.details
        ].map(_toCellValue).toList());
      }

      // 4. Sheet: Sponsors
      var sponsorsSheet = excel['الداعمون'];
      sponsorsSheet.appendRow(['اسم الداعم', 'نوع الدعم', 'القيمة / الخدمة', 'القيمة المالية', 'معلومات التواصل', 'ملاحظات'].map(_toCellValue).toList());
      for (var sp in sponsors) {
        sponsorsSheet.appendRow([
          sp.name,
          sp.type,
          sp.amountOrService,
          sp.financialValue,
          sp.contactInfo,
          sp.notes ?? ''
        ].map(_toCellValue).toList());
      }

      // Save file
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      final fileBytes = excel.save();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        // Share the excel file
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'GradCash التقرير المالي الكامل Excel',
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Excel export failed: $e');
      return false;
    }
  }

  // 3. Full Students Report (كشف الطلاب العام)
  Future<Uint8List> generateFullStudentsReportPdf(
    List<Map<String, dynamic>> students,
    String ceremonyName,
  ) async {
    final pdf = pw.Document();
    final font = await _loadArabicFont();
    final boldFont = await _loadArabicBoldFont();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  pw.Center(child: pw.Text(ceremonyName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
                  pw.Center(child: pw.Text('كشف سداد الطلاب العام', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700))),
                  pw.Divider(),
                  pw.SizedBox(height: 15),
                ],
              ),
            ),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.TableHelper.fromTextArray(
                headers: ['الطالب', 'الرقم الجامعي', 'القسم', 'المطلوب', 'المدفوع', 'المتبقي'],
                data: students.map((s) {
                  final req = (s['required_amount'] as num).toDouble();
                  final paid = (s['paid_amount'] as num).toDouble();
                  return [
                    s['name'] as String,
                    s['university_id'] as String,
                    s['department'] as String,
                    Helpers.formatCurrency(req),
                    Helpers.formatCurrency(paid),
                    Helpers.formatCurrency(req - paid),
                  ];
                }).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey200),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                cellAlignment: pw.Alignment.center,
                cellPadding: const pw.EdgeInsets.all(5),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // 4. Expenses Report (كشف المصروفات العام)
  Future<Uint8List> generateExpensesReportPdf(
    List<Expense> expenses,
    String ceremonyName,
  ) async {
    final pdf = pw.Document();
    final font = await _loadArabicFont();
    final boldFont = await _loadArabicBoldFont();

    double total = 0;
    for (var e in expenses) {
      total += e.amount;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  pw.Center(child: pw.Text(ceremonyName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
                  pw.Center(child: pw.Text('تقرير كشف المصروفات المنفذة', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700))),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('إجمالي المنصرف:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(Helpers.formatCurrency(total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                ],
              ),
            ),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.TableHelper.fromTextArray(
                headers: ['البند', 'المستلم', 'التصنيف', 'المبلغ', 'التاريخ'],
                data: expenses.map((e) => [
                  e.item,
                  e.recipient,
                  e.category,
                  Helpers.formatCurrency(e.amount),
                  e.date,
                ]).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey200),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                cellAlignment: pw.Alignment.center,
                cellPadding: const pw.EdgeInsets.all(6),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // 5. Sponsors Report (كشف الداعمين العام)
  Future<Uint8List> generateSponsorsReportPdf(
    List<Sponsor> sponsors,
    String ceremonyName,
  ) async {
    final pdf = pw.Document();
    final font = await _loadArabicFont();
    final boldFont = await _loadArabicBoldFont();

    double totalFinancial = 0;
    for (var s in sponsors) {
      totalFinancial += s.financialValue;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  pw.Center(child: pw.Text(ceremonyName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
                  pw.Center(child: pw.Text('سجل الداعمين والمساهمين', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700))),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('إجمالي الدعم المالي:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(Helpers.formatCurrency(totalFinancial), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                ],
              ),
            ),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.TableHelper.fromTextArray(
                headers: ['اسم الداعم', 'النوع', 'المساهمة', 'القيمة المالية', 'التواصل'],
                data: sponsors.map((s) => [
                  s.name,
                  s.type,
                  s.amountOrService,
                  Helpers.formatCurrency(s.financialValue),
                  s.contactInfo,
                ]).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey200),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                cellAlignment: pw.Alignment.center,
                cellPadding: const pw.EdgeInsets.all(6),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
