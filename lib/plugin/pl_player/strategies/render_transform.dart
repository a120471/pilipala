import 'dart:ui';

import 'geometry.dart';

/// UI 渲染层视口变换计算结果
/// 将无畸变 ViewRect 适配并投影到物理屏幕 Canvas 视口中，
/// 保证非线性压缩模式下画面有效像素绝不超出物理视口（杜绝 ClipRect 物理硬截断）
class VideoRenderTransform {
  final double scaleX;
  final double scaleY;
  final Offset offset;
  final Rect screenRect;

  const VideoRenderTransform({
    required this.scaleX,
    required this.scaleY,
    required this.offset,
    required this.screenRect,
  });

  /// 计算屏幕渲染层的变换矩阵参数与安全矩形
  ///
  /// 非线性模式下的核心设计原则：
  /// Flutter Transform 的 scaleX/scaleY 分别被限制在各轴的"填充缩放倍率"（fillScale）内。
  /// fillScale = 屏幕尺寸 / 视频初始尺寸，即黑边恰好消失的缩放倍率。
  ///
  /// 当 rawScale <= fillScale 时：该轴视频仍在黑边区间内，Flutter 直接等比放大，着色器无需处理。
  /// 当 rawScale > fillScale 时：Flutter 放大到 fillScale（刚好填满），超出部分由 GLSL
  /// 着色器以非线性边缘压缩方式收纳进视口。着色器的溢出因子 = rawScale / fillScale。
  ///
  /// 组合效果：Flutter fillScale × 着色器 (rawScale / fillScale) = rawScale（各向同性）。
  /// 画面中心区域保持严格 1:1 等比放大，边缘像素零丢失（ClipRect 不会裁切视频内容）。
  factory VideoRenderTransform.calculate({
    required VideoCanvasRect canvas,
    required VideoViewRect view,
    required double videoAspectRatio,
    required bool isNonLinear,
    required double rawScale,
    required Offset rawOffset,
  }) {
    if (!isNonLinear) {
      // 线性模式：各向同性等比缩放，超出部分由 ClipRect 自然裁切
      return VideoRenderTransform(
        scaleX: rawScale,
        scaleY: rawScale,
        offset: rawOffset,
        screenRect: Rect.fromCenter(
          center: Offset(
            canvas.center.dx + rawOffset.dx,
            canvas.center.dy + rawOffset.dy,
          ),
          width: view.width,
          height: view.height,
        ),
      );
    }

    // ===== 非线性模式：Flutter Transform 各轴独立限制，着色器补全剩余缩放 =====

    // 1. 计算视频在容器中的初始适配尺寸（BoxFit.contain 基底）
    final double containerAR = canvas.width / canvas.height;
    double baseVideoWidth, baseVideoHeight;
    if (containerAR > videoAspectRatio) {
      // 容器比视频更宽 → 左右留黑边（Letterbox）
      baseVideoHeight = canvas.height;
      baseVideoWidth = canvas.height * videoAspectRatio;
    } else {
      // 容器比视频更高 → 上下留黑边（Pillarbox）
      baseVideoWidth = canvas.width;
      baseVideoHeight = canvas.width / videoAspectRatio;
    }

    // 2. 各轴的"填充缩放倍率"：该轴黑边恰好消失的缩放值
    final double fillScaleX = canvas.width / baseVideoWidth;
    final double fillScaleY = canvas.height / baseVideoHeight;

    // 3. Flutter Transform 的各轴缩放：限制在 [1.0, fillScale] 区间
    //    保证 Flutter 组件永不超出容器边界 → ClipRect 不裁切任何视频内容
    final double flutterScaleX = rawScale.clamp(1.0, fillScaleX);
    final double flutterScaleY = rawScale.clamp(1.0, fillScaleY);

    // 4. 安全包围盒（供着色器计算偏心锚点 uCenter/vCenter）
    final double leftScreen = view.left.clamp(canvas.left, canvas.right);
    final double rightScreen = view.right.clamp(canvas.left, canvas.right);
    final double topScreen = view.top.clamp(canvas.top, canvas.bottom);
    final double bottomScreen = view.bottom.clamp(canvas.top, canvas.bottom);

    return VideoRenderTransform(
      scaleX: flutterScaleX,
      scaleY: flutterScaleY,
      offset: rawOffset,
      screenRect: Rect.fromLTRB(
          leftScreen, topScreen, rightScreen, bottomScreen),
    );
  }
}
