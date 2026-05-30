import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/student_model.dart';
import '../models/payment_model.dart';
import '../services/finance_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'student_detail_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/report_service.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final filteredStudents = provider.getFilteredStudents();
    final stats = provider.getStatistics();
    final isDark = provider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.ceremonyName),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'تصدير كشف الطلاب PDF',
            onPressed: () => _exportStudentsPdf(context),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'إضافة طالب جديد',
            onPressed: () => _showAddEditStudentSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Quick Stats Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppConstants.cardDarkBg.withValues(alpha: 0.5) : AppConstants.primaryColor.withValues(alpha: 0.03),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStatCard('إجمالي المطلوب', Helpers.formatCurrency(stats['totalRequired']), AppConstants.primaryColor),
                _buildQuickStatCard('إجمالي المدفوع', Helpers.formatCurrency(stats['totalPaid']), AppConstants.successColor),
                _buildQuickStatCard('المتبقي', Helpers.formatCurrency(stats['totalRemaining']), AppConstants.dangerColor),
              ],
            ),
          ),

          // 2. Search and filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'البحث عن طالب (الاسم، الرقم...)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                provider.setStudentSearchQuery('');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => provider.setStudentSearchQuery(val),
                  ),
                ),
                const SizedBox(width: 8),
                _buildSortMenu(context, provider),
                const SizedBox(width: 8),
                _buildFilterMenu(context, provider),
              ],
            ),
          ),

          // 3. Students list
          Expanded(
            child: filteredStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'لا يوجد طلاب مطابقين للبحث',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, index) {
                      final studentMap = filteredStudents[index];
                      final student = Student.fromMap(studentMap);
                      final paid = (studentMap['paid_amount'] as num).toDouble();
                      return _buildStudentCard(context, student, paid);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard(String label, String value, Color color) {
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

  Widget _buildSortMenu(BuildContext context, FinanceProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort),
      tooltip: 'ترتيب الطلاب',
      onSelected: (val) => provider.setStudentSortBy(val),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'name', child: Text('الترتيب حسب الاسم')),
        const PopupMenuItem(value: 'required', child: Text('الأعلى مطلوباً')),
        const PopupMenuItem(value: 'paid', child: Text('الأعلى مدفوعاً')),
        const PopupMenuItem(value: 'remaining', child: Text('الأعلى متبقياً')),
        const PopupMenuItem(value: 'progress', child: Text('نسبة الإنجاز')),
      ],
    );
  }

  Widget _buildFilterMenu(BuildContext context, FinanceProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_alt_outlined),
      tooltip: 'فلترة الطلاب',
      onSelected: (val) => provider.setStudentFilterStatus(val),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'all', child: Text('عرض الكل')),
        const PopupMenuItem(value: 'completed', child: Text('مسدد بالكامل')),
        const PopupMenuItem(value: 'partial', child: Text('سداد جزئي')),
        const PopupMenuItem(value: 'unpaid', child: Text('لم يدفع بعد')),
      ],
    );
  }

  Widget _buildStudentCard(BuildContext context, Student student, double paid) {
    final rem = student.requiredAmount - paid;
    final progress = student.requiredAmount == 0 ? 0.0 : paid / student.requiredAmount;
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final isDark = provider.isDarkMode;

    Color statusColor;
    String statusText;
    if (paid >= student.requiredAmount && student.requiredAmount > 0) {
      statusColor = AppConstants.successColor;
      statusText = 'مكتمل';
    } else if (paid > 0) {
      statusColor = AppConstants.warningColor;
      statusText = 'جزئي';
    } else {
      statusColor = AppConstants.dangerColor;
      statusText = 'لم يدفع';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentDetailScreen(studentId: student.id!),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo or initial
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? AppConstants.primaryLightColor : AppConstants.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: student.photoPath != null && File(student.photoPath!).existsSync()
                      ? Image.file(File(student.photoPath!), fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            student.name.isNotEmpty ? student.name[0] : 'ط',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppConstants.primaryColor,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'القسم: ${student.department} | الرقم: ${student.universityId}',
                      style: const TextStyle(fontSize: 12, color: AppConstants.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المدفوع: ${Helpers.formatCurrency(paid)}', style: const TextStyle(fontSize: 12)),
                        Text('المتبقي: ${Helpers.formatCurrency(rem)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.dangerColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Progress Indicator & Quick Pay Button
              Column(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          color: statusColor,
                          strokeWidth: 4,
                        ),
                        Center(
                          child: Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Quick add payment button
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppConstants.accentColor),
                    iconSize: 26,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'إضافة دفعة مباشرة',
                    onPressed: () => _showAddPaymentSheet(context, student),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show Bottom Sheet to Add/Edit Student
  void _showAddEditStudentSheet(BuildContext context, {Student? student}) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final isEdit = student != null;

    final nameController = TextEditingController(text: student?.name ?? '');
    final uniIdController = TextEditingController(text: student?.universityId ?? '');
    final deptController = TextEditingController(text: student?.department ?? '');
    final amountController = TextEditingController(
      text: isEdit ? student.requiredAmount.toInt().toString() : provider.defaultBaseAmount.toInt().toString(),
    );
    String? photoPath = student?.photoPath;

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
                  isEdit ? 'تعديل بيانات الطالب' : 'إضافة طالب جديد',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: uniIdController,
                  decoration: const InputDecoration(labelText: 'الرقم الجامعي (اختياري)'),
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

                    if (name.isEmpty || dept.isEmpty) {
                      Helpers.showSnackBar(context, 'يرجى إدخال الاسم والقسم على الأقل', isError: true);
                      return;
                    }

                    final newStudent = Student(
                      id: student?.id,
                      name: name,
                      universityId: uniId,
                      department: dept,
                      photoPath: photoPath,
                      requiredAmount: amount,
                    );

                    if (isEdit) {
                      provider.updateStudent(newStudent);
                      Helpers.showSnackBar(context, 'تم تحديث بيانات الطالب');
                    } else {
                      provider.addStudent(newStudent);
                      Helpers.showSnackBar(context, 'تم إضافة الطالب بنجاح');
                    }

                    Navigator.pop(ctx);
                  },
                  child: Text(isEdit ? 'تحديث' : 'إضافة الطالب'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show Bottom Sheet to add payment directly
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
                Text(
                  'إضافة دفعة لـ: ${student.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  onPressed: () {
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

                    provider.addPayment(payment);
                    Helpers.showSnackBar(context, 'تم إضافة الدفعة وتحديث الرصيد');
                    Navigator.pop(ctx);
                  },
                  child: const Text('إضافة الدفعة'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _exportStudentsPdf(BuildContext context) async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    Helpers.showSnackBar(context, 'جاري تحضير ملف كشف الطلاب PDF...');
    
    final pdfBytes = await ReportService.instance.generateFullStudentsReportPdf(
      provider.students,
      provider.ceremonyName,
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/students_report.pdf');
    await file.writeAsBytes(pdfBytes);
    
    await Share.shareXFiles([XFile(file.path)], text: 'كشف جميع الطلاب وحالة السداد');
  }
}
