import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'receipt_parser.dart';

class OcrResult {
  final ReceiptData data;
  final int milliseconds;
  const OcrResult(this.data, this.milliseconds);
}

class ReceiptService {
  static Future<OcrResult> recognize(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final timer = Stopwatch()..start();
    try {
      final text = await recognizer.processImage(InputImage.fromFilePath(path));
      timer.stop();
      return OcrResult(
        ReceiptParser.parse(
          text.text,
          layout: [
            for (final block in text.blocks)
              for (final line in block.lines)
                ReceiptLine(
                  line.text,
                  line.boundingBox.left,
                  line.boundingBox.top,
                  line.boundingBox.width,
                  line.boundingBox.height,
                ),
          ],
        ),
        timer.elapsedMilliseconds,
      );
    } finally {
      await recognizer.close();
    }
  }

  /// The crop rectangle is normalized against the displayed image, not camera preview.
  static Future<String> crop(String source, ui.Rect normalized) async {
    final codec = await ui.instantiateImageCodec(
      await File(source).readAsBytes(),
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    final src = ui.Rect.fromLTRB(
      normalized.left * image.width,
      normalized.top * image.height,
      normalized.right * image.width,
      normalized.bottom * image.height,
    );
    final width = src.width.round().clamp(1, image.width);
    final height = src.height.round().clamp(1, image.height);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      src,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(width, height);
    picture.dispose();
    image.dispose();
    final bytes = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'crop_${DateTime.now().microsecondsSinceEpoch}.png'),
    );
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file.path;
  }

  static Future<String> saveThumbnail(String source) async {
    final codec = await ui.instantiateImageCodec(
      await File(source).readAsBytes(),
      targetWidth: 600,
      allowUpscaling: false,
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'receipts'));
    await dir.create(recursive: true);
    final file = File(
      p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}.png'),
    );
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file.path;
  }

  static Future<void> deleteThumbnail(String? path) async {
    if (path == null) {
      return;
    }
    final root = await getApplicationDocumentsDirectory();
    final folder = p.join(root.path, 'receipts');
    if (p.isWithin(folder, path)) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<void> deleteTemporary(String path) async {
    final root = await getTemporaryDirectory();
    if (p.isWithin(root.path, path)) {
      PaintingBinding.instance.imageCache.evict(FileImage(File(path)));
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
