import { StyleConstants } from "../constants/StyleConstants"
import { HorizontalScroll } from "./HorizontalScroll"
import { AnimationConstants } from "../constants/AnimationConstants"

export enum SegmentDisplayMode {
  HORIZONTAL_SCROLL = 'horizontal', // 横向滚动卡片
  VERTICAL_LIST = 'vertical', // 纵向列表
  GRID = 'grid' // 网格布局
}

@Component
export struct Segment {
  @Prop loading: boolean = false
  @Prop lists: Object[]
  @Prop type: string
  @State title: string | Resource = ''
  actionText: string | undefined | Resource = undefined
  onActionClick?: () => void
  radius: string | number = 8
  displayMode: SegmentDisplayMode = SegmentDisplayMode.HORIZONTAL_SCROLL
  @State isExpanded: boolean = false

  @BuilderParam
  items?: () => void

  @Builder
  private SkeletonLoading() {
    Column() {
      Row() {
        Text()
          .width('30%')
          .height(20)
          .backgroundColor($r('app.color.skeleton_loading'))
          .borderRadius(4)

        if(this.actionText) {
          Text()
            .width('20%')
            .height(16)
            .backgroundColor($r('app.color.skeleton_loading'))
            .borderRadius(4)
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({
        left: 12,
        top: 8,
        right: 12,
        bottom: 4
      })

      HorizontalScroll({ lists: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], type: 'Template'})
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      if(this.loading) {
        this.SkeletonLoading()
      } else {
        // 标题栏
        Row() {
          Text(this.title)
            .fontColor($r('app.color.text_title'))
            .fontWeight(FontWeight.Bold)
            .fontSize(22)

          Blank()

          if(this.actionText) {
            Row({ space: 4 }){
              Text(this.actionText)
                .fontColor($r('app.color.accent_primary'))
                .fontWeight(FontWeight.Medium)
                .fontSize(14)

              Image($r('app.media.refresh'))
                .width(16)
                .height(16)
                .fillColor($r('app.color.accent_primary'))
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(20)
            .backgroundColor($r('app.color.interactive_normal'))
            .onClick(this.onActionClick)
            .clickEffect({ level: ClickEffectLevel.LIGHT })
            .animation({
              duration: AnimationConstants.DURATION_FAST,
              curve: AnimationConstants.CURVE_DECELERATE
            })
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({
          left: 16,
          top: 12,
          right: 16,
          bottom: 8
        })

        // 内容区域
        if (this.displayMode === SegmentDisplayMode.HORIZONTAL_SCROLL) {
          HorizontalScroll({ lists: this.lists, type: this.type })
        }
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 8, bottom: 8 })
  }
}