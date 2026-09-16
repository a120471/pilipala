import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/plugin/pl_player/strategies/video_scale_strategy.dart';

void main() {
  group('VideoRenderTransform Per-Axis Fill-Capped Scaling Tests', () {
    const canvas209 = VideoCanvasRect(width: 2400, height: 1080);
    const aspect169 = 16.0 / 9.0;

    // 对于 20:9 屏幕 (2400x1080) 播放 16:9 视频 (1920x1080):
    //   baseVideoWidth = 1080 * 16/9 = 1920
    //   baseVideoHeight = 1080
    //   fillScaleX = 2400 / 1920 = 1.25 (需要放大到 1.25 倍才能填满横向黑边)
    //   fillScaleY = 1080 / 1080 = 1.0  (初始已填满纵向)
    const fillScaleX209 = 1.25;
    const fillScaleY209 = 1.0;

    test('Case 1: 1.1x centered zoom — X fills black bar, Y capped at fill', () {
      const scale = 1.1;
      const rawOffset = Offset.zero;

      final view = VideoViewRect.fromTransform(
        canvas: canvas209,
        scale: scale,
        offset: rawOffset,
        videoAspectRatio: aspect169,
      );

      final rt = VideoRenderTransform.calculate(
        canvas: canvas209,
        view: view,
        videoAspectRatio: aspect169,
        isNonLinear: true,
        rawScale: scale,
        rawOffset: rawOffset,
      );

      // Flutter scaleX = min(1.1, 1.25) = 1.1 (仍在黑边区间，等比放大)
      expect(rt.scaleX, scale);
      // Flutter scaleY = min(1.1, 1.0) = 1.0 (已填满，着色器负责 Y 轴缩放)
      expect(rt.scaleY, fillScaleY209);

      // offset 保持原值
      expect(rt.offset, rawOffset);

      // screenRect 在 canvas 内
      expect(rt.screenRect.left, greaterThanOrEqualTo(0.0));
      expect(rt.screenRect.right, lessThanOrEqualTo(2400.0));
      expect(rt.screenRect.top, greaterThanOrEqualTo(0.0));
      expect(rt.screenRect.bottom, lessThanOrEqualTo(1080.0));
    });

    test('Case 2: 1.1x eccentric zoom with dy=-60 — Flutter widget stays in bounds', () {
      const scale = 1.1;
      const rawOffset = Offset(0.0, -60.0);

      final view = VideoViewRect.fromTransform(
        canvas: canvas209,
        scale: scale,
        offset: rawOffset,
        videoAspectRatio: aspect169,
      );

      final rt = VideoRenderTransform.calculate(
        canvas: canvas209,
        view: view,
        videoAspectRatio: aspect169,
        isNonLinear: true,
        rawScale: scale,
        rawOffset: rawOffset,
      );

      // X: min(1.1, 1.25) = 1.1
      expect(rt.scaleX, scale);
      // Y: min(1.1, 1.0) = 1.0 — 着色器处理纵向缩放与边缘压缩
      expect(rt.scaleY, fillScaleY209);
      expect(rt.offset, rawOffset);

      // screenRect top 被 clamp 到 0 (view.top < 0)
      expect(rt.screenRect.top, 0.0);
    });

    test('Case 3: 1.25x zoom (critical fill point) — X exactly fills, Y capped', () {
      const scale = 1.25;
      const rawOffset = Offset.zero;

      final view = VideoViewRect.fromTransform(
        canvas: canvas209,
        scale: scale,
        offset: rawOffset,
        videoAspectRatio: aspect169,
      );

      final rt = VideoRenderTransform.calculate(
        canvas: canvas209,
        view: view,
        videoAspectRatio: aspect169,
        isNonLinear: true,
        rawScale: scale,
        rawOffset: rawOffset,
      );

      // X: min(1.25, 1.25) = 1.25 (恰好填满横向黑边)
      expect(rt.scaleX, fillScaleX209);
      // Y: min(1.25, 1.0) = 1.0
      expect(rt.scaleY, fillScaleY209);
    });

    test('Case 4: 1.35x zoom — X capped at fillScale, Y capped at fillScale', () {
      const scale = 1.35;
      const rawOffset = Offset.zero;

      final view = VideoViewRect.fromTransform(
        canvas: canvas209,
        scale: scale,
        offset: rawOffset,
        videoAspectRatio: aspect169,
      );

      final rt = VideoRenderTransform.calculate(
        canvas: canvas209,
        view: view,
        videoAspectRatio: aspect169,
        isNonLinear: true,
        rawScale: scale,
        rawOffset: rawOffset,
      );

      // X: min(1.35, 1.25) = 1.25 (超过填充，着色器补全剩余 1.35/1.25=1.08 倍)
      expect(rt.scaleX, fillScaleX209);
      // Y: min(1.35, 1.0) = 1.0
      expect(rt.scaleY, fillScaleY209);
    });

    test('Case 5: 1.25x with Pan Right dx=+150 — X capped, offset preserved', () {
      const rawOffset = Offset(150.0, 0.0);
      const scale = 1.25;

      final view = VideoViewRect.fromTransform(
        canvas: canvas209,
        scale: scale,
        offset: rawOffset,
        videoAspectRatio: aspect169,
      );

      final rt = VideoRenderTransform.calculate(
        canvas: canvas209,
        view: view,
        videoAspectRatio: aspect169,
        isNonLinear: true,
        rawScale: scale,
        rawOffset: rawOffset,
      );

      expect(rt.scaleX, fillScaleX209);
      expect(rt.scaleY, fillScaleY209);
      expect(rt.offset, rawOffset);

      // screenRect 不超出 canvas
      expect(rt.screenRect.left, 150.0);
      expect(rt.screenRect.right, 2400.0);
      expect(rt.screenRect.top, 0.0);
      expect(rt.screenRect.bottom, 1080.0);
    });

    test('Case 6: Linear mode passes through rawScale isotropically', () {
      const rawOffset = Offset(80.0, -50.0);
      const scale = 1.3;

      final view = VideoViewRect.fromTransform(
        canvas: canvas209,
        scale: scale,
        offset: rawOffset,
        videoAspectRatio: aspect169,
      );

      final rt = VideoRenderTransform.calculate(
        canvas: canvas209,
        view: view,
        videoAspectRatio: aspect169,
        isNonLinear: false, // 线性模式
        rawScale: scale,
        rawOffset: rawOffset,
      );

      // 线性模式始终各向同性透传
      expect(rt.scaleX, scale);
      expect(rt.scaleY, scale);
      expect(rt.offset, rawOffset);
    });

    test('Case 7: Comprehensive per-axis scale capping from 1.05x to 1.5x', () {
      const testScales = [1.05, 1.1, 1.15, 1.2, 1.25, 1.35, 1.5];

      for (final s in testScales) {
        final view = VideoViewRect.fromTransform(
          canvas: canvas209,
          scale: s,
          offset: Offset.zero,
          videoAspectRatio: aspect169,
        );

        final rt = VideoRenderTransform.calculate(
          canvas: canvas209,
          view: view,
          videoAspectRatio: aspect169,
          isNonLinear: true,
          rawScale: s,
          rawOffset: Offset.zero,
        );

        // X 轴: min(s, 1.25)
        final expectedScaleX = s.clamp(1.0, fillScaleX209);
        expect(rt.scaleX, expectedScaleX,
            reason: 'scaleX at zoom $s should be min($s, $fillScaleX209) = $expectedScaleX');

        // Y 轴: min(s, 1.0)
        final expectedScaleY = s.clamp(1.0, fillScaleY209);
        expect(rt.scaleY, expectedScaleY,
            reason: 'scaleY at zoom $s should be min($s, $fillScaleY209) = $expectedScaleY');

        // 组合验证：Flutter * 着色器 = rawScale（等效各向同性）
        // 着色器溢出因子 = rawScale / flutterScale
        final shaderScaleX = s / rt.scaleX;
        final shaderScaleY = s / rt.scaleY;
        // 最终画面中心缩放: flutterScale * shaderScale = rawScale
        expect(rt.scaleX * shaderScaleX, closeTo(s, 0.001),
            reason: 'Combined X zoom at $s must equal rawScale');
        expect(rt.scaleY * shaderScaleY, closeTo(s, 0.001),
            reason: 'Combined Y zoom at $s must equal rawScale');

        // screenRect 在 canvas 内
        expect(rt.screenRect.left >= canvas209.left, isTrue);
        expect(rt.screenRect.right <= canvas209.right, isTrue);
        expect(rt.screenRect.top >= canvas209.top, isTrue);
        expect(rt.screenRect.bottom <= canvas209.bottom, isTrue);
      }
    });

    test('Case 8: Overflow factor equivalence — geometric == rawScale/fillScale', () {
      // 验证几何溢出因子计算与 rawScale/fillScale 公式一致
      const scale = 1.35;

      final view = VideoViewRect.fromTransform(
        canvas: canvas209,
        scale: scale,
        offset: Offset.zero,
        videoAspectRatio: aspect169,
      );

      final (sLeft, sRight, sTop, sBottom) = view.calculateOverflowFactors(canvas209);

      // 中心对称缩放时: overflow = rawScale / fillScale (每侧相等)
      // X 轴: 1.35 / 1.25 = 1.08
      expect(sLeft, closeTo(scale / fillScaleX209, 0.01),
          reason: 'sLeft should match rawScale/fillScaleX');
      expect(sRight, closeTo(scale / fillScaleX209, 0.01),
          reason: 'sRight should match rawScale/fillScaleX');
      // Y 轴: 1.35 / 1.0 = 1.35
      expect(sTop, closeTo(scale / fillScaleY209, 0.01),
          reason: 'sTop should match rawScale/fillScaleY');
      expect(sBottom, closeTo(scale / fillScaleY209, 0.01),
          reason: 'sBottom should match rawScale/fillScaleY');
    });

    test('Case 9: Portrait screen (9:20) — pillarboxed, X capped at 1.0, Y fills', () {
      // 竖屏 1080x2400, 播放 16:9 视频:
      //   baseVideoWidth = 1080 (fills width)
      //   baseVideoHeight = 1080 / (16/9) = 607.5
      //   fillScaleX = 1080/1080 = 1.0 (已填满)
      //   fillScaleY = 2400/607.5 ≈ 3.951
      const portraitCanvas = VideoCanvasRect(width: 1080, height: 2400);
      const scale = 1.15;
      const offset = Offset(20.0, -40.0);

      final view = VideoViewRect.fromTransform(
        canvas: portraitCanvas,
        scale: scale,
        offset: offset,
        videoAspectRatio: aspect169,
      );

      final rt = VideoRenderTransform.calculate(
        canvas: portraitCanvas,
        view: view,
        videoAspectRatio: aspect169,
        isNonLinear: true,
        rawScale: scale,
        rawOffset: offset,
      );

      // fillScaleX = 1.0, fillScaleY ≈ 3.951
      // X: min(1.15, 1.0) = 1.0 (X 轴已填满，着色器处理剩余缩放)
      expect(rt.scaleX, 1.0);
      // Y: min(1.15, 3.951) = 1.15 (Y 轴仍有大量黑边，Flutter 直接放大)
      expect(rt.scaleY, scale);
      expect(rt.offset, offset);

      // screenRect 在 canvas 内
      expect(rt.screenRect.left, 0.0);
      expect(rt.screenRect.right, 1080.0);
    });

    test('Case 10: 16:9 screen with 16:9 video — fillScale = 1.0 for both axes', () {
      // 屏幕与视频比例一致: 1920x1080, 16:9
      const canvas169 = VideoCanvasRect(width: 1920, height: 1080);
      const scale = 1.2;

      final view = VideoViewRect.fromTransform(
        canvas: canvas169,
        scale: scale,
        offset: Offset.zero,
        videoAspectRatio: aspect169,
      );

      final rt = VideoRenderTransform.calculate(
        canvas: canvas169,
        view: view,
        videoAspectRatio: aspect169,
        isNonLinear: true,
        rawScale: scale,
        rawOffset: Offset.zero,
      );

      // fillScaleX = 1920/1920 = 1.0, fillScaleY = 1080/1080 = 1.0
      // 两轴都已填满: Flutter scale 锁定 (1.0, 1.0)
      // 着色器完全负责所有缩放与边缘压缩
      expect(rt.scaleX, 1.0);
      expect(rt.scaleY, 1.0);
    });

    test('Case 11: 4:3 video on 16:9 screen — different fill scales', () {
      // 4:3 视频 (aspect = 4/3 ≈ 1.333) 在 1920x1080 (16:9) 屏幕:
      //   baseVideoWidth = 1080 * 4/3 = 1440
      //   baseVideoHeight = 1080
      //   fillScaleX = 1920/1440 ≈ 1.333
      //   fillScaleY = 1080/1080 = 1.0
      const canvas169 = VideoCanvasRect(width: 1920, height: 1080);
      const aspect43 = 4.0 / 3.0;
      const scale = 1.2;

      final view = VideoViewRect.fromTransform(
        canvas: canvas169,
        scale: scale,
        offset: Offset.zero,
        videoAspectRatio: aspect43,
      );

      final rt = VideoRenderTransform.calculate(
        canvas: canvas169,
        view: view,
        videoAspectRatio: aspect43,
        isNonLinear: true,
        rawScale: scale,
        rawOffset: Offset.zero,
      );

      // X: min(1.2, 1.333) = 1.2 (仍在黑边区间)
      expect(rt.scaleX, scale);
      // Y: min(1.2, 1.0) = 1.0 (着色器负责)
      expect(rt.scaleY, 1.0);
    });
  });
}
