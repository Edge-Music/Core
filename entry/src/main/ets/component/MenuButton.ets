import { StyleConstants } from "../constants/StyleConstants"

@Component
export struct MenuButton {
  @State private isAnimating: boolean = false
  @State private isPressed: boolean = false
  title: ResourceStr = ''
  onNavigate?: (event: ClickEvent) => void
  private animationTimer: number | undefined

  aboutToDisappear() {
    if (this.animationTimer !== undefined) {
      clearTimeout(this.animationTimer)
    }
  }

  @Builder
  private ArrowIcon() {
    Row() {
      Image($r('app.media.ic_chevron_right'))
        .width(16)
        .height(16)
        .fillColor($r("app.color.icon_normal"))
        .translate({ x: this.isAnimating ? 4 : 0 })
        .scale({ x: this.isAnimating ? 1.1 : 1, y: this.isAnimating ? 1.1 : 1 })
        .animation({
          duration: 200,
          curve: Curve.EaseOut,
          iterations: 1,
          playMode: PlayMode.Normal,
          onFinish: () => {
            this.isAnimating = false // 动画结束时直接重置状态
          }
        })
    }
    .margin({ right: this.isAnimating ? -8 : -4 })
    .animation({
      duration: 200,
      curve: Curve.EaseOut
    })
  }

  build() {
    Row() {
      Text(this.title)
        .fontSize(16)
        .fontColor($r("app.color.text_secondary"))
        .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
      Blank()
      this.ArrowIcon()
    }
    .hoverEffect(HoverEffect.Scale)
    .width(StyleConstants.FULL_WIDTH)
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.isPressed ? $r("app.color.homepage_menu_button_pressed") : $r("app.color.homepage_menu_button_normal"))
    .border({ width: 0.5, color: $r("app.color.homepage_menu_button_divider") })
    .borderRadius(8)
    .onClick((event: ClickEvent) => {
      // 立即触发导航回调，不等待动画完成
      this.onNavigate?.(event)

      // 只有在没有动画时才开始新动画
      if (!this.isAnimating) {
        this.isAnimating = true
      }
    })
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false
      }
    })
  }
}