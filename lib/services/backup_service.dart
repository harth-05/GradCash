import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'finance_provider.dart';

class BackupService {
  static final BackupService instance = BackupService._init();

  BackupService._init();

  // Export local backup as JSON and share it
  Future<bool> exportLocalBackup(FinanceProvider provider) async {
    try {
      final dump = await provider.dumpData();
      final jsonString = jsonEncode(dump);
      
      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/gradcash_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await backupFile.writeAsString(jsonString);

      // Share file
      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'GradCash نسخة احتياطية لتطبيق إدارة حفل التخرج',
      );
      
      return true;
    } catch (e) {
      debugPrint('Backup export failed: $e');
      return false;
    }
  }

  // Pick JSON file and restore database
  Future<String?> importLocalBackup(FinanceProvider provider) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(jsonString);

        // Validation of keys
        if (!data.containsKey('students') || !data.containsKey('payments') || !data.containsKey('expenses') || !data.containsKey('sponsors')) {
          return 'ملف النسخة الاحتياطية غير صالح أو تالف';
        }

        await provider.restoreFromMap(data);
        return null; // success
      }
      return 'تم إلغاء تحديد الملف';
    } catch (e) {
      debugPrint('Backup import failed: $e');
      return 'فشل استيراد النسخة الاحتياطية: $e';
    }
  }

  // Google Drive Simulation (since real oauth is setup dependent)
  Future<bool> uploadToGoogleDrive(FinanceProvider provider) async {
    // Simulate API call delay
    await Future.delayed(const Duration(seconds: 3));
    // Save metadata of last sync
    // In production we would authenticate and upload JSON, here we show visual success.
    return true;
  }

  Future<bool> downloadFromGoogleDrive(FinanceProvider provider) async {
    // Simulate API call delay
    await Future.delayed(const Duration(seconds: 3));
    // In production we would download JSON and call provider.restoreFromMap
    return true;
  }
}
