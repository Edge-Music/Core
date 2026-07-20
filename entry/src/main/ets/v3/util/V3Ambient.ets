/**
 * 光感取色 Provider（对齐设计规范 §1.2 / §7.5）
 * 从当前播放封面提取主色，做明度/饱和度兜底修正后写入 AppStorage，
 * 供 v3 播控/进度条/歌词高亮消费。取色仅服务视觉层，不参与推荐打分。
 */
import { http } from '@kit.NetworkKit'
import { image } from '@kit.ImageKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { deviceInfo } from '@kit.BasicServicesKit'
import { ColorExtractor, ExtractedColor } from '../../util/ColorExtractor'
import { cover } from '../../util/AdapterHelper'
import { PreferencesCache } from '../../util/PreferenceCache'
import { V3Color, V3AmbientKey } from '../theme/Tokens'

interface RGB {
  r: number
  g: number
  b: number
}

export class V3Ambient {
  private static lastCover: string = ''

  /**
   * 依据封面刷新光感 accent。歌曲切换时调用。
   * @param coverUrl 封面地址（原始 song.album.cover）
   */
  static updateFromCover(coverUrl?: string): void {
    if (!coverUrl) {
      V3Ambient.applyFallback()
      return
    }
    // effectKit 取色需 API 20+，低版本直接兜底
    if (deviceInfo.sdkApiVersion <= 19) {
      V3Ambient.applyFallback()
      return
    }
    const uri: string = cover(coverUrl, 100) as string
    if (uri === V3Ambient.lastCover) {
      return
    }
    V3Ambient.lastCover = uri

    http.createHttp().request(uri, (error: BusinessError, data: http.HttpResponse) => {
      if (error || data.responseCode !== http.ResponseCode.OK) {
        V3Ambient.applyFallback()
        return
      }
      const buffer: ArrayBuffer = data.result as ArrayBuffer
      const source: image.ImageSource = image.createImageSource(buffer)
      const options: image.InitializationOptions = {
        alphaType: 0,
        editable: false,
        pixelFormat: 3,
        scaleMode: 1,
        size: { height: 100, width: 100 }
      }
      source.createPixelMap(options).then((pixelMap: image.PixelMap) => {
        ColorExtractor.extractColors(pixelMap, 3).then((colors: ExtractedColor[]) => {
          const accent: string = V3Ambient.pickAccent(colors)
          V3Ambient.apply(accent)
          // 跟随封面明度决定深/浅主题（设计规范 §2.3），但尊重用户手动覆盖
          AppStorage.setOrCreate(V3AmbientKey.MODE, V3Ambient.resolveMode(V3Ambient.detectMode(colors)))
        }).catch(() => {
          V3Ambient.applyFallback()
        })
      }).catch(() => {
        V3Ambient.applyFallback()
      })
    })
  }

  /**
   * 从候选色中挑选一个明度足够、适合深色环境高光的 accent。
   * 过暗则提亮，保证控件对比度（近似 §2.3 WCAG 兜底策略的轻量实现）。
   */
  private static pickAccent(colors: ExtractedColor[]): string {
    if (!colors || colors.length === 0) {
      return V3Color.ACCENT_FALLBACK
    }
    let best: RGB | null = null
    let bestScore: number = -1
    for (const c of colors) {
      const rgb: RGB | null = V3Ambient.hexToRgb(c.hex)
      if (!rgb) {
        continue
      }
      const lum: number = V3Ambient.luminance(rgb)
      const sat: number = V3Ambient.saturation(rgb)
      // 偏好中高明度 + 有一定饱和度，避免灰暗或纯白
      const score: number = sat * 0.6 + (1 - Math.abs(lum - 0.62)) * 0.4
      if (score > bestScore) {
        bestScore = score
        best = rgb
      }
    }
    if (!best) {
      return V3Color.ACCENT_FALLBACK
    }
    return V3Ambient.rgbToHex(V3Ambient.normalizeForDark(best))
  }

  /** 提亮过暗的取色结果，压制过曝，锁定在悦目区间 */
  private static normalizeForDark(rgb: RGB): RGB {
    let lum: number = V3Ambient.luminance(rgb)
    let scale: number = 1
    if (lum < 0.45) {
      scale = 0.45 / Math.max(lum, 0.08)
    } else if (lum > 0.85) {
      scale = 0.85 / lum
    }
    return {
      r: Math.min(255, Math.round(rgb.r * scale)),
      g: Math.min(255, Math.round(rgb.g * scale)),
      b: Math.min(255, Math.round(rgb.b * scale))
    }
  }

  private static apply(accent: string): void {
    const rgb: RGB | null = V3Ambient.hexToRgb(accent)
    const glow: string = rgb ? `rgba(${rgb.r},${rgb.g},${rgb.b},0.60)` : V3Color.ACCENT_GLOW
    AppStorage.setOrCreate(V3AmbientKey.ACCENT, accent)
    AppStorage.setOrCreate(V3AmbientKey.GLOW, glow)
  }

  private static applyFallback(): void {
    AppStorage.setOrCreate(V3AmbientKey.ACCENT, V3Color.ACCENT_FALLBACK)
    AppStorage.setOrCreate(V3AmbientKey.GLOW, V3Color.ACCENT_GLOW)
    AppStorage.setOrCreate(V3AmbientKey.MODE, V3Ambient.resolveMode('dark'))
  }

  /** 主题覆盖：v3_theme_override = 'auto'(跟随封面) | 'light' | 'dark' */
  static resolveMode(detected: string): string {
    const ov: string = AppStorage.get<string>('v3_theme_override') ?? 'auto'
    if (ov === 'light') {
      return 'light'
    }
    if (ov === 'dark') {
      return 'dark'
    }
    return detected
  }

  /** 设置主题覆盖并立即生效（light/dark 直接锁；auto 重新按封面取色）+ 持久化 */
  static setThemeOverride(override: string, coverUrl?: string): void {
    AppStorage.setOrCreate('v3_theme_override', override)
    PreferencesCache.setUserPreference('v3_theme_override', override)
    if (override === 'light' || override === 'dark') {
      AppStorage.setOrCreate(V3AmbientKey.MODE, override)
    } else {
      // 跟随封面：清缓存重新取色
      V3Ambient.lastCover = ''
      V3Ambient.updateFromCover(coverUrl)
    }
  }

  /** 启动时从偏好载入主题覆盖到 AppStorage（供 resolveMode 读取），需在首帧前调用 */
  static loadThemeOverride(): void {
    const ov: string = PreferencesCache.getUserPreference('v3_theme_override', 'auto')
    AppStorage.setOrCreate('v3_theme_override', ov)
  }

  /** 跟随封面：封面平均明度高 → 浅色主题，否则深色 */
  private static detectMode(colors: ExtractedColor[]): string {
    if (!colors || colors.length === 0) {
      return 'dark'
    }
    let sum: number = 0
    let weight: number = 0
    for (const c of colors) {
      const rgb: RGB | null = V3Ambient.hexToRgb(c.hex)
      if (!rgb) {
        continue
      }
      const w: number = c.count > 0 ? c.count : 1
      sum += V3Ambient.luminance(rgb) * w
      weight += w
    }
    if (weight === 0) {
      return 'dark'
    }
    return (sum / weight) > 0.52 ? 'light' : 'dark'
  }

  // ---------- 颜色工具 ----------
  private static hexToRgb(hex: string): RGB | null {
    if (!hex) {
      return null
    }
    let h: string = hex.charAt(0) === '#' ? hex.substring(1) : hex
    // 支持 #AARRGGBB / #RRGGBB
    if (h.length === 8) {
      h = h.substring(2)
    }
    if (h.length !== 6) {
      return null
    }
    const r: number = parseInt(h.substring(0, 2), 16)
    const g: number = parseInt(h.substring(2, 4), 16)
    const b: number = parseInt(h.substring(4, 6), 16)
    if (isNaN(r) || isNaN(g) || isNaN(b)) {
      return null
    }
    return { r, g, b }
  }

  private static rgbToHex(rgb: RGB): string {
    const to2 = (n: number): string => {
      const s: string = Math.max(0, Math.min(255, n)).toString(16)
      return s.length === 1 ? '0' + s : s
    }
    return `#${to2(rgb.r)}${to2(rgb.g)}${to2(rgb.b)}`
  }

  /** 感知亮度 0~1 */
  private static luminance(rgb: RGB): number {
    return (0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b) / 255
  }

  /** 饱和度 0~1 */
  private static saturation(rgb: RGB): number {
    const max: number = Math.max(rgb.r, rgb.g, rgb.b)
    const min: number = Math.min(rgb.r, rgb.g, rgb.b)
    if (max === 0) {
      return 0
    }
    return (max - min) / max
  }
}
