import { StyleConstants } from "../constants/StyleConstants"
import { ScrollController } from "../util/ScrollController"

@Component
export struct HeaderAnimation {
  @Prop scrollController: ScrollController
  @Prop isShowLoadingProgress: boolean = false

  build() {
    Row() {
      if(this.scrollController.currentIndex >= 2 && this.isShowLoadingProgress){
        LoadingProgress()
          .width(24)
          .height(24)
          .scale(this.scrollController.currentIndex >= 2 ? { x: 1, y: 1 } : { x: 0, y: 0 })
          .animation({
            duration: 250,
            curve: Curve.FastOutSlowIn
          })
          .margin({ right: 8 })
      }

      Text(this.scrollController.getText())
        .fontColor($r('app.color.text_secondary'))
        .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
        .opacity(this.scrollController.currentIndex >= 0 ? 1 : 0)
        .translate({ y: this.scrollController.currentIndex >= 0 ? 0 : -20 })
        .animation({
          duration: 250,
          curve: Curve.FastOutSlowIn
        })
    }
    .height(this.scrollController.currentIndex >= 0 ? 40 : 0)
    .animation({
      duration: 250,
      curve: Curve.FastOutSlowIn
    })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width(StyleConstants.FULL_WIDTH)
  }
}