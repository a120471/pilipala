import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller.dart';
import '../strategies/video_scale_strategy.dart';

/// 弹出视频缩放与畸变压缩算法对比与选择面板
void showScaleStrategyDialog(BuildContext context, PlPlayerController controller) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      final ColorScheme colorScheme = Theme.of(ctx).colorScheme;
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '画面缩放与边缘压缩算法',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '中心 1:1 等比保真 · 边缘自适应收纳像素',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Obx(() {
                  if (!controller.isZoomed.value) return const SizedBox();
                  return TextButton.icon(
                    onPressed: () {
                      controller.resetZoom();
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text('1.0x 复位'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 10),
            // 状态指示卡片
            Obx(() {
              final double curScale = controller.zoomScale.value;
              final bool isOverThreshold = curScale > 1.5;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isOverThreshold
                      ? Colors.amber.withOpacity(0.12)
                      : colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOverThreshold
                        ? Colors.amber.withOpacity(0.4)
                        : colorScheme.primary.withOpacity(0.2),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOverThreshold
                          ? Icons.info_outline_rounded
                          : Icons.auto_awesome_rounded,
                      size: 18,
                      color: isOverThreshold ? Colors.amber[800] : colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOverThreshold
                            ? '当前 ${curScale.toStringAsFixed(1)}x: 超过 1.5x 阈值，已平滑回退至等比线性缩放以避免边缘极端失真'
                            : '当前 ${curScale.toStringAsFixed(1)}x: 处于自适应压缩区间 (1.0x ~ 1.5x)，中心等比不变，边缘压缩收纳',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isOverThreshold
                              ? Colors.amber[900]
                              : colorScheme.onPrimaryContainer,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                final VideoScaleStrategy activeStrategy =
                    VideoScaleStrategyManager.currentStrategy.value;
                return ListView.separated(
                  itemCount: VideoScaleStrategyManager.strategies.length,
                  separatorBuilder: (_, __) => const Divider(height: 8, thickness: 0.5),
                  itemBuilder: (BuildContext context, int index) {
                    final VideoScaleStrategy strategy =
                        VideoScaleStrategyManager.strategies[index];
                    final bool isSelected = strategy.id == activeStrategy.id;
                    return InkWell(
                      onTap: () {
                        VideoScaleStrategyManager.setStrategy(strategy);
                        controller.applyScaleShader();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Radio<String>(
                              value: strategy.id,
                              groupValue: activeStrategy.id,
                              onChanged: (String? val) {
                                if (val != null) {
                                  VideoScaleStrategyManager.setStrategy(strategy);
                                  controller.applyScaleShader();
                                }
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        strategy.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (strategy.id == 'linear')
                                        _buildBadge(context, '对照组', Colors.grey)
                                      else if (strategy.id == 'piecewise_spline')
                                        _buildBadge(context, '推荐 · C1 连续', colorScheme.primary)
                                      else if (strategy.id == 'tanh_saturation')
                                        _buildBadge(context, '连续平滑', Colors.teal)
                                      else if (strategy.id == 'sinusoidal')
                                        _buildBadge(context, '广电标准', Colors.indigo)
                                      else if (strategy.id == 'power_curve')
                                        _buildBadge(context, '高压保全', Colors.deepOrange),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    strategy.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildBadge(BuildContext context, String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.4), width: 0.6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
