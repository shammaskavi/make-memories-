import 'dart:io';
import 'dart:math';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageProcessingHelper {
  static Future<String> processImage(String path, {bool flip = false}) async {
    final bytes = await File(path).readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Could not decode image');

    // Flip horizontally for front camera if needed
    if (flip) {
      image = img.flipHorizontal(image);
    }

    // Resize to printer width (e.g., 384px)
    image = img.copyResize(image, width: 384);

    // Convert to grayscale
    image = img.grayscale(image);
    image = img.adjustColor(
      image,
      gamma: 1.0, // No boost
      brightness: 0.02, // Tiny lift
      contrast: 0.03, // Tiny edge pop
    );

    // Apply Atkinson dithering
    image = _atkinsonDither(image);

    // Save processed image to temp file
    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/dithered_${DateTime.now().millisecondsSinceEpoch}.png';
    final outFile = File(outPath)..writeAsBytesSync(img.encodePng(image));

    return outFile.path;
  }

  static img.Image _atkinsonDither(img.Image src) {
    final w = src.width;
    final h = src.height;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final oldPixel = img.getLuminance(src.getPixel(x, y));
        final newPixel = oldPixel > 128 ? 255 : 0;
        final err = (oldPixel - newPixel) ~/ 8;

        // Set the new dithered value
        src.setPixelRgb(x, y, newPixel, newPixel, newPixel);

        // Distribute error
        _addPixelErr(src, x + 1, y, err);
        _addPixelErr(src, x + 2, y, err);
        _addPixelErr(src, x - 1, y + 1, err);
        _addPixelErr(src, x, y + 1, err);
        _addPixelErr(src, x + 1, y + 1, err);
        _addPixelErr(src, x, y + 2, err);
      }
    }
    return src;
  }

  static void _addPixelErr(img.Image imgData, int x, int y, int err) {
    if (x < 0 || x >= imgData.width || y < 0 || y >= imgData.height) return;

    final current = img.getLuminance(imgData.getPixel(x, y));
    final updated = (current + err).clamp(0, 255).toInt();

    imgData.setPixelRgb(x, y, updated, updated, updated);
  }
}
