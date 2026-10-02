import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/receipt_service.dart';
import '../../theme/app_theme.dart';
import '../expenses/add_expense_screen.dart';
import 'crop_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;
  bool _busy = false;
  bool _flash = false;
  int _generation = 0;
  Future<void> _cameraWork = Future<void>.value();
  bool _finished = false;
  Offset? _focusPoint;
  bool _focusAccepted = false;
  Timer? _focusTimer;
  int _focusRequest = 0;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    final previous = _cameraWork;
    _cameraWork = _openCamera(previous, generation);
    await _cameraWork;
  }

  Future<void> _openCamera(Future<void> previous, int generation) async {
    await previous;
    if (!mounted ||
        generation != _generation ||
        _lifecycle != AppLifecycleState.resumed) {
      return;
    }
    CameraController? controller;
    try {
      final old = _camera;
      _camera = null;
      await old?.dispose();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Không tìm thấy camera');
      }
      if (!mounted || generation != _generation) {
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _error = null;
        _flash = false;
      });
    } catch (e) {
      try {
        await controller?.dispose();
      } catch (_) {
        /* Initialization already failed. */
      }
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Không mở được camera. Kiểm tra quyền camera trong Cài đặt rồi thử lại.\n$e',
        );
      }
    }
  }

  Future<void> _release() async {
    ++_generation;
    final previous = _cameraWork;
    _cameraWork = _closeCamera(previous);
    await _cameraWork;
  }

  Future<void> _closeCamera(Future<void> previous) async {
    await previous;
    final camera = _camera;
    _camera = null;
    if (mounted) {
      setState(() {});
    }
    try {
      await camera?.dispose();
    } catch (e) {
      _message('Không đóng được camera: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _release();
    } else if (state == AppLifecycleState.resumed &&
        !_busy &&
        _camera == null) {
      _initialize();
    }
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  void _message(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null) {
      return;
    }
    try {
      final value = !_flash;
      await camera.setFlashMode(value ? FlashMode.torch : FlashMode.off);
      if (mounted && camera == _camera) {
        setState(() => _flash = value);
      }
    } catch (e) {
      _message('Thiết bị không hỗ trợ đèn flash: $e');
    }
  }

  Future<void> _focus(Offset point) async {
    final camera = _camera;
    if (camera == null) {
      return;
    }
    final request = ++_focusRequest;
    _focusTimer?.cancel();
    setState(() {
      _focusPoint = point;
      _focusAccepted = false;
    });
    HapticFeedback.selectionClick();
    try {
      await camera.setFocusMode(FocusMode.auto);
      await camera.setFocusPoint(point);
      await camera.setExposurePoint(point);
      if (mounted && camera == _camera && request == _focusRequest) {
        setState(() => _focusAccepted = true);
      }
    } catch (e) {
      _message('Không thể lấy nét tại điểm này: $e');
    } finally {
      if (mounted && request == _focusRequest) {
        _focusTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _focusPoint = null);
          }
        });
      }
    }
  }

  Future<void> _scan({bool gallery = false}) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    String? source;
    String? cropped;
    try {
      if (gallery) {
        await _release();
        source = (await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 2400,
        ))?.path;
      } else {
        final camera = _camera;
        if (camera == null || !camera.value.isInitialized) {
          return;
        }
        source = (await camera.takePicture()).path;
        await _release();
      }
      if (source == null || !mounted) {
        return;
      }
      cropped = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => CropScreen(path: source!)),
      );
      if (cropped == null || !mounted) {
        return;
      }
      final result = await ReceiptService.recognize(cropped);
      if (!mounted) {
        return;
      }
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(ocr: result, imagePath: cropped),
        ),
      );
      if (saved == true && mounted) {
        _finished = true;
        Navigator.pop(context, true);
      }
    } catch (e) {
      _message('Không thể quét hóa đơn: $e');
    } finally {
      if (source != null) {
        await ReceiptService.deleteTemporary(source);
      }
      if (cropped != null) {
        await ReceiptService.deleteTemporary(cropped);
      }
      if (mounted && !_finished) {
        setState(() => _busy = false);
        if (_camera == null && _lifecycle == AppLifecycleState.resumed) {
          await _initialize();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: const Color(0xFF101C25),
        appBar: AppBar(
          backgroundColor: const Color(0xFF101C25),
          foregroundColor: Colors.white,
          title: const Text(
            'Quét hóa đơn',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Bật/tắt flash',
              onPressed: _busy || camera == null ? null : _toggleFlash,
              color: Colors.white,
              icon: Icon(
                _flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Text(
                'Căn hóa đơn trong khung, chạm để lấy nét',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            Expanded(
              child: _busy
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Đang đọc hóa đơn...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            TextButton(
                              onPressed: _initialize,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : camera == null
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                      child: AspectRatio(
                        aspectRatio: 1 / camera.value.aspectRatio,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: LayoutBuilder(
                            builder: (_, constraints) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (event) => _focus(
                                Offset(
                                  (event.localPosition.dx /
                                          constraints.maxWidth)
                                      .clamp(0, 1),
                                  (event.localPosition.dy /
                                          constraints.maxHeight)
                                      .clamp(0, 1),
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(camera),
                                  IgnorePointer(
                                    child: CustomPaint(
                                      painter: CropOverlay(
                                        Rect.fromLTRB(
                                          constraints.maxWidth * .08,
                                          constraints.maxHeight * .08,
                                          constraints.maxWidth * .92,
                                          constraints.maxHeight * .92,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_focusPoint != null)
                                    Positioned(
                                      left:
                                          (_focusPoint!.dx *
                                                      constraints.maxWidth -
                                                  30)
                                              .clamp(
                                                0,
                                                (constraints.maxWidth - 60)
                                                    .clamp(0, double.infinity),
                                              ),
                                      top:
                                          (_focusPoint!.dy *
                                                      constraints.maxHeight -
                                                  30)
                                              .clamp(
                                                0,
                                                (constraints.maxHeight - 60)
                                                    .clamp(0, double.infinity),
                                              ),
                                      child: IgnorePointer(
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: _focusAccepted
                                                  ? const Color(0xFF61E4BC)
                                                  : Colors.amber,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.center_focus_strong_rounded,
                                            color: _focusAccepted
                                                ? const Color(0xFF61E4BC)
                                                : Colors.amber,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_focusPoint != null)
                                    Positioned(
                                      bottom: 22,
                                      left: 0,
                                      right: 0,
                                      child: IgnorePointer(
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _focusAccepted
                                                  ? 'Đã đặt điểm lấy nét'
                                                  : 'Đang đặt điểm lấy nét...',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : () => _scan(gallery: true),
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Thư viện',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                        ),
                        onPressed: _busy || camera == null ? null : _scan,
                        child: const Icon(Icons.camera_alt_rounded, size: 32),
                      ),
                    ),
                    const SizedBox(
                      width: 72,
                      child: Text(
                        'OCR\noffline',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
