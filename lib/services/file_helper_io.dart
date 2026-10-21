import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class PlatformFileHelper {
  static Future<bool> downloadJson(String fileName, String content) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final result = await FilePicker.saveFile(
        dialogTitle: 'Export Tasks JSON',
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      return result != null;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> pickJson() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Import Tasks JSON',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result.isEmpty) return null;
      return await result.first.xFile.readAsString();
    } catch (_) {
      return null;
    }
  }
}
