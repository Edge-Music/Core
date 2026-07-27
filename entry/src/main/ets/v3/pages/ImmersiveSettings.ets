/**
 * OMSP 3.0 · 设置（对齐设计规范 §6 + 屏05/W3）
 * 断点自适应：
 *  - 窄屏：NavBar（返回 + 标题）+ 清单式分组玻璃卡片。
 *  - 宽屏：Master-Detail（左导航 + 右详情）。
 * 「推荐与隐私」含推荐模式权重可视化 + 隐私开关（真实读写偏好）。
 * 展示型深层编辑（语言/音质/EQ/DRC/声道/定时/数据源详情）桥接现有 view/Setting.ets（DRY）。
 */
import { Song, SourceConfig } from '../../type/Adapter'
import { PreferencesCache, qualityLevels, getQualityLevel, QualityLevel, BitrateType,
  SpringAnimationParams } from '../../util/PreferenceCache'
import { AmbientBackground } from '../components/AmbientBackground'
import { SongCacheManager } from '../../util/SongCacheManager'
import { ResponseCacheUtil } from '../../util/ResponseCacheUtil'
import { V3Recommend, RecMode, ModeWeights } from '../recommend/V3Recommend'
import { V3Ambient } from '../util/V3Ambient'
import { V3Color, V3Radius, V3Space, V3Theme } from '../theme/Tokens'
import { PipManager } from '../../util/PipManager'
import WindowUtil from '../../util/WindowUtil'
import { LogUtil, ToastUtil, WantUtil } from '@pura/harmony-utils'
import { BusinessError } from '@kit.BasicServicesKit'
import { bundleManager, common } from '@kit.AbilityKit'

interface NavSection {
  key: string
  title: string
  icon: Resource
}

@Component
export struct ImmersiveSettings {
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('current_playing_song') song: Song | null = null
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @StorageProp('v3_rec_mode') recMode: string = 'default'
  @StorageProp('user_data_source') dataSources: SourceConfig[] = []
  @StorageProp('v3_theme_override') themeOverride: string = 'auto'
  @StorageLink('freeWindowMode') freeWindowMode:boolean = false

  @State fadeInOut: boolean = false
  @State playQuality: number = 128000
  @State downloadQuality: number = 999000
  @State selected: string = 'privacy'
  @State appVersion: string = ''

  // 歌词设置（读写既有 prefKey，ChainLyricsViewWrapper 重进即生效）
  @State showTranslation: boolean = true
  @State lyricFont: number = 18
  @State lyricTransFont: number = 16
  @State lyricTranslitFont: number = 12
  @State lyricNormalScale: number = 0.95
  @State springPreset: string = 'default' // smooth / default / snappy
  @State pipLyricsType: number = 0

  // 歌单自动补充（队列将播完时后台续算补充；默认开启）
  @State autoTopUp: boolean = true

  // 孤儿开关（旧版启用过、3.0 曾无入口关闭）
  @State playingMix: boolean = false
  @State pressureChange: boolean = false
  @State subWindowType: number = 2 // 0左手/1智感/2右手/3关闭
  @State desktopLyrics: boolean = false

  private sections: NavSection[] = [
    { key: 'general', title: '通用', icon: $r('sys.symbol.gearshape') },
    { key: 'playback', title: '播放与音质', icon: $r('sys.symbol.music_note_list') },
    { key: 'lyrics', title: '歌词', icon: $r('sys.symbol.music_note_list') },
    { key: 'privacy', title: '推荐与隐私', icon: $r('sys.symbol.wand_and_stars') },
    { key: 'storage', title: '存储与缓存', icon: $r('sys.symbol.externaldrive_fill') },
    { key: 'source', title: '数据源管理', icon: $r('sys.symbol.externaldrive') },
    { key: 'about', title: '关于', icon: $r('sys.symbol.info_circle') }
  ]

  aboutToAppear(): void {
    this.fadeInOut = PreferencesCache.getUserPreference('fade_in_out', '0') === '1'
    this.playQuality = PreferencesCache.playingLevel()
    this.downloadQuality = PreferencesCache.downloadLevel()
    // 歌词
    this.showTranslation = PreferencesCache.showTranslationLyric()
    this.lyricFont = PreferencesCache.lyricFontSize()
    this.lyricTransFont = PreferencesCache.lyricTranslationFontSize()
    this.lyricTranslitFont = PreferencesCache.lyricTransliterationFontSize()
    this.lyricNormalScale = PreferencesCache.lyricNormalScale()
    this.springPreset = this.detectSpringPreset()
    this.pipLyricsType = parseInt(PreferencesCache.getUserPreference('pip_lyrics_type', '0'))
    this.autoTopUp = PreferencesCache.getUserPreference('v3_auto_topup', '1') === '1'
    // 孤儿开关
    this.playingMix = PreferencesCache.getUserPreference('playing_mix', '0') === '1'
    this.pressureChange = PreferencesCache.getUserPreference('pressure_change', '0') === '1'
    this.subWindowType = parseInt(PreferencesCache.getUserPreference('sub_window_show_type', '2'))
    this.desktopLyrics = PreferencesCache.getUserPreference('Lyic_desktop', '0') === '1'
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      this.appVersion = info.versionName
    } catch (e) {
      this.appVersion = ''
    }
  }

  // 依据 stiffness 反推当前滚动动画预设
  private detectSpringPreset(): string {
    const p: SpringAnimationParams = PreferencesCache.springAnimationParams()
    if (p.stiffness <= 160) {
      return 'smooth'
    }
    if (p.stiffness >= 260) {
      return 'snappy'
    }
    return 'default'
  }

  private applySpringPreset(preset: string): void {
    const base: SpringAnimationParams = PreferencesCache.springAnimationParams()
    let next: SpringAnimationParams
    if (preset === 'smooth') {
      next = { velocity: 0, mass: 0.4, stiffness: 140, damping: 20,
        lineSpacing: base.lineSpacing, highlightLineSpacing: base.highlightLineSpacing, dragDelay: 50 }
    } else if (preset === 'snappy') {
      next = { velocity: 0, mass: 0.22, stiffness: 280, damping: 12,
        lineSpacing: base.lineSpacing, highlightLineSpacing: base.highlightLineSpacing, dragDelay: 20 }
    } else {
      next = { velocity: 0, mass: 0.3, stiffness: 200, damping: 15,
        lineSpacing: base.lineSpacing, highlightLineSpacing: base.highlightLineSpacing, dragDelay: 35 }
    }
    PreferencesCache.springAnimationParams(next)
    this.springPreset = preset
  }

  // 桌面歌词（画中画）开关：写偏好并联动 PipManager 自启
  private toggleDesktopLyrics(v: boolean): void {
    this.desktopLyrics = v
    PreferencesCache.setUserPreference('Lyic_desktop', v ? '1' : '0')
    AppStorage.setOrCreate('Lyic_desktop', v ? '1' : '0')
    try {
      const ctx = this.getUIContext().getHostContext() as common.Context
      if (v) {
        PipManager.getInstance().init(ctx)
        PipManager.getInstance().setAutoStart(true)
      } else {
        PipManager.getInstance().setAutoStart(false)
      }
    } catch (e) {
      LogUtil.error('ImmersiveSettings', '桌面歌词切换失败', (e as BusinessError)?.message ?? '')
    }
  }

  private qualityMenu(): MenuElement[] {
    return qualityLevels.map((q: QualityLevel): MenuElement => {
      return {
        value: q.description,
        action: () => {
          PreferencesCache.playingLevel(q.bitrate)
          this.playQuality = q.bitrate
        }
      }
    })
  }

  private downloadMenu(): MenuElement[] {
    return qualityLevels.map((q: QualityLevel): MenuElement => {
      return {
        value: q.description,
        action: () => {
          PreferencesCache.downloadLevel(q.bitrate)
          this.downloadQuality = q.bitrate
        }
      }
    })
  }

  // 播放音质行（值胶囊在行内直接读 this.playQuality @State，保证选后即时回显）
  @Builder
  QualityRow(top: boolean) {
    Row() {
      Text('播放音质')
        .fontSize(15)
        .fontColor(V3Theme.tx1(this.mode))
        .layoutWeight(1)
      Row({ space: 4 }) {
        Text(getQualityLevel(this.playQuality) ? getQualityLevel(this.playQuality).description : $r('app.string.quality_standard'))
          .fontSize(14)
          .fontColor(V3Theme.tx2(this.mode))
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(14)
          .fontColor([V3Theme.tx3(this.mode)])
      }
      .padding({ left: 12, right: 10, top: 6, bottom: 6 })
      .borderRadius(14)
      .backgroundColor(V3Theme.glass2(this.mode))
      .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
      .bindMenu(this.qualityMenu())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 11, bottom: 11 })
    .border(top ? { width: { top: 1 }, color: V3Theme.hairline(this.mode) } : { width: 0 })
  }

  // 下载音质行
  @Builder
  DownloadQualityRow(top: boolean) {
    Row() {
      Text('下载音质')
        .fontSize(15)
        .fontColor(V3Theme.tx1(this.mode))
        .layoutWeight(1)
      Row({ space: 4 }) {
        Text(getQualityLevel(this.downloadQuality) ? getQualityLevel(this.downloadQuality).description : $r('app.string.quality_standard'))
          .fontSize(14)
          .fontColor(V3Theme.tx2(this.mode))
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(14)
          .fontColor([V3Theme.tx3(this.mode)])
      }
      .padding({ left: 12, right: 10, top: 6, bottom: 6 })
      .borderRadius(14)
      .backgroundColor(V3Theme.glass2(this.mode))
      .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
      .bindMenu(this.downloadMenu())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 11, bottom: 11 })
    .border(top ? { width: { top: 1 }, color: V3Theme.hairline(this.mode) } : { width: 0 })
  }

  private isWide(): boolean {
    return this.widthBp >= WidthBreakpoint.WIDTH_LG
  }

  private curMode(): RecMode {
    return this.recMode === 'fresh' ? 'fresh' : (this.recMode === 'familiar' ? 'familiar' : 'default')
  }

  private modeLabel(): string {
    const m: RecMode = this.curMode()
    return m === 'fresh' ? '新鲜' : (m === 'familiar' ? '熟悉' : '默认')
  }

  private curWeights(): ModeWeights {
    return V3Recommend.weightsOf(this.curMode())
  }

  // ============ 复用行 ============
  @Builder
  ToggleRow(label: string, isOn: boolean, top: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(V3Theme.tx1(this.mode))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor('#C99A57')
        .switchPointColor('#FFFFFF')
        .onChange((v: boolean) => {
          onChange(v)
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 9, bottom: 9 })
    .border(top ? { width: { top: 1 }, color: V3Theme.hairline(this.mode) } : { width: 0 })
  }

  // 滑块当前值 / 展示文本：@Builder 内直接读 @State（避免值参快照导致拖动不回显）
  private sliderValue(key: string): number {
    if (key === 'font') {
      return this.lyricFont
    }
    if (key === 'transFont') {
      return this.lyricTransFont
    }
    if (key === 'translitFont') {
      return this.lyricTranslitFont
    }
    if (key === 'scale') {
      return this.lyricNormalScale
    }
    return 0
  }

  private sliderText(key: string): string {
    if (key === 'scale') {
      return `${Math.round(this.lyricNormalScale * 100)}%`
    }
    return `${Math.round(this.sliderValue(key))}`
  }

  // 滑块行：标题 + 当前值 + Slider（值由 key 反查 @State，保证拖动即时回显）
  @Builder
  SliderRow(label: string, key: string, min: number, max: number, step: number,
    top: boolean, onChange: (v: number) => void) {
    Column({ space: 2 }) {
      Row() {
        Text(label)
          .fontSize(15)
          .fontColor(V3Theme.tx1(this.mode))
          .layoutWeight(1)
        Text(this.sliderText(key))
          .fontSize(13)
          .fontColor(V3Theme.tx2(this.mode))
      }
      .width('100%')
      Slider({ value: this.sliderValue(key), min: min, max: max, step: step })
        .blockColor('#FFFFFF')
        .selectedColor('#C99A57')
        .trackColor(V3Theme.track(this.mode))
        .trackThickness(4)
        .width('100%')
        .onChange((v: number, mode: SliderChangeMode) => {
          onChange(v)
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .border(top ? { width: { top: 1 }, color: V3Theme.hairline(this.mode) } : { width: 0 })
  }

  // 当前选中项索引：@Builder 内直接读 @State（避免值参快照导致点击不回显）
  private segIndex(groupKey: string): number {
    if (groupKey === 'subwin') {
      return this.subWindowType
    }
    if (groupKey === 'pip') {
      return this.pipLyricsType
    }
    if (groupKey === 'spring') {
      return this.springPreset === 'smooth' ? 0 : (this.springPreset === 'snappy' ? 2 : 1)
    }
    return -1
  }

  // 分段选择行：标题 + 一排 chip（选中态由 groupKey 反查 @State，保证即时回显）
  @Builder
  SegRow(label: string, options: string[], groupKey: string, top: boolean, onSelect: (i: number) => void) {
    Column({ space: 10 }) {
      Text(label)
        .fontSize(15)
        .fontColor(V3Theme.tx1(this.mode))
        .width('100%')
      Row({ space: 8 }) {
        ForEach(options, (opt: string, i: number) => {
          Text(opt)
            .fontSize(13)
            .fontColor(this.segIndex(groupKey) === i ? '#FFFFFF' : V3Theme.tx2(this.mode))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(15)
            .backgroundColor(this.segIndex(groupKey) === i ? '#C99A57' : V3Theme.glass2(this.mode))
            .border({
              width: 1,
              color: this.segIndex(groupKey) === i ? Color.Transparent : V3Theme.glassBorder(this.mode)
            })
            .onClick(() => {
              onSelect(i)
            })
        })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .border(top ? { width: { top: 1 }, color: V3Theme.hairline(this.mode) } : { width: 0 })
  }

  @Builder
  GroupHeader(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor(V3Theme.tx3(this.mode))
      .letterSpacing(1.4)
      .margin({ left: 6, top: 18, bottom: 8 })
  }

  // 歌词设置：滚动歌词外观 + 动画 + 桌面/画中画歌词
  @Builder
  LyricsSection() {
    Column() {
      this.ToggleRow('显示翻译歌词', this.showTranslation, false, (v: boolean) => {
        this.showTranslation = v
        PreferencesCache.showTranslationLyric(v)
      })
      this.SliderRow('滚动歌词字号', 'font', 12, 40, 1, true, (v: number) => {
        this.lyricFont = v
        PreferencesCache.lyricFontSize(Math.round(v))
      })
      this.SliderRow('翻译字号', 'transFont', 10, 22, 1, true, (v: number) => {
        this.lyricTransFont = v
        PreferencesCache.lyricTranslationFontSize(Math.round(v))
      })
      this.SliderRow('罗马音字号', 'translitFont', 8, 18, 1, true, (v: number) => {
        this.lyricTranslitFont = v
        PreferencesCache.lyricTransliterationFontSize(Math.round(v))
      })
      this.SliderRow('非高亮行缩放', 'scale', 0.7, 1.0, 0.01, true, (v: number) => {
        this.lyricNormalScale = v
        PreferencesCache.lyricNormalScale(v)
      })
      this.SegRow('滚动动画', ['平滑', '标准', '灵敏'], 'spring', true, (i: number) => {
        this.applySpringPreset(i === 0 ? 'smooth' : (i === 2 ? 'snappy' : 'default'))
      })
      this.SegRow('画中画歌词', ['原词', '翻译', '罗马音'], 'pip', true, (i: number) => {
        this.pipLyricsType = i
        PreferencesCache.setUserPreference('pip_lyrics_type', `${i}`)
        AppStorage.setOrCreate('pip_lyrics_type', i)
      })
      this.ToggleRow('桌面歌词（画中画自启）', this.desktopLyrics, true, (v: boolean) => {
        this.toggleDesktopLyrics(v)
      })
    }
    .width('100%')
    .borderRadius(V3Radius.CHIP)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 18, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
    .clip(true)
  }

  private themeLabel(): string {
    if (this.themeOverride === 'light') {
      return '浅色'
    }
    if (this.themeOverride === 'dark') {
      return '深色'
    }
    return '跟随封面'
  }

  private themeMenu(): MenuElement[] {
    const cover: string = this.song?.album?.cover ?? ''
    return [
      { value: '跟随封面', action: () => { V3Ambient.setThemeOverride('auto', cover) } },
      { value: '浅色', action: () => { V3Ambient.setThemeOverride('light', cover) } },
      { value: '深色', action: () => { V3Ambient.setThemeOverride('dark', cover) } }
    ]
  }

  private langMenu(): MenuElement[] {
    return [
      { value: '简体中文', action: () => { ToastUtil.showShort('当前仅支持简体中文') } }
    ]
  }

  // ============ 各分组内容 ============
  @Builder
  GeneralSection() {
    Column() {
      // 语言（暂仅简体中文）
      Row() {
        Text('语言')
          .fontSize(15)
          .fontColor(V3Theme.tx1(this.mode))
          .layoutWeight(1)
        Row({ space: 4 }) {
          Text('简体中文')
            .fontSize(14)
            .fontColor(V3Theme.tx2(this.mode))
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(14)
            .fontColor([V3Theme.tx3(this.mode)])
        }
        .padding({ left: 12, right: 10, top: 6, bottom: 6 })
        .borderRadius(14)
        .backgroundColor(V3Theme.glass2(this.mode))
        .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
        .bindMenu(this.langMenu())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 11, bottom: 11 })

      // 外观主题（跟随封面/浅色/深色，真实生效）
      Row() {
        Text('外观主题')
          .fontSize(15)
          .fontColor(V3Theme.tx1(this.mode))
          .layoutWeight(1)
        Row({ space: 4 }) {
          Text(this.themeLabel())
            .fontSize(14)
            .fontColor(V3Theme.tx2(this.mode))
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(14)
            .fontColor([V3Theme.tx3(this.mode)])
        }
        .padding({ left: 12, right: 10, top: 6, bottom: 6 })
        .borderRadius(14)
        .backgroundColor(V3Theme.glass2(this.mode))
        .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
        .bindMenu(this.themeMenu())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 11, bottom: 11 })
      .border({ width: { top: 1 }, color: V3Theme.hairline(this.mode) })

      // 悬浮子窗（旧版默认右手显示，此处提供关闭入口，并即时创建/销毁悬浮窗）
      this.SegRow('悬浮球位置', ['左手', '智感', '右手', '关闭'], 'subwin', true, (i: number) => {
        this.subWindowType = i
        PreferencesCache.setUserPreference('sub_window_show_type', `${i}`)
        AppStorage.setOrCreate('sub_window_show_type', i)
        WindowUtil.refreshMultiFuncSubWindow()
      })

      // 气压剧烈变化提醒（订阅气压计，重启后生效）
      this.ToggleRow('气压剧烈变化提醒', this.pressureChange, true, (v: boolean) => {
        this.pressureChange = v
        PreferencesCache.setUserPreference('pressure_change', v ? '1' : '0')
        if (v) {
          ToastUtil.showShort('将在下次启动后生效')
        }
      })
    }
    .width('100%')
    .borderRadius(V3Radius.CHIP)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 18, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
    .clip(true)
  }

  @Builder
  PlaybackSection() {
    Column() {
      this.QualityRow(false)
      this.DownloadQualityRow(true)
      this.ToggleRow('歌曲淡入淡出', this.fadeInOut, true, (v: boolean) => {
        this.fadeInOut = v
        PreferencesCache.setUserPreference('fade_in_out', v ? '1' : '0')
      })
      this.ToggleRow('允许同时播放（不独占音频焦点）', this.playingMix, true, (v: boolean) => {
        this.playingMix = v
        PreferencesCache.setUserPreference('playing_mix', v ? '1' : '0')
      })
      this.ToggleRow('歌单自动补充（将播完时续算推荐）', this.autoTopUp, true, (v: boolean) => {
        this.autoTopUp = v
        PreferencesCache.setUserPreference('v3_auto_topup', v ? '1' : '0')
      })
    }
    .width('100%')
    .borderRadius(V3Radius.CHIP)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 18, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
    .clip(true)
  }

  // 存储与缓存（迁移自旧 PlayerSetting / SoftwareSetting）
  @Builder
  StorageSection() {
    Column() {
      this.ActionRow('清除歌曲缓存', false, async () => {
        const size: number = SongCacheManager.size()
        if (size > 0) {
          await SongCacheManager.clear()
          ToastUtil.showShort(`已清除 ${size} 首歌曲缓存`)
        } else {
          ToastUtil.showShort('暂无歌曲缓存')
        }
      })
      this.ActionRow('清除请求缓存', true, () => {
        const size: number = ResponseCacheUtil.size()
        if (size > 0) {
          ResponseCacheUtil.clear()
          ToastUtil.showShort(`已清除 ${size} 个请求缓存`)
        } else {
          ToastUtil.showShort('暂无请求缓存')
        }
      })
    }
    .width('100%')
    .borderRadius(V3Radius.CHIP)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 18, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
    .clip(true)
  }

  // 通用「操作行」（右侧 chevron，点击触发动作）
  @Builder
  ActionRow(label: string, top: boolean, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(V3Theme.tx1(this.mode))
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([V3Theme.tx3(this.mode)])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 13, bottom: 13 })
    .border(top ? { width: { top: 1 }, color: V3Theme.hairline(this.mode) } : { width: 0 })
    .onClick(onTap)
  }

  @Builder
  WeightBar(label: string, pct: number, colorHex: string, emphasize: boolean) {
    Column() {
      Row() {
        Text(label)
          .fontSize(14)
          .fontColor(V3Theme.tx1(this.mode))
        Blank()
        Text(`${pct}%`)
          .fontSize(13)
          .fontColor(emphasize ? V3Theme.accentFallback(this.mode) : V3Theme.tx2(this.mode))
      }
      .width('100%')
      .margin({ bottom: 8 })
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(8).borderRadius(4).backgroundColor(V3Theme.track(this.mode))
        Row().width(`${pct}%`).height(8).borderRadius(4).backgroundColor(colorHex)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  PrivacySection() {
    Column() {
      // 权重可视化（真实反映当前推荐模式的 §7.4 权重构成）
      Column() {
        Row() {
          Text('推荐模式权重')
            .fontSize(15)
            .fontColor(V3Theme.tx1(this.mode))
          Blank()
          Text(`${this.modeLabel()}模式 · 生效中`)
            .fontSize(12)
            .fontColor(V3Theme.accentFallback(this.mode))
        }
        .width('100%')
        .margin({ bottom: 16 })

        this.WeightBar('常听频次', Math.round(this.curWeights().frequency * 100), '#D4A962', true)
        Row().height(12)
        this.WeightBar('最近在听', Math.round(this.curWeights().recency * 100), '#C1914C', false)
        Row().height(12)
        this.WeightBar('风格偏好', Math.round(this.curWeights().affinity * 100), '#8A8074', false)
        Row().height(12)
        this.WeightBar('新鲜探索', Math.round(this.curWeights().novelty * 100), '#7FB08A', false)
        Row().height(12)
        this.WeightBar('歌词语义', Math.round(this.curWeights().lyricAffinity * 100), '#C77FB0', false)
        Row().height(12)
        this.WeightBar('榜单热度', Math.round(this.curWeights().chartBoost * 100), '#6E5BFF', false)
      }
      .width('100%')
      .padding(16)

      // 说明：推荐全部本地计算、默认强制开启（无需开关）
      Row() {
        SymbolGlyph($r('sys.symbol.checkmark_shield'))
          .fontSize(14)
          .fontColor(['#7FB08A'])
          .margin({ right: 8 })
        Text('推荐全部在本地计算，不上传收听数据')
          .fontSize(12.5)
          .fontColor(V3Theme.tx3(this.mode))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 14 })
      .border({ width: { top: 1 }, color: V3Theme.hairline(this.mode) })
    }
    .width('100%')
    .borderRadius(V3Radius.CHIP)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 18, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
    .clip(true)
  }

  private openSourceManager(): void {
    this.pageStack.pushPath({ name: 'ImmersiveSourceManager' }, { animated: true })
  }

  @Builder
  SourceSection() {
    Column() {
      Row() {
        Text('管理数据源')
          .fontSize(15)
          .fontColor(V3Theme.tx1(this.mode))
          .layoutWeight(1)
        Text(`${this.dataSources.length} 个`)
          .fontSize(13)
          .fontColor(V3Theme.tx2(this.mode))
          .margin({ right: 8 })
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([V3Theme.tx3(this.mode)])
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .onClick(() => {
        this.openSourceManager()
      })

      Row() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(18)
          .fontColor([V3Theme.accentFallback(this.mode)])
          .margin({ right: 10 })
        Text('添加数据源')
          .fontSize(15)
          .fontColor(V3Theme.accentFallback(this.mode))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .border({ width: { top: 1 }, color: V3Theme.hairline(this.mode) })
      .onClick(() => {
        this.openSourceManager()
      })
    }
    .width('100%')
    .borderRadius(V3Radius.CHIP)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 18, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
    .clip(true)
  }

  private openWeb(url: string): void {
    WantUtil.toWebBrowser(url).catch((err: BusinessError) => {
      LogUtil.error('ImmersiveSettings', '拉起浏览器失败', err.message)
      ToastUtil.showShort('跳转浏览器失败')
    })
  }

  @Builder
  AboutSection() {
    Column() {
      Row() {
        Text('版本')
          .fontSize(15)
          .fontColor(V3Theme.tx1(this.mode))
          .layoutWeight(1)
        Text(this.appVersion)
          .fontSize(14)
          .fontColor(V3Theme.tx3(this.mode))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })

      this.ActionRow('意见反馈', true, () => {
        this.openWeb('https://music.yby.zone/feedback.html')
      })
      this.ActionRow('隐私政策', true, () => {
        this.openWeb('https://music.yby.zone/policy.html')
      })
    }
    .width('100%')
    .borderRadius(V3Radius.CHIP)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 18, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
    .clip(true)
  }

  // 直接读 this.selected（@State），避免 @Builder 值参快照导致右栏不切换
  @Builder
  SectionBody() {
    if (this.selected === 'general') {
      this.GeneralSection()
    } else if (this.selected === 'playback') {
      this.PlaybackSection()
    } else if (this.selected === 'lyrics') {
      this.LyricsSection()
    } else if (this.selected === 'privacy') {
      this.PrivacySection()
    } else if (this.selected === 'storage') {
      this.StorageSection()
    } else if (this.selected === 'source') {
      this.SourceSection()
    } else {
      this.AboutSection()
    }
  }

  private sectionTitle(key: string): string {
    for (const s of this.sections) {
      if (s.key === key) {
        return s.title
      }
    }
    return ''
  }

  // ============ 窄屏 ============
  @Builder
  PhoneLayout() {
    Column() {
      // NavBar
      Stack() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([V3Theme.tx1(this.mode)])
            .onClick(() => {
              this.pageStack.pop()
            })
          Blank()
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        Text('设置')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
      }
      .width('100%')
      .height(52)
      .border({ width: { bottom: 1 }, color: V3Theme.hairline(this.mode) })

      Scroll() {
        Column() {
          this.GroupHeader('通用')
          this.GeneralSection()
          this.GroupHeader('播放与音质')
          this.PlaybackSection()
          this.GroupHeader('歌词')
          this.LyricsSection()
          this.GroupHeader('推荐与隐私')
          this.PrivacySection()
          this.GroupHeader('存储与缓存')
          this.StorageSection()
          this.GroupHeader('数据源管理')
          this.SourceSection()
          this.GroupHeader('关于')
          this.AboutSection()
          Row().height(this.bottomRect + 24)
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topRect })
  }

  // ============ 宽屏 Master-Detail ============
  @Builder
  WideLayout() {
    Row() {
      // 左导航
      Column({ space: 6 }) {
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .margin({ left: 12, bottom: 14 })
        ForEach(this.sections, (s: NavSection) => {
          Row({ space: 12 }) {
            SymbolGlyph(s.icon)
              .fontSize(19)
              .fontColor([this.selected === s.key ? V3Theme.accentFallback(this.mode) : V3Theme.tx2(this.mode)])
            Text(s.title)
              .fontSize(15)
              .fontWeight(this.selected === s.key ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.selected === s.key ? V3Theme.accentFallback(this.mode) : V3Theme.tx2(this.mode))
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .borderRadius(14)
          .backgroundColor(this.selected === s.key
            ? (V3Theme.isLight(this.mode) ? 'rgba(169,122,52,0.14)' : 'rgba(255,255,255,0.12)')
            : 'rgba(0,0,0,0)')
          .border({
            width: 1,
            color: this.selected === s.key ? 'rgba(201,154,87,0.55)' : 'rgba(0,0,0,0)'
          })
          .onClick(() => {
            this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.selected = s.key })
          })
        }, (s: NavSection) => s.key)
      }
      .width(300)
      .height('100%')
      .padding({ left: 20, right: 20, top: this.topRect + 34, bottom: this.bottomRect + 24 })
      .backgroundColor(V3Theme.panel(this.mode))
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, { colorMode: V3Theme.blurMode(this.mode) })

      // 右详情
      Column() {
        Text(this.sectionTitle(this.selected))
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .margin({ bottom: 20 })
        Scroll() {
          Column() {
            this.SectionBody()
            Row().height(this.bottomRect + 24)
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)
      }
      .layoutWeight(1)
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 44, right: 44, top: this.topRect + 40 })

      // // 右上关闭
      // SymbolGlyph($r('sys.symbol.xmark'))
      //   .fontSize(18)
      //   .fontColor([V3Theme.tx2(this.mode)])
      //   .margin({ top: this.topRect + 26, right: 28 })
      //   .onClick(() => {
      //     this.pageStack.pop()
      //   })
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    NavDestination() {
      Stack() {
        AmbientBackground({
          coverUrl: this.song?.album?.cover ?? '',
          mode: this.mode,
          blurRadius: 72,
          brightnessVal: 0.5,
          saturateVal: 0.42,
          showGlow: false,
          dim: 0.32
        })

        if (this.isWide()) {
          this.WideLayout()
        } else {
          this.PhoneLayout()
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(this.freeWindowMode&&this.isWide()?false:true)
    .title("",{barStyle:BarStyle.STACK})
    .backgroundColor(V3Color.CANVAS)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
