/**
 * 链式歌词组件包装器
 * 封装 miscutils 中的 ChainLyricsView，适配主工程的数据源和配置
 *
 * 使用方式：
 * 将 import { LyricsView } from '../component/LyricsView'
 * 替换为 import { LyricsView } from '../component/ChainLyricsViewWrapper'
 */

import {
  ChainLyricsView as BaseChainLyricsView,
  LyricLine,
  ChainLyricsConfig,
  LyricTheme,
  DEFAULT_CONFIG,
  DEFAULT_THEME
} from '@ospark/misc-utils'
import { PreferencesCache, SpringAnimationParams as AppSpringAnimationParams } from '../util/PreferenceCache'
import { avPlayerManager } from '../util/AVPlayerManager'
import { EventHelper } from '../util/EventHelper'
import LyricsManager from '../util/LyricsManager'
import { VibrationControl } from '../util/DeviceController'
import { ToastUtil } from '@pura/harmony-utils'

/**
 * 将主工程的 LyricsLine 转换为 miscutils 的 LyricLine 格式
 */
interface AppLyricsLine {
  time: number
  text: string
  translation?: string
  transliteration?: string
}

/** Slider 参数接口 */
interface SliderParams {
  label: string
  value: number
  min: number
  max: number
  step: number
  suffix?: string
  onChange?: (value: number) => void
}

@Component
export struct LyricsView {
  /** 是否显示设置按钮（mode_judge 为 true 时显示翻译按钮和设置按钮） */
  @Prop mode_judge: boolean = false
  /** 高亮行发光颜色（默认白色微光；OMSP 3.0 沉浸页传入封面光感色实现暖金发光） */
  @Prop glowColor: string = 'rgba(255, 255, 255, 0.6)'
  /** 高亮行发光半径 */
  @Prop glowRadius: number = 12
  /** 普通行/高亮行文字色（浅色主题传入深色，实现深底白/浅底深） */
  @Prop normalColor: string = 'rgba(255, 255, 255, 0.85)'
  @Prop highlightColor: string = '#FFFFFF'
  /** 屏幕方向 */
  @Prop screenOrientation: string = 'landscape'
  /** 用户交互（手动滚动 / 点击歌词行）回调，供外部显示播控/进度条等 */
  onInteract?: () => void
  /**
   * 是否处于可见/活动状态（默认 true）。
   * 离屏时（如 Swiper 另一页）冻结索引同步：组件不会每次切行都跑链式动画；
   * 重新可见时直接跳转到当前行（resetSignal 直跳，避免长距离链式补偿动画阻塞主线程、引发播放卡顿）
   */
  @Prop @Watch('onActiveChange') active: boolean = true

  // ==================== AppStorage 数据源 ====================
  @StorageProp('current_parsed_lyrics') @Watch('onLyricsDataChange') private parsedLyrics: AppLyricsLine[] = []
  @StorageProp('current_lyrics_has_translation') private hasTranslation: boolean = false
  @StorageProp('current_lyrics_has_transliteration') private hasTransliteration: boolean = false
  @StorageLink('current_lyrics_index') @Watch('onLyricIndexChange') currentLyricsIndex: number = 0
  @StorageProp('winHeight') winHeight: number = 0

  // ==================== 配置状态 ====================
  @State private showTranslation: boolean = PreferencesCache.showTranslationLyric()
  @State private springParams: AppSpringAnimationParams = PreferencesCache.springAnimationParams()
  @State private lyricFontSize: number = PreferencesCache.lyricFontSize()
  @State private lyricNormalScale: number = PreferencesCache.lyricNormalScale()
  @State private lyricTranslationFontSize: number = PreferencesCache.lyricTranslationFontSize()
  @State private lyricTransliterationFontSize: number = PreferencesCache.lyricTransliterationFontSize()

  // ==================== 内部状态 ====================
  @State private showSpringSettings: boolean = false
  @State private currentLyricsOffsetTime: number = PreferencesCache.currentLyricsOffsetTime()
  @State private lastLyricsOffsetTime: number = PreferencesCache.currentLyricsOffsetTime()
  @State private showTranslateBtn: boolean = false
  @State private isManualScroll: boolean = false
  @State private resetSignal: number = 0
  @State private lastStep: number = 0
  @State private isShow: boolean = false

  // ==================== 窗口化 + 离屏冻结 ====================
  // 歌词组件内部用 ForEach 一次性创建全部行并维护逐行位置状态，歌曲播到后段时
  // 组件出现/切页要一次建几百行 + 长距离补偿动画，主线程长时间阻塞会把
  // Free-PCM 的 writeData 回调（跑在主线程）饿死 → 播放卡顿。
  // 这里只传当前行附近的窗口（60 行），把首屏行数和索引相关的工作量都限制住。
  /** 歌词窗口大小（行） */
  private static readonly WIN_SIZE: number = 60
  /** 当前行在窗口中的目标偏移（上方保留 20 行） */
  private static readonly WIN_ABOVE: number = 20
  /** 搬窗滞回：当前行距窗口边缘小于该值才搬，避免每切一行都重建窗口 */
  private static readonly WIN_HYSTERESIS: number = 8
  /** 全量扩展：每块追加的行数与间隔——把全量重建摊成小碎块，避免一次性长阻塞饿死音频回调 */
  private static readonly EXPAND_CHUNK: number = 80
  private static readonly EXPAND_DELAY: number = 250
  /** 转发给歌词组件的镜像索引（绝对索引）；离屏时冻结 */
  @State private mirroredIndex: number = 0
  /** 窗口起点（全量歌词中的绝对索引） */
  @State private winStart: number = 0
  /** 窗口化后的歌词（仅在搬窗/换歌时重算：build 里 slice 会产生新数组，每帧触发组件 onLyricsChange） */
  @State private winLyrics: AppLyricsLine[] = []
  /** 全量扩展定时器 */
  private expandTimer: number = -1

  // 翻译按钮自动隐藏定时器
  private translateBtnTimeoutId: number = -1

  // 字体大小节流更新
  private fontSizeUpdateTimer: number = -1
  private pendingFontSize: number = 18
  private normalScaleUpdateTimer: number = -1
  private pendingNormalScale: number = 0.95
  private translationFontSizeUpdateTimer: number = -1
  private pendingTranslationFontSize: number = 16
  private transliterationFontSizeUpdateTimer: number = -1
  private pendingTransliterationFontSize: number = 12

  // ==================== 生命周期 ====================
  aboutToAppear() {
    this.pendingFontSize = this.lyricFontSize
    this.pendingNormalScale = this.lyricNormalScale
    this.pendingTranslationFontSize = this.lyricTranslationFontSize
    this.pendingTransliterationFontSize = this.lyricTransliterationFontSize
    // 窗口定位到当前行附近，首屏只建窗口内的行
    this.recomputeWindow(this.currentLyricsIndex)
    this.mirroredIndex = this.currentLyricsIndex
    // 挂载后直跳当前行：抑制组件从第 0 行到当前行的长距离链式补偿动画
    setTimeout(() => {
      this.resetSignal++
    }, 60)
    // 首屏稳定后分块扩展到全量歌词，保证手动滑动能看到整首
    this.scheduleExpand()
  }

  aboutToDisappear() {
    if (this.expandTimer !== -1) {
      clearTimeout(this.expandTimer)
      this.expandTimer = -1
    }
  }

  /** 是否已扩到全量歌词 */
  private isFullLyrics(): boolean {
    const n: number = this.parsedLyrics?.length ?? 0
    return n > 0 && this.winStart === 0 && this.winLyrics.length === n
  }

  /** 调度一次全量扩展（手动滑动中顺延，避免拖拽中途重建） */
  private scheduleExpand(): void {
    if (this.expandTimer !== -1) {
      clearTimeout(this.expandTimer)
    }
    this.expandTimer = setTimeout(() => {
      this.expandTimer = -1
      if (this.isManualScroll) {
        this.scheduleExpand()
        return
      }
      this.expandStep()
    }, LyricsView.EXPAND_DELAY) as number
  }

  /**
   * 分块扩展一步：先向下 append（相对索引不变、无视觉跳动），
   * 到底后再向上 prepend（组件按当前行重新居中），每块 EXPAND_CHUNK 行
   */
  private expandStep(): void {
    const n: number = this.parsedLyrics?.length ?? 0
    if (n === 0 || this.isFullLyrics()) {
      return
    }
    const downRemaining: number = n - this.winStart - this.winLyrics.length
    if (downRemaining > 0) {
      const newLen: number = this.winLyrics.length + Math.min(downRemaining, LyricsView.EXPAND_CHUNK)
      this.winLyrics = this.parsedLyrics.slice(this.winStart, this.winStart + newLen)
      this.scheduleExpand()
      return
    }
    if (this.winStart > 0) {
      const shift: number = Math.min(this.winStart, LyricsView.EXPAND_CHUNK)
      const newStart: number = this.winStart - shift
      this.winLyrics = this.parsedLyrics.slice(newStart, newStart + shift + this.winLyrics.length)
      this.winStart = newStart
      this.scheduleExpand()
    }
  }

  /** 按需搬窗：当前行接近窗口边缘才移动窗口（滞回 WIN_HYSTERESIS 行） */
  private recomputeWindow(idx: number): void {
    const n: number = this.parsedLyrics?.length ?? 0
    // 已扩到全量：不再搬窗/收窄
    if (this.isFullLyrics()) {
      return
    }
    if (n <= LyricsView.WIN_SIZE) {
      // 短歌词整量传入（与普通歌曲行为一致）
      if (this.winLyrics.length !== n) {
        this.winStart = 0
        this.winLyrics = this.parsedLyrics.slice(0)
      }
      return
    }
    if (this.winLyrics.length > 0 &&
      idx >= this.winStart + LyricsView.WIN_HYSTERESIS &&
      idx <= this.winStart + this.winLyrics.length - LyricsView.WIN_HYSTERESIS) {
      return
    }
    const start: number = Math.max(0, Math.min(idx - LyricsView.WIN_ABOVE, n - LyricsView.WIN_SIZE))
    this.winStart = start
    this.winLyrics = this.parsedLyrics.slice(start, start + LyricsView.WIN_SIZE)
  }

  /** 歌词数据变化（换歌）：重置窗口并定位到当前行，重新调度全量扩展 */
  private onLyricsDataChange(): void {
    if (this.expandTimer !== -1) {
      clearTimeout(this.expandTimer)
      this.expandTimer = -1
    }
    this.winStart = 0
    this.winLyrics = []
    this.recomputeWindow(this.currentLyricsIndex)
    if (this.active) {
      this.mirroredIndex = this.currentLyricsIndex
    }
    this.scheduleExpand()
  }

  /** 可见性变化：重新可见时同步到当前行并直跳（离屏期间冻结，不切行动画） */
  private onActiveChange(): void {
    if (this.active) {
      this.recomputeWindow(this.currentLyricsIndex)
      this.mirroredIndex = this.currentLyricsIndex
      setTimeout(() => {
        this.resetSignal++
      }, 60)
      // 尚未扩到全量时继续扩展
      if (!this.isFullLyrics()) {
        this.scheduleExpand()
      }
    }
  }

  // ==================== 监听器 ====================
  // 播放索引变化：离屏冻结（不搬窗、不同步）；手动滚动时不搬窗（避免打断浏览）
  private onLyricIndexChange(): void {
    if (!this.active) {
      return
    }
    this.mirroredIndex = this.currentLyricsIndex
    if (!this.isManualScroll) {
      this.recomputeWindow(this.currentLyricsIndex)
    }
  }

  // ==================== 配置转换 ====================
  private getConfig(): ChainLyricsConfig {
    return {
      springParams: {
        velocity: this.springParams.velocity,
        mass: this.springParams.mass,
        stiffness: this.springParams.stiffness,
        damping: this.springParams.damping,
        lineSpacing: this.springParams.lineSpacing,
        highlightLineSpacing: this.springParams.highlightLineSpacing,
        dragDelay: this.springParams.dragDelay
      },
      highlightPositionRatio: this.screenOrientation == 'portrait' ? 0.25 : 0.45,
      dragOffset: 15,
      chainAnimationRange: 20,
      dragHoldDuration: 80,
      manualScrollRecoveryTime: 7000,
      defaultLineHeight: 60,
      lineHeightWithTranslation: 90
    }
  }

  private getTheme(): LyricTheme {
    return {
      normalStyle: {
        fontSize: this.lyricFontSize,
        fontWeight: FontWeight.Bolder,
        fontColor: this.normalColor,
        opacity: 0.9,
        scale: this.lyricNormalScale
      },
      highlightStyle: {
        fontSize: this.lyricFontSize,
        fontWeight: FontWeight.Bolder,
        fontColor: this.highlightColor,
        textShadow: {
          radius: this.glowRadius,
          color: this.glowColor,
          offsetX: 0,
          offsetY: 0
        },
        opacity: 1,
        scale: 1.0
      },
      translationFontSize: this.lyricTranslationFontSize,
      transliterationFontSize: this.lyricTransliterationFontSize
    }
  }

  // ==================== 事件处理 ====================
  /** 时间戳为 0 的行数：>=2 说明是 作词/作曲 等元信息行块（源数据无时间被填了 0），不是真实歌词 */
  private zeroTimeLineCount(): number {
    let c: number = 0
    for (const l of this.parsedLyrics) {
      if (l.time === 0) {
        c++
        if (c >= 2) {
          break
        }
      }
    }
    return c
  }

  private handleLineClick(time: number, index: number) {
    this.onInteract?.()
    // index 为窗口内相对索引，换算回全量歌词索引
    const absIndex: number = this.winStart + index
    const line: AppLyricsLine | undefined = this.parsedLyrics[absIndex]
    // 无有效时间戳的行（元信息行/解析异常行）：提示无法跳转，不执行 seek，避免打断播放
    if (!line || !Number.isFinite(line.time) || line.time < 0 ||
      (line.time === 0 && this.zeroTimeLineCount() >= 2)) {
      ToastUtil.showShort('该句歌词无法跳转')
      return
    }
    // 跳转播放
    avPlayerManager.seek(time)
    // 更新 PiP 歌词
    EventHelper.postPipLyric(line.text)
  }

  private handleHighlightChange(_index: number) {
    // 可选：处理高亮变化
  }

  private handleManualScrollStart() {
    this.onInteract?.()
    this.isManualScroll = true
    this.refreshTranslateBtnTimer()
  }

  private handleManualScrollEnd() {
    this.isManualScroll = false
  }

  /** 刷新翻译按钮显示计时器 */
  private refreshTranslateBtnTimer() {
    if (this.translateBtnTimeoutId !== -1) {
      clearTimeout(this.translateBtnTimeoutId)
    }
    this.showTranslateBtn = true
    this.translateBtnTimeoutId = setTimeout(() => {
      this.translateBtnTimeoutId = -1
      this.showTranslateBtn = false
    }, 5000) as number
  }

  /** 恢复到当前行 */
  private resumeToCurrentLine() {
    this.resetSignal++
  }

  /** 双指手势更新偏移 */
  private handleUpdate(newStep: number): boolean {
    if (newStep !== this.lastStep) {
      this.lastStep = newStep
      return true
    }
    return false
  }

  /** 切换翻译显示 */
  private toggleTranslation() {
    this.showTranslation = !this.showTranslation
    PreferencesCache.showTranslationLyric(this.showTranslation)
  }

  // ==================== 配置保存 ====================
  private saveSpringParams() {
    PreferencesCache.springAnimationParams(this.springParams)
  }

  // ==================== UI 构建 ====================
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 歌词组件
      BaseChainLyricsView({
        // 窗口化歌词 + 窗口内相对索引：限制首屏建行数与索引相关工作量
        lyrics: this.winLyrics as LyricLine[],
        currentIndex: this.mirroredIndex - this.winStart,
        showTranslation: this.showTranslation,
        config: this.getConfig(),
        theme: this.getTheme(),
        containerHeight: this.winHeight,
        resetSignal: this.resetSignal,
        eventCallbacks: {
          onLineClick: (time: number, index: number) => {
            this.handleLineClick(time, index)
          },
          onHighlightChange: (index: number) => {
            this.handleHighlightChange(index)
          },
          onManualScrollStart: () => {
            this.handleManualScrollStart()
          },
          onManualScrollEnd: () => {
            this.handleManualScrollEnd()
          }
        }
      })
      .width('100%')
      .height('100%')

      // 设置按钮和翻译按钮（仅 mode_judge 为 true 时显示）
      if (this.mode_judge) {
        // 设置按钮
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_gearshape'))
            .width(24)
            .height(24)
            .fillColor(Color.White)
        }
        .width(52)
        .height(52)
        .visibility(this.isManualScroll || this.showTranslateBtn ? Visibility.Visible : Visibility.None)
        .backgroundColor('transparent')
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
        .margin({ bottom: 24, right: 24 })
        .position({ x: '100%', y: '100%' })
        .translate({ x: -76, y: this.hasTranslation || this.hasTransliteration ? -140 : -76 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
        .hoverEffect(HoverEffect.Highlight)
        .onClick(() => {
          // 恢复到当前行
          this.resumeToCurrentLine()
          this.showSpringSettings = true
        })

        // 翻译按钮
        if (this.hasTranslation || this.hasTransliteration) {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_translate'))
              .width(24)
              .height(24)
              .fillColor(this.showTranslation ? Color.White : 'rgba(255, 255, 255, 0.5)')
          }
          .width(52)
          .height(52)
          .visibility(this.isManualScroll || this.showTranslateBtn ? Visibility.Visible : Visibility.None)
          .backgroundColor('transparent')
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
          .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
          .margin({ bottom: 24, right: 24 })
          .position({ x: '100%', y: '100%' })
          .translate({ x: -76, y: -76 })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
          .hoverEffect(HoverEffect.Highlight)
          .onClick(() => {
            this.showTranslation = !this.showTranslation
            PreferencesCache.showTranslationLyric(this.showTranslation)
          })
        }
      }

      // 偏移显示
      if (this.mode_judge) {
        Column() {
          Text(`历史偏移：${this.lastLyricsOffsetTime}MS`)
            .fontSize(16)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
          Text(`当前偏移：${this.currentLyricsOffsetTime}MS`)
            .fontSize(16)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: this.winHeight * 0.30 })
        .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK)
        .height(60)
        .width(200)
        .borderRadius(15)
        .visibility(Visibility.None) // 暂时隐藏，需要时显示
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showSpringSettings, this.springSettingsSheet(), {
      height: '50%',
      dragBar: true,
      backgroundColor: $r('app.color.dialog_background')
    })
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        // 三指手势 - 重置偏移或切换翻译
        PanGesture({ fingers: 3, direction: PanDirection.Vertical, distance: 1 })
          .onActionEnd((event: GestureEvent) => {
            const currentStep = Math.floor(event.offsetY / 20)
            if (currentStep < 1) {
              // 向下滑动：重置偏移
              LyricsManager.setPreTime(0)
              PreferencesCache.currentLyricsOffsetTime(0)
              this.currentLyricsOffsetTime = 0
              this.lastLyricsOffsetTime = 0
              VibrationControl.handlePresetVibration(1)
              ToastUtil.showToast(`当前歌词偏移：${this.currentLyricsOffsetTime}MS`,
                { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight / 4 } })
            }
            if (currentStep > 1) {
              // 向上滑动：切换翻译
              if (this.hasTranslation || this.hasTransliteration) {
                this.toggleTranslation()
              }
            }
          }),

        // 双指手势 - 调整偏移
        PanGesture({ fingers: 2, direction: PanDirection.Vertical, distance: 1 })
          .onActionStart(() => {
            this.isShow = true
          })
          .onActionUpdate((event: GestureEvent) => {
            const newStep = Math.floor(event.offsetY / 50)
            if (this.handleUpdate(newStep)) {
              this.currentLyricsOffsetTime = this.lastLyricsOffsetTime + this.lastStep * 100
              LyricsManager.setPreTime(this.currentLyricsOffsetTime)
              PreferencesCache.currentLyricsOffsetTime(this.currentLyricsOffsetTime)
              VibrationControl.handlePresetVibration(1)
            }
          })
          .onActionEnd(() => {
            this.lastStep = 0
            this.isShow = false
            this.lastLyricsOffsetTime = this.currentLyricsOffsetTime
            ToastUtil.showToast(`当前歌词偏移：${this.currentLyricsOffsetTime}MS`,
              { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight / 4 } })
          })
      )
    )
  }

  // ==================== 设置面板 ====================
  @Builder
  springSettingsSheet() {
    Column() {
      Text('歌词设置')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_title'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 12, bottom: 12 })

      Scroll() {
        Column() {
          // 初始速度
          this.SettingSlider({
            label: '初始速度',
            value: this.springParams.velocity ?? 0,
            min: -20,
            max: 20,
            step: 0.5,
            onChange: (value: number) => {
              this.updateSpringParam('velocity', value)
            }
          })

          // 质量
          this.SettingSlider({
            label: '质量',
            value: this.springParams.mass ?? 0.3,
            min: 0,
            max: 2,
            step: 0.05,
            onChange: (value: number) => {
              this.updateSpringParam('mass', value)
            }
          })

          // 刚度
          this.SettingSlider({
            label: '刚度',
            value: this.springParams.stiffness ?? 200,
            min: 50,
            max: 400,
            step: 10,
            onChange: (value: number) => {
              this.updateSpringParam('stiffness', value)
            }
          })

          // 阻尼
          this.SettingSlider({
            label: '阻尼',
            value: this.springParams.damping ?? 15,
            min: 5,
            max: 50,
            step: 1,
            onChange: (value: number) => {
              this.updateSpringParam('damping', value)
            }
          })

          // 行间距
          this.SettingSlider({
            label: '行间距',
            value: this.springParams.lineSpacing ?? 24,
            min: 8,
            max: 48,
            step: 2,
            suffix: 'vp',
            onChange: (value: number) => {
              this.updateSpringParam('lineSpacing', value)
            }
          })

          // 高亮行间距
          this.SettingSlider({
            label: '高亮行间距',
            value: this.springParams.highlightLineSpacing ?? 8,
            min: 0,
            max: 48,
            step: 2,
            suffix: 'vp',
            onChange: (value: number) => {
              this.updateSpringParam('highlightLineSpacing', value)
            }
          })

          // 每行延迟
          this.SettingSlider({
            label: '每行延迟',
            value: this.springParams.dragDelay ?? 35,
            min: 0,
            max: 100,
            step: 5,
            suffix: 'ms',
            onChange: (value: number) => {
              this.updateSpringParam('dragDelay', value)
            }
          })

          // 歌词字体大小
          this.SettingSlider({
            label: '歌词字体大小',
            value: this.lyricFontSize,
            min: 12,
            max: 40,
            step: 1,
            suffix: 'fp',
            onChange: (value: number) => {
              this.pendingFontSize = value
              if (this.fontSizeUpdateTimer === -1) {
                this.fontSizeUpdateTimer = setTimeout(() => {
                  this.lyricFontSize = this.pendingFontSize
                  PreferencesCache.lyricFontSize(this.pendingFontSize)
                  this.fontSizeUpdateTimer = -1
                }, 500) as number
              }
            }
          })

          // 翻译字体大小
          this.SettingSlider({
            label: '翻译字体大小',
            value: this.lyricTranslationFontSize,
            min: 10,
            max: 22,
            step: 1,
            suffix: 'fp',
            onChange: (value: number) => {
              this.pendingTranslationFontSize = value
              if (this.translationFontSizeUpdateTimer === -1) {
                this.translationFontSizeUpdateTimer = setTimeout(() => {
                  this.lyricTranslationFontSize = this.pendingTranslationFontSize
                  PreferencesCache.lyricTranslationFontSize(this.pendingTranslationFontSize)
                  this.translationFontSizeUpdateTimer = -1
                }, 500) as number
              }
            }
          })

          // 罗马音字体大小
          this.SettingSlider({
            label: '罗马音字体大小',
            value: this.lyricTransliterationFontSize,
            min: 8,
            max: 18,
            step: 1,
            suffix: 'fp',
            onChange: (value: number) => {
              this.pendingTransliterationFontSize = value
              if (this.transliterationFontSizeUpdateTimer === -1) {
                this.transliterationFontSizeUpdateTimer = setTimeout(() => {
                  this.lyricTransliterationFontSize = this.pendingTransliterationFontSize
                  PreferencesCache.lyricTransliterationFontSize(this.pendingTransliterationFontSize)
                  this.transliterationFontSizeUpdateTimer = -1
                }, 500) as number
              }
            }
          })

          // 非高亮缩放比例
          this.SettingSlider({
            label: '非高亮缩放比例',
            value: this.lyricNormalScale,
            min: 0.7,
            max: 1.0,
            step: 0.01,
            suffix: 'x',
            onChange: (value: number) => {
              this.pendingNormalScale = value
              if (this.normalScaleUpdateTimer === -1) {
                this.normalScaleUpdateTimer = setTimeout(() => {
                  this.lyricNormalScale = this.pendingNormalScale
                  PreferencesCache.lyricNormalScale(this.pendingNormalScale)
                  this.normalScaleUpdateTimer = -1
                }, 500) as number
              }
            }
          })

          // 重置按钮
          Button('恢复默认')
            .width('80%')
            .height(44)
            .backgroundColor($r('app.color.button_background'))
            .fontColor($r('app.color.text_title'))
            .borderWidth(1)
            .borderColor($r('app.color.border_line'))
            .borderRadius(22)
            .margin({ top: 16 })
            .onClick(() => {
              // 使用 miscutils 中定义的默认值
              this.springParams = {
                velocity: DEFAULT_CONFIG.springParams!.velocity!,
                mass: DEFAULT_CONFIG.springParams!.mass!,
                stiffness: DEFAULT_CONFIG.springParams!.stiffness!,
                damping: DEFAULT_CONFIG.springParams!.damping!,
                lineSpacing: DEFAULT_CONFIG.springParams!.lineSpacing!,
                highlightLineSpacing: DEFAULT_CONFIG.springParams!.highlightLineSpacing!,
                dragDelay: DEFAULT_CONFIG.springParams!.dragDelay!
              }
              this.saveSpringParams()
              this.lyricFontSize = DEFAULT_THEME.normalStyle.fontSize ?? 24
              this.lyricNormalScale = 0.95 // 非高亮行默认缩放 0.95
              this.lyricTranslationFontSize = DEFAULT_THEME.translationFontSize ?? 16
              this.lyricTransliterationFontSize = DEFAULT_THEME.transliterationFontSize ?? 12
              PreferencesCache.lyricFontSize(this.lyricFontSize)
              PreferencesCache.lyricNormalScale(this.lyricNormalScale)
              PreferencesCache.lyricTranslationFontSize(this.lyricTranslationFontSize)
              PreferencesCache.lyricTransliterationFontSize(this.lyricTransliterationFontSize)
            })

          Blank().height(80)
        }
        .width('100%')
        .padding(16)
        .alignItems(HorizontalAlign.Center)
      }
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }

  /** 更新弹簧参数（创建新对象触发响应式） */
  private updateSpringParam(key: string, value: number) {
    const newParams: AppSpringAnimationParams = {
      velocity: this.springParams.velocity,
      mass: this.springParams.mass,
      stiffness: this.springParams.stiffness,
      damping: this.springParams.damping,
      lineSpacing: this.springParams.lineSpacing,
      highlightLineSpacing: this.springParams.highlightLineSpacing,
      dragDelay: this.springParams.dragDelay
    }
    switch (key) {
      case 'velocity':
        newParams.velocity = value
        break
      case 'mass':
        newParams.mass = value
        break
      case 'stiffness':
        newParams.stiffness = value
        break
      case 'damping':
        newParams.damping = value
        break
      case 'lineSpacing':
        newParams.lineSpacing = value
        break
      case 'highlightLineSpacing':
        newParams.highlightLineSpacing = value
        break
      case 'dragDelay':
        newParams.dragDelay = value
        break
    }
    this.springParams = newParams
    this.saveSpringParams()
  }

  @Builder
  SettingSlider(params: SliderParams = {
    label: '',
    value: 0,
    suffix: '',
    min: 0,
    max: 0,
    step: 0.1
  }) {
    Column() {
      Row() {
        Text(params.label)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(params.value.toFixed((params.step ?? 1) < 1 ? 2 : 0) + (params.suffix ?? ''))
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .margin({ bottom: 8 })

      Slider({
        value: params.value,
        min: params.min ?? 0,
        max: params.max ?? 100,
        step: params.step ?? 1,
        style: SliderStyle.InSet
      })
        .selectedColor($r('app.color.title_emphasis_color'))
        .trackThickness(16)
        .onChange(params.onChange)
    }
    .width('100%')
    .margin({ bottom: 16 })
  }
}
