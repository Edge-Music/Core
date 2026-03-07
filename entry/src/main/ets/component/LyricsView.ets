import { StyleConstants } from "../constants/StyleConstants";
import { AnimationConstants } from "../constants/AnimationConstants";
import { avPlayerManager } from "../util/AVPlayerManager";
import { PreferencesCache, SpringAnimationParams } from "../util/PreferenceCache";
import LyricsManager, { LyricsLine } from "../util/LyricsManager";
import { VibrationControl } from "../util/DeviceController";
import { EventHelper } from "../util/EventHelper";
import { LyricItem } from "./LyricItem";
import { ToastUtil } from "@pura/harmony-utils";
import { curves } from '@kit.ArkUI';

@Component
export struct LyricsView {
  // 每行平均内容高度（不含间距）
  private readonly AVG_ITEM_HEIGHT: number = StyleConstants.LYRIC_HEIGHT_NO_TRANSLATION

  @StorageProp('leftCutoutRectWidth') leftCutoutRectWidth: number = 0
  @StorageProp('rightCutoutRectWidth') rightCutoutRectWidth: number = 0
  @StorageProp('current_parsed_lyrics') @Watch('onLyricsChange') private parsedLyrics: Array<LyricsLine> = []
  @StorageProp('current_lyrics_has_translation') private hasTranslation: boolean = false
  @StorageProp('current_lyrics_has_transliteration') private hasTransliteration: boolean = false
  @StorageProp('winHeight') winHeight: number = 0
  @StorageLink('current_lyrics_index') @Watch("onLyricIndexChange") private currentLyricsIndex: number = 0

  @State private manualScrollTimeoutId: number = -1
  @State private translateBtnTimeoutId: number = -1  // 翻译按钮延迟隐藏计时器
  @State private showTranslateBtn: boolean = false   // 翻译按钮显示状态
  @State private isManualScroll: boolean = false
  @State private isAutoScroll: boolean = false
  @State private currentLyricsOffsetTime: number = PreferencesCache.currentLyricsOffsetTime()
  @State private lastLyricsOffsetTime: number = PreferencesCache.currentLyricsOffsetTime()
  @State private lastStep: number = 0
  @State private isShow: boolean = false
  @State mode_judge: boolean = false
  @State private showTranslation: boolean = PreferencesCache.showTranslationLyric()
  @State private prevLyricsIndex: number = -1

  // 弹簧动画参数
  @State private springParams: SpringAnimationParams = PreferencesCache.springAnimationParams()
  // 设置界面显示状态
  @State private showSpringSettings: boolean = false

  // 字体大小设置
  @State private lyricFontSize: number = PreferencesCache.lyricFontSize()
  @State private lyricHighlightScale: number = PreferencesCache.lyricHighlightScale()
  @State private lyricTranslationFontSize: number = PreferencesCache.lyricTranslationFontSize()
  @State private lyricTransliterationFontSize: number = PreferencesCache.lyricTransliterationFontSize()
  // 字体大小节流更新
  private fontSizeUpdateTimer: number = -1
  private pendingFontSize: number = 18
  private highlightScaleUpdateTimer: number = -1
  private pendingHighlightScale: number = 1.2
  private translationFontSizeUpdateTimer: number = -1
  private pendingTranslationFontSize: number = 16
  private transliterationFontSizeUpdateTimer: number = -1
  private pendingTransliterationFontSize: number = 12

  // 缓存的动画曲线（避免每帧创建）
  private cachedAnimationCurve: ICurve | null = null

  // 用于链式动画时延迟更新高亮状态
  @State private displayLyricsIndex: number = 0
  // 上一次的高亮行索引（用于判断高亮状态变化导致的高度变化）
  private prevHighlightIndex: number = -1

  // 每行的实际高度（通过 onAreaChange 实时获取）
  @State private itemHeights: number[] = []
  // 每行的 Y 位置（独立控制，实现独立动画）
  @State private itemYPositions: number[] = []
  // 每行额外的偏移（用于链式动画拖拽效果）
  @State private itemExtraOffset: number[] = []
  // 手动滑动时的额外偏移
  @State private manualOffset: number = 0

  // 动画timeout列表
  private animationTimeouts: number[] = []

  // 手动滑动相关
  private dragStartOffset: number = 0  // 拖动开始时的 manualOffset
  private lastDragY: number = 0         // 上一次的 offsetY（用于计算速度）
  private velocityY: number = 0
  private inertiaTimeoutId: number = -1

  aboutToAppear() {
    this.displayLyricsIndex = this.currentLyricsIndex
    // 确保歌词加载后立即初始化位置
    if (this.parsedLyrics.length > 0) {
      this.initPositions()
    }
    // 初始化动画曲线缓存
    this.updateCachedAnimationCurve()
  }

  // 获取缓存的动画曲线（性能优化：避免每帧创建新对象）
  private getAnimationCurve(): ICurve {
    if (!this.cachedAnimationCurve) {
      this.updateCachedAnimationCurve()
    }
    return this.cachedAnimationCurve!
  }

  // 更新缓存的动画曲线
  private updateCachedAnimationCurve() {
    this.cachedAnimationCurve = curves.springCurve(
      this.springParams.velocity ?? 0,
      this.springParams.mass ?? 0.3,
      this.springParams.stiffness ?? 200,
      this.springParams.damping ?? 15
    )
  }

  // 目标位置（高亮行的 Y 位置，基于屏幕高度百分比）
  private getTargetY(): number {
    return this.winHeight * StyleConstants.LYRIC_HIGHLIGHT_POSITION_RATIO
  }

  // 监听歌词数据变化
  onLyricsChange() {
    if (this.parsedLyrics.length > 0) {
      // 重置所有状态
      this.displayLyricsIndex = this.currentLyricsIndex
      this.isManualScroll = false
      this.isAutoScroll = false
      this.manualOffset = 0
      this.clearAllAnimations()
      this.clearInertiaAnimation()
      this.initPositions()
    }
  }

  aboutToDisappear() {
    this.clearAllAnimations()
    this.clearInertiaAnimation()
    if (this.translateBtnTimeoutId !== -1) {
      clearTimeout(this.translateBtnTimeoutId)
    }
    // 清除字体大小更新定时器
    if (this.fontSizeUpdateTimer !== -1) {
      clearTimeout(this.fontSizeUpdateTimer)
    }
    if (this.highlightScaleUpdateTimer !== -1) {
      clearTimeout(this.highlightScaleUpdateTimer)
    }
    if (this.translationFontSizeUpdateTimer !== -1) {
      clearTimeout(this.translationFontSizeUpdateTimer)
    }
    if (this.transliterationFontSizeUpdateTimer !== -1) {
      clearTimeout(this.transliterationFontSizeUpdateTimer)
    }
  }

  // 计算某行的中心 Y 位置（考虑高亮行的额外间距）
  // highlightIndex: 当前高亮行的索引
  private getItemCenterY(index: number, highlightIndex: number): number {
    const lineSpacing = this.springParams.lineSpacing ?? 24
    const highlightLineSpacing = this.springParams.highlightLineSpacing ?? 8
    let y = 0
    for (let i = 0; i < index; i++) {
      // 每行占用高度 = 内容高度 + 行间距
      y += (this.itemHeights[i] ?? this.AVG_ITEM_HEIGHT) + lineSpacing
      // 如果下一行是高亮行，添加额外间距（高亮行上方的间距）
      if (i + 1 === highlightIndex) {
        y += highlightLineSpacing
      }
      // 如果当前行是高亮行，添加额外间距（高亮行下方的间距）
      if (i === highlightIndex) {
        y += highlightLineSpacing
      }
    }
    const currentHeight = this.itemHeights[index] ?? this.AVG_ITEM_HEIGHT
    return y + currentHeight / 2
  }

  // 获取某行显示位置的 Y 坐标（元素顶部位置）
  // itemYPositions 存储的是元素中心的 Y 位置
  // position.y 需要是元素顶部的位置，所以要减去高度的一半
  private getItemDisplayY(index: number): number {
    const centerY = (this.itemYPositions[index] ?? 0) + this.manualOffset + (this.itemExtraOffset[index] ?? 0)
    const height = this.itemHeights[index] ?? this.AVG_ITEM_HEIGHT
    return centerY - height / 2
  }

  // 计算目标行居中时，每行应该在的位置
  private calculateItemYPositions(targetIndex: number): number[] {
    const positions: number[] = []
    const highlightCenterY = this.getItemCenterY(targetIndex, targetIndex)

    for (let i = 0; i < this.parsedLyrics.length; i++) {
      const itemCenterY = this.getItemCenterY(i, targetIndex)
      // 每行的位置 = TARGET_Y + 该行相对于高亮行的偏移
      // 使高亮行中心对齐 TARGET_Y，其他行按相对位置排列
      positions[i] = this.getTargetY() + (itemCenterY - highlightCenterY)
    }
    return positions
  }

  // 获取限位后的手动偏移
  private getClampedManualOffset(offset: number): number {
    if (this.parsedLyrics.length === 0) return 0

    const firstY = this.itemYPositions[0] ?? 0
    const lastY = this.itemYPositions[this.parsedLyrics.length - 1] ?? 0

    // 向下拉限制：第一行中心可以到达 TARGET_Y
    // itemYPositions[0] + offset = TARGET_Y => offset = TARGET_Y - firstY
    const pullDownLimit = this.getTargetY() - firstY

    // 向上推限制：最后一行中心可以到达 TARGET_Y
    const pushUpLimit = this.getTargetY() - lastY

    // pullDownLimit 通常 > pushUpLimit
    const lower = Math.min(pullDownLimit, pushUpLimit)
    const upper = Math.max(pullDownLimit, pushUpLimit)

    return Math.max(lower, Math.min(upper, offset))
  }

  // 初始化
  private initPositions() {
    if (this.parsedLyrics.length === 0) return

    // 清除所有旧数据
    this.itemExtraOffset = new Array(this.parsedLyrics.length).fill(0)
    this.itemYPositions = new Array(this.parsedLyrics.length).fill(0)

    // 初始化高度数组：使用默认估算值（实际高度由 onAreaChange 更新）
    this.itemHeights = this.parsedLyrics.map(() => this.AVG_ITEM_HEIGHT)

    // 初始化位置数组，使用当前显示的高亮行
    this.itemYPositions = this.calculateItemYPositions(this.displayLyricsIndex)
    this.manualOffset = 0
  }

  // 更新单行高度（由 onAreaChange 回调触发）
  private updateItemHeight(index: number, height: number) {
    if (index < 0 || index >= this.parsedLyrics.length) return
    // 手动拖动期间不更新，避免位置跳动
    if (this.isManualScroll) return

    const oldHeight = this.itemHeights[index] ?? 0
    // 允许更小的差异触发更新（翻译切换时高度变化可能较小）
    if (Math.abs(oldHeight - height) > 0.5) {
      this.itemHeights = this.itemHeights.map((h, i) => i === index ? height : h)
      // 高亮状态变化导致的高度变化（scale 变化），不影响其他行位置，跳过重新计算
      if (index === this.displayLyricsIndex || index === this.prevHighlightIndex) {
        return
      }
      this.itemYPositions = this.calculateItemYPositions(this.displayLyricsIndex)
    }
  }

  // 清除所有动画
  private clearAllAnimations() {
    this.animationTimeouts.forEach(id => clearTimeout(id))
    this.animationTimeouts = []
  }

  // 清除惯性动画
  private clearInertiaAnimation() {
    if (this.inertiaTimeoutId !== -1) {
      clearTimeout(this.inertiaTimeoutId)
      this.inertiaTimeoutId = -1
    }
  }

  // 监听歌词索引变化（来自播放器）
  onLyricIndexChange() {
    if (this.currentLyricsIndex !== -1 && !this.isManualScroll) {
      // 记录之前的高亮行（用于判断 scale 变化导致的高度变化）
      this.prevHighlightIndex = this.displayLyricsIndex

      // 判断是否使用链式动画：只有自动切换到下一行时才使用动画
      const isNextLine = this.currentLyricsIndex === this.displayLyricsIndex + 1
      // 判断当前高亮行持续时间是否足够长（太短就不用动画，避免连续快速滚动导致间距变大）
      const minDuration = 1000 // 最小持续时间阈值(ms)
      const currentLineDuration = this.getLyricLineDuration(this.displayLyricsIndex)
      const shouldUseAnimation = isNextLine && currentLineDuration >= minDuration

      // 调试日志
      console.log(`[LyricsView] onLyricIndexChange: currentIndex=${this.currentLyricsIndex}, displayIndex=${this.displayLyricsIndex}, isNextLine=${isNextLine}, duration=${currentLineDuration}ms, shouldUseAnimation=${shouldUseAnimation}`)

      if (shouldUseAnimation) {
        this.triggerChainAnimation(this.currentLyricsIndex)
      } else {
        this.displayLyricsIndex = this.currentLyricsIndex
        this.updatePositionsForIndex(this.currentLyricsIndex)
      }
    }
    this.prevLyricsIndex = this.currentLyricsIndex
  }

  // 获取某行歌词的持续时间（到下一行的时间差）
  private getLyricLineDuration(index: number): number {
    if (index < 0 || index >= this.parsedLyrics.length - 1) {
      // 最后一行或无效索引，返回足够长的时间
      return 10000
    }
    const currentLine = this.parsedLyrics[index]
    const nextLine = this.parsedLyrics[index + 1]
    return nextLine.time - currentLine.time
  }

  // 直接更新位置（无链式动画，但有整体平滑移动）
  private updatePositionsForIndex(targetIndex: number) {
    if (targetIndex < 0) return

    // 先清除可能正在运行的链式动画
    this.clearAllAnimations()

    // 重置额外偏移和手动偏移（确保无链式拖拽效果）
    this.itemExtraOffset = new Array(this.parsedLyrics.length).fill(0)
    this.manualOffset = 0

    // 更新高亮索引
    this.displayLyricsIndex = targetIndex

    // 计算新的位置并更新（会有整体平滑移动动画）
    this.itemYPositions = this.calculateItemYPositions(targetIndex)
  }

  // 链式动画
  private triggerChainAnimation(currentIndex: number) {
    this.clearAllAnimations()

    if (this.itemYPositions.length !== this.parsedLyrics.length) {
      this.initPositions()
    }

    this.isAutoScroll = true
    this.manualOffset = 0
    const direction = currentIndex > this.prevLyricsIndex ? 1 : -1

    // 计算目标位置
    const targetPositions = this.calculateItemYPositions(currentIndex)

    // 以 prevLyricsIndex（之前的位置）为基准计算动画范围
    // 限制范围在合理区间，避免大距离跳动
    const CHAIN_ANIMATION_RANGE = 20
    const minAnimIndex = Math.max(0, Math.min(this.prevLyricsIndex, currentIndex) - 5)
    const maxAnimIndex = Math.min(this.parsedLyrics.length - 1, Math.max(this.prevLyricsIndex, currentIndex) + CHAIN_ANIMATION_RANGE)

    // 先设置所有行的目标位置（范围外的立即设置，范围内的做动画）
    for (let i = 0; i < this.parsedLyrics.length; i++) {
      // 范围外的行立即设置位置
      if (i < minAnimIndex || i > maxAnimIndex) {
        this.itemYPositions[i] = targetPositions[i]
      }
    }

    // 重置额外偏移
    this.itemExtraOffset = new Array(this.parsedLyrics.length).fill(0)

    // 追踪动画完成状态
    const totalItems = maxAnimIndex - minAnimIndex + 1
    let completedCount = 0

    // 拖拽持续时间
    const dragHoldDuration = 80

    // 链式更新每行的位置
    for (let i = minAnimIndex; i <= maxAnimIndex; i++) {
      const delay = (i - minAnimIndex) * (this.springParams.dragDelay ?? 35)
      const dragOffset = (direction === 1 ? -1 : 1) * AnimationConstants.LYRIC_DRAG_OFFSET

      const timeoutId = setTimeout(() => {
        // 手动拖动期间跳过所有更新
        if (this.isManualScroll) return

        // 更新高亮索引
        if (i === currentIndex) {
          this.displayLyricsIndex = currentIndex
        }

        // 先设置拖拽偏移
        this.setItemExtraOffset(i, dragOffset)

        // 更新该行的位置
        this.setItemYPosition(i, targetPositions[i])

        // 延迟回弹
        const reboundTimeoutId = setTimeout(() => {
          if (this.isManualScroll) return
          this.setItemExtraOffset(i, 0)

          completedCount++
          if (completedCount >= totalItems) {
            this.isAutoScroll = false
          }
        }, dragHoldDuration) as number

        this.animationTimeouts.push(reboundTimeoutId)
      }, delay) as number

      this.animationTimeouts.push(timeoutId)
    }
  }

  // 设置单行的 Y 位置
  private setItemYPosition(index: number, y: number) {
    // 手动拖动期间不接受链式动画的更新
    if (this.isManualScroll) return
    this.itemYPositions = this.itemYPositions.map((item, i) =>
      i === index ? y : item
    )
  }

  // 设置单行的额外偏移（不可变更新）
  private setItemExtraOffset(index: number, offset: number) {
    // 手动拖动期间不接受链式动画的更新
    if (this.isManualScroll) return
    this.itemExtraOffset = this.itemExtraOffset.map((item, i) =>
      i === index ? offset : item
    )
  }

  // 上次更新高亮时的偏移量（避免频繁更新）
  private lastHighlightOffset: number = 0

  // 更新高亮索引：找到中心最接近 TARGET_Y 的行
  private updateHighlightFromPosition() {
    // 只有偏移量变化超过半个行高才更新，避免频繁计算
    if (Math.abs(this.manualOffset - this.lastHighlightOffset) < this.AVG_ITEM_HEIGHT / 2) {
      return
    }
    this.lastHighlightOffset = this.manualOffset

    // 使用二分查找找到最接近 TARGET_Y 的行
    let left = 0
    let right = this.parsedLyrics.length - 1

    while (left < right) {
      const mid = Math.floor((left + right) / 2)
      const midY = (this.itemYPositions[mid] ?? 0) + this.manualOffset

      if (midY < this.getTargetY()) {
        left = mid + 1
      } else {
        right = mid
      }
    }

    // 检查 left 和 left-1 哪个更接近
    const leftY = (this.itemYPositions[left] ?? 0) + this.manualOffset
    const leftDist = Math.abs(leftY - this.getTargetY())

    if (left > 0) {
      const prevY = (this.itemYPositions[left - 1] ?? 0) + this.manualOffset
      const prevDist = Math.abs(prevY - this.getTargetY())
      if (prevDist < leftDist) {
        left = left - 1
      }
    }

    if (left !== this.displayLyricsIndex) {
      this.displayLyricsIndex = left
    }
  }

  // 切换翻译显示状态
  private toggleTranslation() {
    // 停止自动滚动和链式动画
    this.clearAllAnimations()
    this.isAutoScroll = false

    // 清除手动滚动状态，让动画和高度更新生效
    this.isManualScroll = false
    if (this.manualScrollTimeoutId !== -1) {
      clearTimeout(this.manualScrollTimeoutId)
      this.manualScrollTimeoutId = -1
    }

    // 清除链式动画的额外偏移
    this.itemExtraOffset = new Array(this.parsedLyrics.length).fill(0)
    this.manualOffset = 0

    this.showTranslation = !this.showTranslation
    PreferencesCache.showTranslationLyric(this.showTranslation)
    VibrationControl.handlePresetVibration()

    // 不在这里更新高度，让 onAreaChange 自然触发更新
    // 这样位置变化会跟随翻译动画平滑过渡

    // 刷新翻译按钮显示时间
    this.refreshTranslateBtnTimer()
  }

  // 刷新翻译按钮显示计时器
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

  // 惯性滑动动画
  private startInertiaScroll(initialVelocity: number) {
    let velocity = initialVelocity
    const friction = 0.92
    const minVelocity = 0.5

    const step = () => {
      if (Math.abs(velocity) < minVelocity) {
        this.inertiaTimeoutId = -1
        this.startManualScrollTimer()
        return
      }

      const newOffset = this.getClampedManualOffset(this.manualOffset + velocity)

      if (Math.abs(newOffset - this.manualOffset) < 0.1) {
        this.inertiaTimeoutId = -1
        this.startManualScrollTimer()
        return
      }

      this.manualOffset = newOffset
      this.updateHighlightFromPosition()

      velocity *= friction
      this.inertiaTimeoutId = setTimeout(step, 8) as number
    }

    this.inertiaTimeoutId = setTimeout(step, 8) as number
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.parsedLyrics.length === 0) {
        Column() {
          Text($r('app.string.no_lyric_available'))
            .fontSize(18)
            .fontColor('rgba(255, 255, 255, 0.5)')
            .margin(16)
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
      } else {
        // 歌词容器 - 使用 Stack 实现绝对定位
        Stack() {
          ForEach(this.parsedLyrics, (item: LyricsLine, index: number) => {
            Column() {
              LyricItem({
                item: item,
                index: index,
                showTranslation: this.showTranslation,
                currentLyricsIndex: this.displayLyricsIndex,
                lyricFontSize: this.lyricFontSize,
                highlightScale: this.lyricHighlightScale,
                translationFontSize: this.lyricTranslationFontSize,
                transliterationFontSize: this.lyricTransliterationFontSize
              })
            }
            .width(StyleConstants.FULL_WIDTH)
            .position({ x: 0, y: this.getItemDisplayY(index) })
            .animation(this.isManualScroll ? { duration: 0 } : {
              curve: this.getAnimationCurve()
            })
            .onClick(() => {
              this.handleLyricClick(item.time, index)
            })
            .onAreaChange((_oldValue: Area, newValue: Area) => {
              const newHeight = newValue.height as number
              this.updateItemHeight(index, newHeight)
            })
          })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .clip(true)
      }

      // 翻译按钮和设置按钮
      if (this.mode_judge === true) {
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
          // 恢复自动滚动并预览动画效果
          this.resumeAutoScrollWithPreview()
          this.showSpringSettings = true
        })
        .animation({
          duration: AnimationConstants.DURATION_FAST,
          curve: AnimationConstants.CURVE_DECELERATE
        })

        // 翻译按钮（仅有翻译/音译时显示）
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
          .onClick(() => this.toggleTranslation())
          .animation({
            duration: AnimationConstants.DURATION_FAST,
            curve: AnimationConstants.CURVE_DECELERATE
          })
        }
      }

      // 偏移显示
      Column() {
        Text(`历史偏移：${this.lastLyricsOffsetTime}MS`)
          .fontSize(16)
          .fontColor(Color.White)
          .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
          .animation({ duration: 200 })
        Text(`当前偏移：${this.currentLyricsOffsetTime}MS`)
          .fontSize(16)
          .fontColor(Color.White)
          .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
          .animation({ duration: 200 })
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: this.winHeight * 0.30 })
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK)
      .height(60)
      .width(200)
      .borderRadius(15)
      .visibility(this.isShow ? Visibility.Visible : Visibility.None)

    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
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
              LyricsManager.setPreTime(0)
              PreferencesCache.currentLyricsOffsetTime(0)
              this.currentLyricsOffsetTime = 0
              this.lastLyricsOffsetTime = 0
              VibrationControl.handlePresetVibration(1)
              ToastUtil.showToast(`当前歌词偏移：${this.currentLyricsOffsetTime}MS`,
                { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight / 4 } })
            }
            if (currentStep > 1) {
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
          }),

        // 单指手势 - 手动拖动歌词
        PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 5 })
          .onActionStart(() => {
            // 中断自动滚动和链式动画
            if (this.isAutoScroll) {
              this.clearAllAnimations()
              this.isAutoScroll = false
            }

            // 重置位置到当前高亮行的正确位置（消除链式动画的中间状态）
            // 先计算当前位置相对于目标的偏移，保存到 manualOffset
            const targetCenterY = this.getTargetY()
            const extraOffset = this.itemExtraOffset[0] ?? 0

            // 当前的实际偏移 = (itemYPositions[displayLyricsIndex] - 目标中心位置) + manualOffset + extraOffset
            const currentDisplayY = (this.itemYPositions[this.displayLyricsIndex] ?? targetCenterY)
            const actualOffset = currentDisplayY - targetCenterY + this.manualOffset + extraOffset

            // 重置位置和偏移
            this.itemYPositions = this.calculateItemYPositions(this.displayLyricsIndex)
            this.itemExtraOffset = new Array(this.parsedLyrics.length).fill(0)
            this.manualOffset = actualOffset

            // 保存当前的 manualOffset 作为拖动起点
            this.dragStartOffset = this.manualOffset
            this.lastDragY = 0
            this.velocityY = 0
            this.lastHighlightOffset = this.manualOffset

            this.isManualScroll = true
            this.clearInertiaAnimation()
            if (this.manualScrollTimeoutId !== -1) {
              clearTimeout(this.manualScrollTimeoutId)
              this.manualScrollTimeoutId = -1
            }
          })
          .onActionUpdate((event: GestureEvent) => {
            const deltaY = event.offsetY - this.lastDragY
            this.lastDragY = event.offsetY
            this.velocityY = deltaY

            const newOffset = this.getClampedManualOffset(this.dragStartOffset + event.offsetY)
            this.manualOffset = newOffset
            this.updateHighlightFromPosition()
          })
          .onActionEnd(() => {
            if (Math.abs(this.velocityY) > 2) {
              this.startInertiaScroll(this.velocityY * 1.5)
            } else {
              this.startManualScrollTimer()
            }
          })
      )
    )
  }

  handleUpdate(newStep: number): boolean {
    if (newStep !== this.lastStep) {
      this.lastStep = newStep
      return true
    }
    return false
  }

  // 歌词点击处理
  private handleLyricClick(time: number, index: number) {
    this.clearAllAnimations()
    this.clearInertiaAnimation()
    this.isManualScroll = false
    this.isAutoScroll = false  // 重置自动滚动状态

    this.prevLyricsIndex = this.displayLyricsIndex  // 保存当前位置用于动画方向

    this.displayLyricsIndex = index
    this.currentLyricsIndex = index
    AppStorage.setOrCreate('test_index', this.parsedLyrics[index].text)
    EventHelper.postPipLyric(this.parsedLyrics[index].text)

    // 点击跳转：直接更新位置（无动画）
    this.updatePositionsForIndex(index)

    avPlayerManager.seek(time)
  }

  private startManualScrollTimer() {
    if (this.manualScrollTimeoutId !== -1) {
      clearTimeout(this.manualScrollTimeoutId)
    }

    this.isManualScroll = true

    this.manualScrollTimeoutId = setTimeout(() => {
      this.isManualScroll = false
      this.manualScrollTimeoutId = -1
      this.displayLyricsIndex = this.currentLyricsIndex
      // 直接更新位置（无动画）
      this.updatePositionsForIndex(this.currentLyricsIndex)
    }, 7000) as number
  }

  // 恢复自动滚动并预览链式动画
  private resumeAutoScrollWithPreview() {
    // 清除手动滚动定时器
    if (this.manualScrollTimeoutId !== -1) {
      clearTimeout(this.manualScrollTimeoutId)
      this.manualScrollTimeoutId = -1
    }

    // 清除惯性动画
    this.clearInertiaAnimation()

    // 恢复自动滚动状态
    this.isManualScroll = false

    // 重置偏移
    this.itemExtraOffset = new Array(this.parsedLyrics.length).fill(0)
    this.manualOffset = 0

    // 更新到当前播放位置（无动画）
    this.displayLyricsIndex = this.currentLyricsIndex
    this.itemYPositions = this.calculateItemYPositions(this.currentLyricsIndex)
  }

  // 弹簧设置面板
  @Builder
  springSettingsSheet() {
    Column() {
      // 固定标题
      Text('歌词设置')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_title'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 12, bottom: 12 })

      // 可滚动内容区域
      Scroll() {
        Column() {
          // 初始速度
          Column() {
            Row() {
              Text('初始速度')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text(this.springParams.velocity.toFixed(1))
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Slider({
              value: this.springParams.velocity,
              min: -20,
              max: 20,
              step: 0.5,
              style: SliderStyle.InSet
            })
              .selectedColor($r('app.color.title_emphasis_color'))
              .trackThickness(16)
              .onChange((value: number) => {
                this.springParams.velocity = value
                this.saveSpringParams()
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          // 质量
          Column() {
            Row() {
              Text('质量')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text(this.springParams.mass.toFixed(2))
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Slider({
              value: this.springParams.mass,
              min: 0,
              max: 2,
              step: 0.05,
              style: SliderStyle.InSet
            })
              .selectedColor($r('app.color.title_emphasis_color'))
              .trackThickness(16)
              .onChange((value: number) => {
                this.springParams.mass = value
                this.saveSpringParams()
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          // 刚度
          Column() {
            Row() {
              Text('刚度')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text(this.springParams.stiffness.toFixed(0))
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Slider({
              value: this.springParams.stiffness,
              min: 50,
              max: 400,
              step: 10,
              style: SliderStyle.InSet
            })
              .selectedColor($r('app.color.title_emphasis_color'))
              .trackThickness(16)
              .onChange((value: number) => {
                this.springParams.stiffness = value
                this.saveSpringParams()
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          // 阻尼
          Column() {
            Row() {
              Text('阻尼')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text(this.springParams.damping.toFixed(0))
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Slider({
              value: this.springParams.damping,
              min: 5,
              max: 50,
              step: 1,
              style: SliderStyle.InSet
            })
              .selectedColor($r('app.color.title_emphasis_color'))
              .trackThickness(16)
              .onChange((value: number) => {
                this.springParams.damping = value
                this.saveSpringParams()
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          // 行间距
          Column() {
            Row() {
              Text('行间距')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text((this.springParams.lineSpacing ?? 24).toFixed(0))
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Slider({
              value: this.springParams.lineSpacing ?? 24,
              min: 8,
              max: 48,
              step: 2,
              style: SliderStyle.InSet
            })
              .selectedColor($r('app.color.title_emphasis_color'))
              .trackThickness(16)
              .onChange((value: number) => {
                this.springParams.lineSpacing = value
                this.saveSpringParams()
                // 实时更新歌词位置
                this.itemYPositions = this.calculateItemYPositions(this.displayLyricsIndex)
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          // 高亮行间距
          Column() {
            Row() {
              Text('高亮行间距')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text((this.springParams.highlightLineSpacing ?? 8).toFixed(0))
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Slider({
              value: this.springParams.highlightLineSpacing ?? 8,
              min: 0,
              max: 48,
              step: 2,
              style: SliderStyle.InSet
            })
              .selectedColor($r('app.color.title_emphasis_color'))
              .trackThickness(16)
              .onChange((value: number) => {
                this.springParams.highlightLineSpacing = value
                this.saveSpringParams()
                // 实时更新歌词位置
                this.itemYPositions = this.calculateItemYPositions(this.displayLyricsIndex)
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          // 每行延迟
          Column() {
            Row() {
              Text('每行延迟')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text((this.springParams.dragDelay ?? 35).toFixed(0) + 'ms')
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Slider({
              value: this.springParams.dragDelay ?? 35,
              min: 0,
              max: 100,
              step: 5,
              style: SliderStyle.InSet
            })
              .selectedColor($r('app.color.title_emphasis_color'))
              .trackThickness(16)
              .onChange((value: number) => {
                this.springParams.dragDelay = value
                this.saveSpringParams()
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          // 歌词字体大小
          Column() {
            Row() {
              Text('歌词字体大小')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text(this.lyricFontSize.toFixed(0))
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Slider({
              value: this.lyricFontSize,
              min: 12,
              max: 40,
              step: 1,
              style: SliderStyle.InSet
            })
              .selectedColor($r('app.color.title_emphasis_color'))
              .trackThickness(16)
              .onChange((value: number) => {
                // 节流更新：100ms 内只更新一次
                this.pendingFontSize = value
                if (this.fontSizeUpdateTimer === -1) {
                  this.fontSizeUpdateTimer = setTimeout(() => {
                    this.lyricFontSize = this.pendingFontSize
                    PreferencesCache.lyricFontSize(this.pendingFontSize)
                    this.fontSizeUpdateTimer = -1
                  }, 100) as number
                }
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          // 翻译字体大小
          Column() {
            Row() {
              Text('翻译字体大小')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text(this.lyricTranslationFontSize.toFixed(0))
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Slider({
              value: this.lyricTranslationFontSize,
              min: 10,
              max: 22,
              step: 1,
              style: SliderStyle.InSet
            })
              .selectedColor($r('app.color.title_emphasis_color'))
              .trackThickness(16)
              .onChange((value: number) => {
                this.pendingTranslationFontSize = value
                if (this.translationFontSizeUpdateTimer === -1) {
                  this.translationFontSizeUpdateTimer = setTimeout(() => {
                    this.lyricTranslationFontSize = this.pendingTranslationFontSize
                    PreferencesCache.lyricTranslationFontSize(this.pendingTranslationFontSize)
                    this.translationFontSizeUpdateTimer = -1
                  }, 100) as number
                }
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          // 罗马音字体大小
          Column() {
            Row() {
              Text('罗马音字体大小')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text(this.lyricTransliterationFontSize.toFixed(0))
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Slider({
              value: this.lyricTransliterationFontSize,
              min: 8,
              max: 18,
              step: 1,
              style: SliderStyle.InSet
            })
              .selectedColor($r('app.color.title_emphasis_color'))
              .trackThickness(16)
              .onChange((value: number) => {
                this.pendingTransliterationFontSize = value
                if (this.transliterationFontSizeUpdateTimer === -1) {
                  this.transliterationFontSizeUpdateTimer = setTimeout(() => {
                    this.lyricTransliterationFontSize = this.pendingTransliterationFontSize
                    PreferencesCache.lyricTransliterationFontSize(this.pendingTransliterationFontSize)
                    this.transliterationFontSizeUpdateTimer = -1
                  }, 100) as number
                }
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          // 高亮放大比例
          Column() {
            Row() {
              Text('高亮放大比例')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text(this.lyricHighlightScale.toFixed(2) + 'x')
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Slider({
              value: this.lyricHighlightScale,
              min: 1.0,
              max: 1.1,
              step: 0.01,
              style: SliderStyle.InSet
            })
              .selectedColor($r('app.color.title_emphasis_color'))
              .trackThickness(16)
              .onChange((value: number) => {
                // 节流更新：100ms 内只更新一次
                this.pendingHighlightScale = value
                if (this.highlightScaleUpdateTimer === -1) {
                  this.highlightScaleUpdateTimer = setTimeout(() => {
                    this.lyricHighlightScale = this.pendingHighlightScale
                    PreferencesCache.lyricHighlightScale(this.pendingHighlightScale)
                    this.highlightScaleUpdateTimer = -1
                  }, 100) as number
                }
              })
          }
          .width('100%')
          .margin({ bottom: 20 })

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
              this.springParams = { velocity: 0, mass: 0.3, stiffness: 200, damping: 15, lineSpacing: 24, highlightLineSpacing: 0, dragDelay: 35 }
              this.saveSpringParams()
              // 重置字体设置
              this.lyricFontSize = 24
              this.lyricHighlightScale = 1.05
              this.lyricTranslationFontSize = 16
              this.lyricTransliterationFontSize = 12
              PreferencesCache.lyricFontSize(24)
              PreferencesCache.lyricHighlightScale(1.05)
              PreferencesCache.lyricTranslationFontSize(16)
              PreferencesCache.lyricTransliterationFontSize(12)
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

  // 保存弹簧参数
  private saveSpringParams() {
    PreferencesCache.springAnimationParams(this.springParams)
    // 更新缓存的动画曲线
    this.updateCachedAnimationCurve()
  }
}
