import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/finance_provider.dart';
import '../services/backup_service.dart';
import '../services/report_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'pin_lock_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final isDark = provider.isDarkMode;
    final logoPath = provider.customLogoPath;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات والنسخ الاحتياطي'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. App Identity Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _pickLogo(context),
                    child: Tooltip(
                      message: 'تغيير الشعار',
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipOval(
                          child: logoPath != null && File(logoPath).existsSync()
                              ? Image.file(File(logoPath), fit: BoxFit.cover)
                              : Image.asset('image/GradCash.png', fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.ceremonyName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المبلغ الافتراضي للطالب: ${Helpers.formatCurrency(provider.defaultBaseAmount)}',
                          style: const TextStyle(fontSize: 13, color: AppConstants.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'تعديل هوية الحفل',
                    onPressed: () => _showEditIdentityDialog(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Main Settings Sections
          _buildSectionHeader('المظهر والأمان'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('الوضع الليلي (Dark Mode)', style: TextStyle(fontSize: 14)),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  value: isDark,
                  onChanged: (val) => provider.toggleThemeMode(val),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('رمز حماية التطبيق (PIN)', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    provider.pinCode.isEmpty ? 'التطبيق غير محمي برمز سري' : 'تغيير أو إزالة الرمز السري',
                    style: const TextStyle(fontSize: 11),
                  ),
                  leading: const Icon(Icons.lock_outline),
                  trailing: Icon(provider.pinCode.isEmpty ? Icons.add : Icons.edit),
                  onTap: () => _manageSecurityPIN(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('النسخ الاحتياطي وإدارة البيانات'),
          Card(
            child: Column(
              children: [
                // Local Backup
                ListTile(
                  title: const Text('تصدير نسخة احتياطية محلية', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('حفظ البيانات كملف JSON ومشاركته', style: TextStyle(fontSize: 11)),
                  leading: const Icon(Icons.download),
                  onTap: () => _exportLocalBackup(context),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('استعادة من نسخة محلية', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('اختيار ملف نسخة احتياطية من جهازك والتحميل', style: TextStyle(fontSize: 11)),
                  leading: const Icon(Icons.upload_file),
                  onTap: () => _importLocalBackup(context),
                ),
                const Divider(height: 1),
                
                // Google Drive Sync
                ListTile(
                  title: const Text('نسخ احتياطي إلى Google Drive', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('حفظ وتأمين البيانات سحابياً', style: TextStyle(fontSize: 11)),
                  leading: const Icon(Icons.cloud_upload_outlined),
                  onTap: () => _syncGoogleDrive(context, true),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('استعادة البيانات من Google Drive', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('تحميل البيانات السحابية الحالية للتطبيق', style: TextStyle(fontSize: 11)),
                  leading: const Icon(Icons.cloud_download_outlined),
                  onTap: () => _syncGoogleDrive(context, false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('التقارير المالية والوثائق'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('تصدير التقرير المالي العام PDF', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('تحضير ومشاركة كشف الحساب والمصروفات والداعمين', style: TextStyle(fontSize: 11)),
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  onTap: () => _exportFinancialPdf(context),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('تصدير التقرير المالي الشامل Excel', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('إنشاء ورقة عمل Excel منظمة بالكامل بكافة التفاصيل', style: TextStyle(fontSize: 11)),
                  leading: const Icon(Icons.grid_on),
                  onTap: () => _exportFinancialExcel(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('حول التطبيق والمطور'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  title: Text('GradCash v1.0.0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text('نظام مالي ذكي متكامل لمسؤولي حفلات التخرج والفعاليات.', style: TextStyle(fontSize: 11)),
                  leading: Icon(Icons.info_outline),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialIcon(
                        context,
                        icon: Icons.chat_bubble_outline,
                        color: Colors.green,
                        label: 'واتساب',
                        onTap: () => _launchSocialUrl(context, 'https://wa.me/${AppConstants.developerWhatsapp}'),
                      ),
                      _buildSocialIcon(
                        context,
                        icon: Icons.telegram,
                        color: Colors.blue,
                        label: 'تلجرام',
                        onTap: () => _launchSocialUrl(context, AppConstants.developerTelegram),
                      ),
                      _buildSocialIcon(
                        context,
                        icon: Icons.camera_alt_outlined,
                        color: Colors.purple,
                        label: 'انستغرام',
                        onTap: () => _launchSocialUrl(context, AppConstants.developerInstagram),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(BuildContext context, {required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.accentColor),
      ),
    );
  }

  // Pick Custom logo
  Future<void> _pickLogo(BuildContext context) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (!context.mounted) return;
      provider.setCustomLogoPath(image.path);
      Helpers.showSnackBar(context, 'تم تغيير شعار التطبيق بنجاح');
    }
  }

  // Edit identity dialog
  void _showEditIdentityDialog(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final nameController = TextEditingController(text: provider.ceremonyName);
    final amountController = TextEditingController(text: provider.defaultBaseAmount.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل هوية الحفل والمالية', style: TextStyle(fontFamily: 'Cairo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم الحفل / المناسبة'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'المبلغ المطلوب الافتراضي للطلاب'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount = double.tryParse(amountController.text.trim()) ?? 30000.0;

              if (name.isNotEmpty) {
                provider.setCeremonyName(name);
                provider.setDefaultBaseAmount(amount);
                Helpers.showSnackBar(context, 'تم تحديث هوية التطبيق والمالية');
              }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  // Setup / Reset PIN Screen
  void _manageSecurityPIN(BuildContext context) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    if (provider.pinCode.isEmpty) {
      // Create PIN
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PinLockScreen(isSetup: true)),
      );
    } else {
      // Remove or change PIN
      final confirm = await Helpers.showConfirmDialog(
        context: context,
        title: 'حماية التطبيق',
        content: 'هل تريد إزالة الرمز السري وإلغاء حماية التطبيق؟',
        confirmLabel: 'إزالة الحماية',
        isDanger: true,
      );
      if (confirm) {
        if (!context.mounted) return;
        provider.setPinCode('');
        Helpers.showSnackBar(context, 'تم إلغاء قفل الحماية بنجاح');
      }
    }
  }

  // Local backups
  Future<void> _exportLocalBackup(BuildContext context) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    Helpers.showSnackBar(context, 'جاري إنشاء ملف النسخة الاحتياطية...');
    final done = await BackupService.instance.exportLocalBackup(provider);
    if (!context.mounted) return;
    if (done) {
      Helpers.showSnackBar(context, 'تم تصدير النسخة الاحتياطية ومشاركتها بنجاح');
    } else {
      Helpers.showSnackBar(context, 'فشل تصدير النسخة الاحتياطية', isError: true);
    }
  }

  Future<void> _importLocalBackup(BuildContext context) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final confirm = await Helpers.showConfirmDialog(
      context: context,
      title: 'استعادة البيانات',
      content: 'تنبيه: سيؤدي استيراد النسخة الاحتياطية إلى استبدال كافة البيانات الحالية. هل ترغب بالاستمرار؟',
      confirmLabel: 'استعادة',
      isDanger: true,
    );

    if (confirm) {
      final error = await BackupService.instance.importLocalBackup(provider);
      if (!context.mounted) return;
      if (error == null) {
        Helpers.showSnackBar(context, 'تم استيراد البيانات واستعادتها بنجاح');
      } else {
        Helpers.showSnackBar(context, error, isError: true);
      }
    }
  }

  // Google Drive Mock Sync
  Future<void> _syncGoogleDrive(BuildContext context, bool isUpload) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 15),
            Text(
              isUpload ? 'جاري رفع البيانات إلى Google Drive...' : 'جاري سحب واستعادة البيانات سحابياً...',
              style: const TextStyle(fontFamily: 'Cairo'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    bool success;
    if (isUpload) {
      success = await BackupService.instance.uploadToGoogleDrive(provider);
    } else {
      success = await BackupService.instance.downloadFromGoogleDrive(provider);
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (success) {
      Helpers.showSnackBar(
        context,
        isUpload ? 'تم رفع النسخة الاحتياطية بنجاح' : 'تم استعادة البيانات السحابية بنجاح',
      );
    } else {
      Helpers.showSnackBar(context, 'فشلت المزامنة مع السحابة، حاول لاحقاً', isError: true);
    }
  }

  // Reports
  Future<void> _exportFinancialPdf(BuildContext context) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    
    Helpers.showSnackBar(context, 'جاري تحضير ملف التقرير PDF...');
    final stats = provider.getStatistics();
    
    final pdfBytes = await ReportService.instance.generateFinancialReportPdf(
      stats,
      provider.students,
      provider.expenses,
      provider.sponsors,
      provider.ceremonyName,
    );

    // Save and Share
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/financial_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await tempFile.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(tempFile.path)],
      text: 'التقرير المالي العام: ${provider.ceremonyName}',
    );
  }

  Future<void> _exportFinancialExcel(BuildContext context) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    
    Helpers.showSnackBar(context, 'جاري تحضير ملف Excel...');
    final stats = provider.getStatistics();
    
    final success = await ReportService.instance.exportFinancialExcel(
      stats,
      provider.students,
      provider.expenses,
      provider.sponsors,
      provider.ceremonyName,
    );

    if (!context.mounted) return;
    if (!success) {
      Helpers.showSnackBar(context, 'فشل تصدير ملف Excel', isError: true);
    }
  }

  // Social Contact URLs launch
  Future<void> _launchSocialUrl(BuildContext context, String urlString) async {
    final url = Uri.parse(urlString);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback: open in browser
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        // Fallback: try platform default (browser)
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (context.mounted) {
          Helpers.showSnackBar(context, 'فشل فتح الرابط، يرجى المحاولة لاحقاً', isError: true);
        }
      }
    }
  }
}
