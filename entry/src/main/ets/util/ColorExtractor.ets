/**
 * 颜色提取工具类
 * 从图片中提取主要颜色
 * 使用 HarmonyOS effectKit ColorPicker API
 */

import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { ColorConverter } from './ColorConverter';

/**
 * 提取的颜色信息
 */
export interface ExtractedColor {
  hex: string;
  count: number;
  percentage: number;
}

export class ColorExtractor {
  /**
   * 从 PixelMap 提取主要颜色
   * 使用 HarmonyOS ColorPicker API
   * @param pixelMap 图片 PixelMap
   * @param maxColors 最大提取颜色数量（建议 5-10）
   * @returns 提取的颜色数组
   */
  static async extractColors(pixelMap: image.PixelMap, maxColors: number = 3): Promise<ExtractedColor[]> {
    const colors: ExtractedColor[] = [];

    try {
      // 创建 ColorPicker 实例
      const colorPicker = await effectKit.createColorPicker(pixelMap);

      // 1. 获取主色（综合权重计算的视觉代表性颜色）
      const mainColor = colorPicker.getMainColorSync();
      colors.push({
        hex: ColorExtractor.colorToHex(mainColor),
        count: 100,
        percentage: 25
      });

      // 2. 获取占比最多的颜色
      const largestColor = colorPicker.getLargestProportionColor();
      const largestHex = ColorExtractor.colorToHex(largestColor);
      if (!ColorExtractor.isDuplicateColor(colors, largestHex)) {
        colors.push({
          hex: largestHex,
          count: 80,
          percentage: 20
        });
      }

      // 3. 获取最高饱和度颜色
      const saturationColor = colorPicker.getHighestSaturationColor();
      const saturationHex = ColorExtractor.colorToHex(saturationColor);
      if (!ColorExtractor.isDuplicateColor(colors, saturationHex)) {
        colors.push({
          hex: saturationHex,
          count: 60,
          percentage: 15
        });
      }

      // 4. 获取平均颜色
      const averageColor = colorPicker.getAverageColor();
      const averageHex = ColorExtractor.colorToHex(averageColor);
      if (!ColorExtractor.isDuplicateColor(colors, averageHex)) {
        colors.push({
          hex: averageHex,
          count: 40,
          percentage: 10
        });
      }

      // 5. 使用区域采样获取更多颜色
      const regions = [
        [0, 0, 0.5, 0.5],     // 左上
        [0.5, 0, 1, 0.5],     // 右上
        [0, 0.5, 0.5, 1],     // 左下
        [0.5, 0.5, 1, 1],     // 右下
        [0.25, 0.25, 0.75, 0.75] // 中心
      ];

      for (const region of regions) {
        if (colors.length >= maxColors) {
          break;
        }

        try {
          const regionPicker = await effectKit.createColorPicker(pixelMap, region);
          const regionColor = regionPicker.getMainColorSync();
          const regionHex = ColorExtractor.colorToHex(regionColor);

          if (!ColorExtractor.isDuplicateColor(colors, regionHex)) {
            colors.push({
              hex: regionHex,
              count: 20,
              percentage: 5
            });
          }
        } catch (err) {
          // 区域采样失败，跳过
        }
      }

      // 重新计算百分比
      const totalCount = colors.reduce((sum, color) => sum + color.count, 0);
      colors.forEach(color => {
        color.percentage = (color.count / totalCount) * 100;
      });
      const HighestColor = colorPicker.getHighestSaturationColor();
      const HighestHex = ColorExtractor.colorToHex(averageColor);
      let colors2 = colors.slice(0, maxColors)
      colors2.push({
        hex: HighestHex,
        count: 30,
        percentage: 10
      });
      return colors2;

    } catch (err) {
      // 如果 ColorPicker 失败，返回空数组
      return [];
    }
  }

  /**
   * 将 effectKit.Color 转换为 HEX 字符串
   */
  private static colorToHex(color: effectKit.Color): string {
    return ColorConverter.rgbToHex(color.red, color.green, color.blue);
  }

  /**
   * 检查颜色是否已存在（避免重复）
   */
  private static isDuplicateColor(colors: ExtractedColor[], hex: string, threshold: number = 30): boolean {
    for (const color of colors) {
      const distance = ColorExtractor.colorDistance(color.hex, hex);
      if (distance < threshold) {
        return true;
      }
    }
    return false;
  }

  /**
   * 过滤相似颜色
   * 移除过于相似的颜色
   */
  static filterSimilarColors(colors: ExtractedColor[], threshold: number = 30): ExtractedColor[] {
    const filtered: ExtractedColor[] = [];

    for (const color of colors) {
      if (!ColorExtractor.isDuplicateColor(filtered, color.hex, threshold)) {
        filtered.push(color);
      }
    }

    return filtered;
  }

  /**
   * 计算两个颜色之间的欧几里得距离
   */
  private static colorDistance(hex1: string, hex2: string): number {
    const rgb1 = ColorConverter.hexToRgb(hex1);
    const rgb2 = ColorConverter.hexToRgb(hex2);

    const rDiff = rgb1.r - rgb2.r;
    const gDiff = rgb1.g - rgb2.g;
    const bDiff = rgb1.b - rgb2.b;

    return Math.sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff);
  }
}

