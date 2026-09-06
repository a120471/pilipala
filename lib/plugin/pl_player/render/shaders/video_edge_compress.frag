#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

// 视频非线性边缘压缩着色器（方案B，Flutter 管线内同步渲染）。
//
// 逐边压缩：仅对「溢出屏幕视口」的边做非线性压缩（把该边的视频内容压回屏幕），
// 「拉入屏幕露出黑边」的边保持原生（视频自然边缘 + 黑边）。这保证：
//   - 中心 1:1 保真（content at rawScale）；
//   - 只压缩溢出边，不压缩黑边侧（与平移状态相关，而非仅缩放大小）；
//   - 无像素丢失（溢出边内容被压回，而不是被裁掉）。
//
// 由 uCenter 表达平移后画面中心相对屏幕的位置，由逐边溢出因子 uOverflow 表达各边溢出量。

uniform vec2 uSize;         // 画布(视口)尺寸 px
uniform float uCenterRatio; // 中心保真区占比 (默认 0.6)
uniform vec4 uOverflow;     // x=left, y=right, z=top, w=bottom 逐边溢出因子
uniform vec2 uFillScale;    // 各轴黑边恰好消失的缩放倍率 fillScaleX/Y
uniform float uScale;       // 当前 rawScale（总缩放）
uniform vec2 uCenter;       // 内容中心（画布居中坐标 [-1,1]）
uniform sampler2D uImage;   // 视频帧（仅视频区域，BoxFit.contain 尺寸）

out vec4 fragColor;

// 逆向非线性映射：屏幕半轴坐标 absU∈[0,1] -> 视频半轴坐标 v∈[0,1]。
// 中心区严格等比（content at rawScale），边缘区 C1 连续二次压缩。
float inverseMap(float absU, float s) {
    if (s <= 1.001) {
        return clamp(absU / s, 0.0, 1.0);
    }
    if (absU <= uCenterRatio) {
        return absU / s;
    }
    float vCenter = uCenterRatio / s;
    float t = clamp((absU - uCenterRatio) / (1.0 - uCenterRatio), 0.0, 1.0);
    float delta = 1.0 - vCenter;
    float m0 = (1.0 / s) * (1.0 - uCenterRatio);
    float a = delta - m0;
    float b = m0;
    return clamp(vCenter + b * t + a * t * t, 0.0, 1.0);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize; // 画布坐标 [0,1]
    vec2 c = uv * 2.0 - 1.0;                 // 画布居中坐标 [-1,1]
    vec2 rel = c - uCenter;                  // 相对视频内容中心的距离

    float Sx = uScale / uFillScale.x;        // 视频各轴半宽（自然，叠单位）
    float Sy = uScale / uFillScale.y;

    float sSideX = rel.x >= 0.0 ? uOverflow.y : uOverflow.x;
    float sSideY = rel.y >= 0.0 ? uOverflow.w : uOverflow.z;
    float sideDistX = rel.x >= 0.0
        ? max(1.0 - uCenter.x, 0.05)
        : max(1.0 + uCenter.x, 0.05);
    float sideDistY = rel.y >= 0.0
        ? max(1.0 - uCenter.y, 0.05)
        : max(1.0 + uCenter.y, 0.05);
    float signX = rel.x >= 0.0 ? 1.0 : -1.0;
    float signY = rel.y >= 0.0 ? 1.0 : -1.0;

    // 无溢出的边（该侧视频自然边缘在屏幕内）且已超出自然边界 → 黑边
    if ((sSideX <= 1.001 && abs(rel.x) > Sx) ||
        (sSideY <= 1.001 && abs(rel.y) > Sy)) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    float vx;
    if (sSideX <= 1.001) {
        vx = clamp(rel.x / Sx, -1.0, 1.0);   // 原生，无压缩
    } else {
        vx = inverseMap(abs(rel.x) / sideDistX, sSideX) * signX; // 溢出边压缩
    }

    float vy;
    if (sSideY <= 1.001) {
        vy = clamp(rel.y / Sy, -1.0, 1.0);   // 原生，无压缩
    } else {
        vy = inverseMap(abs(rel.y) / sideDistY, sSideY) * signY; // 溢出边压缩
    }

    vec2 src = vec2((vx + 1.0) / 2.0, (vy + 1.0) / 2.0);
    fragColor = texture(uImage, src);
}
