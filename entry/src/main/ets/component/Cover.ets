import { StyleConstants } from "../constants/StyleConstants"
import { AnimationConstants } from "../constants/AnimationConstants"

@Component
export struct Cover {
  loading?: boolean = false
  title?: string = ''
  subTitle?: string = ''
  menuItems?: MenuElement[] = []
  src: ResourceStr = ''
  radius: number | string = 8
  titleAlign: TextAlign = TextAlign.Start
  overlayTitle?: boolean = false // 是否将标题叠加在图片上

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
    Column({ space: 10 }) {
      Stack({ alignContent: this.overlayTitle ? Alignment.Bottom : Alignment.TopStart }) {
        Image(this.src ?? $r("app.media.icon"))
          .width(StyleConstants.FULL_WIDTH)
          .aspectRatio(1)
          .borderRadius(this.radius)
          .clip(true)
          .shadow({
            radius: 12,
            color: $r("app.color.shadow_medium"),
            offsetX: 0,
            offsetY: 4
          })
          .hoverEffect(HoverEffect.Scale)

        this.MoreButton()
      }
      .width(StyleConstants.FULL_WIDTH)

        Column({ space: 6 }) {
          if (this.loading) {
            Text()
              .width('80%')
              .height(16)
              .backgroundColor($r('app.color.skeleton_loading'))
              .borderRadius(4)

            if (this.subTitle) {
              Text()
                .width('60%')
                .height(14)
                .backgroundColor($r('app.color.skeleton_loading'))
                .borderRadius(4)
            }
          } else {
            if (this.title) {
              Text(this.title)
                .width(StyleConstants.FULL_WIDTH)
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .fontWeight(FontWeight.Medium)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
                .textAlign(this.titleAlign)
                .lineHeight(20)
            }

            if (this.subTitle) {
              Text(this.subTitle)
                .width(StyleConstants.FULL_WIDTH)
                .fontSize(13)
                .fontWeight(FontWeight.Regular)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
                .textAlign(this.titleAlign)
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .width(StyleConstants.FULL_WIDTH)
    }
    .clickEffect({ level: ClickEffectLevel.LIGHT })
  }


}