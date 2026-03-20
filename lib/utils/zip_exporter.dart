import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

class ZipExporter {
  /// Creates a ZIP archive of all collected images and returns its path.
  /// The ZIP is saved to the app's external storage / downloads folder.
  static Future<String> exportZip() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/images');
    if (!await imagesDir.exists()) {
      throw Exception('No images collected yet.');
    }

    final encoder = ZipFileEncoder();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final zipPath = '${dir.path}/ml_dataset_$timestamp.zip';
    encoder.create(zipPath);

    // Walk the images directory
    await for (final folderEntity in imagesDir.list()) {
      if (folderEntity is! Directory) continue;
      final folderName = folderEntity.path.split('/').last;
      await for (final fileEntity in folderEntity.list()) {
        if (fileEntity is! File) continue;
        if (!fileEntity.path.endsWith('.png')) continue;
        final fileName = fileEntity.path.split('/').last;
        encoder.addFile(fileEntity, '$folderName/$fileName');
      }
    }

    encoder.close();
    return zipPath;
  }
}
