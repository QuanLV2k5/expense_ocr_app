import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/receipt_service.dart';

class CropScreen extends StatefulWidget {
  final String path;
  const CropScreen({super.key, required this.path});
  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  Rect _crop = const Rect.fromLTRB(.05, .05, .95, .95);
  double? _ratio;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final image = await decodeImageFromList(bytes);
      final ratio = image.width / image.height;
      image.dispose();
      if (mounted) {
        setState(() => _ratio = ratio);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Không đọc được ảnh: $e');
      }
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final path = await ReceiptService.crop(widget.path, _crop);
      if (mounted) {
        Navigator.pop(context, path);
      } else {
        await ReceiptService.deleteTemporary(path);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Không thể cắt ảnh: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Cắt hóa đơn'),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _crop = const Rect.fromLTRB(0, 0, 1, 1)),
            child: const Text('Toàn ảnh'),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Kéo hai góc khung để giữ lại phần hóa đơn.'),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
          Expanded(
            child: _ratio == null && _error != null
                ? const Center(
                    child: Icon(Icons.broken_image_outlined, size: 64),
                  )
                : _ratio == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: AspectRatio(
                      aspectRatio: _ratio!,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.biggest;
                          final rect = Rect.fromLTRB(
                            _crop.left * size.width,
                            _crop.top * size.height,
                            _crop.right * size.width,
                            _crop.bottom * size.height,
                          );
                          Widget handle(bool start) {
                            final point = start
                                ? rect.topLeft
                                : rect.bottomRight;
                            return Positioned(
                              left: (point.dx - 20).clamp(
                                0,
                                (size.width - 40).clamp(0, double.infinity),
                              ),
                              top: (point.dy - 20).clamp(
                                0,
                                (size.height - 40).clamp(0, double.infinity),
                              ),
                              child: GestureDetector(
                                onPanUpdate: _busy
                                    ? null
                                    : (details) => setState(() {
                                        final dx =
                                            details.delta.dx / size.width;
                                        final dy =
                                            details.delta.dy / size.height;
                                        _crop = start
                                            ? Rect.fromLTRB(
                                                (_crop.left + dx).clamp(
                                                  0,
                                                  _crop.right - .1,
                                                ),
                                                (_crop.top + dy).clamp(
                                                  0,
                                                  _crop.bottom - .1,
                                                ),
                                                _crop.right,
                                                _crop.bottom,
                                              )
                                            : Rect.fromLTRB(
                                                _crop.left,
                                                _crop.top,
                                                (_crop.right + dx).clamp(
                                                  _crop.left + .1,
                                                  1,
                                                ),
                                                (_crop.bottom + dy).clamp(
                                                  _crop.top + .1,
                                                  1,
                                                ),
                                              );
                                      }),
                                child: const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    Icons.open_with,
                                    color: Colors.white,
                                    shadows: [Shadow(blurRadius: 4)],
                                  ),
                                ),
                              ),
                            );
                          }

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(File(widget.path), fit: BoxFit.fill),
                              IgnorePointer(
                                child: CustomPaint(painter: CropOverlay(rect)),
                              ),
                              handle(true),
                              handle(false),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _busy || _ratio == null ? null : _confirm,
                icon: const Icon(Icons.crop),
                label: Text(_busy ? 'Đang cắt...' : 'Dùng ảnh này'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CropOverlay extends CustomPainter {
  final Rect rect;
  CropOverlay(this.rect);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(path, Paint()..color = Colors.black54);
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(CropOverlay oldDelegate) => oldDelegate.rect != rect;
}
