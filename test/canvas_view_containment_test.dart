import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/plugin/pl_player/strategies/video_scale_strategy.dart';

void main() {
  group('Canvas and View Containment Comprehensive Tests', () {
    // -------------------------------------------------------------------------
    // 1. 横屏常见比例：20:9 屏幕 (2400 x 1080)
    // -------------------------------------------------------------------------
    group('20:9 Canvas (2400 x 1080)', () {
      const canvas = VideoCanvasRect(width: 2400, height: 1080);

      test('Case 1.1: 16:9 View at 1.0x (1920x1080) -> Inside Canvas, no overflow', () {
        final view = VideoViewRect.fromSizeAndOffset(
          canvas: canvas,
          viewWidth: 1920,
          viewHeight: 1080,
        );
        expect(view.left, 240.0);
        expect(view.right, 2160.0);
        expect(view.top, 0.0);
        expect(view.bottom, 1080.0);

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, 1.0);
        expect(sR, 1.0);
        expect(sT, 1.0);
        expect(sB, 1.0);
      });

      test('Case 1.2: 16:9 View at 1.1x (2112x1188) -> X in black bar (1.0), Y overflows (1.10)', () {
        final view = VideoViewRect.fromSizeAndOffset(
          canvas: canvas,
          viewWidth: 2112,
          viewHeight: 1188,
        );
        // X: 144 to 2256 (within 0 to 2400)
        expect(view.left, 144.0);
        expect(view.right, 2256.0);
        // Y: -54 to 1134 (overflows 0 to 1080)
        expect(view.top, -54.0);
        expect(view.bottom, 1134.0);

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, 1.0);
        expect(sR, 1.0);
        expect(sT, closeTo(1188.0 / 1080.0, 1e-4)); // 1.10
        expect(sB, closeTo(1188.0 / 1080.0, 1e-4)); // 1.10
      });

      test('Case 1.3: 16:9 View at 1.25x (2400x1350) -> X perfectly fills canvas, Y overflows (1.25)', () {
        final view = VideoViewRect.fromSizeAndOffset(
          canvas: canvas,
          viewWidth: 2400,
          viewHeight: 1350,
        );
        expect(view.left, 0.0);
        expect(view.right, 2400.0);
        expect(view.top, -135.0);
        expect(view.bottom, 1215.0);

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, 1.0); // Exact match with canvas border
        expect(sR, 1.0);
        expect(sT, closeTo(1.25, 1e-4));
        expect(sB, closeTo(1.25, 1e-4));
      });

      test('Case 1.4: 16:9 View at 1.35x (2592x1458) -> All 4 sides overflow', () {
        final view = VideoViewRect.fromSizeAndOffset(
          canvas: canvas,
          viewWidth: 2592,
          viewHeight: 1458,
        );
        expect(view.left, -96.0);
        expect(view.right, 2496.0);
        expect(view.top, -189.0);
        expect(view.bottom, 1269.0);

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, closeTo(1296.0 / 1200.0, 1e-4)); // 1.08
        expect(sR, closeTo(1296.0 / 1200.0, 1e-4)); // 1.08
        expect(sT, closeTo(729.0 / 540.0, 1e-4)); // 1.35
        expect(sB, closeTo(729.0 / 540.0, 1e-4)); // 1.35
      });

      test('Case 1.5: 16:9 View at 1.25x with Pan Right (dx = +150) -> Left inside canvas (1.0), Right overflows', () {
        final view = VideoViewRect.fromSizeAndOffset(
          canvas: canvas,
          viewWidth: 2400,
          viewHeight: 1350,
          offset: const Offset(150.0, 0.0),
        );
        expect(view.left, 150.0); // Pulled into screen, black bar exposed!
        expect(view.right, 2550.0); // Pushed further out!

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, 1.0); // Must be zero distortion on left!
        expect(sR, closeTo(1200.0 / 1050.0, 1e-4)); // ~1.1428
        expect(sT, closeTo(1.25, 1e-4));
        expect(sB, closeTo(1.25, 1e-4));
      });

      test('Case 1.6: 16:9 View at 1.25x with Pan Down (dy = +100) -> Top moves closer to canvas, Bottom overflows more', () {
        final view = VideoViewRect.fromSizeAndOffset(
          canvas: canvas,
          viewWidth: 2400,
          viewHeight: 1350,
          offset: const Offset(0.0, 100.0),
        );
        expect(view.top, -35.0); // -135 + 100
        expect(view.bottom, 1315.0); // 1215 + 100

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, 1.0);
        expect(sR, 1.0);
        expect(sT, closeTo(675.0 / 640.0, 1e-4)); // ~1.0547
        expect(sB, closeTo(675.0 / 440.0, 1e-4)); // ~1.5341
        expect(sB > sT, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // 2. 竖屏常见比例：9:20 手机竖屏 (1080 x 2400)
    // -------------------------------------------------------------------------
    group('9:20 Portrait Canvas (1080 x 2400)', () {
      const canvas = VideoCanvasRect(width: 1080, height: 2400);

      test('Case 2.1: 16:9 Landscape Video on Portrait Canvas at 1.0x -> Horizontal filled, Top/Bottom massive black bars', () {
        // Under BoxFit.contain: W0 = 1080, H0 = 1080 / (16/9) = 607.5
        final view = VideoViewRect.fromTransform(
          canvas: canvas,
          scale: 1.0,
          offset: Offset.zero,
          videoAspectRatio: 16.0 / 9.0,
        );
        expect(view.width, 1080.0);
        expect(view.height, 607.5);
        expect(view.left, 0.0);
        expect(view.right, 1080.0);
        expect(view.top, 896.25);
        expect(view.bottom, 1503.75);

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, 1.0);
        expect(sR, 1.0);
        expect(sT, 1.0);
        expect(sB, 1.0);
      });

      test('Case 2.2: 16:9 Landscape Video on Portrait Canvas at 1.5x -> X overflows, Y still in black bars', () {
        final view = VideoViewRect.fromTransform(
          canvas: canvas,
          scale: 1.5,
          offset: Offset.zero,
          videoAspectRatio: 16.0 / 9.0,
        );
        // Wv = 1080 * 1.5 = 1620, Hv = 607.5 * 1.5 = 911.25
        expect(view.width, 1620.0);
        expect(view.height, 911.25);
        expect(view.left, -270.0); // overflows left
        expect(view.right, 1350.0); // overflows right
        expect(view.top, 744.375); // still inside canvas!
        expect(view.bottom, 1655.625); // still inside canvas!

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, closeTo(1.50, 1e-4));
        expect(sR, closeTo(1.50, 1e-4));
        expect(sT, 1.0); // No compression needed in Y!
        expect(sB, 1.0);
      });

      test('Case 2.3: 9:16 Portrait Video on Portrait Canvas (1080 x 2400) at 1.0x -> Horizontal filled (1080x1920)', () {
        // Under BoxFit.contain: W0 = 1080, H0 = 1080 / (9/16) = 1920
        final view = VideoViewRect.fromTransform(
          canvas: canvas,
          scale: 1.0,
          offset: Offset.zero,
          videoAspectRatio: 9.0 / 16.0,
        );
        expect(view.width, 1080.0);
        expect(view.height, 1920.0);
        expect(view.top, 240.0);
        expect(view.bottom, 2160.0);

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, 1.0);
        expect(sR, 1.0);
        expect(sT, 1.0);
        expect(sB, 1.0);
      });
    });

    // -------------------------------------------------------------------------
    // 3. 平板 / 折叠屏比例：4:3 屏幕 (2048 x 1536)
    // -------------------------------------------------------------------------
    group('4:3 Tablet Canvas (2048 x 1536)', () {
      const canvas = VideoCanvasRect(width: 2048, height: 1536);

      test('Case 3.1: 16:9 Video on 4:3 Canvas at 1.0x -> Horizontal filled, vertical black bars', () {
        // W0 = 2048, H0 = 2048 / (16/9) = 1152
        final view = VideoViewRect.fromTransform(
          canvas: canvas,
          scale: 1.0,
          offset: Offset.zero,
          videoAspectRatio: 16.0 / 9.0,
        );
        expect(view.width, 2048.0);
        expect(view.height, 1152.0);
        expect(view.left, 0.0);
        expect(view.right, 2048.0);
        expect(view.top, 192.0);
        expect(view.bottom, 1344.0);

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, 1.0);
        expect(sR, 1.0);
        expect(sT, 1.0);
        expect(sB, 1.0);
      });

      test('Case 3.2: 16:9 Video on 4:3 Canvas at 1.3333x (Fills vertical black bars: 2730.67x1536)', () {
        final view = VideoViewRect.fromTransform(
          canvas: canvas,
          scale: 1536.0 / 1152.0, // 1.33333x
          offset: Offset.zero,
          videoAspectRatio: 16.0 / 9.0,
        );
        expect(view.height, closeTo(1536.0, 1e-4)); // Fills vertical
        expect(view.top, closeTo(0.0, 1e-4));
        expect(view.bottom, closeTo(1536.0, 1e-4));

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, closeTo(1.3333, 1e-4)); // X overflows
        expect(sR, closeTo(1.3333, 1e-4));
        expect(sT, 1.0); // Y exactly matches canvas
        expect(sB, 1.0);
      });

      test('Case 3.3: 4:3 Video on 4:3 Canvas at 1.0x -> Exact 1:1 match in all directions', () {
        final view = VideoViewRect.fromTransform(
          canvas: canvas,
          scale: 1.0,
          offset: Offset.zero,
          videoAspectRatio: 4.0 / 3.0,
        );
        expect(view.width, 2048.0);
        expect(view.height, 1536.0);
        expect(view.left, 0.0);
        expect(view.right, 2048.0);
        expect(view.top, 0.0);
        expect(view.bottom, 1536.0);

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, 1.0);
        expect(sR, 1.0);
        expect(sT, 1.0);
        expect(sB, 1.0);
      });
    });

    // -------------------------------------------------------------------------
    // 4. 正方形 / 异形屏幕：1:1 Canvas (1080 x 1080)
    // -------------------------------------------------------------------------
    group('1:1 Square Canvas (1080 x 1080)', () {
      const canvas = VideoCanvasRect(width: 1080, height: 1080);

      test('Case 4.1: 16:9 Video on 1:1 Canvas at 1.2x -> X overflows, Y still in black bars', () {
        // W0 = 1080, H0 = 1080 / (16/9) = 607.5
        final view = VideoViewRect.fromTransform(
          canvas: canvas,
          scale: 1.2,
          offset: Offset.zero,
          videoAspectRatio: 16.0 / 9.0,
        );
        // Wv = 1296, Hv = 729
        expect(view.width, 1296.0);
        expect(view.height, 729.0);
        expect(view.left, -108.0);
        expect(view.right, 1188.0);
        expect(view.top, 175.5);
        expect(view.bottom, 904.5);

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas);
        expect(sL, closeTo(1.20, 1e-4));
        expect(sR, closeTo(1.20, 1e-4));
        expect(sT, 1.0);
        expect(sB, 1.0);
      });

      test('Case 4.2: 21:9 Ultra-widescreen Video (2560x1080) on 16:9 Canvas (1920x1080)', () {
        const c169 = VideoCanvasRect(width: 1920, height: 1080);
        // Video aspect = 2560 / 1080 = 2.37
        final view = VideoViewRect.fromTransform(
          canvas: c169,
          scale: 1.0,
          offset: Offset.zero,
          videoAspectRatio: 2560.0 / 1080.0,
        );
        expect(view.width, 1920.0);
        expect(view.height, closeTo(1920.0 / (2560.0 / 1080.0), 1e-4)); // 810.0
        expect(view.top, 135.0); // Top black bar = 135
        expect(view.bottom, 945.0); // Bottom black bar = 135

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(c169);
        expect(sL, 1.0);
        expect(sR, 1.0);
        expect(sT, 1.0);
        expect(sB, 1.0);
      });
    });

    // -------------------------------------------------------------------------
    // 5. 任意直接尺寸对比测试 (Direct Size & Offset Matrix)
    // -------------------------------------------------------------------------
    group('Direct Arbitrary Size and Offset Matrix', () {
      test('Case 5.1: Small View inside Big Canvas -> Always (1.0, 1.0, 1.0, 1.0)', () {
        const c = VideoCanvasRect(width: 1000, height: 1000);
        final v = VideoViewRect.fromSizeAndOffset(
          canvas: c,
          viewWidth: 500,
          viewHeight: 500,
        );
        expect(v.calculateOverflowFactors(c), (1.0, 1.0, 1.0, 1.0));
      });

      test('Case 5.2: View shifted strictly diagonally -> (Top, Right) overflow, (Bottom, Left) 1.0', () {
        const c = VideoCanvasRect(width: 1000, height: 1000);
        // Shift top-right: dx = +100, dy = -100
        final v = VideoViewRect.fromSizeAndOffset(
          canvas: c,
          viewWidth: 1000,
          viewHeight: 1000,
          offset: const Offset(100.0, -100.0),
        );
        expect(v.left, 100.0); // >= 0 -> no overflow
        expect(v.right, 1100.0); // > 1000 -> overflow!
        expect(v.top, -100.0); // < 0 -> overflow!
        expect(v.bottom, 900.0); // <= 1000 -> no overflow

        final (sL, sR, sT, sB) = v.calculateOverflowFactors(c);
        expect(sL, 1.0);
        expect(sR, closeTo(500.0 / 400.0, 1e-4)); // 1.25
        expect(sT, closeTo(500.0 / 400.0, 1e-4)); // 1.25
        expect(sB, 1.0);
      });
    });

    // -------------------------------------------------------------------------
    // 6. View 缩放中心不是 Canvas 中心（偏心缩放 / Focal-Point Zoom）
    // -------------------------------------------------------------------------
    group('6. Eccentric Zoom (Focal Point != Canvas Center)', () {
      const canvas209 = VideoCanvasRect(width: 2400, height: 1080);
      const aspect169 = 16.0 / 9.0;
      // 16:9 on 20:9 canvas has initial w0 = 1920, h0 = 1080, canvas.center = (1200, 540)

      test('Case 6.1: Focal Point to the Right (1800, 540) at 1.1x -> View shifts left, X still in black bars', () {
        const focal = Offset(1800.0, 540.0);
        final view = VideoViewRect.fromFocalPointZoom(
          canvas: canvas209,
          focalPoint: focal,
          scale: 1.1,
          videoAspectRatio: aspect169,
        );
        // cViewNew = (1800, 540) - (1800 - 1200, 0) * 1.1 = (1800 - 660, 540) = (1140, 540)
        expect(view.center.dx, 1140.0);
        expect(view.center.dy, 540.0);
        expect(view.width, 1920.0 * 1.1); // 2112.0
        expect(view.height, 1080.0 * 1.1); // 1188.0

        // left = 1140 - 1056 = 84.0 (inside canvas, black bar of 84px on left)
        expect(view.left, 84.0);
        // right = 1140 + 1056 = 2196.0 (inside canvas, black bar of 204px on right)
        expect(view.right, 2196.0);
        // top = 540 - 594 = -54.0 (overflows canvas top)
        expect(view.top, -54.0);
        // bottom = 540 + 594 = 1134.0 (overflows canvas bottom)
        expect(view.bottom, 1134.0);

        // Point invariance: The normalized distance from view center to focalPoint
        // on the initial image was (1800 - 1200) / (1920 / 2) = 600 / 960 = 0.625
        // Under new view: (1800 - 1140) / (2112 / 2) = 660 / 1056 = 0.625
        final initialDistToFocal = focal.dx - canvas209.center.dx; // 600
        final initialNormalizedX = initialDistToFocal / (1920.0 / 2.0);
        final newDistToFocal = focal.dx - view.center.dx; // 660
        final newNormalizedX = newDistToFocal / (view.width / 2.0);
        expect(newNormalizedX, closeTo(initialNormalizedX, 1e-6));

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas209);
        expect(sL, 1.0); // Inside black bar
        expect(sR, 1.0); // Inside black bar
        expect(sT, closeTo(1188.0 / 1080.0, 1e-4)); // 1.10
        expect(sB, closeTo(1188.0 / 1080.0, 1e-4)); // 1.10
      });

      test('Case 6.2: Focal Point to the Right (1800, 540) at 1.25x -> Left overflows, Right still inside black bar', () {
        const focal = Offset(1800.0, 540.0);
        final view = VideoViewRect.fromFocalPointZoom(
          canvas: canvas209,
          focalPoint: focal,
          scale: 1.25,
          videoAspectRatio: aspect169,
        );
        // cViewNew = 1800 - 600 * 1.25 = 1800 - 750 = 1050
        expect(view.center.dx, 1050.0);
        expect(view.width, 2400.0);
        expect(view.height, 1350.0);

        // left = 1050 - 1200 = -150.0 (overflows left!)
        expect(view.left, -150.0);
        // right = 1050 + 1200 = 2250.0 (canvas right is 2400 -> inside black bar of 150px!)
        expect(view.right, 2250.0);

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas209);
        // sL: distViewLeft / distCanvasLeft = 1200 / 1050 ≈ 1.14286
        expect(sL, closeTo(1200.0 / 1050.0, 1e-4));
        expect(sR, 1.0); // Zero distortion on right!
        expect(sT, closeTo(1.25, 1e-4));
        expect(sB, closeTo(1.25, 1e-4));
      });

      test('Case 6.3: Focal Point in Top-Left Quadrant (600, 270) at 1.2x -> Asymmetric 4-edge overflows', () {
        const focal = Offset(600.0, 270.0);
        final view = VideoViewRect.fromFocalPointZoom(
          canvas: canvas209,
          focalPoint: focal,
          scale: 1.2,
          videoAspectRatio: aspect169,
        );
        // cViewOld = (1200, 540)
        // cViewNew.dx = 600 - (600 - 1200) * 1.2 = 600 - (-720) = 1320
        // cViewNew.dy = 270 - (270 - 540) * 1.2 = 270 - (-324) = 594
        expect(view.center.dx, 1320.0);
        expect(view.center.dy, 594.0);
        expect(view.width, 2304.0);
        expect(view.height, 1296.0);

        expect(view.left, 168.0); // > 0 -> Inside canvas, black bar!
        expect(view.right, 2472.0); // > 2400 -> Overflows right!
        expect(view.top, -54.0); // < 0 -> Overflows top!
        expect(view.bottom, 1242.0); // > 1080 -> Overflows bottom!

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas209);
        expect(sL, 1.0); // Black bar -> 1.0
        expect(sR, closeTo(1152.0 / (2400.0 - 1320.0), 1e-4)); // 1152 / 1080 ≈ 1.0667
        expect(sT, closeTo(648.0 / 594.0, 1e-4)); // ≈ 1.0909
        expect(sB, closeTo(648.0 / (1080.0 - 594.0), 1e-4)); // 648 / 486 = 1.3333

        // Bottom overflow factor is significantly larger than top because view was pushed downward
        expect(sB > sT, isTrue);
      });

      test('Case 6.4: Focal Point in Bottom-Right Quadrant (1800, 810) at 1.3x -> Top/Left overflow more', () {
        const focal = Offset(1800.0, 810.0);
        final view = VideoViewRect.fromFocalPointZoom(
          canvas: canvas209,
          focalPoint: focal,
          scale: 1.3,
          videoAspectRatio: aspect169,
        );
        // cViewNew.dx = 1800 - (1800 - 1200) * 1.3 = 1800 - 780 = 1020
        // cViewNew.dy = 810 - (810 - 540) * 1.3 = 810 - 351 = 459
        expect(view.center.dx, 1020.0);
        expect(view.center.dy, 459.0);
        expect(view.width, 2496.0);
        expect(view.height, 1404.0);

        expect(view.left, -228.0); // Overflows left!
        expect(view.right, 2268.0); // < 2400 -> Inside canvas!
        expect(view.top, -243.0); // Overflows top!
        expect(view.bottom, 1161.0); // Overflows bottom!

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(canvas209);
        expect(sL, closeTo(1248.0 / 1020.0, 1e-4)); // ≈ 1.2235
        expect(sR, 1.0); // Black bar on right
        expect(sT, closeTo(702.0 / 459.0, 1e-4)); // ≈ 1.5294
        expect(sB, closeTo(702.0 / (1080.0 - 459.0), 1e-4)); // 702 / 621 ≈ 1.1304
        expect(sT > sB, isTrue);
      });

      test('Case 6.5: Secondary Zoom from already zoomed and offset state', () {
        // Initial state: scaled to 1.2x with offset (50, -30)
        const focal = Offset(1500.0, 400.0);
        const initialOffset = Offset(50.0, -30.0);
        final view = VideoViewRect.fromFocalPointZoom(
          canvas: canvas209,
          focalPoint: focal,
          scale: 1.44, // 1.2 * 1.2
          initialScale: 1.2,
          initialOffset: initialOffset,
          videoAspectRatio: aspect169,
        );

        // Verify dimensions
        expect(view.width, closeTo(1920.0 * 1.44, 1e-4));
        expect(view.height, closeTo(1080.0 * 1.44, 1e-4));

        // Verify focal point invariance between initial and new view
        final cOld = Offset(canvas209.center.dx + initialOffset.dx, canvas209.center.dy + initialOffset.dy);
        final initialNormX = (focal.dx - cOld.dx) / (1920.0 * 1.2 / 2.0);
        final initialNormY = (focal.dy - cOld.dy) / (1080.0 * 1.2 / 2.0);

        final newNormX = (focal.dx - view.center.dx) / (view.width / 2.0);
        final newNormY = (focal.dy - view.center.dy) / (view.height / 2.0);

        expect(newNormX, closeTo(initialNormX, 1e-6));
        expect(newNormY, closeTo(initialNormY, 1e-6));
      });

      test('Case 6.6: Portrait Canvas (1080 x 2400) with Eccentric Zoom near Top Edge', () {
        const portraitCanvas = VideoCanvasRect(width: 1080, height: 2400);
        // 16:9 on portrait: w0 = 1080, h0 = 607.5, top = 896.25, bottom = 1503.75
        const focal = Offset(540.0, 900.0); // Near top of video
        final view = VideoViewRect.fromFocalPointZoom(
          canvas: portraitCanvas,
          focalPoint: focal,
          scale: 1.3,
          videoAspectRatio: aspect169,
        );

        expect(view.width, closeTo(1080.0 * 1.3, 1e-4)); // 1404
        expect(view.left, closeTo(-162.0, 1e-4)); // Overflows left
        expect(view.right, closeTo(1242.0, 1e-4)); // Overflows right
        // Top and bottom are still well within the vertical canvas (2400)
        expect(view.top > 0.0, isTrue);
        expect(view.bottom < 2400.0, isTrue);

        final (sL, sR, sT, sB) = view.calculateOverflowFactors(portraitCanvas);
        expect(sL, closeTo(1.3, 1e-4));
        expect(sR, closeTo(1.3, 1e-4));
        expect(sT, 1.0); // No vertical overflow
        expect(sB, 1.0);
      });
    });

    // -------------------------------------------------------------------------
    // 7. 对 View 进行平移后的效果 (Panning / Translation Effects)
    // -------------------------------------------------------------------------
    group('7. Panning / Translation Effects on View', () {
      const canvas209 = VideoCanvasRect(width: 2400, height: 1080);
      const aspect169 = 16.0 / 9.0;

      test('Case 7.1: Continuous Horizontal Panning at 1.25x -> Monotonic right overflow and left locked at 1.0', () {
        final initialView = VideoViewRect.fromTransform(
          canvas: canvas209,
          scale: 1.25,
          offset: Offset.zero,
          videoAspectRatio: aspect169,
        );
        expect(initialView.left, 0.0);
        expect(initialView.right, 2400.0);

        // Step 1: Pan right +50
        final viewPan50 = initialView.translate(const Offset(50.0, 0.0));
        expect(viewPan50.left, 50.0);
        expect(viewPan50.right, 2450.0);
        final (sL1, sR1, _, _) = viewPan50.calculateOverflowFactors(canvas209);
        expect(sL1, 1.0); // Left pulled into canvas (black bar)
        expect(sR1, closeTo(1200.0 / 1150.0, 1e-4)); // ≈ 1.0435

        // Step 2: Pan further right +100 (total +150)
        final viewPan150 = viewPan50.translate(const Offset(100.0, 0.0));
        expect(viewPan150.left, 150.0);
        expect(viewPan150.right, 2550.0);
        final (sL2, sR2, _, _) = viewPan150.calculateOverflowFactors(canvas209);
        expect(sL2, 1.0);
        expect(sR2, closeTo(1200.0 / 1050.0, 1e-4)); // ≈ 1.1429
        expect(sR2 > sR1, isTrue); // Monotonically increasing

        // Step 3: Pan further right +150 (total +300)
        final viewPan300 = viewPan150.translate(const Offset(150.0, 0.0));
        expect(viewPan300.left, 300.0);
        expect(viewPan300.right, 2700.0);
        final (sL3, sR3, _, _) = viewPan300.calculateOverflowFactors(canvas209);
        expect(sL3, 1.0);
        expect(sR3, closeTo(1200.0 / 900.0, 1e-4)); // 1.3333
        expect(sR3 > sR2, isTrue);

        // Step 4: Reverse Pan Left to -300
        final viewPanNeg300 = initialView.translate(const Offset(-300.0, 0.0));
        expect(viewPanNeg300.left, -300.0);
        expect(viewPanNeg300.right, 2100.0);
        final (sLNeg, sRNeg, _, _) = viewPanNeg300.calculateOverflowFactors(canvas209);
        expect(sRNeg, 1.0); // Right pulled into canvas
        expect(sLNeg, closeTo(1200.0 / 900.0, 1e-4)); // Exactly mirrors sR3!
        expect(sLNeg, equals(sR3)); // Perfect bilateral symmetry
      });

      test('Case 7.2: Vertical Panning at 1.1x -> Top edge pulled into screen resets sTop to 1.0', () {
        // At 1.1x: w = 2112, h = 1188. Initially top = -54, bottom = 1134
        final initialView = VideoViewRect.fromTransform(
          canvas: canvas209,
          scale: 1.1,
          offset: Offset.zero,
          videoAspectRatio: aspect169,
        );
        expect(initialView.top, -54.0);
        expect(initialView.bottom, 1134.0);
        final (_, _, sT0, sB0) = initialView.calculateOverflowFactors(canvas209);
        expect(sT0, closeTo(1.10, 1e-4));
        expect(sB0, closeTo(1.10, 1e-4));

        // Pan down by exactly +54: top touches canvas border
        final viewTouchTop = initialView.translate(const Offset(0.0, 54.0));
        expect(viewTouchTop.top, 0.0);
        expect(viewTouchTop.bottom, 1188.0);
        final (_, _, sT1, sB1) = viewTouchTop.calculateOverflowFactors(canvas209);
        expect(sT1, 1.0); // Exactly on border -> 1.0
        expect(sB1, closeTo(594.0 / (1080.0 - 594.0), 1e-4)); // 594 / 486 ≈ 1.2222

        // Pan down further by +20 (total +74): top pulled inside canvas (black bar of 20px)
        final viewInsideTop = initialView.translate(const Offset(0.0, 74.0));
        expect(viewInsideTop.top, 20.0); // Inside!
        expect(viewInsideTop.bottom, 1208.0);
        final (_, _, sT2, sB2) = viewInsideTop.calculateOverflowFactors(canvas209);
        expect(sT2, 1.0); // Inside screen -> strictly 1.0
        expect(sB2, closeTo(594.0 / (1080.0 - 614.0), 1e-4)); // 594 / 466 ≈ 1.2747
        expect(sB2 > sB1, isTrue);

        // Pan up by -74: bottom pulled inside canvas
        final viewInsideBottom = initialView.translate(const Offset(0.0, -74.0));
        expect(viewInsideBottom.bottom, 1060.0); // Inside! (1060 < 1080)
        final (_, _, sT3, sB3) = viewInsideBottom.calculateOverflowFactors(canvas209);
        expect(sB3, 1.0); // Inside screen -> strictly 1.0
        expect(sT3, closeTo(sB2, 1e-4)); // Symmetric to bottom pan
      });

      test('Case 7.3: Diagonal Panning at 1.35x -> Two adjacent edges pulled in become 1.0', () {
        final initialView = VideoViewRect.fromTransform(
          canvas: canvas209,
          scale: 1.35,
          offset: Offset.zero,
          videoAspectRatio: aspect169,
        );
        // Initially all 4 sides overflow: left = -96, right = 2496, top = -189, bottom = 1269
        final (sL0, sR0, sT0, sB0) = initialView.calculateOverflowFactors(canvas209);
        expect(sL0 > 1.0, isTrue);
        expect(sR0 > 1.0, isTrue);
        expect(sT0 > 1.0, isTrue);
        expect(sB0 > 1.0, isTrue);

        // Pan diagonally down-right: dx = +120, dy = +200
        final diagView = initialView.translate(const Offset(120.0, 200.0));
        expect(diagView.left, 24.0); // Pulled into screen!
        expect(diagView.right, 2616.0); // Overflows more
        expect(diagView.top, 11.0); // Pulled into screen!
        expect(diagView.bottom, 1469.0); // Overflows more

        final (sL, sR, sT, sB) = diagView.calculateOverflowFactors(canvas209);
        expect(sL, 1.0); // Zero distortion on left!
        expect(sR, closeTo(1296.0 / (2400.0 - 1320.0), 1e-4)); // 1296 / 1080 = 1.20
        expect(sT, 1.0); // Zero distortion on top!
        expect(sB, closeTo(729.0 / (1080.0 - 740.0), 1e-4)); // 729 / 340 ≈ 2.1441
      });

      test('Case 7.4: Translation Equivalence with fromTransform and getOffset', () {
        final v0 = VideoViewRect.fromTransform(
          canvas: canvas209,
          scale: 1.2,
          offset: Offset.zero,
          videoAspectRatio: aspect169,
        );
        const delta = Offset(120.0, -80.0);
        final vTranslated = v0.translate(delta);
        final vDirect = VideoViewRect.fromTransform(
          canvas: canvas209,
          scale: 1.2,
          offset: delta,
          videoAspectRatio: aspect169,
        );

        expect(vTranslated.left, vDirect.left);
        expect(vTranslated.right, vDirect.right);
        expect(vTranslated.top, vDirect.top);
        expect(vTranslated.bottom, vDirect.bottom);
        expect(vTranslated.center, vDirect.center);
        expect(vTranslated.getOffset(canvas209), delta);

        final factors1 = vTranslated.calculateOverflowFactors(canvas209);
        final factors2 = vDirect.calculateOverflowFactors(canvas209);
        expect(factors1, factors2);
      });
    });

    // -------------------------------------------------------------------------
    // 8. 真实复合手势交互全链条 (Combined Eccentric Zoom + Pan Workflows)
    // -------------------------------------------------------------------------
    group('8. Combined Eccentric Zoom + Pan Workflows', () {
      const canvas = VideoCanvasRect(width: 2400, height: 1080);
      const aspect = 16.0 / 9.0;

      test('Case 8.1: Pinch zoom at off-center point, followed by Pan, followed by second Pinch', () {
        // Step 1: Initial state (1.0x, centered)
        final v0 = VideoViewRect.fromSizeAndOffset(
          canvas: canvas,
          viewWidth: 1920.0,
          viewHeight: 1080.0,
        );
        expect(v0.center, canvas.center);

        // Step 2: Pinch zoom at (1600, 400) to 1.15x
        const focal1 = Offset(1600.0, 400.0);
        final v1 = VideoViewRect.fromFocalPointZoom(
          canvas: canvas,
          focalPoint: focal1,
          scale: 1.15,
          videoAspectRatio: aspect,
        );
        expect(v1.width, closeTo(1920.0 * 1.15, 1e-4));
        expect(v1.height, closeTo(1080.0 * 1.15, 1e-4));

        // Step 3: User pans view by (-80, 60)
        const panDelta = Offset(-80.0, 60.0);
        final v2 = v1.translate(panDelta);
        expect(v2.center, Offset(v1.center.dx - 80.0, v1.center.dy + 60.0));
        expect(v2.width, v1.width);
        expect(v2.height, v1.height);

        // Step 4: User pinches again at another point (1000, 700) to 1.35x
        const focal2 = Offset(1000.0, 700.0);
        final offsetBeforePinch2 = v2.getOffset(canvas);
        final v3 = VideoViewRect.fromFocalPointZoom(
          canvas: canvas,
          focalPoint: focal2,
          scale: 1.35,
          initialScale: 1.15,
          initialOffset: offsetBeforePinch2,
          videoAspectRatio: aspect,
        );
        expect(v3.width, closeTo(1920.0 * 1.35, 1e-4));
        expect(v3.height, closeTo(1080.0 * 1.35, 1e-4));

        // Verify focal2 invariance during Step 4
        final normX2Before = (focal2.dx - v2.center.dx) / (v2.width / 2.0);
        final normY2Before = (focal2.dy - v2.center.dy) / (v2.height / 2.0);
        final normX2After = (focal2.dx - v3.center.dx) / (v3.width / 2.0);
        final normY2After = (focal2.dy - v3.center.dy) / (v3.height / 2.0);
        expect(normX2After, closeTo(normX2Before, 1e-6));
        expect(normY2After, closeTo(normY2Before, 1e-6));

        // Overflow factors throughout are all valid and non-negative
        final (sL3, sR3, sT3, sB3) = v3.calculateOverflowFactors(canvas);
        expect(sL3 >= 1.0, isTrue);
        expect(sR3 >= 1.0, isTrue);
        expect(sT3 >= 1.0, isTrue);
        expect(sB3 >= 1.0, isTrue);
      });
    });
  });
}
