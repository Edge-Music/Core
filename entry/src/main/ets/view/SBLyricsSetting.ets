import { StyleConstants } from "../constants/StyleConstants";
import { PreferencesCache, SBLyricsPre } from "../util/PreferenceCache";
import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem } from "@kit.ArkUI";
import { LogUtil } from "@pura/harmony-utils";

@Component
export struct SBLyricsSetting{
  @Consume('NavPathStack') pageStack: NavPathStack;
  @State @Watch("onChangeSetting") settingData: SBLyricsPre = PreferencesCache.statusBarLyricsSetting()
  @State linesOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '单行' }, { text: '双行' }] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THIN,
    fontSize:12
  })
  @State linesIndex:number[] = [this.settingData.lines]
  @State alignOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '居中' }, { text: '居左' }] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.BACKGROUND_REGULAR,
    fontSize:12
  })
  @State alignIndex:number[] = [this.settingData.alignment]
  onChangeSetting(){
    LogUtil.info('SBLSetting '+ JSON.stringify(this.settingData))
    PreferencesCache.statusBarLyricsSetting(this.settingData)
  }
  build() {
    NavDestination(){
      Column({ space: 8 }) {
        Column({ space: 1 }) {
          Row() {
            Text('状态栏歌词')
              .fontSize(16)
              .fontColor($r('app.color.text_title'))
              .fontWeight(FontWeight.Medium)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.settingData.open })
              .onChange((isOn:boolean)=>{
                this.settingData.open = isOn
              })
          }
          .width(StyleConstants.FULL_WIDTH)
          .padding({
            left: 16,
            right: 16,
            top: 12,
            bottom: 12
          })
        }
        .backgroundColor($r('app.color.setting_item_background'))
        .borderRadius(8)
      }
      .width(StyleConstants.FULL_WIDTH)
      .expandSafeArea()
      .padding({ left: 12, right: 12, top: 5 })
      .transition({ opacity: 250, scale: { x: 1, y: 1 } })
      .animation({
        delay: 50,
        duration: 250,
        curve: Curve.FastOutSlowIn
      })
      if (this.settingData.open)
      Column({ space: 8 }) {
        Column({ space: 8 }) {
          Row() {
            Text('展示方式')
              .fontSize(16)
              .fontColor($r('app.color.text_title'))
              .fontWeight(FontWeight.Medium)
            Blank()
              .layoutWeight(1)
            SegmentButton({
              options:this.linesOptions,
              selectedIndexes:this.linesIndex,
              onItemClicked:(data:number)=>{
                this.settingData.lines = data
              }
            })
              .width(120)
              .height(26)
              .margin({right:6})
          }
          .width(StyleConstants.FULL_WIDTH)
          Row() {
            Text('对齐方式')
              .fontSize(16)
              .fontColor($r('app.color.text_title'))
              .fontWeight(FontWeight.Medium)
            Blank()
              .layoutWeight(1)
            SegmentButton({
              options:this.alignOptions,
              selectedIndexes:this.alignIndex,
              onItemClicked:(data:number)=>{
                this.settingData.alignment = data
              }
            })
              .width(120)
              .height(26)
              .margin({right:6})
          }
          .width(StyleConstants.FULL_WIDTH)
          Row() {
            Text('左右调节')
              .fontSize(16)
              .fontColor($r('app.color.text_title'))
              .fontWeight(FontWeight.Medium)
            Blank()
            Slider({
              value:this.settingData.x,
              min: 0,
              max: 100,
              style: SliderStyle.InSet
            })
              .layoutWeight(1)
              .onChange((value:number)=>{
                this.settingData.x = value
              })
          }
          .width(StyleConstants.FULL_WIDTH)
          Row() {
            Text('上下调节')
              .fontSize(16)
              .fontColor($r('app.color.text_title'))
              .fontWeight(FontWeight.Medium)
            Blank()
            Slider({
              value:this.settingData.y,
              min: 0,
              max: 100,
              style: SliderStyle.InSet
            })
              .layoutWeight(1)
              .onChange((value:number)=>{
                this.settingData.y = value
              })
          }
          .width(StyleConstants.FULL_WIDTH)
          Row() {
            Text('显示宽度')
              .fontSize(16)
              .fontColor($r('app.color.text_title'))
              .fontWeight(FontWeight.Medium)
            Blank()
            Slider({
              value:this.settingData.width,
              min: 0,
              max: 100,
              style: SliderStyle.InSet
            })
              .layoutWeight(1)
              .onChange((value:number)=>{
                this.settingData.width = value
              })
          }
          .width(StyleConstants.FULL_WIDTH)
          Row() {
            Text('背景透明')
              .fontSize(16)
              .fontColor($r('app.color.text_title'))
              .fontWeight(FontWeight.Medium)
            Blank()
            Slider({
              value:this.settingData.transparency,
              min: 0,
              max: 100,
              style: SliderStyle.InSet
            })
              .layoutWeight(1)
              .onChange((value:number)=>{
                this.settingData.transparency = value
              })
          }
          .width(StyleConstants.FULL_WIDTH)
          Row() {
            Text('Aa')
              .fontSize(12)
              .fontColor($r('app.color.text_title'))
              .fontWeight(FontWeight.Medium)
            Slider({
              value:this.settingData.fontSize,
              min: 0,
              max: 100,
              style: SliderStyle.InSet
            })
              .layoutWeight(1)
              .onChange((value:number)=>{
                this.settingData.fontSize = value
              })
            Text('Aa')
              .fontSize(24)
              .fontColor($r('app.color.text_title'))
              .fontWeight(FontWeight.Medium)
          }
          .width(StyleConstants.FULL_WIDTH)
        }
        .backgroundColor($r('app.color.setting_item_background'))
        .borderRadius(8)
        .padding({left:16,right:16,bottom:12,top:12})
      }
      .width(StyleConstants.FULL_WIDTH)
      .expandSafeArea()
      .padding({ left: 12, right: 12, top: 5 })
      .transition({ opacity: 250, scale: { x: 1, y: 1 } })
      .animation({
        delay: 50,
        duration: 250,
        curve: Curve.FastOutSlowIn
      })
    }.title('状态栏歌词设置').hideToolBar(true).backgroundColor($r('app.color.page_background'))
  }
}