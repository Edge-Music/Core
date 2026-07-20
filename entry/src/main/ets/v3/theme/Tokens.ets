/**
 * OMSP 3.0 设计 Token（沉浸 · 光感 · 液态玻璃）
 * 对齐《OMSP-3.0-设计规范.md》§2 色彩与视觉 Token 体系。
 *
 * 本轮仅落地深色主题（旗舰：播放页 + 歌词页）。浅色主题与语义三层 Token
 * 后续迭代补齐。此处以「暖金光感」作为设计稿展示态的兜底 accent，
 * 运行时由 [[V3Ambient]] 依据封面取色覆盖。
 */

// ============ 圆角 ============
export class V3Radius {
  static readonly CARD: number = 26      // 主播放卡片
  static readonly SHEET: number = 32     // 抽屉/弹层顶部
  static readonly CONTROL: number = 28   // 播控条（近似胶囊）
  static readonly CHIP: number = 16      // 榜单/模式 Chip
  static readonly AVATAR: number = 22    // 头像/圆形按钮
}

// ============ 模糊 ============
export class V3Blur {
  static readonly SURFACE: number = 28   // 主浮层
  static readonly AMBIENT: number = 44   // 背景环境层
}

// ============ 间距 ============
export class V3Space {
  static readonly XS: number = 4
  static readonly S: number = 8
  static readonly M: number = 16
  static readonly L: number = 24
  static readonly XL: number = 32
}

// ============ 动效 ============
export class V3Motion {
  static readonly STANDARD_DURATION: number = 320
  static readonly LIQUID_DURATION: number = 480
  static readonly AMBIENT_DURATION: number = 500  // 光感取色过渡
}

// ============ 深色主题色彩（liquid glass 表现最强） ============
export class V3Color {
  // 文本
  static readonly TEXT_PRIMARY: string = '#FFFFFF'
  static readonly TEXT_SECONDARY: string = 'rgba(255,255,255,0.64)'
  static readonly TEXT_TERTIARY: string = 'rgba(255,255,255,0.40)'
  static readonly TEXT_FAINT: string = 'rgba(255,255,255,0.26)'

  // 玻璃材质
  static readonly GLASS_SURFACE_1: string = 'rgba(255,255,255,0.09)'
  static readonly GLASS_SURFACE_2: string = 'rgba(255,255,255,0.14)'
  static readonly GLASS_BORDER: string = 'rgba(255,255,255,0.16)'
  static readonly GLASS_HIGHLIGHT: string = 'rgba(255,255,255,0.34)'
  static readonly GLASS_INNER_LINE: string = 'rgba(255,255,255,0.05)'

  // 进度轨道
  static readonly CONTROL_TRACK: string = 'rgba(255,255,255,0.18)'

  // 光感暖金兜底（取色前的设计稿展示态）
  static readonly ACCENT_FALLBACK: string = '#D8B072'
  static readonly ACCENT_GRAD_START: string = '#B98D47'
  static readonly ACCENT_GRAD_END: string = '#D4A962'
  static readonly PLAY_GRAD_START: string = '#D3A860'
  static readonly PLAY_GRAD_END: string = '#C1914C'
  static readonly PLAY_ICON: string = '#2A1F0E'
  static readonly ACCENT_GLOW: string = 'rgba(216,176,114,0.60)'

  // 环境
  static readonly CANVAS: string = '#0A0A0D'
  static readonly ONLINE_DOT: string = '#7FB08A'
  static readonly SHADOW_AMBIENT: string = 'rgba(0,0,0,0.45)'
}

// ============ 光感取色 AppStorage 键 ============
export class V3AmbientKey {
  // 当前封面提取的高光 accent（十六进制字符串）
  static readonly ACCENT: string = 'v3_ambient_accent'
  // accent 的发光色（rgba）
  static readonly GLOW: string = 'v3_ambient_glow'
  // 主题模式：'dark' | 'light'（跟随封面明度，见设计规范 §2.3）
  static readonly MODE: string = 'v3_theme_mode'
}

/**
 * 主题感知色彩（深/浅双主题，对齐设计规范 §2.2/§2.3）
 * 组件持 @StorageProp('v3_theme_mode') 读取 mode，用 V3Theme.xxx(mode) 取色，
 * 主题切换时随 @StorageProp 响应式刷新。accent 仍由封面取色覆盖。
 */
export class V3Theme {
  static isLight(mode: string): boolean {
    return mode === 'light'
  }

  // 文本
  static tx1(mode: string): string {
    return mode === 'light' ? '#0A0A0D' : '#FFFFFF'
  }
  static tx2(mode: string): string {
    return mode === 'light' ? 'rgba(10,10,13,0.60)' : 'rgba(255,255,255,0.64)'
  }
  static tx3(mode: string): string {
    return mode === 'light' ? 'rgba(10,10,13,0.38)' : 'rgba(255,255,255,0.40)'
  }
  static txFaint(mode: string): string {
    return mode === 'light' ? 'rgba(10,10,13,0.26)' : 'rgba(255,255,255,0.26)'
  }

  // 玻璃材质
  // 浅色：半透明白填充（保留磨砂玻璃通透感）+ 可见深色发丝边 + 投影 共同定义卡片，
  // 通透性由较低不透明度提供，清晰度由边框/投影/磨砂模糊保证（不再用高不透明白块）。
  static glass1(mode: string): string {
    return mode === 'light' ? 'rgba(255,255,255,0.58)' : 'rgba(255,255,255,0.09)'
  }
  static glass2(mode: string): string {
    return mode === 'light' ? 'rgba(255,255,255,0.75)' : 'rgba(255,255,255,0.14)'
  }
  // 卡片磨砂材质（浅色卡片叠加此模糊即得通透玻璃质感；用在直接盖在环境层上的卡片）
  static cardBlur(): BlurStyle {
    return BlurStyle.COMPONENT_ULTRA_THICK
  }
  // 边框：浅色改为可见的深色发丝线（原来是白色贴白底＝隐形）
  static glassBorder(mode: string): string {
    return mode === 'light' ? 'rgba(10,10,13,0.12)' : 'rgba(255,255,255,0.16)'
  }
  static glassInner(mode: string): string {
    return mode === 'light' ? 'rgba(10,10,13,0.06)' : 'rgba(255,255,255,0.05)'
  }
  static hairline(mode: string): string {
    return mode === 'light' ? 'rgba(10,10,13,0.10)' : 'rgba(255,255,255,0.10)'
  }

  // 进度轨道
  static track(mode: string): string {
    return mode === 'light' ? 'rgba(10,10,13,0.14)' : 'rgba(255,255,255,0.18)'
  }

  // 环境底色
  static canvas(mode: string): string {
    return mode === 'light' ? '#EDEAE4' : '#0A0A0D'
  }

  // 卡片投影色（浅色用柔和暖灰投影拉开层级；深色用黑投影）
  static cardShadow(mode: string): string {
    return mode === 'light' ? 'rgba(40,34,24,0.14)' : 'rgba(0,0,0,0.35)'
  }

  // 侧栏/面板容器填充（比卡片更淡一档，配合模糊）
  static panel(mode: string): string {
    return mode === 'light' ? 'rgba(255,255,255,0.60)' : 'rgba(255,255,255,0.06)'
  }

  // 模糊层的颜色模式（浅色主题用 LIGHT，避免玻璃发灰发暗）
  static blurMode(mode: string): ThemeColorMode {
    return mode === 'light' ? ThemeColorMode.LIGHT : ThemeColorMode.DARK
  }

  // 暖金 accent 兜底（浅色下用更深的铜色保证对比度）
  static accentFallback(mode: string): string {
    return mode === 'light' ? '#A97A34' : '#D8B072'
  }

  // 播放大圆钮渐变 + 图标色（浅色=深铜底白图标；深色=亮金底深图标）
  static playGradStart(mode: string): string {
    return mode === 'light' ? '#C1934F' : '#D3A860'
  }
  static playGradEnd(mode: string): string {
    return mode === 'light' ? '#9C6F2D' : '#C1914C'
  }
  static playIcon(mode: string): string {
    return mode === 'light' ? '#FFFFFF' : '#2A1F0E'
  }
  static accentGradStart(mode: string): string {
    return mode === 'light' ? '#A97A34' : '#B98D47'
  }
  static accentGradEnd(mode: string): string {
    return mode === 'light' ? '#C1914C' : '#D4A962'
  }
}
