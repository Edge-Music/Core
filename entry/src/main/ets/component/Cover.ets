import { StyleConstants } from "../constants/StyleConstants"


@Reusable
@Component
export struct Cover {
  loading?: boolean = false
  title?: string = ''
  subTitle?: string = ''
  menuItems?: MenuElement[] = []
  src: ResourceStr = ''
  radius: number | string = 8
  titleAlign: HorizontalAlign = HorizontalAlign.Start

  @Builder
  MoreButton() {
    if (this.menuItems?.length) {
      Stack() {
        Column()
          .width(32)
          .height(32)
          .borderRadius(8)
          .backgroundColor('rgba(123, 123, 123, 0.2)')
          .backdropBlur(16)

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Image($r('app.media.ic_more'))
            .width(20)
            .height(20)
            .fillColor($r('sys.color.white'))
        }
        .width(32)
        .height(32)
        .borderRadius(8)
        .backgroundColor('transparent')
      }
      .position({ x: '100%', y: 0 })
      .translate({ x: -32, y: 0 })
      .bindMenu(this.menuItems || [])
    }
  }

  build() {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Image(this.src ?? $r("app.media.icon"))
          .hoverEffect(HoverEffect.Scale)
          .width(StyleConstants.FULL_WIDTH)
          .aspectRatio(1)
          .borderRadius(this.radius)
          .clip(true)

        this.MoreButton()
      }

      Column({ space: 4 }) {
        if (this.loading) {
          Text()
            .width('80%')
            .height(16)
            .backgroundColor('rgba(0, 0, 0, 0.05)')// 骨架屏颜色
            .borderRadius(4)

          if (this.subTitle) {
            Text()
              .width('60%')
              .height(14)
              .backgroundColor('rgba(0, 0, 0, 0.05)')// 骨架屏颜色
              .borderRadius(4)
          }
        } else {
          if (this.title) {
            Text(this.title)
              .width(StyleConstants.FULL_WIDTH)
              .fontSize(16)
              .fontColor($r('app.color.text_title'))
              .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
          }

          if (this.subTitle) {
            Text(this.subTitle)
              .width(StyleConstants.FULL_WIDTH)
              .fontSize(14)
              .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
          }
        }
      }
      .alignItems(this.titleAlign)
      .width(StyleConstants.FULL_WIDTH)
    }
    .clickEffect({ level: ClickEffectLevel.LIGHT })
  }


}