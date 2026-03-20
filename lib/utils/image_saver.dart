import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageSaver {
  /// Reads the JPEG from [sourcePath], resizes to 128x128 as RGB PNG,
  /// and saves it under {appDocs}/images/{folderName}/img{n}.png.
  static Future<String> saveImage({
    required String sourcePath,
    required List<String> classes,
  }) async {
    final folderName = (List<String>.from(classes)..sort()).join('_');
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/images/$folderName');
    await folder.create(recursive: true);

    // Count existing images to determine next index
    final existing = folder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .length;

    // Decode, resize, convert to RGB PNG on isolate
    final inputBytes = await File(sourcePath).readAsBytes();
    final pngBytes = await compute(_processImage, inputBytes);

    final outPath = '${folder.path}/img$existing.png';
    await File(outPath).writeAsBytes(pngBytes);
    return outPath;
  }
}

/// Runs in an isolate: decode JPEG, resize to 128x128, encode as RGB PNG.
Uint8List _processImage(Uint8List inputBytes) {
  final decoded = img.decodeImage(inputBytes);
  if (decoded == null) throw Exception('Could not decode image');
  final resized = img.copyResize(
    decoded,
    width: 128,
    height: 128,
    interpolation: img.Interpolation.linear,
  );
  // Write pixels into a 3-channel RGB image to strip any alpha channel
  final rgb = img.Image(width: 128, height: 128, numChannels: 3);
  for (int y = 0; y < 128; y++) {
    for (int x = 0; x < 128; x++) {
      final pixel = resized.getPixel(x, y);
      rgb.setPixelRgb(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
    }
  }
  return Uint8List.fromList(img.encodePng(rgb));
}
