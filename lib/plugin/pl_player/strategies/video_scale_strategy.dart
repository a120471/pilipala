import 'dart:math' as math;
import 'dart:ui';

import 'package:get/get.dart';

import 'geometry.dart';

// 兼容旧引用：几何模型与渲染变换分别抽离为独立模块
export 'geometry.dart';
export 'render_transform.dart';

/// 视频缩放与畸变映射抽象策略
abstract class VideoScaleStrategy {
  String get id;
  String get name;
  String get description;

  /// 计算 4 个边界（左、右、上、下）的独立溢出缩放因子
  /// 基于 Canvas（屏幕视口）与 View（视频画面）几何包含关系统一判定
  static (double, double, double, double) calculate4BoundaryOverflows({
    required double scale,
    required Offset offset,
    required Size containerSize,
    required double videoAspectRatio,
  }) {
    if (scale <= 1.0 && offset == Offset.zero) {
      return (1.0, 1.0, 1.0, 1.0);
    }

    final double wc = containerSize.width > 0 ? containerSize.width : 1920.0;
    final double hc = containerSize.height > 0 ? containerSize.height : 1080.0;

    final VideoCanvasRect canvas = VideoCanvasRect(width: wc, height: hc);
    final VideoViewRect view = VideoViewRect.fromTransform(
      canvas: canvas,
      scale: scale,
      offset: offset,
      videoAspectRatio: videoAspectRatio,
    );

    return view.calculateOverflowFactors(canvas);
  }

  /// 非线性压缩生效的最大缩放倍数（超过此阈值自动回退为等比线性缩放）
  double get maxNonLinearScale => 1.5;

  /// 策略核心映射方法：将原片坐标 x 映射到屏幕视口坐标
  /// @param x 归一化输入坐标 [-scale, scale]
  /// @param scale 当前放大倍数 (scale > 1.0)
  /// @param centerRatio 中心保真区占比 (0.0 ~ 1.0, 默认 0.6)
  double map(double x, double scale, {double centerRatio = 0.6});

  /// 统一入口：包含边界检查与超限回退逻辑
  double apply(double x, double scale, {double centerRatio = 0.6}) {
    if (scale <= 1.0) return x;
    // 当缩放比例过大时，回退到等比线性缩放，避免边缘过度失真
    if (scale > maxNonLinearScale) {
      return x * scale;
    }
    return map(x, scale, centerRatio: centerRatio);
  }

  /// 逆向映射：供着色器/纹理采样采样使用（从屏幕坐标 y ∈ [-1, 1] 反算原片坐标 x）
  double inverseMap(double y, double scale, {double centerRatio = 0.6}) {
    if (scale <= 1.0) return y;
    if (scale > maxNonLinearScale) {
      return y / scale;
    }
    return inverse(y, scale, centerRatio: centerRatio);
  }

  /// 子类具体实现的逆向映射
  double inverse(double y, double scale, {double centerRatio = 0.6}) {
    return y / scale;
  }

  /// 生成该策略对应的 mpv GLSL 用户着色器代码（由 mpv vo=gpu 硬件加速渲染管线执行）
  /// 支持 4 边界独立溢出缩放比例（overflowScaleLeft, overflowScaleRight, overflowScaleTop, overflowScaleBottom）
  /// 仅超出对应屏幕视口边界的半轴才进行非线性压缩，未超出的一侧零畸变原生呈现
  String generateGlslShader({
    double? overflowScaleLeft,
    double? overflowScaleRight,
    double? overflowScaleTop,
    double? overflowScaleBottom,
    double? overflowScaleX,
    double? overflowScaleY,
    double? scale,
    double? uCenter,
    double? vCenter,
    double centerRatio = 0.6,
  }) {
    final double sLeft = overflowScaleLeft ?? overflowScaleX ?? scale ?? 1.0;
    final double sRight = overflowScaleRight ?? overflowScaleX ?? scale ?? 1.0;
    final double sTop = overflowScaleTop ?? overflowScaleY ?? scale ?? 1.0;
    final double sBottom = overflowScaleBottom ?? overflowScaleY ?? scale ?? 1.0;
    final double uc = (uCenter ?? 0.0).clamp(-0.8, 0.8);
    final double vc = (vCenter ?? 0.0).clamp(-0.8, 0.8);
    final String formulaX = glslFormula('absU', 'x', 'Sx', 'u0x');
    final String formulaY = glslFormula('absV', 'y', 'Sy', 'u0y');
    return '''//!HOOK MAIN
//!BIND HOOKED
//!DESC NonLinearEdgeCompress_asymmetric_$id

vec4 hook() {
    vec2 pos = HOOKED_pos;
    float uRaw = pos.x * 2.0 - 1.0;
    float vRaw = pos.y * 2.0 - 1.0;
    float uc = ${uc.toStringAsFixed(4)};
    float vc = ${vc.toStringAsFixed(4)};

    float u = uRaw - uc;
    float v = vRaw - vc;
    float signU = u >= 0.0 ? 1.0 : -1.0;
    float signV = v >= 0.0 ? 1.0 : -1.0;

    float absU = u >= 0.0 ? (u / max(1.0 - uc, 0.001)) : ((-u) / max(1.0 + uc, 0.001));
    float absV = v >= 0.0 ? (v / max(1.0 - vc, 0.001)) : ((-v) / max(1.0 + vc, 0.001));

    float sLeft = ${sLeft.toStringAsFixed(4)};
    float sRight = ${sRight.toStringAsFixed(4)};
    float sTop = ${sTop.toStringAsFixed(4)};
    float sBottom = ${sBottom.toStringAsFixed(4)};
    float x0 = ${centerRatio.toStringAsFixed(4)};

    float Sx = u >= 0.0 ? sRight : sLeft;
    float Sy = v >= 0.0 ? sBottom : sTop;
    float u0x = x0;
    float u0y = x0;

    float x;
    {
$formulaX
    }

    float y;
    {
$formulaY
    }

    float sampleX = clamp(0.5 + (u >= 0.0 ? (x * (1.0 - uc) * 0.5) : (-x * (1.0 + uc) * 0.5)), 0.0, 1.0);
    float sampleY = clamp(0.5 + (v >= 0.0 ? (y * (1.0 - vc) * 0.5) : (-y * (1.0 + vc) * 0.5)), 0.0, 1.0);

    return HOOKED_tex(vec2(sampleX, sampleY));
}
''';
  }

  /// 子类实现的单维度坐标映射 GLSL 代码
  String glslFormula(String coordVar, String outVar, String scaleVar, String u0Var);
}

/// 对照组：传统纯等比线性缩放（超出屏幕部分直接裁切）
class LinearScaleStrategy extends VideoScaleStrategy {
  @override
  String get id => 'linear';
  @override
  String get name => '等比裁切 (线性)';
  @override
  String get description => '传统等比缩放，中心与边缘比例完全一致，画面边缘溢出裁切';

  @override
  double map(double x, double scale, {double centerRatio = 0.6}) {
    return x * scale;
  }

  @override
  double inverse(double y, double scale, {double centerRatio = 0.6}) {
    return y / scale;
  }

  @override
  String glslFormula(String coordVar, String outVar, String scaleVar, String u0Var) {
    return '        $outVar = $scaleVar <= 1.001 ? $coordVar : ($coordVar / $scaleVar);';
  }
}

/// 方案 A：分段样条平滑压缩 (Piecewise Spline)
/// 中心保真区 100% 等比不变，过渡区到边缘采用 C1 连续二次平滑样条压缩进屏幕边缘
class PiecewiseSplineStrategy extends VideoScaleStrategy {
  @override
  String get id => 'piecewise_spline';
  @override
  String get name => '分段样条压缩';
  @override
  String get description => '中心 60% 绝对不变形，交界处一阶导平滑连续，边缘平滑渐进收纳所有画面像素';

  @override
  double map(double x, double scale, {double centerRatio = 0.6}) {
    final double sign = x >= 0 ? 1.0 : -1.0;
    final double absX = x.abs();
    final double x0 = centerRatio;

    // 中心区域保持 1:1 绝对不变形
    if (absX <= x0) {
      return x;
    }

    final double maxDomain = scale;
    if (absX >= maxDomain) {
      return sign * 1.0;
    }

    final double t = (absX - x0) / (maxDomain - x0);
    // C1 连续二次插值
    final double sRatio = (scale - x0) / (1.0 - x0);
    final double a = 1.0 - sRatio;
    final double b = sRatio;
    final double smoothT = (a * t * t + b * t).clamp(0.0, 1.0);

    final double mappedAbs = x0 + (1.0 - x0) * smoothT;
    return sign * mappedAbs.clamp(0.0, 1.0);
  }

  @override
  double inverse(double y, double scale, {double centerRatio = 0.6}) {
    final double sign = y >= 0 ? 1.0 : -1.0;
    final double absY = y.abs();
    final double x0 = centerRatio;

    if (absY <= x0) {
      return y;
    }
    if (absY >= 1.0) {
      return sign * scale;
    }

    final double normY = (absY - x0) / (1.0 - x0);
    final double sRatio = (scale - x0) / (1.0 - x0);
    final double a = 1.0 - sRatio;
    final double b = sRatio;

    double t;
    if (a.abs() < 1e-6) {
      t = normY / b;
    } else {
      final double discriminant = math.max(0.0, b * b + 4 * a * normY);
      t = (-b + math.sqrt(discriminant)) / (2 * a);
    }
    t = t.clamp(0.0, 1.0);
    final double absX = x0 + t * (scale - x0);
    return sign * absX;
  }

  @override
  String glslFormula(String coordVar, String outVar, String scaleVar, String u0Var) {
    return '''        if ($scaleVar <= 1.001) {
            $outVar = $coordVar;
        } else if ($coordVar <= $u0Var) {
            $outVar = $coordVar / $scaleVar;
        } else {
            float t = ($coordVar - $u0Var) / (1.0 - $u0Var);
            float startVal = $u0Var / $scaleVar;
            float endVal = 1.0;
            float delta = endVal - startVal;
            float m0 = (1.0 / $scaleVar) * (1.0 - $u0Var);
            float a = delta - m0;
            float b = m0;
            $outVar = startVal + b * t + a * t * t;
        }''';
  }
}

/// 方案 B：双曲正切软饱和映射 (Tanh Soft Saturation)
/// 利用 tanh 函数在中心线性、两端渐近饱和的数学特性，全局无接缝突变
class TanhSaturationStrategy extends VideoScaleStrategy {
  @override
  String get id => 'tanh_saturation';
  @override
  String get name => '双曲正切饱和';
  @override
  String get description => '全局连续平滑无缝衔接，视觉过渡自然如广角镜头';

  static const double k = 1.6;

  @override
  double map(double x, double scale, {double centerRatio = 0.6}) {
    final double numerator = _tanh(k * x);
    final double denominator = _tanh(k * scale);
    if (denominator.abs() < 1e-6) return x;
    return (numerator / denominator).clamp(-1.0, 1.0);
  }

  @override
  double inverse(double y, double scale, {double centerRatio = 0.6}) {
    final double denom = _tanh(k * scale);
    final double u = (y * denom).clamp(-0.9999, 0.9999);
    // arctanh(u) = 0.5 * ln((1 + u) / (1 - u))
    final double atanh = 0.5 * math.log((1.0 + u) / (1.0 - u));
    return atanh / k;
  }

  @override
  String glslFormula(String coordVar, String outVar, String scaleVar, String u0Var) {
    return '''        if ($scaleVar <= 1.001) {
            $outVar = $coordVar;
        } else if ($coordVar <= $u0Var) {
            $outVar = $coordVar / $scaleVar;
        } else {
            float t = ($coordVar - $u0Var) / (1.0 - $u0Var);
            float ev = exp(2.0 * t);
            float em = exp(-2.0 * t);
            float normTanh = ((ev - em) / (ev + em)) / 0.96402758;
            $outVar = ($u0Var / $scaleVar) + (1.0 - $u0Var / $scaleVar) * normTanh;
        }''';
  }

  double _tanh(double v) {
    final double ep = math.exp(v);
    final double em = math.exp(-v);
    return (ep - em) / (ep + em);
  }
}

/// 方案 C：正弦拉伸 (Sinusoidal Smart-Stretch)
/// 类似广电影视 4:3 -> 16:9 智能填充标准算法
class SinusoidalStretchStrategy extends VideoScaleStrategy {
  @override
  String get id => 'sinusoidal';
  @override
  String get name => '正弦智能拉伸';
  @override
  String get description => '影视级智能全屏算法，平衡视觉焦点与边缘信息完整性';

  @override
  double map(double x, double scale, {double centerRatio = 0.6}) {
    final double normX = (x / scale).clamp(-1.0, 1.0);
    final double delta = (scale - 1.0) / scale;
    final double warped = normX - (delta / math.pi) * math.sin(math.pi * normX);
    return (warped * scale).clamp(-1.0, 1.0);
  }

  @override
  double inverse(double y, double scale, {double centerRatio = 0.6}) {
    // 正弦反变换通过牛顿迭代法快速求精确解 (3-4 次即可达 1e-6 精度)
    double normX = (y / scale).clamp(-1.0, 1.0);
    final double delta = (scale - 1.0) / scale;
    final double targetWarped = y / scale;

    for (int i = 0; i < 4; i++) {
      final double f = normX - (delta / math.pi) * math.sin(math.pi * normX) - targetWarped;
      final double df = 1.0 - delta * math.cos(math.pi * normX);
      if (df.abs() < 1e-6) break;
      normX -= f / df;
    }
    return normX * scale;
  }

  @override
  String glslFormula(String coordVar, String outVar, String scaleVar, String u0Var) {
    return '''        if ($scaleVar <= 1.001) {
            $outVar = $coordVar;
        } else if ($coordVar <= $u0Var) {
            $outVar = $coordVar / $scaleVar;
        } else {
            float t = ($coordVar - $u0Var) / (1.0 - $u0Var);
            float s = sin(1.57079632679 * t);
            $outVar = ($u0Var / $scaleVar) + (1.0 - $u0Var / $scaleVar) * (s * s);
        }''';
  }
}

/// 方案 D：分段幂函数强力压缩 (Piecewise Power Curve)
/// 适合需要强行保全边角所有文字信息与细微画面的场景
class PowerCurveStrategy extends VideoScaleStrategy {
  @override
  String get id => 'power_curve';
  @override
  String get name => '幂函数强力压缩';
  @override
  String get description => '强力将极端边缘信息挤入画面，最高程度保全边角内容';

  static const double p = 0.7; // 幂指数，越小边缘压缩力度越强

  @override
  double map(double x, double scale, {double centerRatio = 0.6}) {
    final double sign = x >= 0 ? 1.0 : -1.0;
    final double absX = x.abs();
    final double x0 = centerRatio;

    if (absX <= x0) {
      return x;
    }

    final double maxDomain = scale;
    if (absX >= maxDomain) {
      return sign * 1.0;
    }

    final double t = (absX - x0) / (maxDomain - x0);
    final double mappedAbs = x0 + (1.0 - x0) * math.pow(t, p);
    return sign * mappedAbs.clamp(0.0, 1.0);
  }

  @override
  double inverse(double y, double scale, {double centerRatio = 0.6}) {
    final double sign = y >= 0 ? 1.0 : -1.0;
    final double absY = y.abs();
    final double x0 = centerRatio;

    if (absY <= x0) {
      return y;
    }
    if (absY >= 1.0) {
      return sign * scale;
    }

    final double normY = (absY - x0) / (1.0 - x0);
    final double t = math.pow(normY, 1.0 / p).toDouble();
    final double absX = x0 + t * (scale - x0);
    return sign * absX;
  }

  @override
  String glslFormula(String coordVar, String outVar, String scaleVar, String u0Var) {
    return '''        if ($scaleVar <= 1.001) {
            $outVar = $coordVar;
        } else if ($coordVar <= $u0Var) {
            $outVar = $coordVar / $scaleVar;
        } else {
            float t = ($coordVar - $u0Var) / (1.0 - $u0Var);
            $outVar = ($u0Var / $scaleVar) + (1.0 - $u0Var / $scaleVar) * pow(t, 0.65);
        }''';
  }
}

/// 缩放算法策略管理器
class VideoScaleStrategyManager {
  static final List<VideoScaleStrategy> strategies = [
    PiecewiseSplineStrategy(),
    TanhSaturationStrategy(),
    SinusoidalStretchStrategy(),
    PowerCurveStrategy(),
    LinearScaleStrategy(),
  ];

  static final Rx<VideoScaleStrategy> currentStrategy =
      Rx<VideoScaleStrategy>(strategies[0]);

  static void setStrategy(VideoScaleStrategy strategy) {
    currentStrategy.value = strategy;
  }

  static void setStrategyById(String id) {
    final found = strategies.firstWhere(
      (e) => e.id == id,
      orElse: () => strategies[0],
    );
    currentStrategy.value = found;
  }
}
