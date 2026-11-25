import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../app/theme.dart';
import 'document_detector.dart';
import 'page_processor.dart';

enum _Phase { starting, live, capturing, review, error }

/// Live document camera.
///
/// Every preview frame is checked for a page outline, which is drawn on top
/// of the camera image. When the outline holds steady the page is captured
/// automatically, cropped and straightened, then shown for approval:
/// Retake, Next page, or Done. Pops with the list of saved page images.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  static const _detector = DocumentDetector(maxSide: 360);

  /// Consecutive steady frames before auto-capture (~0.8 s at ~12 fps).
  static const _steadyFramesNeeded = 9;

  /// Max corner movement (fraction of the frame) that still counts as steady.
  static const _steadyTolerance = 0.022;

  CameraController? _controller;
  _Phase _phase = _Phase.starting;
  String? _error;

  bool _auto = true;
  bool _torch = false;

  Quad? _quad; // smoothed outline drawn on screen
  Quad? _lastRaw;
  int _steady = 0;
  int _misses = 0;
  bool _frameBusy = false;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  final List<String> _pages = [];
  String? _pending; // processed page waiting for approval
  bool _pendingCropped = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(const []);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      c?.dispose();
    } else if (state == AppLifecycleState.resumed && c == null) {
      _start();
    }
  }

  // ---------------------------------------------------------------- camera

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await _resumeLive();
    } on CameraException catch (e) {
      _fail(e.code == 'CameraAccessDenied' ||
              e.code == 'CameraAccessDeniedWithoutPrompt'
          ? 'ArmScan needs camera access to scan. You can allow it in '
              'your phone\'s Settings > Apps > ArmScan > Permissions.'
          : 'The camera could not start (${e.description ?? e.code}).');
    } catch (e) {
      _fail('The camera could not start ($e).');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _error = message;
    });
  }

  Future<void> _resumeLive() async {
    final c = _controller;
    if (c == null) return;
    _quad = null;
    _lastRaw = null;
    _steady = 0;
    _misses = 0;
    if (!c.value.isStreamingImages) await c.startImageStream(_onFrame);
    if (_torch) await c.setFlashMode(FlashMode.torch);
    if (mounted) setState(() => _phase = _Phase.live);
  }

  void _onFrame(CameraImage image) {
    if (_phase != _Phase.live || _frameBusy) return;
    final now = DateTime.now();
    if (now.difference(_lastFrame).inMilliseconds < 70) return;
    _lastFrame = now;
    _frameBusy = true;
    try {
      final (gray, w, h) = _uprightGray(image);
      _onDetection(_detector.detectGray(gray, w, h));
    } catch (e) {
      debugPrint('Frame detection failed: $e');
    } finally {
      _frameBusy = false;
    }
  }

  /// Downsampled luminance (Y plane), rotated to portrait to match the
  /// on-screen preview.
  (Uint8List, int, int) _uprightGray(CameraImage image) {
    final plane = image.planes.first;
    final src = plane.bytes;
    final stride = plane.bytesPerRow;
    final w = image.width, h = image.height;
    final step = ((w > h ? w : h) / 360).ceil().clamp(1, 16);
    final sw = w ~/ step, sh = h ~/ step;

    final landscape = w > h;
    if (!landscape) {
      final out = Uint8List(sw * sh);
      for (var y = 0; y < sh; y++) {
        final row = y * step * stride;
        for (var x = 0; x < sw; x++) {
          out[y * sw + x] = src[row + x * step];
        }
      }
      return (out, sw, sh);
    }

    // Sensor frames are landscape; rotate by the sensor orientation.
    final clockwise =
        (_controller?.description.sensorOrientation ?? 90) != 270;
    final ow = sh, oh = sw; // rotated size
    final out = Uint8List(ow * oh);
    for (var oy = 0; oy < oh; oy++) {
      for (var ox = 0; ox < ow; ox++) {
        final sx = clockwise ? oy : sw - 1 - oy;
        final sy = clockwise ? sh - 1 - ox : ox;
        out[oy * ow + ox] = src[sy * step * stride + sx * step];
      }
    }
    return (out, ow, oh);
  }

  void _onDetection(Quad? q) {
    if (!mounted) return;
    if (q == null) {
      _misses++;
      if (_misses > 4) {
        _quad = null;
        _lastRaw = null;
        _steady = 0;
      }
    } else {
      _misses = 0;
      final last = _lastRaw;
      _steady = (last != null && q.maxCornerShift(last) < _steadyTolerance)
          ? _steady + 1
          : 0;
      _lastRaw = q;
      _quad = _quad == null ? q : _quad!.lerp(q, 0.55);
    }
    setState(() {});
    if (_auto && _steady >= _steadyFramesNeeded) _capture();
  }

  double get _previewAspect {
    final size = _controller?.value.previewSize;
    if (size == null) return 3 / 4;
    return size.height / size.width; // portrait width / height
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || _phase != _Phase.live) return;
    setState(() => _phase = _Phase.capturing);
    HapticFeedback.mediumImpact();
    final hint = _quad;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
      final shot = await c.takePicture();
      if (_torch) await c.setFlashMode(FlashMode.off);
      final dir = await getTemporaryDirectory();
      final out = '${dir.path}/page_${const Uuid().v4()}.jpg';
      final cropped = await PageProcessor.process(shot.path, out,
          hint: hint, hintAspect: _previewAspect);
      unawaited(File(shot.path).delete().catchError((_) => File(shot.path)));
      if (!mounted) return;
      setState(() {
        _pending = out;
        _pendingCropped = cropped;
        _phase = _Phase.review;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      await _resumeLive();
    }
  }

  // ---------------------------------------------------------------- review

  Future<void> _retake() async {
    final p = _pending;
    _pending = null;
    if (p != null) unawaited(File(p).delete().catchError((_) => File(p)));
    await _resumeLive();
  }

  Future<void> _keepAndContinue() async {
    _pages.add(_pending!);
    _pending = null;
    await _resumeLive();
  }

  void _keepAndFinish() {
    if (_pending != null) _pages.add(_pending!);
    _pending = null;
    Navigator.of(context).pop(List<String>.from(_pages));
  }

  void _finish() => Navigator.of(context).pop(List<String>.from(_pages));

  Future<void> _close() async {
    if (_pages.isEmpty) {
      Navigator.of(context).pop(const <String>[]);
      return;
    }
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Keep ${_pages.length} scanned '
            '${_pages.length == 1 ? 'page' : 'pages'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Discard')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Keep')),
        ],
      ),
    );
    if (!mounted || keep == null) return;
    Navigator.of(context).pop(keep ? List<String>.from(_pages) : <String>[]);
  }

  Future<void> _toggleTorch() async {
    final c = _controller;
    if (c == null) return;
    _torch = !_torch;
    try {
      await c.setFlashMode(_torch ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      _torch = false;
    }
    setState(() {});
  }

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _phase == _Phase.review ? _retake() : _close();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: switch (_phase) {
            _Phase.review => _buildReview(),
            _Phase.error => _buildError(),
            _ => _buildCamera(),
          },
        ),
      ),
    );
  }

  Widget _buildCamera() {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final progress = (_steady / _steadyFramesNeeded).clamp(0.0, 1.0);
    final hint = switch ((_phase, _quad)) {
      (_Phase.capturing, _) => 'Capturing…',
      (_, null) => 'Point the camera at a document',
      _ when !_auto => 'Page found. Tap the shutter',
      _ => 'Hold steady…',
    };

    return SafeArea(
      child: Column(
        children: [
          _TopBar(
            pageCount: _pages.length,
            auto: _auto,
            torch: _torch,
            onClose: _close,
            onToggleAuto: () => setState(() => _auto = !_auto),
            onToggleTorch: _toggleTorch,
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (ready)
                  ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: c.value.previewSize!.height,
                        height: c.value.previewSize!.width,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(c),
                            CustomPaint(
                              painter: _QuadPainter(
                                quad: _quad,
                                progress: _auto ? progress : 1,
                                capturing: _phase == _Phase.capturing,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const Center(
                      child: CircularProgressIndicator(color: ArmColors.gold)),
                if (_phase == _Phase.capturing)
                  const ColoredBox(color: Color(0x55000000)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: ArmSpacing.md,
                  child: Center(child: _HintPill(text: hint)),
                ),
              ],
            ),
          ),
          _BottomBar(
            lastPage: _pages.isEmpty ? null : _pages.last,
            pageCount: _pages.length,
            busy: _phase != _Phase.live,
            onShutter: _capture,
            onDone: _pages.isEmpty ? null : _finish,
          ),
        ],
      ),
    );
  }

  Widget _buildReview() {
    final theme = Theme.of(context);
    final n = _pages.length + 1;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ArmSpacing.sm, ArmSpacing.sm, ArmSpacing.md, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Retake',
                  onPressed: _retake,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                const SizedBox(width: ArmSpacing.xs),
                Text('Page $n',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (!_pendingCropped)
                  const _HintPill(text: 'No edges found. Full photo kept'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(ArmSpacing.md),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: ArmColors.gold, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x66000000), blurRadius: 24),
                    ],
                  ),
                  child: Image.file(File(_pending!),
                      fit: BoxFit.contain,
                      semanticLabel: 'Scanned page $n'),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ArmSpacing.md, 0, ArmSpacing.md, ArmSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retake,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: ArmColors.gray500),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: ArmSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _keepAndContinue,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Next page'),
                  ),
                ),
                const SizedBox(width: ArmSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _keepAndFinish,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ArmColors.black,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ArmSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: ArmColors.gold, size: 48),
            const SizedBox(height: ArmSpacing.md),
            Text(_error ?? 'Camera unavailable',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: ArmSpacing.lg),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(const <String>[]),
                child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pageCount,
    required this.auto,
    required this.torch,
    required this.onClose,
    required this.onToggleAuto,
    required this.onToggleTorch,
  });

  final int pageCount;
  final bool auto;
  final bool torch;
  final VoidCallback onClose;
  final VoidCallback onToggleAuto;
  final VoidCallback onToggleTorch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ArmSpacing.sm, vertical: ArmSpacing.xs),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close scanner',
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const Spacer(),
          IconButton(
            tooltip: torch ? 'Turn light off' : 'Turn light on',
            onPressed: onToggleTorch,
            icon: Icon(torch ? Icons.flash_on : Icons.flash_off,
                color: torch ? ArmColors.gold : Colors.white),
          ),
          const SizedBox(width: ArmSpacing.xs),
          Semantics(
            button: true,
            toggled: auto,
            label: 'Auto capture',
            child: GestureDetector(
              onTap: onToggleAuto,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: auto ? ArmColors.gold : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(auto ? 'AUTO' : 'MANUAL',
                    style: TextStyle(
                        color: auto ? ArmColors.black : Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: ArmSpacing.sm),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.lastPage,
    required this.pageCount,
    required this.busy,
    required this.onShutter,
    required this.onDone,
  });

  final String? lastPage;
  final int pageCount;
  final bool busy;
  final VoidCallback onShutter;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ArmSpacing.lg, ArmSpacing.md, ArmSpacing.lg, ArmSpacing.lg),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: lastPage == null
                ? null
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(File(lastPage!),
                                fit: BoxFit.cover, cacheWidth: 160),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -8,
                        top: -8,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: ArmColors.gold,
                          child: Text('$pageCount',
                              style: const TextStyle(
                                  color: ArmColors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Capture page',
            child: GestureDetector(
              onTap: busy ? null : onShutter,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ArmColors.gold, width: 5),
                ),
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: busy ? ArmColors.gray500 : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 64,
            child: TextButton(
              onPressed: onDone,
              style: TextButton.styleFrom(
                foregroundColor: ArmColors.gold,
                disabledForegroundColor: const Color(0x55FFFFFF),
                minimumSize: const Size(64, 48),
                padding: EdgeInsets.zero,
              ),
              child: const Text('Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintPill extends StatelessWidget {
  const _HintPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC111111),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}

/// Draws the detected page outline. It turns from white to gold as the
/// page holds steady, so the user can see auto-capture coming.
class _QuadPainter extends CustomPainter {
  _QuadPainter({
    required this.quad,
    required this.progress,
    required this.capturing,
  });

  final Quad? quad;
  final double progress;
  final bool capturing;

  @override
  void paint(Canvas canvas, Size size) {
    final q = quad;
    if (q == null) return;
    final path = Path()
      ..addPolygon(
          [for (final p in q.points) Offset(p.dx * size.width, p.dy * size.height)],
          true);
    final color = Color.lerp(Colors.white, ArmColors.gold, progress)!;
    canvas.drawPath(
        path,
        Paint()
          ..color = ArmColors.gold.withValues(alpha: capturing ? 0.35 : 0.18));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.008
          ..strokeJoin = StrokeJoin.round);
    final r = size.shortestSide * 0.018;
    for (final p in q.points) {
      canvas.drawCircle(
          Offset(p.dx * size.width, p.dy * size.height), r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_QuadPainter old) =>
      old.quad != quad || old.progress != progress || old.capturing != capturing;
}
