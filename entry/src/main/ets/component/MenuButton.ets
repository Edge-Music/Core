import { StyleConstants } from "../constants/StyleConstants"
import { AnimationConstants } from "../constants/AnimationConstants"

@Component
export struct MenuButton {
  @State private isAnimating: boolean = false
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
    Image($r('app.media.ic_chevron_right'))
      .width(18)
      .height(18)
      .fillColor($r("app.color.accent_primary"))
      .translate({ x: this.isAnimating ? 6 : 0 })
      .animation({
        duration: AnimationConstants.DURATION_FAST,
        curve: AnimationConstants.CURVE_SPRING,
        iterations: 1,
        playMode: PlayMode.Normal,
        onFinish: () => {
          this.isAnimating = false
        }
      })
  }

  build() {
    Row({ space: 8 }) {
      Text(this.title)
        .fontSize(15)
        .fontColor($r("app.color.text_primary"))
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      this.ArrowIcon()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(52)
    .padding({ left: 16, right: 16 })
    .borderRadius(14)
    .stateStyles({
      normal: this.normalStyles,
      pressed: this.pressedStyles,
      focused: this.focusedStyles
    })
    .shadow({
      radius: 12,
      color: $r("app.color.shadow_light"),
      offsetX: 0,
      offsetY: 2
    })
    .onClick((event: ClickEvent) => {
      this.onNavigate?.(event)

      // 触发箭头动画
      if (!this.isAnimating) {
        this.isAnimating = true
      }
    })
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
    .clickEffect({
      level: ClickEffectLevel.LIGHT,
      scale: 0.95
    })
    .hoverEffect(HoverEffect.Highlight)
  }

  @Styles normalStyles() {
    .backgroundColor($r("app.color.card_elevated"))
  }

  @Styles pressedStyles() {
    .backgroundColor($r("app.color.interactive_pressed"))
  }

  @Styles focusedStyles() {
    .backgroundColor($r("app.color.card_hover"))
    .border({
      width: 2,
      color: $r("app.color.accent_primary")
    })
  }
}