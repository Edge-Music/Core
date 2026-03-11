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

  // ==================== AppStorage 数据源 ====================
  @StorageProp('current_parsed_lyrics') private parsedLyrics: AppLyricsLine[] = []
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
  }

  // ==================== 监听器 ====================
  // @Watch 回调会在索引变化时自动触发，用于调试
  private onLyricIndexChange(): void {
    // 组件内部会自动处理索引变化
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
      highlightPositionRatio: 0.25,
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
        fontColor: 'rgba(255, 255, 255, 0.85)',
        opacity: 0.9,
        scale: this.lyricNormalScale
      },
      highlightStyle: {
        fontSize: this.lyricFontSize,
        fontWeight: FontWeight.Bolder,
        fontColor: Color.White,
        textShadow: {
          radius: 12,
          color: 'rgba(255, 255, 255, 0.6)',
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
  private handleLineClick(time: number, index: number) {
    // 跳转播放
    avPlayerManager.seek(time)
    // 更新 PiP 歌词
    if (this.parsedLyrics[index]) {
      EventHelper.postPipLyric(this.parsedLyrics[index].text)
    }
  }

  private handleHighlightChange(_index: number) {
    // 可选：处理高亮变化
  }

  private handleManualScrollStart() {
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
        lyrics: this.parsedLyrics as LyricLine[],
        currentIndex: this.currentLyricsIndex,
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
