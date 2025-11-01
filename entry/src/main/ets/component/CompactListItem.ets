import { StyleConstants } from "../constants/StyleConstants"
import { AnimationConstants } from "../constants/AnimationConstants"

/**
 * 紧凑列表项组件
 * 用于横向展示内容，减少垂直空间占用
 */
@Component
export struct CompactListItem {
  title: string = ''
  subtitle: string = ''
  coverUrl: ResourceStr = ''
  radius: number | string = 8
  menuItems?: MenuElement[] = []
  onItemClick?: () => void

  build() {
    Row({ space: 12 }) {
      // 封面
      Image(this.coverUrl ?? $r("app.media.icon"))
        .width(56)
        .height(56)
        .borderRadius(this.radius)
        .backgroundColor($r('app.color.skeleton_loading'))
        .clip(true)

      // 文本信息
      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width(StyleConstants.FULL_WIDTH)

        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(StyleConstants.FULL_WIDTH)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 更多按钮
      if (this.menuItems && this.menuItems.length > 0) {
        Button({ type: ButtonType.Normal }) {
          Image($r('app.media.ic_more'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.icon_normal'))
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor($r('app.color.interactive_normal'))
        .bindMenu(this.menuItems)
        .clickEffect({
          level: ClickEffectLevel.LIGHT,
          scale: 0.9
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(72)
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .borderRadius(12)
    .stateStyles({
      normal: this.normalStyles,
      pressed: this.pressedStyles
    })
    .onClick(() => {
      this.onItemClick?.()
    })
    .clickEffect({
      level: ClickEffectLevel.LIGHT,
      scale: 0.97
    })
    .hoverEffect(HoverEffect.Highlight)
  }

  @Styles normalStyles() {
    .backgroundColor($r('app.color.card_elevated'))
  }

  @Styles pressedStyles() {
    .backgroundColor($r('app.color.interactive_pressed'))
  }
}

