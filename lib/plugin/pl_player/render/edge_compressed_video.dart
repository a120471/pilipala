import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../strategies/geometry.dart';

/// 视频非线性边缘压缩渲染器（方案 B）。
///
/// 在 Flutter 管线内完成「等比放大 + 中心 1:1 保真 + 边缘非线性压缩」：
/// 用 [RendererRepaintBoundary] 每帧捕获视频帧，交给 [video_edge_compress.frag]
/// 这一 FragmentShader 做坐标精确的非线性映射。相比「Flutter 二次缩放 + mpv 着色器」的
/// 双层方案，它：
///   - 同步渲染（无 mpv 重编译滞后），彻底消除缩放比例在线性/非线性间的跳变；
///   - 以屏幕视口为基准做压缩（mpv 着色器不知道视口在哪），消除顶边像素丢失。
class EdgeCompressedVideo extends StatefulWidget {
  const EdgeCompressedVideo({
    required this.video,
    required this.rawScale,
    required this.offset,
    required this.videoAspect,
    this.centerRatio = 0.6,
    super.key,
  });

  /// 底层视频组件（media_kit 的 [Video]，未做任何缩放，由本组件做二次渲染）。
  final Widget video;
  final double rawScale;
  final Offset offset;
  final double videoAspect;
  final double centerRatio;

  @override
  State<EdgeCompressedVideo> createState() => _EdgeCompressedVideoState();
}

class _EdgeCompressedVideoState extends State<EdgeCompressedVideo>
    with SingleTickerProviderStateMixin {
  final GlobalKey _captureKey = GlobalKey();

  ui.FragmentShader? _shader;
  ui.Image? _frame;

  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.rawScale > 1.001) {
      _ticker.start();
    }
    _loadShader();
  }

  @override
  void didUpdateWidget(covariant EdgeCompressedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rawScale > 1.001) {
      if (!_ticker.isTicking) {
        _ticker.start();
      }
    } else {
      if (_ticker.isTicking) {
        _ticker.stop();
      }
      if (_frame != null) {
        _frame?.dispose();
        _frame = null;
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame?.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'lib/plugin/pl_player/render/shaders/video_edge_compress.frag',
      );
      setState(() => _shader = program.fragmentShader());
    } catch (_) {
      // 着色器加载失败时退化为纯视频（不压缩），保证功能可用。
    }
  }

  /// 仅当处于压缩区间时捕获当前帧并触发重绘。手势高频期间通过 RawScale/Offset
  /// 观测值驱动，而非每帧全量重建，降低开销。
  void _onTick(Duration _) {
    if (_shader == null || widget.rawScale <= 1.001) return;
    final RenderObject? ro = _captureKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return;
    final ui.Image image = ro.toImageSync();
    // 延迟释放上一帧，避免其仍被当前 painter 引用时被释放；由 GC 兜底回收早先帧。
    final ui.Image? old = _frame;
    if (mounted) {
      setState(() {
        _frame = image;
        WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth > 0 ? constraints.maxWidth : 1920;
        final double h = constraints.maxHeight > 0 ? constraints.maxHeight : 1080;
        final double scale = widget.rawScale;
        final Offset offset = widget.offset;

        // 视频在画布中的 BoxFit.contain 基底尺寸
        final double containerAR = w / h;
        double baseW, baseH;
        if (containerAR > widget.videoAspect) {
          baseH = h;
          baseW = h * widget.videoAspect;
        } else {
          baseW = w;
          baseH = w / widget.videoAspect;
        }

        // 不需要压缩（初始 1.0x）：直接以 BoxFit.contain 显示底层视频。
        if (scale <= 1.001 || _shader == null) {
          return widget.video;
        }

        // 压缩参数：逐边溢出因子（复用已被单测验证的几何模型）
        final double fillScaleX = baseW > 0 ? w / baseW : 1.0;
        final double fillScaleY = baseH > 0 ? h / baseH : 1.0;
        final double uCenter = w > 0 ? (2.0 * offset.dx) / w : 0.0;
        final double vCenter = h > 0 ? (2.0 * offset.dy) / h : 0.0;
        final VideoCanvasRect canvas = VideoCanvasRect(width: w, height: h);
        final VideoViewRect view = VideoViewRect.fromTransform(
          canvas: canvas,
          scale: scale,
          offset: offset,
          videoAspectRatio: widget.videoAspect,
        );
        final (double sLeft, double sRight, double sTop, double sBottom) =
            view.calculateOverflowFactors(canvas);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 底层视频（供 RepaintBoundary 捕获），置于最底并被上层着色器完全覆盖
            Positioned(
              left: (w - baseW) / 2,
              top: (h - baseH) / 2,
              width: baseW,
              height: baseH,
              child: RepaintBoundary(
                key: _captureKey,
                child: SizedBox(width: baseW, height: baseH, child: widget.video),
              ),
            ),
            // 上层着色器输出：覆盖整个画布
            Positioned.fill(
              child: CustomPaint(
                painter: _EdgeCompressPainter(
                  shader: _shader!,
                  frame: _frame,
                  canvasSize: Size(w, h),
                  centerRatio: widget.centerRatio,
                  overflow: (sLeft, sRight, sTop, sBottom),
                  scale: scale,
                  fillScale: Offset(fillScaleX, fillScaleY),
                  center: Offset(uCenter, vCenter),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EdgeCompressPainter extends CustomPainter {
  _EdgeCompressPainter({
    required this.shader,
    required this.frame,
    required this.canvasSize,
    required this.centerRatio,
    required this.overflow,
    required this.scale,
    required this.fillScale,
    required this.center,
  });

  final ui.FragmentShader shader;
  final ui.Image? frame;
  final Size canvasSize;
  final double centerRatio;
  final (double, double, double, double) overflow;
  final double scale;
  final Offset fillScale;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? f = frame;
    if (f == null) return;
    shader
      ..setFloat(0, canvasSize.width)
      ..setFloat(1, canvasSize.height)
      ..setFloat(2, centerRatio)
      ..setFloat(3, overflow.$1)
      ..setFloat(4, overflow.$2)
      ..setFloat(5, overflow.$3)
      ..setFloat(6, overflow.$4)
      ..setFloat(7, fillScale.dx)
      ..setFloat(8, fillScale.dy)
      ..setFloat(9, scale)
      ..setFloat(10, center.dx)
      ..setFloat(11, center.dy)
      ..setImageSampler(0, f);
    canvas.drawRect(Offset.zero & canvasSize, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _EdgeCompressPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.canvasSize != canvasSize ||
        oldDelegate.centerRatio != centerRatio ||
        oldDelegate.overflow != overflow ||
        oldDelegate.scale != scale ||
        oldDelegate.fillScale != fillScale ||
        oldDelegate.center != center;
  }
}
