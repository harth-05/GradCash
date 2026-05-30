import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/expense_model.dart';
import '../services/finance_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/report_service.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  bool _showTrash = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final isDark = provider.isDarkMode;
    final list = _showTrash ? provider.trashExpenses : provider.expenses;

    double totalAmt = 0.0;
    for (var exp in provider.expenses) {
      totalAmt += exp.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_showTrash ? 'سلة المحذوفات' : 'إدارة المصروفات'),
        actions: [
          if (!_showTrash)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'تصدير كشف المصروفات PDF',
              onPressed: () => _exportExpensesPdf(context),
            ),
          if (!_showTrash)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'إضافة مصروف',
              onPressed: () => _showAddEditExpenseSheet(context),
            ),
          if (_showTrash && list.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              tooltip: 'تفريغ السلة',
              onPressed: () => _clearAllTrash(context),
            ),
          IconButton(
            icon: Icon(_showTrash ? Icons.arrow_back : Icons.delete_outline),
            tooltip: _showTrash ? 'العودة للمصروفات' : 'سلة المحذوفات',
            onPressed: () {
              setState(() {
                _showTrash = !_showTrash;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Total display card (non-trash only)
          if (!_showTrash)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: isDark ? AppConstants.cardDarkBg.withValues(alpha: 0.5) : AppConstants.primaryColor.withValues(alpha: 0.03),
              child: Column(
                children: [
                  const Text('إجمالي المصروفات الحالية', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    Helpers.formatCurrency(totalAmt),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppConstants.accentColor : AppConstants.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showTrash ? Icons.delete_outline : Icons.account_balance_wallet_outlined,
                          size: 50,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _showTrash ? 'سلة المحذوفات فارغة' : 'لا توجد مصروفات مسجلة بعد',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final expense = list[index];
                      return _buildExpenseCard(context, expense);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(BuildContext context, Expense expense) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final isDark = provider.isDarkMode;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? AppConstants.primaryLightColor : AppConstants.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(expense.category),
                color: isDark ? AppConstants.accentColor : AppConstants.primaryColor,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.item,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المستلم: ${expense.recipient}\nالتصنيف: ${expense.category}',
                    style: const TextStyle(fontSize: 12, color: AppConstants.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${Helpers.formatDate(expense.date)} - ${Helpers.formatTime(expense.time)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Value & Operations
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Helpers.formatCurrency(expense.amount),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.dangerColor, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (expense.receiptPath != null)
                      IconButton(
                        icon: const Icon(Icons.receipt_long, color: Colors.grey, size: 20),
                        onPressed: () => _viewReceiptImage(context, expense.receiptPath!),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 8),
                    if (!_showTrash) ...[
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showAddEditExpenseSheet(context, expense: expense);
                          } else if (val == 'trash') {
                            _trashExpense(context, expense);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'edit', child: Text('تعديل المصروف')),
                          const PopupMenuItem(value: 'trash', child: Text('نقل إلى السلة', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ] else ...[
                      IconButton(
                        icon: const Icon(Icons.restore, color: AppConstants.successColor, size: 20),
                        tooltip: 'استعادة',
                        onPressed: () => provider.restoreExpense(expense.id!),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                        tooltip: 'حذف نهائي',
                        onPressed: () => _deletePermanently(context, expense),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'قاعة':
        return Icons.business;
      case 'ضيافة':
        return Icons.flatware;
      case 'تصوير':
        return Icons.camera_alt;
      case 'دروع وشهادات':
        return Icons.emoji_events;
      default:
        return Icons.payments;
    }
  }

  void _trashExpense(BuildContext context, Expense expense) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final confirm = await Helpers.showConfirmDialog(
      context: context,
      title: 'نقل للسلة',
      content: 'هل تريد نقل هذا المصروف بقيمة ${Helpers.formatCurrency(expense.amount)} إلى سلة المحذوفات؟',
      confirmLabel: 'نقل',
    );
    if (confirm && context.mounted) {
      await provider.trashExpense(expense.id!);
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'تم نقل المصروف إلى سلة المحذوفات');
    }
  }

  void _deletePermanently(BuildContext context, Expense expense) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final confirm = await Helpers.showConfirmDialog(
      context: context,
      title: 'حذف نهائي',
      content: 'هل تريد حذف المصروف "${expense.item}" بشكل نهائي؟ لا يمكن التراجع عن هذه الخطوة.',
      confirmLabel: 'حذف نهائي',
      isDanger: true,
    );
    if (confirm && context.mounted) {
      await provider.deleteExpensePermanently(expense.id!);
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'تم حذف المصروف نهائياً');
    }
  }

  void _clearAllTrash(BuildContext context) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final confirm = await Helpers.showConfirmDialog(
      context: context,
      title: 'تفريغ السلة',
      content: 'هل أنت متأكد من حذف كافة المصروفات في سلة المحذوفات نهائياً؟',
      confirmLabel: 'تفريغ',
      isDanger: true,
    );
    if (confirm && context.mounted) {
      await provider.clearTrash();
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'تم تفريغ سلة المحذوفات بالكامل');
    }
  }

  void _viewReceiptImage(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('إثبات الدفع / الفاتورة'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
              ],
            ),
            if (File(path).existsSync())
              InteractiveViewer(
                child: Image.file(File(path), fit: BoxFit.contain),
              )
            else
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('صورة الفاتورة غير متوفرة أو تم حذفها من الجهاز'),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddEditExpenseSheet(BuildContext context, {Expense? expense}) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final isEdit = expense != null;

    final itemController = TextEditingController(text: expense?.item ?? '');
    final amountController = TextEditingController(text: expense?.amount.toInt().toString() ?? '');
    final recipientController = TextEditingController(text: expense?.recipient ?? '');
    final detailsController = TextEditingController(text: expense?.details ?? '');
    String selectedCategory = expense?.category ?? 'قاعة';
    String? receiptPath = expense?.receiptPath;

    final categories = ['قاعة', 'ضيافة', 'تصوير', 'دروع وشهادات', 'أخرى'];

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
                  isEdit ? 'تعديل بيانات الصرف' : 'تسجيل مصروف جديد',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Image picker for receipt
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setModalState(() {
                          receiptPath = image.path;
                        });
                      }
                    },
                    child: Container(
                      width: 100,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: receiptPath != null && File(receiptPath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(File(receiptPath!), fit: BoxFit.cover),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long, color: Colors.grey),
                                SizedBox(height: 4),
                                Text('إضافة فاتورة', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: itemController,
                  decoration: const InputDecoration(labelText: 'ماذا تم شراؤه؟'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ المالي'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: recipientController,
                  decoration: const InputDecoration(labelText: 'الجهة / الشخص المستلم'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(labelText: 'تفاصيل إضافية'),
                ),
                const SizedBox(height: 15),

                const Text('تصنيف المصروف:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: categories.map((cat) {
                    bool isSelected = selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() {
                            selectedCategory = cat;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    final item = itemController.text.trim();
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    final recipient = recipientController.text.trim();
                    final details = detailsController.text.trim();

                    if (item.isEmpty || amount <= 0 || recipient.isEmpty) {
                      Helpers.showSnackBar(context, 'يرجى إدخال البيانات المطلوبة بشكل صحيح', isError: true);
                      return;
                    }

                    final now = DateTime.now();
                    String date = expense?.date ?? "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                    String time = expense?.time ?? "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

                    final newExpense = Expense(
                      id: expense?.id,
                      amount: amount,
                      recipient: recipient,
                      item: item,
                      details: details,
                      category: selectedCategory,
                      date: date,
                      time: time,
                      receiptPath: receiptPath,
                    );

                    if (isEdit) {
                      provider.updateExpense(newExpense);
                      Helpers.showSnackBar(context, 'تم تحديث بيانات الصرف');
                    } else {
                      provider.addExpense(newExpense);
                      Helpers.showSnackBar(context, 'تم تسجيل المصروف بنجاح');
                    }

                    Navigator.pop(ctx);
                  },
                  child: Text(isEdit ? 'تحديث' : 'تسجيل الصرف'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _exportExpensesPdf(BuildContext context) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    Helpers.showSnackBar(context, 'جاري تحضير ملف كشف المصروفات PDF...');
    
    final pdfBytes = await ReportService.instance.generateExpensesReportPdf(
      provider.expenses,
      provider.ceremonyName,
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/expenses_report.pdf');
    await file.writeAsBytes(pdfBytes);
    
    await Share.shareXFiles([XFile(file.path)], text: 'كشف المصروفات العام');
  }
}
