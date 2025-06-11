import { StyleConstants } from "../constants/StyleConstants";
import { avPlayerManager } from "../util/AVPlayerManager";
import { PreferencesCache } from "../util/PreferenceCache";
import { App, LengthMetrics } from '@kit.ArkUI'
import { LyricsLine } from "../util/LyricsManager";
import { VibrationControl } from "../util/DeviceController";
import { EventHelper } from "../util/EventHelper";
import { LyricItem } from "./LyricItem";

@Component
export struct LyricsView {
  @StorageProp('leftCutoutRectWidth') leftCutoutRectWidth: number = 0
  @StorageProp('rightCutoutRectWidth') rightCutoutRectWidth: number = 0
  @StorageProp('current_parsed_lyrics') private parsedLyrics: Array<LyricsLine> = []
  @StorageLink('current_lyrics_index') @Watch("onTimeUpdate") private currentLyricsIndex: number = 0
  @State mode_judge: boolean = false
  @State private isAnimating: boolean = false
  @State private showTranslation: boolean = PreferencesCache.showTranslationLyric()
  @StorageProp('current_lyrics_has_translation') private hasTranslation: boolean = false // 是否有翻译歌词
  @StorageProp('current_lyrics_has_transliteration') private hasTransliteration: boolean = false
  private scroller: Scroller = new Scroller()
  private readonly SCROLL_ANIMATION_DURATION: number = 400
  private lastTriggerTime: number = 0;
  @State private manualScrollTimeoutId: number = -1; // 手动滚动超时ID
  @State private isManualScroll: boolean = false; // 是否处于手动滚动状态
  @State private isAutoScroll: boolean = false; // 是否处于自动滚动状态

  aboutToAppear() {
    this.scrollToLyric(this.currentLyricsIndex)
  }

  aboutToDisappear() {
  }

  // 监听当前播放时间更新
  onTimeUpdate() {
    // 如果索引变化且不在动画中，则更新并滚动
    if (this.currentLyricsIndex !== -1 && !this.isAnimating && !this.isManualScroll) {
      this.isAnimating = true
      this.scrollToLyric(this.currentLyricsIndex)
    }
  }

  // 滚动到指定歌词位置
  private scrollToLyric(index: number) {
    if (index < 0) {
      return
    }
    this.isAutoScroll = true
    // 保持在视图中间偏上的位置，很显然这是一个经验修正
    const targetIndex = Math.max(0, this.mode_judge ? index - (10 * (this.showTranslation ? 0.1 : 0.3)) : index - (this.showTranslation ? 0 : 1))
    animateTo({
      duration: this.SCROLL_ANIMATION_DURATION,
      curve: Curve.EaseOut,
      onFinish: () => {
        this.isAnimating = false
        this.isAutoScroll = false
      }
    }, () => {
      this.scroller.scrollToIndex(targetIndex)
    })
  }

  // 切换翻译显示状态
  private toggleTranslation() {
    animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
      this.showTranslation = !this.showTranslation
      this.scrollToLyric(this.currentLyricsIndex)
      PreferencesCache.showTranslationLyric(this.showTranslation)
      VibrationControl.handlePresetVibration()
    })
  }

  /**
   * 双指操作防抖
   * @param func
   */
  private debounce(func: Function) {
    const now = Date.now();
    if (now - this.lastTriggerTime > 300) {
      func();
      this.lastTriggerTime = now;
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        if (this.parsedLyrics.length === 0) {
          Text($r('app.string.no_lyric_available'))
            .fontSize(18)
            .fontColor('rgba(255, 255, 255, 0.5)')
            .margin(16)
        } else {
          List({ scroller: this.scroller }) {
            ForEach(this.parsedLyrics, (item: LyricsLine, index) => {
              ListItem() {
                LyricItem({
                  item: item,
                  index: index,
                  showTranslation: this.showTranslation,
                  currentLyricsIndex: this.currentLyricsIndex,
                })
              }
              .key('lyricItem'+index)
              .onClick(() => {
                this.handleLyricClick(item.time, index)
              })
              .width(StyleConstants.FULL_WIDTH)
            })
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .chainAnimation(true)
          .edgeEffect(EdgeEffect.Spring)
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
            // 检测到手动滚动时启动计时器
            if (!this.isAutoScroll) {
              this.startManualScrollTimer()
            }
          })
          .onScrollStop(() => {
            // 滚动停止时也检查是否需要锁定
            if (!this.isAutoScroll && this.isManualScroll) {
              this.startManualScrollTimer()
            }
          })
          .fadingEdge(true, {
            fadingEdgeLength:LengthMetrics.vp(80)
          })
          .contentStartOffset(50)
          .contentEndOffset(100)
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)

      if ((this.hasTranslation || this.hasTransliteration) && this.mode_judge === true) {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_translate'))
            .width(24)
            .height(24)
            .fillColor((this.hasTranslation || this.hasTransliteration) ? Color.White : 'rgba(255, 255, 255, 0.6)')
        }
        .width(48)
        .height(48)
        .backgroundColor(this.showTranslation ? 'rgba(255, 255, 255, 0.2)' : Color.Transparent)
        .margin({ bottom: 24, right: 24 })
        .position({ x: '100%', y: '100%' })
        .translate({ x: -72, y: -72 })
        .onClick(() => this.toggleTranslation())
        .animation({
          duration: 300,
          curve: Curve.EaseInOut
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .gesture(
      PinchGesture()
        .onActionUpdate((event: PinchGestureEvent) => {
          if (event.scale > 1.1) {
            this.debounce(() => {
              if(!this.showTranslation && (this.hasTranslation || this.hasTransliteration)){
                this.toggleTranslation()
              }
            });
          } else if (event.scale < 0.9) {
            this.debounce(() => {
              if(this.showTranslation && (this.hasTranslation || this.hasTransliteration)){
                this.toggleTranslation()
              }
            });
          }
        })
    )
  }

  // 歌词点击处理
  private handleLyricClick(time: number, index: number) {
    // 更新UI状态
    this.isAnimating = true
    this.isManualScroll = false
    this.currentLyricsIndex = index
    AppStorage.setOrCreate('test_index', this.parsedLyrics[index].text)
    EventHelper.postPipLyric(this.parsedLyrics[index].text)

    // 滚动到目标位置
    this.scrollToLyric(index)

    // 跳转到指定时间
    avPlayerManager.seek(time)
  }

  private startManualScrollTimer() {
    // 清除之前的计时器
    if (this.manualScrollTimeoutId) {
      clearTimeout(this.manualScrollTimeoutId)
    }

    // 设置手动滚动状态
    this.isManualScroll = true

    // 设置7秒后恢复自动滚动
    this.manualScrollTimeoutId = setTimeout(() => {
      this.isManualScroll = false
      this.manualScrollTimeoutId = -1
      // 恢复后立即同步到当前歌词位置
      this.scrollToLyric(this.currentLyricsIndex)
    }, 7000) as number
  }
}

