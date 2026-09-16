import 'dart:math' as math;
import 'dart:ui';

/// 屏幕视口区域 (Canvas)
class VideoCanvasRect {
  final double width;
  final double height;

  const VideoCanvasRect({required this.width, required this.height});

  double get left => 0.0;
  double get top => 0.0;
  double get right => width;
  double get bottom => height;
  Offset get center => Offset(width / 2.0, height / 2.0);
  double get aspectRatio => height > 0 ? (width / height) : (16.0 / 9.0);
}

/// 当前视频画面虚拟无畸变外接矩形 (View)
class VideoViewRect {
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double width;
  final double height;
  final Offset center;

  const VideoViewRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.width,
    required this.height,
    required this.center,
  });

  /// 直接从 Canvas、View 宽高以及平移 Offset 构造
  factory VideoViewRect.fromSizeAndOffset({
    required VideoCanvasRect canvas,
    required double viewWidth,
    required double viewHeight,
    Offset offset = Offset.zero,
  }) {
    final Offset cv = Offset(
      canvas.center.dx + offset.dx,
      canvas.center.dy + offset.dy,
    );
    return VideoViewRect(
      left: cv.dx - viewWidth / 2.0,
      top: cv.dy - viewHeight / 2.0,
      right: cv.dx + viewWidth / 2.0,
      bottom: cv.dy + viewHeight / 2.0,
      width: viewWidth,
      height: viewHeight,
      center: cv,
    );
  }

  /// 从 Canvas、缩放中心 FocalPoint、当前缩放倍数 scale 构造偏心缩放的 View
  /// 保证屏幕上处于 focalPoint 下的原片画面像素在缩放过程中绝对固定
  factory VideoViewRect.fromFocalPointZoom({
    required VideoCanvasRect canvas,
    required Offset focalPoint,
    required double scale,
    required double videoAspectRatio,
    double initialScale = 1.0,
    Offset initialOffset = Offset.zero,
  }) {
    final double w0;
    final double h0;
    if (canvas.aspectRatio >= videoAspectRatio) {
      h0 = canvas.height;
      w0 = canvas.height * videoAspectRatio;
    } else {
      w0 = canvas.width;
      h0 = canvas.width / videoAspectRatio;
    }

    final double wv = w0 * scale;
    final double hv = h0 * scale;

    final Offset cViewOld = Offset(
      canvas.center.dx + initialOffset.dx,
      canvas.center.dy + initialOffset.dy,
    );
    final double scaleRatio = scale / initialScale;
    final Offset cViewNew = Offset(
      focalPoint.dx - (focalPoint.dx - cViewOld.dx) * scaleRatio,
      focalPoint.dy - (focalPoint.dy - cViewOld.dy) * scaleRatio,
    );

    return VideoViewRect(
      left: cViewNew.dx - wv / 2.0,
      top: cViewNew.dy - hv / 2.0,
      right: cViewNew.dx + wv / 2.0,
      bottom: cViewNew.dy + hv / 2.0,
      width: wv,
      height: hv,
      center: cViewNew,
    );
  }

  /// 对当前 View 进行平移操作，返回平移后的新 ViewRect
  VideoViewRect translate(Offset delta) {
    final Offset newCenter =
        Offset(center.dx + delta.dx, center.dy + delta.dy);
    return VideoViewRect(
      left: left + delta.dx,
      top: top + delta.dy,
      right: right + delta.dx,
      bottom: bottom + delta.dy,
      width: width,
      height: height,
      center: newCenter,
    );
  }

  /// 获取当前 View 中心相对于 Canvas 中心的位移偏移
  Offset getOffset(VideoCanvasRect canvas) => Offset(
        center.dx - canvas.center.dx,
        center.dy - canvas.center.dy,
      );

  /// 从 Canvas、当前缩放倍数 scale、位移 offset、视频原生宽高比 videoAspectRatio 构造
  factory VideoViewRect.fromTransform({
    required VideoCanvasRect canvas,
    required double scale,
    required Offset offset,
    required double videoAspectRatio,
  }) {
    // 初始 BoxFit.contain 尺寸
    final double w0;
    final double h0;
    if (canvas.aspectRatio >= videoAspectRatio) {
      h0 = canvas.height;
      w0 = canvas.height * videoAspectRatio;
    } else {
      w0 = canvas.width;
      h0 = canvas.width / videoAspectRatio;
    }

    return VideoViewRect.fromSizeAndOffset(
      canvas: canvas,
      viewWidth: w0 * scale,
      viewHeight: h0 * scale,
      offset: offset,
    );
  }

  /// 计算 View 相对于 Canvas 的 4 边界溢出压缩因子 (left, right, top, bottom)
  (double, double, double, double) calculateOverflowFactors(
      VideoCanvasRect canvas) {
    // 1. 左边界判定：View.left 是否突破 Canvas.left (0)
    final double overflowLeft;
    if (left >= canvas.left) {
      // 在 Canvas 内部（包含黑边），无溢出，零畸变
      overflowLeft = 1.0;
    } else {
      // 突破左边界：View 中心到 View 左边缘距离除以 View 中心到 Canvas 可视左边缘距离
      final double distViewLeft = width / 2.0;
      final double distCanvasLeft = math.max(center.dx - canvas.left, 1.0);
      overflowLeft = distViewLeft / distCanvasLeft;
    }

    // 2. 右边界判定：View.right 是否突破 Canvas.right (canvas.width)
    final double overflowRight;
    if (right <= canvas.right) {
      // 在 Canvas 内部，无溢出，零畸变
      overflowRight = 1.0;
    } else {
      // 突破右边界
      final double distViewRight = width / 2.0;
      final double distCanvasRight = math.max(canvas.right - center.dx, 1.0);
      overflowRight = distViewRight / distCanvasRight;
    }

    // 3. 上边界判定：View.top 是否突破 Canvas.top (0)
    final double overflowTop;
    if (top >= canvas.top) {
      overflowTop = 1.0;
    } else {
      final double distViewTop = height / 2.0;
      final double distCanvasTop = math.max(center.dy - canvas.top, 1.0);
      overflowTop = distViewTop / distCanvasTop;
    }

    // 4. 下边界判定：View.bottom 是否突破 Canvas.bottom (canvas.height)
    final double overflowBottom;
    if (bottom <= canvas.bottom) {
      overflowBottom = 1.0;
    } else {
      final double distViewBottom = height / 2.0;
      final double distCanvasBottom = math.max(canvas.bottom - center.dy, 1.0);
      overflowBottom = distViewBottom / distCanvasBottom;
    }

    return (
      overflowLeft > 1.0 ? overflowLeft : 1.0,
      overflowRight > 1.0 ? overflowRight : 1.0,
      overflowTop > 1.0 ? overflowTop : 1.0,
      overflowBottom > 1.0 ? overflowBottom : 1.0,
    );
  }
}
