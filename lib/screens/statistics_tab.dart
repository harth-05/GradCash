import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/finance_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class StatisticsTab extends StatefulWidget {
  const StatisticsTab({super.key});

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab> {
  @override
  void initState() {
    super.initState();
    // Stats are now refreshed automatically by FinanceProvider when data changes
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final stats = provider.advancedStats;

    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final double required = stats['totalRequired'];
    final double paid = stats['totalPaid'];
    final double remaining = stats['totalRemaining'];
    final double expenses = stats['totalExpenses'];
    final double sponsors = stats['totalSponsors'];
    final double netBalance = stats['netBalance'];

    final int completed = stats['completedCount'];
    final int remainingStd = stats['remainingCount'];
    final String mostUsed = stats['mostUsedMethod'];

    final Map<String, double> methodAmounts = stats['paymentMethodsAmount'];
    final Map<String, double> expenseCategories = stats['expensesByCategory'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التقارير والإحصائيات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات',
            onPressed: () => provider.refreshData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.refreshData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Grid of Financial Summary Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildSummaryCard(
                    'صافي الرصيد الحالي',
                    Helpers.formatCurrency(netBalance),
                    Icons.account_balance,
                    Colors.teal,
                    onTap: () => provider.setTabIndex(1), // Expenses tab
                  ),
                  _buildSummaryCard(
                    'إجمالي المصروفات',
                    Helpers.formatCurrency(expenses),
                    Icons.payments,
                    AppConstants.dangerColor,
                    onTap: () => provider.setTabIndex(1),
                  ),
                  _buildSummaryCard(
                    'المدفوع من الطلاب',
                    Helpers.formatCurrency(paid),
                    Icons.people,
                    AppConstants.successColor,
                    onTap: () => provider.setTabIndex(0),
                  ),
                  _buildSummaryCard(
                    'دعم المساهمين',
                    Helpers.formatCurrency(sponsors),
                    Icons.card_giftcard,
                    AppConstants.accentColor,
                    onTap: () => provider.setTabIndex(2),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Budget overview card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ميزانية الحفل الكلية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('المطلوب تحصيله: ${Helpers.formatCurrency(required)}'),
                          Text('المتبقي للتحصيل: ${Helpers.formatCurrency(remaining)}', style: const TextStyle(color: AppConstants.dangerColor)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: required == 0 ? 0.0 : paid / required,
                          backgroundColor: Colors.grey.shade200,
                          color: AppConstants.successColor,
                          minHeight: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Paid vs Remaining Pie Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('تحصيل دفعات الطلاب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: paid == 0 && remaining == 0
                            ? const Center(child: Text('لا توجد بيانات كافية لعرض الرسم البياني'))
                            : PieChart(
                                PieChartData(
                                  centerSpaceRadius: 40,
                                  sections: [
                                    PieChartSectionData(
                                      color: AppConstants.successColor,
                                      value: paid,
                                      title: Helpers.formatCurrency(paid),
                                      radius: 30,
                                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    PieChartSectionData(
                                      color: AppConstants.dangerColor,
                                      value: remaining,
                                      title: Helpers.formatCurrency(remaining),
                                      radius: 30,
                                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendItem('المدفوع', AppConstants.successColor),
                          const SizedBox(width: 20),
                          _buildLegendItem('المتبقي', AppConstants.dangerColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Methods Breakdown
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('تحليل طرق الدفع المستعملة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('الأكثر استخداماً: $mostUsed', style: const TextStyle(fontSize: 12, color: AppConstants.accentColor, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Column(
                        children: methodAmounts.entries.map((entry) {
                          double methodVal = entry.value;
                          double pct = paid == 0 ? 0.0 : methodVal / paid;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    Text(Helpers.formatCurrency(methodVal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 6,
                                    color: AppConstants.primaryColor,
                                    backgroundColor: Colors.grey.shade100,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Expense Breakdown Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('توزيع المصروفات حسب التصنيف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 20),
                      expenseCategories.isEmpty
                          ? const SizedBox(
                              height: 100,
                              child: Center(child: Text('لا توجد مصروفات مسجلة بعد')),
                            )
                          : SizedBox(
                              height: 185,
                              child: PieChart(
                                PieChartData(
                                  centerSpaceRadius: 0,
                                  sections: expenseCategories.entries.map((entry) {
                                    final colorsList = [Colors.blue, Colors.orange, Colors.purple, Colors.red, Colors.green];
                                    final index = expenseCategories.keys.toList().indexOf(entry.key) % colorsList.length;
                                    return PieChartSectionData(
                                      color: colorsList[index],
                                      value: entry.value,
                                      title: entry.key,
                                      radius: 80,
                                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 6. Student status summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCountCol('الطلاب مكتملي السداد', completed, AppConstants.successColor),
                      Container(width: 1, height: 50, color: Colors.grey.shade300),
                      _buildCountCol('الطلاب المتبقي عليهم', remainingStd, AppConstants.dangerColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final isDark = provider.isDarkMode;

    return Card(
      color: isDark ? AppConstants.cardDarkBg : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 24),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: AppConstants.textMuted),
                  ),
                ],
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildCountCol(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppConstants.textMuted)),
        const SizedBox(height: 4),
        Text(
          '$count طلاب',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
