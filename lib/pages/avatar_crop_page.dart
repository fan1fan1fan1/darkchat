import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 头像裁剪页：单指拖动 / 双指缩放 / 圆形裁剪框，确定后返回 base64
class AvatarCropPage extends StatefulWidget {
  final String imagePath;
  const AvatarCropPage({super.key, required this.imagePath});

  /// 返回裁剪后的 base64（PNG），取消返回 null
  static Future<String?> push(BuildContext context, String imagePath) =>
      Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AvatarCropPage(imagePath: imagePath)));

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  static const double _crop = 280; // 裁剪框直径（逻辑像素）
  static const int _out = 256; // 输出尺寸

  ui.Image? _img;
  double _scale = 1;
  double _minScale = 1;
  Offset _offset = Offset.zero; // 图片左上角在画布坐标系中的位置
  bool _saving = false;

  Size get _canvas {
    // 画布大小：取屏幕与裁剪框中较大者，保证拖动余量
    final s = MediaQuery.of(context).size;
    return Size(math.max(s.width, _crop), math.max(s.height, _crop));
  }

  Offset get _center => Offset(_canvas.width / 2, _canvas.height / 2);

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec =
        await ui.instantiateImageCodec(bytes, targetWidth: 1024); // 限制解码尺寸
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    final img = frame.image;
    final c = _canvas;
    // cover：短边盖住裁剪框
    final base = _crop / math.min(img.width, img.height);
    _minScale = base;
    _scale = base;
    _offset = _center - Offset(img.width * base, img.height * base) / 2;
    setState(() => _img = img);
  }

  void _clamp() {
    final c = _canvas;
    final dw = (_img?.width ?? 1) * _scale;
    final dh = (_img?.height ?? 1) * _scale;
    final r = _crop / 2;
    // 图片必须始终覆盖圆形裁剪框
    double x = _offset.dx, y = _offset.dy;
    if (x > _center.dx - r) x = _center.dx - r;
    if (y > _center.dy - r) y = _center.dy - r;
    if (x + dw < _center.dx + r) x = _center.dx + r - dw;
    if (y + dh < _center.dy + r) y = _center.dy + r - dh;
    _offset = Offset(x, y);
  }

  void _onScale(ScaleUpdateDetails d) {
    final old = _scale;
    _scale = (_scale * d.scale).clamp(_minScale, _minScale * 6);
    // 以双指中心为缩放锚点
    if (d.scale != 1 && d.focalPoint != Offset.zero) {
      _offset = _offset - (d.focalPoint - _center) * (_scale / old - 1);
    }
    _offset += d.focalPointDelta;
    _clamp();
    setState(() {});
  }

  Future<void> _confirm() async {
    if (_img == null || _saving) return;
    setState(() => _saving = true);
    try {
      final c = _canvas;
      final r = _crop / 2;
      // 屏幕圆框 → 原图坐标
      final srcLeft = (_center.dx - r - _offset.dx) / _scale;
      final srcTop = (_center.dy - r - _offset.dy) / _scale;
      final srcSize = _crop / _scale;
      final rec = ui.PictureRecorder();
      Canvas(rec)
        ..drawImageRect(
            _img!,
            Rect.fromLTWH(srcLeft, srcTop, srcSize, srcSize),
            Rect.fromLTWH(0, 0, _out.toDouble(), _out.toDouble()),
            Paint()..filterQuality = FilterQuality.high);
      final pic = rec.endRecording();
      final out = await pic.toImage(_out, _out);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.of(context).pop(base64Encode(data!.buffer.asUint8List()));
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, '裁剪失败，请重试', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _canvas;
    return Scaffold(
      backgroundColor: Colors.black,
      body: _img == null
          ? const Center(
              child: CircularProgressIndicator(color: kAccent, strokeWidth: 2))
          : GestureDetector(
              onScaleUpdate: _onScale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: _offset.dx,
                    top: _offset.dy,
                    width: _img!.width * _scale,
                    height: _img!.height * _scale,
                    child: RawImage(
                      image: _img,
                      fit: BoxFit.fill,
                      width: _img!.width * _scale,
                      height: _img!.height * _scale,
                    ),
                  ),
                  // 圆形镂空遮罩 + 边框
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CropMask(
                          center: _center, radius: _crop / 2, canvasSize: c),
                    ),
                  ),
                  // 顶部标题 / 底部按钮浮层（点击穿透手势给图片）
                  Align(
                    alignment: Alignment.topCenter,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('移 动 · 缩 放',
                            style: TextStyle(
                                color: kTextSub.withOpacity(0.8),
                                fontSize: 12,
                                letterSpacing: 3)),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed:
                                  _saving ? null : () => Navigator.pop(context),
                              child: const Text('取消',
                                  style:
                                      TextStyle(color: kTextSub, fontSize: 15)),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kAccent.withOpacity(0.15),
                                border: Border.all(color: kAccentDim),
                              ),
                              child: _saving
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              color: kAccent, strokeWidth: 2)),
                                    )
                                  : IconButton(
                                      onPressed: _confirm,
                                      icon: const Icon(Icons.check,
                                          color: kAccent, size: 26),
                                    ),
                            ),
                            TextButton(
                              onPressed: _saving ? null : _confirm,
                              child: const Text('确定',
                                  style:
                                      TextStyle(color: kAccent, fontSize: 15)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// 半透明遮罩挖出圆形孔 + 白紫描边
class _CropMask extends CustomPainter {
  final Offset center;
  final double radius;
  final Size canvasSize;
  _CropMask(
      {required this.center, required this.radius, required this.canvasSize});

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final mask = Path()
      ..addRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(Path.combine(PathOperation.difference, mask, hole),
        Paint()..color = Colors.black.withOpacity(0.62));
    canvas.drawOval(
        Rect.fromCircle(center: center, radius: radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF8B5CF6).withOpacity(0.9));
    // 十字辅助线
    final p = Paint()
      ..strokeWidth = 0.6
      ..color = Colors.white.withOpacity(0.18);
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), p);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), p);
  }

  @override
  bool shouldRepaint(covariant _CropMask old) =>
      old.center != center || old.radius != radius;
}
