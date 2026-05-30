import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/student_model.dart';
import '../models/payment_model.dart';
import '../services/finance_provider.dart';
import '../services/report_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class StudentDetailScreen extends StatefulWidget {
  final int studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FinanceProvider>(context, listen: false)
          .loadPaymentsForStudent(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final isDark = provider.isDarkMode;

    // Retrieve student map to get computed paid_amount
    final studentMap = provider.students.firstWhere(
      (s) => s['id'] == widget.studentId,
      orElse: () => {},
    );

    if (studentMap.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطالب')),
        body: const Center(child: Text('الطالب غير موجود')),
      );
    }

    final student = Student.fromMap(studentMap);
    final paid = (studentMap['paid_amount'] as num).toDouble();
    final rem = student.requiredAmount - paid;
    final progress = student.requiredAmount == 0 ? 0.0 : paid / student.requiredAmount;
    final payments = provider.studentPayments;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(student.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'تصدير كشف حساب PDF',
              onPressed: () => _exportStudentStatement(context, studentMap, payments),
            ),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  _showEditStudentSheet(context, student);
                } else if (val == 'delete') {
                  _deleteStudent(context, student);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
                const PopupMenuItem(value: 'delete', child: Text('حذف الطالب', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Profile Card with details
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isDark ? AppConstants.primaryLightColor : AppConstants.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: student.photoPath != null && File(student.photoPath!).existsSync()
                              ? Image.file(File(student.photoPath!), fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    student.name[0],
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppConstants.primaryColor,
                                    ),
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
                              student.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('الرقم الجامعي: ${student.universityId}', style: const TextStyle(fontSize: 13, color: AppConstants.textMuted)),
                            Text('القسم: ${student.department}', style: const TextStyle(fontSize: 13, color: AppConstants.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Financial Progress Card & Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'ملخص الدفعات السديدة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      
                      // Chart Row
                      Row(
                        children: [
                          // Pie Chart
                          Expanded(
                            flex: 4,
                            child: SizedBox(
                              height: 140,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 35,
                                  sections: [
                                    PieChartSectionData(
                                      color: AppConstants.successColor,
                                      value: paid,
                                      title: '${(progress * 100).toInt()}%',
                                      radius: 25,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      color: AppConstants.dangerColor,
                                      value: rem > 0 ? rem : 0,
                                      title: '',
                                      radius: 25,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Stats details
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatRow('المطلوب:', Helpers.formatCurrency(student.requiredAmount), Colors.grey),
                                const SizedBox(height: 8),
                                _buildStatRow('المدفوع:', Helpers.formatCurrency(paid), AppConstants.successColor),
                                const SizedBox(height: 8),
                                _buildStatRow('المتبقي:', Helpers.formatCurrency(rem), AppConstants.dangerColor),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Payments Record list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'سجل المدفوعات التفصيلي',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPaymentSheet(context, student),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة دفعة', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              payments.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.payment_outlined, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('لا توجد دفعات مسجلة لهذا الطالب', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payments.length,
                      itemBuilder: (context, index) {
                        final payment = payments[index];
                        return _buildPaymentItem(context, payment);
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
        ),
      ],
    );
  }

  Widget _buildPaymentItem(BuildContext context, Payment payment) {

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          Helpers.formatCurrency(payment.amount),
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.successColor),
        ),
        subtitle: Text(
          'طريقة الدفع: ${payment.paymentMethod}\n${Helpers.formatDate(payment.date)} - ${Helpers.formatTime(payment.time)}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (payment.notes != null)
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.grey),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('ملاحظات الدفعة'),
                      content: Text(payment.notes!, style: const TextStyle(fontFamily: 'Cairo')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))
                      ],
                    ),
                  );
                },
              ),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  _showEditPaymentSheet(context, payment);
                } else if (val == 'delete') {
                  _deletePayment(context, payment);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل الدفعة')),
                const PopupMenuItem(value: 'delete', child: Text('حذف الدفعة', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Action methods
  Future<void> _exportStudentStatement(BuildContext context, Map<String, dynamic> studentData, List<Payment> payments) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    
    Helpers.showSnackBar(context, 'جاري تحضير ملف PDF...');
    final pdfBytes = await ReportService.instance.generateStudentStatementPdf(
      studentData,
      payments,
      provider.ceremonyName,
    );

    // Share PDF file using temporary directory
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/statement_${studentData['name']}.pdf');
    await tempFile.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(tempFile.path)],
      text: 'كشف حساب الطالب: ${studentData['name']}',
    );
  }

  void _deleteStudent(BuildContext context, Student student) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final confirm = await Helpers.showConfirmDialog(
      context: context,
      title: 'حذف طالب',
      content: 'هل أنت متأكد من حذف الطالب ${student.name}؟ سيتم حذف جميع دفعاته أيضاً.',
      confirmLabel: 'حذف',
      isDanger: true,
    );

    if (confirm && context.mounted) {
      await provider.deleteStudent(student.id!);
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'تم حذف الطالب بنجاح');
      Navigator.pop(context);
    }
  }

  void _deletePayment(BuildContext context, Payment payment) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final confirm = await Helpers.showConfirmDialog(
      context: context,
      title: 'حذف دفعة',
      content: 'هل تريد حذف هذه الدفعة بقيمة ${Helpers.formatCurrency(payment.amount)}؟',
      confirmLabel: 'حذف',
      isDanger: true,
    );

    if (confirm && context.mounted) {
      await provider.deletePayment(payment.id!);
      await provider.loadPaymentsForStudent(widget.studentId);
      if (!context.mounted) return;
      Helpers.showSnackBar(context, 'تم حذف الدفعة وتحديث الحساب');
    }
  }

  // Edit student modal sheet
  void _showEditStudentSheet(BuildContext context, Student student) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final nameController = TextEditingController(text: student.name);
    final uniIdController = TextEditingController(text: student.universityId);
    final deptController = TextEditingController(text: student.department);
    final amountController = TextEditingController(text: student.requiredAmount.toInt().toString());
    String? photoPath = student.photoPath;

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
                const Text(
                  'تعديل بيانات الطالب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Image Picker
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setModalState(() {
                          photoPath = image.path;
                        });
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: photoPath != null && File(photoPath!).existsSync()
                          ? ClipOval(child: Image.file(File(photoPath!), fit: BoxFit.cover))
                          : const Icon(Icons.camera_alt, size: 30, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم الطالب'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: uniIdController,
                  decoration: const InputDecoration(labelText: 'الرقم الجامعي'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deptController,
                  decoration: const InputDecoration(labelText: 'القسم'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ المطلوب'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final uniId = uniIdController.text.trim();
                    final dept = deptController.text.trim();
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;

                    if (name.isEmpty || uniId.isEmpty || dept.isEmpty) {
                      Helpers.showSnackBar(context, 'يرجى ملء جميع الحقول', isError: true);
                      return;
                    }

                    final updated = student.copyWith(
                      name: name,
                      universityId: uniId,
                      department: dept,
                      photoPath: photoPath,
                      requiredAmount: amount,
                    );

                    provider.updateStudent(updated);
                    Helpers.showSnackBar(context, 'تم تعديل بيانات الطالب');
                    Navigator.pop(ctx);
                  },
                  child: const Text('تحديث البيانات'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add/Edit Payment Modal
  void _showAddPaymentSheet(BuildContext context, Student student) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedMethod = 'كاش';
    final methods = ['كاش', 'محفظة جيب', 'ون كاش', 'الكريمي', 'حوالة'];

    final now = DateTime.now();
    String formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    String formattedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

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
                const Text(
                  'إضافة دفعة سداد جديدة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ المدفوع'),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
                const SizedBox(height: 15),

                const Text('طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: methods.map((method) {
                    bool isSelected = selectedMethod == method;
                    return ChoiceChip(
                      label: Text(method),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() {
                            selectedMethod = method;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amount <= 0) {
                      Helpers.showSnackBar(context, 'يرجى إدخال مبلغ صحيح', isError: true);
                      return;
                    }

                    final payment = Payment(
                      studentId: student.id!,
                      amount: amount,
                      paymentMethod: selectedMethod,
                      date: formattedDate,
                      time: formattedTime,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    );

                    await provider.addPayment(payment);
                    await provider.loadPaymentsForStudent(widget.studentId);
                    if (!ctx.mounted) return;
                    Helpers.showSnackBar(ctx, 'تم تسجيل الدفعة بنجاح');
                    Navigator.pop(ctx);
                  },
                  child: const Text('تسجيل الدفعة'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPaymentSheet(BuildContext context, Payment payment) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final amountController = TextEditingController(text: payment.amount.toInt().toString());
    final notesController = TextEditingController(text: payment.notes ?? '');
    String selectedMethod = payment.paymentMethod;
    final methods = ['كاش', 'محفظة جيب', 'ون كاش', 'الكريمي', 'حوالة'];

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
                const Text(
                  'تعديل الدفعة السديدة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ المدفوع'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 15),

                const Text('طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: methods.map((method) {
                    bool isSelected = selectedMethod == method;
                    return ChoiceChip(
                      label: Text(method),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() {
                            selectedMethod = method;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amount <= 0) {
                      Helpers.showSnackBar(context, 'يرجى إدخال مبلغ صحيح', isError: true);
                      return;
                    }

                    final updated = payment.copyWith(
                      amount: amount,
                      paymentMethod: selectedMethod,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    );

                    await provider.updatePayment(updated);
                    await provider.loadPaymentsForStudent(widget.studentId);
                    if (!ctx.mounted) return;
                    Helpers.showSnackBar(ctx, 'تم تحديث الدفعة');
                    Navigator.pop(ctx);
                  },
                  child: const Text('تعديل الدفعة'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
