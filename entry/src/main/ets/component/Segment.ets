import { StyleConstants } from "../constants/StyleConstants"
import { Artist, Playlist, Song } from "../type/Adapter"
import { Cover } from "./Cover"
import { HorizontalScroll } from "./HorizontalScroll"

@Component
export struct Segment {
  @Prop loading: boolean = false
  @Prop lists: Object[]
  @Prop type: string
  @State title: string | Resource = ''
  actionText: string | undefined | Resource = undefined
  onActionClick?: () => void
  radius: string | number = 8

  @BuilderParam
  items?: () => void

  @Builder
  private Title() {
    Row() {
      Text(this.title)
        .fontColor($r('app.color.text_title'))
        .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
        .fontSize(20)
        .margin({ left: 30 })

      if (this.actionText) {
        Row() {
          Text(this.actionText)
            .fontColor($r('app.color.text_secondary'))
            .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
            .fontSize(14)

          Image($r('app.media.refresh'))
            .width(16)
            .fillColor($r('app.color.text_secondary'))
            .margin({ left: 2 })
        }
        .onClick(this.onActionClick)
        .margin({ right: 30 })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({
      top: 8,
      bottom: 4
    })
  }

  @Builder
  private SkeletonTitle() {
    Row() {
      Text()
        .width('30%')
        .height(20)
        .backgroundColor($r('app.color.skeleton_loading'))
        .borderRadius(4)
        .margin({ left: 30 })

      if (this.actionText) {
        Text()
          .width('20%')
          .height(16)
          .backgroundColor($r('app.color.skeleton_loading'))
          .borderRadius(4)
          .margin({ right: 30 })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({
      top: 8,
      bottom: 4
    })
  }

  build() {
    Column() {
      if (this.loading) {
        this.SkeletonTitle()
      } else {
        this.Title()
      }

      HorizontalScroll({
        lists: this.loading ? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] : this.lists,
        type: this.loading ? 'Template' : this.type
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 20 })
  }
}
