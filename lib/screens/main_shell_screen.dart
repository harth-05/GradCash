import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/finance_provider.dart';
import '../utils/constants.dart';
import 'students_tab.dart';
import 'expenses_tab.dart';
import 'sponsors_tab.dart';
import 'statistics_tab.dart';
import 'settings_tab.dart';
import '../services/backup_service.dart';
import '../services/report_service.dart';
import 'pin_lock_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/helpers.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final List<Widget> _tabs = [
    const StudentsTab(),
    const ExpensesTab(),
    const SponsorsTab(),
    const StatisticsTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final isDark = provider.isDarkMode;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: _buildDrawer(context, provider),
        body: IndexedStack(
          index: provider.currentIndex > 4 ? 0 : provider.currentIndex,
          children: _tabs,
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: isDark 
                ? AppConstants.accentColor.withValues(alpha: 0.2) 
                : AppConstants.primaryColor.withValues(alpha: 0.1),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              return const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: provider.currentIndex > 4 ? 0 : provider.currentIndex,
            onDestinationSelected: (index) {
              provider.setTabIndex(index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people, color: AppConstants.accentColor),
                label: 'الطلاب',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet, color: AppConstants.accentColor),
                label: 'المصروفات',
              ),
              NavigationDestination(
                icon: Icon(Icons.card_giftcard_outlined),
                selectedIcon: Icon(Icons.card_giftcard, color: AppConstants.accentColor),
                label: 'الداعمين',
              ),
              NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics, color: AppConstants.accentColor),
                label: 'الإحصائيات',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings, color: AppConstants.accentColor),
                label: 'الإعدادات',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, FinanceProvider provider) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppConstants.primaryColor,
              gradient: LinearGradient(
                colors: [AppConstants.primaryColor, AppConstants.primaryColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.school, size: 40, color: AppConstants.primaryColor),
                ),
                const SizedBox(height: 10),
                Text(
                  provider.ceremonyName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                const Text(
                  'نظام إدارة مالية حفلات التخرج',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Cairo'),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.people_outline,
            label: 'إدارة الطلاب',
            index: 0,
            currentIndex: provider.currentIndex,
            onTap: () {
              provider.setTabIndex(0);
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.account_balance_wallet_outlined,
            label: 'المصروفات',
            index: 1,
            currentIndex: provider.currentIndex,
            onTap: () {
              provider.setTabIndex(1);
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.card_giftcard_outlined,
            label: 'الداعمين والمساهمين',
            index: 2,
            currentIndex: provider.currentIndex,
            onTap: () {
              provider.setTabIndex(2);
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.analytics_outlined,
            label: 'الإحصائيات والنشاط',
            index: 3,
            currentIndex: provider.currentIndex,
            onTap: () {
              provider.setTabIndex(3);
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.settings_outlined,
            label: 'الإعدادات والنسخ الاحتياطي',
            index: 4,
            currentIndex: provider.currentIndex,
            onTap: () {
              provider.setTabIndex(4);
              Navigator.pop(context);
            },
          ),
          const Divider(),
          
          // Quick Reports Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'التقارير السريعة',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text('تقرير مالي شامل PDF', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              _exportFinancialPdf(context, provider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.green),
            title: const Text('تقرير مالي شامل Excel', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              _exportFinancialExcel(context, provider);
            },
          ),
          
          const Divider(),
          
          // Social & Contact
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialIcon(
                  icon: Icons.chat_bubble_outline,
                  color: Colors.green,
                  label: 'واتساب',
                  onTap: () => _launchSocialUrl(context, 'https://wa.me/${AppConstants.developerWhatsapp}'),
                ),
                _buildSocialIcon(
                  icon: Icons.telegram,
                  color: Colors.blue,
                  label: 'تلجرام',
                  onTap: () => _launchSocialUrl(context, AppConstants.developerTelegram),
                ),
                _buildSocialIcon(
                  icon: Icons.camera_alt_outlined,
                  color: Colors.purple,
                  label: 'انستغرام',
                  onTap: () => _launchSocialUrl(context, AppConstants.developerInstagram),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          const Center(
            child: Text('GradCash v1.0.0', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSocialIcon({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // --- Report helpers used from Drawer ---

  Future<void> _exportFinancialPdf(BuildContext context, FinanceProvider provider) async {
    Helpers.showSnackBar(context, 'جاري تحضير PDF...');
    final pdfBytes = await ReportService.instance.generateFinancialReportPdf(
      provider.getStatistics(), 
      provider.students, provider.expenses, provider.sponsors, provider.ceremonyName
    );
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/report.pdf');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)], text: 'التقرير المالي');
  }

  Future<void> _exportFinancialExcel(BuildContext context, FinanceProvider provider) async {
    Helpers.showSnackBar(context, 'جاري تحضير Excel...');
    await ReportService.instance.exportFinancialExcel(
      provider.getStatistics(), provider.students, provider.expenses, provider.sponsors, provider.ceremonyName
    );
  }

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

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    required int currentIndex,
    required VoidCallback onTap,
  }) {
    final isSelected = index == currentIndex;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppConstants.primaryColor : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppConstants.primaryColor : null,
          fontFamily: 'Cairo',
          fontSize: 14,
        ),
      ),
      selected: isSelected,
      onTap: onTap,
    );
  }
}
