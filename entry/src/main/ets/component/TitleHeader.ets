import { StyleConstants } from "../constants/StyleConstants";
import { PreferencesCache } from "../util/PreferenceCache";

@Component
export struct TitleHeader {
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('decorHeight') decorHeight: number = 0
  @Consume('NavPathStack') pageStack: NavPathStack;
  @Prop title: ResourceStr = $r("app.string.homepage")
  @BuilderParam leftContent: () => void;
  @BuilderParam rightContent: () => void;
  @BuilderParam midContent: () => void;
  @State isFirstPage: boolean = true
  @Prop backActive: boolean = false
  @State is_2in1:boolean =false
  aboutToAppear() {
    this.isFirstPage = false
    this.is_2in1= PreferencesCache.getUserPreference('devicetype')==='2in1'?true:false
  }

  pagesStackPop(){
    if(this.pageStack.size() > 1){
      this.pageStack.pop()
    }
  }

  @Builder
  BackButton() {
    if (!this.isFirstPage) {
      Row() {
        Image($r('app.media.ic_back'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.text_primary'))
          .scale({ x: this.backActive ? 0.9 : 1, y: this.backActive ? 0.9 : 1 })
          .translate({ x: this.backActive ? 4 : 0 })
          .animation({
            duration: 150,
            curve: Curve.FastOutSlowIn
          })
        Text($r('app.string.back'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 2 })
      }
      .height(28)
      .borderRadius(14)
      .padding({ left: 6, right: 10 })
      .backgroundColor($r('app.color.back_button_normal'))
      .onClick(() => {
        this.pageStack.pop()
      })
      .scale({ x: this.backActive ? 1.05 : 1, y: this.backActive ? 1.05 : 1 })
      .animation({
        duration: 150,
        curve: Curve.FastOutSlowIn
      })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Column(){
        // PC工具栏适配
        Row()
          .height(this.topRect)
          .backgroundColor('transparent')
          .width('100%')
          .visibility(this.topRect > 0 ? Visibility.Visible : Visibility.None)

        Row(){
          Image($r('app.media.icon'))
            .height(this.decorHeight/2)
            .width(this.decorHeight/2)
            .margin({ left: 16 })
          Blank().width(5)
          Text('云享社').fontSize(14).fontWeight(FontWeight.Bold)
        }
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .height(this.decorHeight)
        .backgroundColor('transparent')
        .width('100%')
        .visibility(this.decorHeight > 0 ? Visibility.Visible : Visibility.None)

        Row() {
          Row() {
            if (this.leftContent) {
              this.leftContent()
            }

            Text(this.title)
              .fontColor($r('app.color.text_title'))
              .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
              .fontSize($r('app.float.title_font_size'))
              .maxLines(1)
              .onClick(() => {
                this.backActive = true
                setTimeout(() => {
                  this.pagesStackPop()
                }, 300)
              })
              .onHover((isHover: boolean) => {
                if(isHover){
                  this.backActive = true
                }
              })

            // 自定义左侧
            if(this.midContent){
              this.midContent()
            }
            // 自定义右侧
            if (this.rightContent) {
              this.rightContent()
            }
            // Blank()
          }
          .padding({ left: 16, right: 16})
          .justifyContent(FlexAlign.SpaceBetween)
          .width(StyleConstants.FULL_WIDTH)
          .alignItems(VerticalAlign.Center)
          Row() {
            Text($r('app.string.back'))
              .fontColor($r('app.color.text_title'))
              .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
              .fontSize($r('app.float.title_font_size'))
              .maxLines(1)
              .padding({ left: 16 })
          }
          .visibility(this.backActive ? Visibility.Visible : Visibility.None)
          .width(StyleConstants.FULL_WIDTH)
          .onHover((isHover: boolean) => {
            if(isHover){
              this.backActive = true
            }else{
              this.backActive = false
            }
          })
          .onClick(() => {
            this.pagesStackPop()
          })
        }
        .width(StyleConstants.FULL_WIDTH)
        .backgroundColor(Color.Transparent)
        .height(50)
        .translate({ x: this.backActive ? '-100%' : 0 }) // 初始值16与所有标题左padding一致
        .animation({
          duration: 250,
          curve: Curve.FastOutSlowIn
        })
      }
    }
  }
}