import { StyleConstants } from "../constants/StyleConstants";
import { AnimationConstants } from "../constants/AnimationConstants";
import { avPlayerManager } from "../util/AVPlayerManager";
import { PreferencesCache } from "../util/PreferenceCache";
import LyricsManager, { LyricsLine } from "../util/LyricsManager";
import { VibrationControl } from "../util/DeviceController";
import { EventHelper } from "../util/EventHelper";
import { LyricItem } from "./LyricItem";
import { ToastUtil } from "@pura/harmony-utils";

@Component
export struct LyricsView {
  private scroller: Scroller = new Scroller()
  private readonly SCROLL_ANIMATION_DURATION: number = 400 // 优化动画时长
  private uiContext: UIContext | undefined = undefined;

  @StorageProp('leftCutoutRectWidth') leftCutoutRectWidth: number = 0
  @StorageProp('rightCutoutRectWidth') rightCutoutRectWidth: number = 0
  @StorageProp('current_parsed_lyrics') private parsedLyrics: Array<LyricsLine> = []
  @StorageProp('current_lyrics_has_translation') private hasTranslation: boolean = false // 是否有翻译歌词
  @StorageProp('current_lyrics_has_transliteration') private hasTransliteration: boolean = false
  @StorageProp('winHeight') winHeight: number = 0
  @StorageLink('current_lyrics_index') @Watch("onTimeUpdate") private currentLyricsIndex: number = 0

  @State private manualScrollTimeoutId: number = -1; // 手动滚动超时ID
  @State private isManualScroll: boolean = false; // 是否处于手动滚动状态
  @State private isAutoScroll: boolean = false; // 是否处于自动滚动状态
  @State private currentLyricsOffsetTime: number = PreferencesCache.currentLyricsOffsetTime()
  @State private lastLyricsOffsetTime: number = PreferencesCache.currentLyricsOffsetTime()
  @State private lastStep: number = 0
  @State private isShow: boolean = false
  @State mode_judge: boolean = false
  @State private showTranslation: boolean = PreferencesCache.showTranslationLyric()
  @State private lyricOffsets: number[] = [] // 波浪动画偏移量数组

  aboutToAppear() {
    this.uiContext = this.getUIContext();
    // 初始化波浪偏移量数组
    this.lyricOffsets = new Array(this.parsedLyrics.length).fill(0);
    this.scrollToLyric(this.currentLyricsIndex)
  }

  aboutToDisappear() {
  }

  // 监听当前播放时间更新 - 触发波浪动画
  onTimeUpdate() {
    // 如果索引变化且不在动画中，则更新并滚动
    if (this.currentLyricsIndex !== -1 && !this.isManualScroll) {
      this.triggerWaveAnimation(this.currentLyricsIndex)
      this.scrollToLyric(this.currentLyricsIndex)
    }
  }

  // 优化波浪式动画效果 - 只对高亮歌词及其下方应用动画
  private triggerWaveAnimation(currentIndex: number) {
    if (this.lyricOffsets.length !== this.parsedLyrics.length) {
      this.lyricOffsets = new Array(this.parsedLyrics.length).fill(0);
    }

    // 为每个歌词项计算波浪偏移
    this.parsedLyrics.forEach((_, index) => {
      // 只对高亮歌词及其下方的歌词应用波浪动画
      if (index >= currentIndex) {
        const distance = index - currentIndex; // 使用相对距离，不取绝对值

        // 波浪效果：距离当前项越近，波动越明显
        if (distance < 8) {
          const waveIntensity = (8 - distance) * 3; // 波浪强度
          const delay = distance * 40; // 延迟时间，形成波浪传播效果

          // 使用定时器创建延迟动画
          setTimeout(() => {
            this.uiContext?.animateTo({
              duration: AnimationConstants.DURATION_NORMAL,
              curve: AnimationConstants.CURVE_SPRING,
            }, () => {
              // 先向上偏移，然后回到原位
              this.lyricOffsets[index] = -waveIntensity;
            });

            // 回弹动画
            setTimeout(() => {
              this.uiContext?.animateTo({
                duration: AnimationConstants.DURATION_FAST,
                curve: AnimationConstants.CURVE_DECELERATE,
              }, () => {
                this.lyricOffsets[index] = 0;
              });
            }, 150);
          }, delay);
        }
      }
    });
  }

  // 滚动到指定歌词位置
  private scrollToLyric(index: number) {
    if (index < 0) {
      return
    }
    this.isAutoScroll = true
    // 保持在视图中间偏上的位置，很显然这是一个经验修正
    const targetIndex = this.getTargetIndex(index)
    this.uiContext?.animateTo({
      duration: this.SCROLL_ANIMATION_DURATION,
      curve: Curve.EaseOut,
      onFinish: () => {
        this.isAutoScroll = false
      }
    }, () => {
      this.scroller.scrollToIndex(targetIndex)
    })
  }

  private getTargetIndex(index: number) {
    return Math.max(0, this.mode_judge ? index - (this.showTranslation ? 1 : 3) : index - (this.showTranslation ? 0 : 1))
  }

  // 切换翻译显示状态
  private toggleTranslation() {
    this.uiContext?.animateTo({
      duration: 500,
      curve: Curve.EaseInOut,
      onFinish: () => {
        this.startManualScrollTimer()
      }
    }, () => {
      this.showTranslation = !this.showTranslation
      this.scrollToLyric(this.currentLyricsIndex)
      PreferencesCache.showTranslationLyric(this.showTranslation)
      VibrationControl.handlePresetVibration()
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.parsedLyrics.length === 0) {
          Text($r('app.string.no_lyric_available'))
            .fontSize(18)
            .fontColor('rgba(255, 255, 255, 0.5)')
            .margin(16)
        } else {
          // 使用 Stack 包裹 List 以添加渐变遮罩
          Stack() {
            List({
              initialIndex: this.getTargetIndex(this.currentLyricsIndex),
              scroller: this.scroller
            }) {
              ForEach(this.parsedLyrics, (item: LyricsLine, index) => {
                ListItem() {
                  LyricItem({
                    item: item,
                    index: index,
                    showTranslation: this.showTranslation,
                    currentLyricsIndex: this.currentLyricsIndex,
                    offsetY: this.lyricOffsets[index] || 0 // 传递波浪偏移量
                  })
                }
                .width(StyleConstants.FULL_WIDTH)
                .key('lyricItem'+index)
                .onClick(() => {
                  this.handleLyricClick(item.time, index)
                })
              })
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .onDidScroll(() => {
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
            .contentStartOffset(100)
            .contentEndOffset(100)
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .layoutWeight(1)
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)

      // 现代化翻译按钮 - 半透明背景 + 阴影效果
      if ((this.hasTranslation || this.hasTransliteration) && this.mode_judge === true) {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_translate'))
            .width(24)
            .height(24)
            .fillColor(this.showTranslation ? Color.White : 'rgba(255, 255, 255, 0.5)')
        }
        .width(52)
        .height(52)
        .visibility(this.isManualScroll ? Visibility.Visible : Visibility.None)
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

      Column() {
        Text(`历史偏移：${this.lastLyricsOffsetTime}MS`)
          .fontSize(16)
          .fontColor(Color.White)
          .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
          .animation({
            duration: 200
          })
        Text(`当前偏移：${this.currentLyricsOffsetTime}MS`)
          .fontSize(16)
          .fontColor(Color.White)
          .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
          .animation({
            duration: 200
          })
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: this.winHeight*0.30 })
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK)
      .height(60)
      .width(200)
      .borderRadius(15)
      .visibility(this.isShow ? Visibility.Visible : Visibility.None)

    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .gesture(
      GestureGroup(GestureMode.Exclusive,

        PanGesture({ fingers: 3 , direction: PanDirection.Vertical, distance: 1 })
          .onActionEnd((event: GestureEvent)=> {
            const currentStep = Math.floor(event.offsetY / 20)
            if(currentStep < 1){
              LyricsManager.setPreTime(0)
              PreferencesCache.currentLyricsOffsetTime(0)
              this.currentLyricsOffsetTime = 0
              this.lastLyricsOffsetTime = 0
              VibrationControl.handlePresetVibration(1)
              ToastUtil.showToast(`当前歌词偏移：${this.currentLyricsOffsetTime}MS`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/4 } })
            }
            if(currentStep > 1){
              if(this.hasTranslation || this.hasTransliteration){
                this.toggleTranslation()
              }
            }
          }),

        PanGesture({ fingers: 2 , direction: PanDirection.Vertical, distance: 1 })
          .onActionStart(() => {
            this.isShow = true
          })
          .onActionUpdate((event: GestureEvent)=> {
            const newStep = Math.floor(event.offsetY / 50)
            if(this.handleUpdate(newStep)){
              this.currentLyricsOffsetTime = this.lastLyricsOffsetTime + this.lastStep*100
              LyricsManager.setPreTime(this.currentLyricsOffsetTime)
              PreferencesCache.currentLyricsOffsetTime(this.currentLyricsOffsetTime)
              VibrationControl.handlePresetVibration(1)
            }
          })
          .onActionEnd(() => {
            this.lastStep = 0
            this.isShow = false
            this.lastLyricsOffsetTime = this.currentLyricsOffsetTime
            ToastUtil.showToast(`当前歌词偏移：${this.currentLyricsOffsetTime}MS`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/4 } })
          }),

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
    // 更新UI状态
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
    if (this.manualScrollTimeoutId !== -1) {
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

