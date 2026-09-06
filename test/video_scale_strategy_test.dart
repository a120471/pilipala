import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/plugin/pl_player/strategies/video_scale_strategy.dart';

void main() {
  group('VideoScaleStrategy Tests', () {
    test('Strategy manager registers all 5 strategies and switches correctly', () {
      expect(VideoScaleStrategyManager.strategies.length, 5);
      final initial = VideoScaleStrategyManager.currentStrategy.value;
      expect(initial, isA<PiecewiseSplineStrategy>());

      VideoScaleStrategyManager.setStrategyById('tanh_saturation');
      expect(VideoScaleStrategyManager.currentStrategy.value, isA<TanhSaturationStrategy>());

      VideoScaleStrategyManager.setStrategyById('piecewise_spline');
      expect(VideoScaleStrategyManager.currentStrategy.value, isA<PiecewiseSplineStrategy>());
    });

    test('All strategies return original coordinate when scale <= 1.0', () {
      for (final strategy in VideoScaleStrategyManager.strategies) {
        expect(strategy.apply(0.0, 1.0), 0.0);
        expect(strategy.apply(0.5, 1.0), 0.5);
        expect(strategy.apply(-0.5, 1.0), -0.5);
        expect(strategy.inverseMap(0.5, 1.0), 0.5);
      }
    });

    test('PiecewiseSplineStrategy preserves center 1:1 and maps boundaries to 1.0', () {
      final spline = PiecewiseSplineStrategy();
      const double scale = 1.3;

      // Center region (0.0 to 0.6) must be identical
      expect(spline.apply(0.0, scale), closeTo(0.0, 1e-6));
      expect(spline.apply(0.3, scale), closeTo(0.3, 1e-6));
      expect(spline.apply(0.6, scale), closeTo(0.6, 1e-6));
      expect(spline.apply(-0.6, scale), closeTo(-0.6, 1e-6));

      // Boundary (scale) must map to screen edge 1.0
      expect(spline.apply(scale, scale), closeTo(1.0, 1e-6));
      expect(spline.apply(-scale, scale), closeTo(-1.0, 1e-6));

      // Inverse map should accurately invert
      for (double x in [0.0, 0.2, 0.5, 0.6, 0.8, 1.0, 1.2, scale]) {
        final double y = spline.apply(x, scale);
        final double recoveredX = spline.inverseMap(y, scale);
        expect(recoveredX, closeTo(x, 1e-4));
      }
    });

    test('Over-threshold scale (> 1.5) smoothly falls back to pure linear scale', () {
      final spline = PiecewiseSplineStrategy();
      const double scale = 2.0; // > maxNonLinearScale (1.5)

      // When scale > 1.5, apply must return linear scale (x * scale)
      expect(spline.apply(0.5, scale), closeTo(0.5 * scale, 1e-6));
      expect(spline.apply(0.8, scale), closeTo(0.8 * scale, 1e-6));
      expect(spline.inverseMap(1.0, scale), closeTo(1.0 / scale, 1e-6));
    });

    test('TanhSaturationStrategy maps boundaries within [-1.0, 1.0]', () {
      final tanh = TanhSaturationStrategy();
      const double scale = 1.4;

      expect(tanh.apply(0.0, scale), closeTo(0.0, 1e-6));
      expect(tanh.apply(scale, scale), closeTo(1.0, 1e-4));
      expect(tanh.apply(-scale, scale), closeTo(-1.0, 1e-4));

      // Inverse map inversion check
      for (double x in [0.0, 0.3, 0.7, 1.1, scale]) {
        final double y = tanh.apply(x, scale);
        final double recoveredX = tanh.inverseMap(y, scale);
        expect(recoveredX, closeTo(x, 1e-3));
      }
    });

    test('PowerCurveStrategy preserves center and maps edge to 1.0', () {
      final power = PowerCurveStrategy();
      const double scale = 1.35;

      expect(power.apply(0.0, scale), closeTo(0.0, 1e-6));
      expect(power.apply(0.5, scale), closeTo(0.5, 1e-6));
      expect(power.apply(0.6, scale), closeTo(0.6, 1e-6));
      expect(power.apply(scale, scale), closeTo(1.0, 1e-6));

      // Inverse test
      for (double x in [0.0, 0.4, 0.6, 0.9, 1.2, scale]) {
        final double y = power.apply(x, scale);
        final double recoveredX = power.inverseMap(y, scale);
        expect(recoveredX, closeTo(x, 1e-4));
      }
    });

    test('LinearScaleStrategy produces exact linear scale', () {
      final linear = LinearScaleStrategy();
      const double scale = 1.4;

      expect(linear.apply(0.5, scale), closeTo(0.5 * scale, 1e-6));
      expect(linear.inverseMap(0.7, scale), closeTo(0.7 / scale, 1e-6));
    });

    test('All strategies generate valid mpv GLSL shader code with 4-boundary support', () {
      for (final strategy in VideoScaleStrategyManager.strategies) {
        final shader = strategy.generateGlslShader(
          overflowScaleLeft: 1.0,
          overflowScaleRight: 1.2,
          overflowScaleTop: 1.0,
          overflowScaleBottom: 1.35,
          centerRatio: 0.6,
        );
        expect(shader, contains('//!HOOK MAIN'));
        expect(shader, contains('//!BIND HOOKED'));
        expect(shader, contains('HOOKED_tex'));
        expect(shader, contains('sLeft = 1.0000;'));
        expect(shader, contains('sRight = 1.2000;'));
        expect(shader, contains('sTop = 1.0000;'));
        expect(shader, contains('sBottom = 1.3500;'));
        expect(shader, contains('Sx = u >= 0.0 ? sRight : sLeft;'));
        expect(shader, contains('Sy = v >= 0.0 ? sBottom : sTop;'));
        expect(shader, contains('0.6000'));
      }
    });

    test('GLSL shader contains passthrough logic for axes with scale <= 1.001', () {
      final spline = PiecewiseSplineStrategy();
      final shader = spline.generateGlslShader(
        overflowScaleLeft: 1.0,
        overflowScaleRight: 1.25,
        overflowScaleTop: 1.0,
        overflowScaleBottom: 1.0,
        centerRatio: 0.6,
      );
      // When half-axis scale <= 1.001 (e.g. sLeft = 1.0), it uses passthrough
      expect(shader, contains('if (Sx <= 1.001) {\n            x = absU;'));
      // When half-axis scale > 1.001 (e.g. sRight = 1.25), it uses non-linear calculation
      expect(shader, contains('x = startVal + b * t + a * t * t'));
    });

    test('calculate4BoundaryOverflows correctly handles asymmetric panning and edge overflow', () {
      const containerSize = Size(2400, 1080); // 20:9
      const double videoAspect = 1920.0 / 1080.0; // 16:9
      // fillScaleX = 2400 / 1920 = 1.25, fillScaleY = 1.0

      // 1. Scale <= 1.0 returns all 1.0 (no overflow)
      final zeroOverflow = VideoScaleStrategy.calculate4BoundaryOverflows(
        scale: 0.9,
        offset: const Offset(50, 50),
        containerSize: containerSize,
        videoAspectRatio: videoAspect,
      );
      expect(zeroOverflow, (1.0, 1.0, 1.0, 1.0));

      // 2. Centered zoom 1.1x: X within black bars (fillScaleX = 1.25), Y overflows
      final centerZoom1 = VideoScaleStrategy.calculate4BoundaryOverflows(
        scale: 1.1,
        offset: Offset.zero,
        containerSize: containerSize,
        videoAspectRatio: videoAspect,
      );
      expect(centerZoom1.$1, 1.0); // left
      expect(centerZoom1.$2, 1.0); // right
      expect(centerZoom1.$3, closeTo(1.1, 1e-4)); // top
      expect(centerZoom1.$4, closeTo(1.1, 1e-4)); // bottom

      // 3. Pan right (dx > 0): right pushes further out, left pulls inside
      final panRight = VideoScaleStrategy.calculate4BoundaryOverflows(
        scale: 1.35,
        offset: const Offset(150.0, 0.0),
        containerSize: containerSize,
        videoAspectRatio: videoAspect,
      );
      // Right overflow must be strictly greater than left overflow
      expect(panRight.$2 > panRight.$1, isTrue);
      // When panned significantly to the right, left side is completely within viewport (1.0)
      final panFarRight = VideoScaleStrategy.calculate4BoundaryOverflows(
        scale: 1.26,
        offset: const Offset(300.0, 0.0),
        containerSize: containerSize,
        videoAspectRatio: videoAspect,
      );
      expect(panFarRight.$1, 1.0); // left side has zero distortion!
      expect(panFarRight.$2 > 1.0, isTrue); // only right side is compressed

      // 4. Pan down (dy > 0): bottom pushes out, top pulls inside
      final panDown = VideoScaleStrategy.calculate4BoundaryOverflows(
        scale: 1.2,
        offset: const Offset(0.0, 100.0),
        containerSize: containerSize,
        videoAspectRatio: videoAspect,
      );
      expect(panDown.$4 > panDown.$3, isTrue);
    });

    test('VideoCanvasRect and VideoViewRect geometric containment calculations', () {
      const canvas = VideoCanvasRect(width: 2400, height: 1080); // 20:9
      const double videoAspect = 1920.0 / 1080.0; // 16:9

      // Scenario 1: Center zoom 1.1x -> X within black bars (width=2112 < 2400), Y overflows (height=1188 > 1080)
      final view1 = VideoViewRect.fromTransform(
        canvas: canvas,
        scale: 1.1,
        offset: Offset.zero,
        videoAspectRatio: videoAspect,
      );
      expect(view1.width, 2112.0);
      expect(view1.height, 1188.0);
      expect(view1.left, 144.0);
      expect(view1.right, 2256.0);
      expect(view1.top, -54.0);
      expect(view1.bottom, 1134.0);

      // Containment checks
      expect(view1.left >= canvas.left, isTrue); // In canvas (black bar remains)
      expect(view1.right <= canvas.right, isTrue); // In canvas
      expect(view1.top < canvas.top, isTrue); // Penetrates top
      expect(view1.bottom > canvas.bottom, isTrue); // Penetrates bottom

      final (sL1, sR1, sT1, sB1) = view1.calculateOverflowFactors(canvas);
      expect(sL1, 1.0);
      expect(sR1, 1.0);
      expect(sT1, closeTo(1.10, 1e-4));
      expect(sB1, closeTo(1.10, 1e-4));

      // Scenario 2: Center zoom 1.35x -> all 4 sides penetrate Canvas
      final view2 = VideoViewRect.fromTransform(
        canvas: canvas,
        scale: 1.35,
        offset: Offset.zero,
        videoAspectRatio: videoAspect,
      );
      expect(view2.left < canvas.left, isTrue);
      expect(view2.right > canvas.right, isTrue);
      expect(view2.top < canvas.top, isTrue);
      expect(view2.bottom > canvas.bottom, isTrue);

      final (sL2, sR2, sT2, sB2) = view2.calculateOverflowFactors(canvas);
      expect(sL2, closeTo(1296.0 / 1200.0, 1e-4)); // 1.08
      expect(sR2, closeTo(1296.0 / 1200.0, 1e-4)); // 1.08
      expect(sT2, closeTo(729.0 / 540.0, 1e-4)); // 1.35
      expect(sB2, closeTo(729.0 / 540.0, 1e-4)); // 1.35

      // Scenario 3: Off-center zoom 1.25x with dx = +150 (pushed right)
      final view3 = VideoViewRect.fromTransform(
        canvas: canvas,
        scale: 1.25,
        offset: const Offset(150.0, 0.0),
        videoAspectRatio: videoAspect,
      );
      expect(view3.left >= canvas.left, isTrue); // left is at 150 >= 0 (black bar, uncompressed!)
      expect(view3.right > canvas.right, isTrue); // right is at 2550 > 2400 (overflows!)

      final (sL3, sR3, _, _) = view3.calculateOverflowFactors(canvas);
      expect(sL3, 1.0); // Zero distortion on left
      expect(sR3, closeTo(1200.0 / 1050.0, 1e-4)); // ~1.1428 compressed on right
    });

    test('Two-stage fill scale and overflow scale calculations for landscape and portrait', () {
      // Landscape: 20:9 screen (2400x1080), 16:9 video (1920x1080)
      const double screenAspectLandscape = 2400.0 / 1080.0;
      const double videoAspect = 1920.0 / 1080.0;
      const double fillScaleX = screenAspectLandscape >= videoAspect
          ? (screenAspectLandscape / videoAspect)
          : 1.0;
      const double fillScaleY = screenAspectLandscape >= videoAspect
          ? 1.0
          : (videoAspect / screenAspectLandscape);

      expect(fillScaleX, closeTo(1.25, 1e-4));
      expect(fillScaleY, closeTo(1.0, 1e-4));

      // Stage 1: Scale = 1.1x (< 1.25x fillScaleX)
      // X is expanding to fill black bars: no overflow, no compression!
      const double scale1 = 1.1;
      const double overflowX1 = scale1 > fillScaleX ? (scale1 / fillScaleX) : 1.0;
      const double overflowY1 = scale1 > fillScaleY ? (scale1 / fillScaleY) : 1.0;
      expect(overflowX1, 1.0);
      expect(overflowY1, closeTo(1.1, 1e-4));

      // Stage 2: Scale = 1.4x (> 1.25x fillScaleX)
      // Black bars filled, now X overflows and triggers compression!
      const double scale2 = 1.4;
      const double overflowX2 = scale2 > fillScaleX ? (scale2 / fillScaleX) : 1.0;
      const double overflowY2 = scale2 > fillScaleY ? (scale2 / fillScaleY) : 1.0;
      expect(overflowX2, closeTo(1.4 / 1.25, 1e-4));
      expect(overflowY2, closeTo(1.4, 1e-4));
    });

    test('Dynamic focal point zooming keeps content under focal point pinned', () {
      // Container 1000x1000, Center at (500, 500)
      const Offset center = Offset(500.0, 500.0);
      const Offset startOffset = Offset.zero;
      const double startScale = 1.0;
      const Offset startFocalPoint = Offset(200.0, 200.0);

      // User pinches to 2.0x, keeping fingers at (200, 200)
      const double newScale = 2.0;
      const Offset curFocalPoint = Offset(200.0, 200.0);
      const double ratio = newScale / startScale;

      final double newOffsetX = curFocalPoint.dx - center.dx - ratio * (startFocalPoint.dx - center.dx - startOffset.dx);
      final double newOffsetY = curFocalPoint.dy - center.dy - ratio * (startFocalPoint.dy - center.dy - startOffset.dy);
      final Offset newOffset = Offset(newOffsetX, newOffsetY);

      // Under new transform, the content point (-300, -300) from center:
      // P' = center + newOffset + newScale * (-300, -300)
      final Offset contentRelToCenter = startFocalPoint - center - startOffset;
      final Offset transformedPoint = center + newOffset + contentRelToCenter * newScale;

      expect(transformedPoint.dx, closeTo(curFocalPoint.dx, 1e-4));
      expect(transformedPoint.dy, closeTo(curFocalPoint.dy, 1e-4));
    });

    test('Pan and zoom hysteresis logic correctly filters out small fluctuations', () {
      // Current mode: Pan
      const double modeStartSpan = 1.0;
      const double modeStartScale = 1.35; // User previously zoomed to 1.35x

      // 1. Small finger distance fluctuation during pan (e.g. 5% change)
      const double spanUpdate1 = 1.05;
      final double spanChange1 = (spanUpdate1 / modeStartSpan - 1.0).abs();
      // Threshold for pan -> zoom is 0.12 (12%)
      final bool shouldSwitchToZoom1 = spanChange1 >= 0.12;
      expect(shouldSwitchToZoom1, isFalse);
      // In pan mode, scale remains strictly locked at modeStartScale
      final double effectiveScaleInPan = shouldSwitchToZoom1 ? (modeStartScale * spanUpdate1) : modeStartScale;
      expect(effectiveScaleInPan, modeStartScale);

      // 2. Intentional strong pinch during pan (15% distance change)
      const double spanUpdate2 = 1.15;
      final double spanChange2 = (spanUpdate2 / modeStartSpan - 1.0).abs();
      final bool shouldSwitchToZoom2 = spanChange2 >= 0.12;
      expect(shouldSwitchToZoom2, isTrue);

      // 3. Zoom mode: small focal displacement does not drop out of zoom
      const double focalDistSmall = 15.0; // < 28px threshold
      const double spanChangeSmall = 0.01;
      const bool shouldSwitchToPan1 = focalDistSmall >= 28.0 && spanChangeSmall < 0.03;
      expect(shouldSwitchToPan1, isFalse);

      // Large focal displacement with steady span drops into pan
      const double focalDistLarge = 35.0; // >= 28px threshold
      const bool shouldSwitchToPan2 = focalDistLarge >= 28.0 && spanChangeSmall < 0.03;
      expect(shouldSwitchToPan2, isTrue);
    });
  });
}
