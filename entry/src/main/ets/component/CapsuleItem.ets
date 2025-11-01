import { StyleConstants } from "../constants/StyleConstants"
import { AnimationConstants } from "../constants/AnimationConstants"

/**
 * 胶囊风格组件
 * 用于展示歌单、标签等内容
 */
@Component
export struct CapsuleItem {
  title: string = ''
  menuItems?: MenuElement[] = []
  onItemClick?: () => void

  build() {
    Row({ space: 8 }) {
      Text(this.title)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 更多图标按钮
      if (this.menuItems && this.menuItems.length > 0) {
        Image($r('app.media.ic_more'))
          .width(18)
          .height(18)
          .fillColor($r('app.color.icon_normal'))
          .bindMenu(this.menuItems)
      }
    }
    .height(48)
    .padding({ left: 20, right: 20 })
    .borderRadius(24)
    .constraintSize({ maxWidth: 300 })
    .stateStyles({
      normal: this.normalStyles,
      pressed: this.pressedStyles
    })
    .onClick(() => {
      this.onItemClick?.()
    })
    .clickEffect({
      level: ClickEffectLevel.LIGHT,
      scale: 0.95
    })
    .hoverEffect(HoverEffect.Highlight)
  }

  @Styles normalStyles() {
    .backgroundColor($r('app.color.card_elevated'))
    .border({
      width: 1,
      color: $r('app.color.divider')
    })
  }

  @Styles pressedStyles() {
    .backgroundColor($r('app.color.interactive_pressed'))
    .border({
      width: 1,
      color: $r('app.color.accent_primary')
    })
  }
}

