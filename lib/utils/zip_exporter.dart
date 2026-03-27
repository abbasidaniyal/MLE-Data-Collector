import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

class ZipExporter {
  /// Creates a ZIP archive of all collected images and returns its path.
  /// The ZIP is saved to the device's Downloads folder, or falls back to the
  /// app's documents directory if the Downloads folder is unavailable.
  static Future<String> exportZip() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/images');
    if (!await imagesDir.exists()) {
      throw Exception('No images collected yet.');
    }

    final downloadsDir = await getDownloadsDirectory();
    final saveDir = downloadsDir ?? appDir;

    final encoder = ZipFileEncoder();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final zipPath = '${saveDir.path}/ml_dataset_$timestamp.zip';
    encoder.create(zipPath);

    // Walk the images directory
    await for (final folderEntity in imagesDir.list()) {
      if (folderEntity is! Directory) continue;
      final folderName = folderEntity.path.split('/').last;
      await for (final fileEntity in folderEntity.list()) {
        if (fileEntity is! File) continue;
        if (!fileEntity.path.endsWith('.png')) continue;
        final fileName = fileEntity.path.split('/').last;
        await encoder.addFile(fileEntity, '$folderName/$fileName');
      }
    }

    await encoder.close();
    return zipPath;
  }
}
