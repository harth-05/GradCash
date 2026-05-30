import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sponsor_model.dart';
import '../services/finance_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/report_service.dart';

class SponsorsTab extends StatelessWidget {
  const SponsorsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final sponsors = provider.sponsors;
    final isDark = provider.isDarkMode;

    double totalFinancialSupport = 0.0;
    int financialCount = 0;
    int serviceCount = 0;

    for (var sp in sponsors) {
      if (sp.type == 'مالي') {
        totalFinancialSupport += sp.financialValue;
        financialCount++;
      } else {
        serviceCount++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الداعمين والمساهمين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'تصدير تقرير PDF',
            onPressed: () => _exportSponsorsPdf(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة داعم جديد',
            onPressed: () => _showAddEditSponsorSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppConstants.cardDarkBg.withValues(alpha: 0.5) : AppConstants.primaryColor.withValues(alpha: 0.03),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSponsorStat('إجمالي الدعم المالي', Helpers.formatCurrency(totalFinancialSupport), AppConstants.successColor),
                _buildSponsorStat('داعم مالي', '$financialCount جهات', AppConstants.primaryColor),
                _buildSponsorStat('داعم خدمي', '$serviceCount جهات', AppConstants.accentColor),
              ],
            ),
          ),

          Expanded(
            child: sponsors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.card_giftcard_outlined, size: 50, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'لا يوجد داعمين مسجلين بعد',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sponsors.length,
                    itemBuilder: (context, index) {
                      final sponsor = sponsors[index];
                      return _buildSponsorCard(context, sponsor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSponsorStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppConstants.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildSponsorCard(BuildContext context, Sponsor sponsor) {

    bool isFinancial = sponsor.type == 'مالي';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isFinancial
                    ? AppConstants.successColor.withValues(alpha: 0.1)
                    : AppConstants.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFinancial ? Icons.attach_money : Icons.handshake_outlined,
                color: isFinancial ? AppConstants.successColor : AppConstants.accentColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),

            // Content details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sponsor.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isFinancial ? AppConstants.successColor : AppConstants.accentColor).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sponsor.type,
                          style: TextStyle(
                            color: isFinancial ? AppConstants.successColor : AppConstants.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'مساهمة: ${sponsor.amountOrService}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (sponsor.notes != null && sponsor.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'ملاحظات: ${sponsor.notes}',
                      style: const TextStyle(fontSize: 12, color: AppConstants.textMuted),
                    ),
                  ],
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _contactSponsor(context, sponsor.contactInfo),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppConstants.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          sponsor.contactInfo,
                          style: const TextStyle(fontSize: 12, color: AppConstants.primaryColor, decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Actions
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  _showAddEditSponsorSheet(context, sponsor: sponsor);
                } else if (val == 'delete') {
                  _deleteSponsor(context, sponsor);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
                const PopupMenuItem(value: 'delete', child: Text('حذف الداعم', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _contactSponsor(BuildContext context, String contact) async {
    final uri = Uri.parse('tel:$contact');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        Helpers.showSnackBar(context, 'لا يمكن إجراء اتصال بالرقم الجامعي', isError: true);
      }
    }
  }

  void _deleteSponsor(BuildContext context, Sponsor sponsor) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final confirm = await Helpers.showConfirmDialog(
      context: context,
      title: 'حذف مساهمة',
      content: 'هل تريد حذف الداعم ${sponsor.name} من قائمة الداعمين؟',
      confirmLabel: 'حذف',
      isDanger: true,
    );
    if (confirm) {
      await provider.deleteSponsor(sponsor.id!);
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'تم حذف الداعم بنجاح');
    }
  }

  void _showAddEditSponsorSheet(BuildContext context, {Sponsor? sponsor}) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final isEdit = sponsor != null;

    final nameController = TextEditingController(text: sponsor?.name ?? '');
    final supportController = TextEditingController(text: sponsor?.amountOrService ?? '');
    final contactController = TextEditingController(text: sponsor?.contactInfo ?? '');
    final notesController = TextEditingController(text: sponsor?.notes ?? '');
    String selectedType = sponsor?.type ?? 'مالي';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEdit ? 'تعديل بيانات الداعم' : 'إضافة داعم جديد',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم الداعم / الجهة'),
                ),
                const SizedBox(height: 12),

                const Text('نوع الدعم:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('دعم مالي'),
                      selected: selectedType == 'مالي',
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() {
                            selectedType = 'مالي';
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('دعم خدمي (عيني)'),
                      selected: selectedType == 'خدمي',
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() {
                            selectedType = 'خدمي';
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: supportController,
                  decoration: InputDecoration(
                    labelText: selectedType == 'مالي' ? 'مبلغ الدعم (بالأرقام)' : 'مادة الدعم (مثلاً: طباعة كروت، كيكة حفل)',
                    hintText: selectedType == 'مالي' ? 'مثال: 50000' : 'مثال: طباعة بنرات',
                  ),
                  keyboardType: selectedType == 'مالي' ? TextInputType.number : TextInputType.text,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: 'رقم هاتف التواصل (اختياري)'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final support = supportController.text.trim();
                    final contact = contactController.text.trim();
                    final notes = notesController.text.trim();
                    double val = 0;

                    if (selectedType == 'مالي') {
                      val = double.tryParse(support) ?? 0.0;
                    }

                    if (name.isEmpty || support.isEmpty) {
                      Helpers.showSnackBar(context, 'يرجى إدخال اسم الداعم ونوع الدعم', isError: true);
                      return;
                    }

                    final newSponsor = Sponsor(
                      id: sponsor?.id,
                      name: name,
                      type: selectedType,
                      amountOrService: support,
                      financialValue: val,
                      contactInfo: contact,
                      notes: notes.isEmpty ? null : notes,
                    );

                    if (isEdit) {
                      provider.updateSponsor(newSponsor);
                      Helpers.showSnackBar(context, 'تم تحديث بيانات الداعم');
                    } else {
                      provider.addSponsor(newSponsor);
                      Helpers.showSnackBar(context, 'تم إضافة الداعم بنجاح');
                    }

                    Navigator.pop(ctx);
                  },
                  child: Text(isEdit ? 'تحديث البيانات' : 'إضافة الداعم'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _exportSponsorsPdf(BuildContext context) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    Helpers.showSnackBar(context, 'جاري تحضير تقرير الداعمين PDF...');
    
    // I need to add this method to ReportService
    final pdfBytes = await ReportService.instance.generateSponsorsReportPdf(
      provider.sponsors,
      provider.ceremonyName,
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/sponsors_report.pdf');
    await file.writeAsBytes(pdfBytes);
    
    await Share.shareXFiles([XFile(file.path)], text: 'تقرير الداعمين والمساهمين');
  }
}
