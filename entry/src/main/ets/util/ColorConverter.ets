/**
 * 颜色转换工具类
 * 支持 HEX、RGB、HSL、HSV 之间的相互转换
 */

export interface RGB {
  r: number;
  g: number;
  b: number;
  a?: number;
}

export interface HSL {
  h: number;
  s: number;
  l: number;
  a?: number;
}

export interface HSV {
  h: number;
  s: number;
  v: number;
  a?: number;
}

export interface CMYK {
  c: number;
  m: number;
  y: number;
  k: number;
}

export class ColorConverter {
  /**
   * HEX 转 RGB
   * 支持标准格式 #RRGGBB 和华为格式 #AARRGGBB（Alpha 在前）
   * @param hex HEX 颜色值，如 #FF5733 或 #FFFF5733
   * @returns RGB 对象
   */
  static hexToRgb(hex: string): RGB {
    // 移除 # 号
    hex = hex.replace('#', '');

    // 处理短格式 HEX（如 #FFF）
    if (hex.length === 3) {
      hex = hex.split('').map(char => char + char).join('');
    }

    // 处理华为格式的 8 位 HEX（AARRGGBB）
    let a = 1.0;
    if (hex.length === 8) {
      // Alpha 在前两位
      a = parseInt(hex.substring(0, 2), 16) / 255;
      // RGB 在后六位
      hex = hex.substring(2, 8);
    }

    const r = parseInt(hex.substring(0, 2), 16);
    const g = parseInt(hex.substring(2, 4), 16);
    const b = parseInt(hex.substring(4, 6), 16);

    return { r, g, b, a };
  }

  /**
   * RGB 转 HEX
   * @param r 红色值 (0-255)
   * @param g 绿色值 (0-255)
   * @param b 蓝色值 (0-255)
   * @param a 透明度 (0-1)，可选
   * @returns HEX 颜色值
   */
  static rgbToHex(r: number, g: number, b: number, a?: number): string {
    const toHex = (value: number): string => {
      const hex = Math.round(value).toString(16);
      return hex.length === 1 ? '0' + hex : hex;
    };
    
    let hex = '#' + toHex(r) + toHex(g) + toHex(b);
    
    if (a !== undefined && a < 1.0) {
      hex += toHex(a * 255);
    }
    
    return hex.toUpperCase();
  }

  /**
   * RGB 转 HSL
   * @param r 红色值 (0-255)
   * @param g 绿色值 (0-255)
   * @param b 蓝色值 (0-255)
   * @returns HSL 对象
   */
  static rgbToHsl(r: number, g: number, b: number): HSL {
    r /= 255;
    g /= 255;
    b /= 255;

    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    let h = 0;
    let s = 0;
    const l = (max + min) / 2;

    if (max !== min) {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

      if (max === r) {
        h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
      } else if (max === g) {
        h = ((b - r) / d + 2) / 6;
      } else {
        h = ((r - g) / d + 4) / 6;
      }
    }

    return {
      h: Math.round(h * 360),
      s: Math.round(s * 100),
      l: Math.round(l * 100)
    };
  }

  /**
   * HSL 转 RGB
   * @param h 色相 (0-360)
   * @param s 饱和度 (0-100)
   * @param l 亮度 (0-100)
   * @returns RGB 对象
   */
  static hslToRgb(h: number, s: number, l: number): RGB {
    h /= 360;
    s /= 100;
    l /= 100;

    let r: number;
    let g: number;
    let b: number;

    if (s === 0) {
      r = g = b = l;
    } else {
      const hue2rgb = (p: number, q: number, t: number): number => {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
      };

      const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      const p = 2 * l - q;

      r = hue2rgb(p, q, h + 1 / 3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1 / 3);
    }

    return {
      r: Math.round(r * 255),
      g: Math.round(g * 255),
      b: Math.round(b * 255)
    };
  }

  /**
   * RGB 转 HSV
   * @param r 红色值 (0-255)
   * @param g 绿色值 (0-255)
   * @param b 蓝色值 (0-255)
   * @returns HSV 对象
   */
  static rgbToHsv(r: number, g: number, b: number): HSV {
    r /= 255;
    g /= 255;
    b /= 255;

    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    let h = 0;
    const v = max;
    const d = max - min;
    const s = max === 0 ? 0 : d / max;

    if (max !== min) {
      if (max === r) {
        h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
      } else if (max === g) {
        h = ((b - r) / d + 2) / 6;
      } else {
        h = ((r - g) / d + 4) / 6;
      }
    }

    return {
      h: Math.round(h * 360),
      s: Math.round(s * 100),
      v: Math.round(v * 100)
    };
  }

  /**
   * HSV 转 RGB
   * @param h 色相 (0-360)
   * @param s 饱和度 (0-100)
   * @param v 明度 (0-100)
   * @returns RGB 对象
   */
  static hsvToRgb(h: number, s: number, v: number): RGB {
    h /= 360;
    s /= 100;
    v /= 100;

    const i = Math.floor(h * 6);
    const f = h * 6 - i;
    const p = v * (1 - s);
    const q = v * (1 - f * s);
    const t = v * (1 - (1 - f) * s);

    let r: number;
    let g: number;
    let b: number;

    switch (i % 6) {
      case 0:
        r = v; g = t; b = p;
        break;
      case 1:
        r = q; g = v; b = p;
        break;
      case 2:
        r = p; g = v; b = t;
        break;
      case 3:
        r = p; g = q; b = v;
        break;
      case 4:
        r = t; g = p; b = v;
        break;
      case 5:
        r = v; g = p; b = q;
        break;
      default:
        r = 0; g = 0; b = 0;
    }

    return {
      r: Math.round(r * 255),
      g: Math.round(g * 255),
      b: Math.round(b * 255)
    };
  }

  /**
   * HEX 转 HSL
   */
  static hexToHsl(hex: string): HSL {
    const rgb = ColorConverter.hexToRgb(hex);
    return ColorConverter.rgbToHsl(rgb.r, rgb.g, rgb.b);
  }

  /**
   * HSL 转 HEX
   */
  static hslToHex(h: number, s: number, l: number): string {
    const rgb = ColorConverter.hslToRgb(h, s, l);
    return ColorConverter.rgbToHex(rgb.r, rgb.g, rgb.b);
  }

  /**
   * HEX 转 HSV
   */
  static hexToHsv(hex: string): HSV {
    const rgb = ColorConverter.hexToRgb(hex);
    return ColorConverter.rgbToHsv(rgb.r, rgb.g, rgb.b);
  }

  /**
   * HSV 转 HEX
   */
  static hsvToHex(h: number, s: number, v: number): string {
    const rgb = ColorConverter.hsvToRgb(h, s, v);
    return ColorConverter.rgbToHex(rgb.r, rgb.g, rgb.b);
  }

  /**
   * RGB 转 CMYK
   * @param r 红色值 (0-255)
   * @param g 绿色值 (0-255)
   * @param b 蓝色值 (0-255)
   * @returns CMYK 对象（百分比 0-100）
   */
  static rgbToCmyk(r: number, g: number, b: number): CMYK {
    // 归一化 RGB 值到 0-1
    const rNorm = r / 255;
    const gNorm = g / 255;
    const bNorm = b / 255;

    // 计算 K（黑色）
    const k = 1 - Math.max(rNorm, gNorm, bNorm);

    // 特殊情况：纯黑色
    if (k === 1) {
      return { c: 0, m: 0, y: 0, k: 100 };
    }

    // 计算 C、M、Y
    const c = (1 - rNorm - k) / (1 - k);
    const m = (1 - gNorm - k) / (1 - k);
    const y = (1 - bNorm - k) / (1 - k);

    // 转换为百分比并返回
    return {
      c: Math.round(c * 100),
      m: Math.round(m * 100),
      y: Math.round(y * 100),
      k: Math.round(k * 100)
    };
  }

  /**
   * 生成渐变色序列
   * @param startColor 起始颜色（HEX）
   * @param endColor 结束颜色（HEX）
   * @param steps 渐变步数
   * @returns HEX 颜色数组
   */
  static generateGradient(startColor: string, endColor: string, steps: number): string[] {
    const startRgb = ColorConverter.hexToRgb(startColor);
    const endRgb = ColorConverter.hexToRgb(endColor);
    const gradient: string[] = [];

    for (let i = 0; i < steps; i++) {
      const ratio = i / (steps - 1);
      const r = Math.round(startRgb.r + (endRgb.r - startRgb.r) * ratio);
      const g = Math.round(startRgb.g + (endRgb.g - startRgb.g) * ratio);
      const b = Math.round(startRgb.b + (endRgb.b - startRgb.b) * ratio);
      gradient.push(ColorConverter.rgbToHex(r, g, b));
    }

    return gradient;
  }
}

