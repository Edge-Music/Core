import { DialogAction, DialogHelper } from "@pura/harmony-dialog"
import { ToastUtil } from "@pura/harmony-utils"
import { EventHelper } from "../util/EventHelper"
import { AnimationConstants } from "../constants/AnimationConstants"

@Component
export struct TimerSelector {
  @StorageLink('playing_pause_time') pauseAt: number = -1
  @StorageProp('winHeight') winHeight: number = 0
  @State remainingTime: string = ''
  @State selectedOption: number = -1
  @State isVisible: boolean = false
  @State showTimerUI: boolean = false
  private timerId: number | null = null
  // 预设时间选项（分钟）
  private readonly timeOptions: number[] = [10, 15, 20, 30, 45, 60, 90, 120]
  uiContext: UIContext | undefined = undefined;
  aboutToAppear() {
    this.startCountdown()
    this.uiContext = this.getUIContext();
    // Initialize selected option if timer is active
    if (this.pauseAt > 0) {
      const remainingMinutes = Math.floor((this.pauseAt - Date.now()) / 60000)
      this.selectedOption = this.timeOptions.includes(remainingMinutes) ? remainingMinutes : -1
      this.showTimerUI = true
    }

    // Trigger entrance animation
    setTimeout(() => {
      this.isVisible = true
    }, 50)
  }

  aboutToDisappear() {
    if (this.timerId !== null) {
      clearInterval(this.timerId)
      this.timerId = null
    }
  }

  private updateRemainingTime() {
    const remaining = this.pauseAt - Date.now()
    if (remaining <= 0) {
      // Animate out the timer UI first, then clear the time
      if (this.showTimerUI) {
        this.showTimerUI = false
        setTimeout(() => {
          this.remainingTime = ''
          this.selectedOption = -1
        }, 300) // Match animation duration
      } else {
        this.remainingTime = ''
        this.selectedOption = -1
      }
      return
    }

    const hours = Math.floor(remaining / 3600000)
    const minutes = Math.floor((remaining % 3600000) / 60000)
    const seconds = Math.floor((remaining % 60000) / 1000)

    if (hours > 0) {
      this.remainingTime = `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
    } else {
      this.remainingTime = `${minutes}:${seconds.toString().padStart(2, '0')}`
    }

    // Show timer UI if it's not already visible
    if (!this.showTimerUI) {
      this.showTimerUI = true
    }
  }

  private startCountdown() {
    if (this.timerId !== null) {
      clearInterval(this.timerId)
    }
    this.updateRemainingTime() // Update immediately
    this.timerId = setInterval(() => {
      this.updateRemainingTime()
    }, 1000)
  }

  private setTimer(minutes: number) {
    this.uiContext?.animateTo({
      duration: AnimationConstants.DURATION_NORMAL,
      curve: AnimationConstants.CURVE_DECELERATE
    }, () => {
      this.showTimerUI = true
      const now = Date.now()
      const endTime = now + minutes * 60000 // 计算结束时间
      this.pauseAt = endTime // 更新暂停时间
      this.selectedOption = minutes // 更新选中选项
      EventHelper.postPauseTimer(endTime)
    })
  }

  private cancelTimer() {
    this.uiContext?.animateTo({
      duration: AnimationConstants.DURATION_NORMAL,
      curve: AnimationConstants.CURVE_DECELERATE
    }, () => {
      this.showTimerUI = false
      this.pauseAt = -1
      this.selectedOption = -1
      EventHelper.postPauseTimer(-1)
    })
  }

  @Builder
  TimeOption(minutes: number, index: number) {
    Button({ type: ButtonType.Capsule }) {
      Row() {
        Text(minutes.toString())
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(minutes === this.selectedOption ? Color.White : $r('app.color.text_title'))

        Text($r('app.string.minute'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 4 })
          .fontColor(minutes === this.selectedOption ? 'rgba(255, 255, 255, 0.9)' :
          $r('app.color.text_secondary'))
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 18, right: 18 })
    }
    .height(48)
    .backgroundColor(minutes === this.selectedOption ? $r('app.color.accent_primary') :
    $r('app.color.surface_2'))
    .backgroundBlurStyle(minutes === this.selectedOption ? BlurStyle.COMPONENT_THICK : BlurStyle.COMPONENT_THIN)
    .shadow(minutes === this.selectedOption ? ShadowStyle.OUTER_DEFAULT_MD : ShadowStyle.OUTER_DEFAULT_SM)
    .margin({ right: 12, bottom: 16 })
    .borderRadius(24)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .hoverEffect(HoverEffect.Highlight)
    .onClick(() => this.setTimer(minutes))
    .animation({
      duration: AnimationConstants.DURATION_NORMAL,
      curve: AnimationConstants.CURVE_DECELERATE,
      delay: 50 + index * 30,
      iterations: 1,
      playMode: PlayMode.Normal
    })
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 20 }))
      .animation({
        duration: AnimationConstants.DURATION_NORMAL,
        curve: AnimationConstants.CURVE_DECELERATE,
        delay: 50 + index * 30
      }))
    .opacity(this.isVisible ? 1 : 0)
  }

  build() {
    Column() {
      // Use fixed heights for transition areas to prevent content jump
      // 紧凑型倒计时显示区域 - 横向布局，节省垂直空间
      Column() {
        if (this.remainingTime) {
          Row() {
            // 左侧：倒计时信息
            Row({ space: 12 }) {
              // 时钟图标
              SymbolGlyph($r('sys.symbol.timer'))
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor([$r('app.color.accent_primary')])

              // 倒计时文字
              Column({ space: 2 }) {
                Text('剩余时间')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_secondary'))

                Text(this.remainingTime)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bolder)
                  .fontColor($r('app.color.accent_primary'))
                  .textShadow({
                    radius: 6,
                    color: 'rgba(255, 107, 129, 0.25)',
                    offsetX: 0,
                    offsetY: 0
                  })
              }
              .alignItems(HorizontalAlign.Start)
            }
            .layoutWeight(1)

            // 右侧：开关控制
            Row({ space: 8 }) {
              Text('开启')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_secondary'))

              Toggle({ type: ToggleType.Switch, isOn: true })
                .width(48)
                .height(28)
                .switchPointColor(Color.White)
                .selectedColor($r('app.color.accent_primary'))
                .onChange((isOn) => {
                  if (!isOn) {
                    this.cancelTimer()
                  }
                })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Center)
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .backgroundColor($r('app.color.surface_1'))
          .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
          .shadow(ShadowStyle.OUTER_DEFAULT_MD)
          .borderRadius(16)
          .animation({
            duration: AnimationConstants.DURATION_NORMAL,
            curve: AnimationConstants.CURVE_SPRING
          })
          .opacity(this.showTimerUI ? 1 : 0)
          .scale({ x: this.showTimerUI ? 1 : 0.95, y: this.showTimerUI ? 1 : 0.95 })
        }
      }
      .animation({
        duration: AnimationConstants.DURATION_NORMAL,
        curve: AnimationConstants.CURVE_SPRING
      })
      .height(this.remainingTime ? (this.showTimerUI ? 68 : 0) : 0)
      .margin({ bottom: this.remainingTime && this.showTimerUI ? 20 : 0 })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.95, y: 0.95 }))
        .animation({
          duration: AnimationConstants.DURATION_NORMAL,
          curve: AnimationConstants.CURVE_SPRING
        }))

      // 现代化标题
      Text($r('app.string.select_time'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_title'))
        .alignSelf(ItemAlign.Start)
        .margin({ top: 8, bottom: 20 })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 10 }))
          .animation({
            duration: AnimationConstants.DURATION_SLOW,
            curve: AnimationConstants.CURVE_DECELERATE,
            delay: 200
          }))
        .opacity(this.isVisible ? 1 : 0)

      // Preset time options with more spacing
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.timeOptions, (minutes: number, index: number) => {
          this.TimeOption(minutes, index)
        })
      }
      .width('100%')
      .padding({ top: 8, bottom: 12 })
      .margin({ bottom: 24 })

      // 现代化自定义时间按钮 - 增强模糊效果
      Button() {
        Row() {
          Text($r('app.string.custom_time'))
            .fontColor($r('app.color.text_title'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .backgroundColor($r('app.color.surface_2'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
      .shadow(ShadowStyle.OUTER_DEFAULT_SM)
      .height(56)
      .width('100%')
      .borderRadius(28)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
      .hoverEffect(HoverEffect.Highlight)
      .onClick(() => {
        DialogHelper.showTextInputDialog({
          title: $r('app.string.set_scheduled_shutdown'),
          text: this.pauseAt > 0 ? Math.floor((this.pauseAt - Date.now()) / 60000).toString() : '',
          inputType: InputType.Number,
          cancelButton: {
            style: CancelButtonStyle.INVISIBLE
          },
          onAction: (action: number, _dialogId: string, value: string): void => {
            if (action == DialogAction.SURE) {
              const min = parseInt(value)
              if (isNaN(min) || min <= 0) {
                ToastUtil.showToast("请输入一个有效的分钟数", { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/4 } })
                return
              }
              this.setTimer(min)
            }
          }
        })
      })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
        .animation({
          duration: AnimationConstants.DURATION_SLOW,
          curve: AnimationConstants.CURVE_DECELERATE,
          delay: 300 + this.timeOptions.length * 30
        }))
      .opacity(this.isVisible ? 1 : 0)
    }
    .width('100%')
    .height("100%")
    .padding(24)
    .borderRadius(20)
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
      .animation({
        duration: AnimationConstants.DURATION_SLOW,
        curve: AnimationConstants.CURVE_SPRING
      }))
    .opacity(this.isVisible ? 1 : 0)
  }
}