import { StyleConstants } from "../constants/StyleConstants";
import { PreferencesCache, SBLyricsPre } from "../util/PreferenceCache";
import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem } from "@kit.ArkUI";
import { LogUtil, ToastUtil } from "@pura/harmony-utils";
import WindowUtil from "../util/WindowUtil";
import { common, Permissions } from "@kit.AbilityKit";
import { reqPermissionsFromUser } from "../util/PermissionManager";
import { avPlayerManager } from "../util/AVPlayerManager";

const TAG = 'SBLyricsSetting'
@Component
export struct SBLyricsSetting{
  @State handlePopup: boolean = false
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('winHeight') winHeight: number = 0
  @State @Watch("onChangeSetting") settingData: SBLyricsPre = PreferencesCache.statusBarLyricsSetting()
  @State linesIndex: number[] = [this.settingData.lines]
  @State alignIndex:number[] = [this.settingData.alignment]

  @State linesOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '单行' }, { text: '双行' }] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THIN,
    selectedBackgroundColor: $r('app.color.title_emphasis_color'),
    fontSize: 12
  })
  @State alignOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '居中' }, { text: '居左' }] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.BACKGROUND_REGULAR,
    selectedBackgroundColor: $r('app.color.title_emphasis_color'),
    fontSize: 12
  })

  aboutToAppear(): void {
    if(this.settingData.open) {
      WindowUtil.createLyricsFloatWindow()
    }
  }

  async aboutToDisappear(): Promise<void> {
    avPlayerManager.avPlayer
    const player = await avPlayerManager.getAVPlayerInstance();
    if(player.state !== 'playing') {
      WindowUtil.destroyLyricsFloatWindow()
    }
  }

  onChangeSetting(){
    LogUtil.info('SBLSetting '+ JSON.stringify(this.settingData))
    PreferencesCache.statusBarLyricsSetting(this.settingData)
    AppStorage.setOrCreate('SBLyricsSetting', JSON.stringify(this.settingData))
  }

  build() {
    NavDestination(){
      Column({ space: 8 }) {
        Scroll() {
          Column({ space: 4 }) {
            Row() {
              Text('状态栏歌词')
                .fontSize(16)
                .fontColor($r('app.color.text_title'))
                .fontWeight(FontWeight.Medium)
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.settingData.open })
                .onChange((isOn: boolean) => {
                  this.settingData.open = isOn
                  if (isOn) {
                    const permissions: Array<Permissions> = ['ohos.permission.SYSTEM_FLOAT_WINDOW'];
                    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
                    reqPermissionsFromUser(permissions, context).then((result: boolean) => {
                      if(result) {
                        WindowUtil.createLyricsFloatWindow()
                        LogUtil.info(`[${TAG}]`, `悬浮窗权限已获取: [SYSTEM_FLOAT_WINDOW]`);
                        ToastUtil.showToast("悬浮窗权限授权成功", { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/4 } });
                      } else {
                        this.settingData.open = false
                        WindowUtil.destroyLyricsFloatWindow()
                        LogUtil.info(`[${TAG}]`, `悬浮窗权限未获取: [SYSTEM_FLOAT_WINDOW]`);
                        ToastUtil.showToast("未获得悬浮窗授权，用户可再次授予", { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/4 } });
                      }
                    })
                  } else {
                    WindowUtil.destroyLyricsFloatWindow()
                  }
                })
                .selectedColor($r('app.color.title_emphasis_color'))
            }
            .width(StyleConstants.FULL_WIDTH)
            .backgroundColor($r('app.color.setting_item_background'))
            .padding(12)
            .borderRadius(8)

            Column({ space: 4 }) {
              Column({ space: 12 }) {
                // Row() {
                //   Text('展示方式')
                //     .fontSize(16)
                //     .fontColor($r('app.color.text_title'))
                //     .fontWeight(FontWeight.Medium)
                //   Blank()
                //     .layoutWeight(1)
                //   SegmentButton({
                //     options: this.linesOptions,
                //     selectedIndexes:this.linesIndex,
                //     onItemClicked:(data:number)=>{
                //       this.settingData.lines = data
                //     }
                //   })
                //     .width(120)
                //     .height(26)
                //     .margin({right:6})
                // }
                // .width(StyleConstants.FULL_WIDTH)
                Row() {
                  Text('对齐方式')
                    .fontSize(16)
                    .fontColor($r('app.color.text_title'))
                    .fontWeight(FontWeight.Medium)
                  Blank()
                    .layoutWeight(1)
                  SegmentButton({
                    options: this.alignOptions,
                    selectedIndexes:this.alignIndex,
                    onItemClicked:(data:number)=>{
                      this.settingData.alignment = data
                    }
                  })
                    .width(120)
                    .margin({right:6})
                }
                .height(26)
                .width(StyleConstants.FULL_WIDTH)

                Row() {
                  Text('展示阴影')
                    .fontSize(16)
                    .fontColor($r('app.color.text_title'))
                    .fontWeight(FontWeight.Medium)
                  Text('󰄀')
                    .margin({ left: 2 })
                    .fontSize(16)
                    .fontColor($r('app.color.text_title'))
                    .onClick(() => {
                      this.handlePopup = true
                    })
                    .bindPopup($$this.handlePopup, {
                      message: '仅2in1、PC、平板设备生效',
                      placement: Placement.Top,
                      onWillDismiss: () => {
                        this.handlePopup = false
                      }
                    })
                  Blank()
                  Toggle({ type: ToggleType.Switch, isOn: this.settingData.showShadow })
                    .onChange((isOn: boolean) => {
                      this.settingData.showShadow = isOn
                    })
                    .selectedColor($r('app.color.title_emphasis_color'))
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
                    max: 1.00,
                    step: 0.01,
                    style: SliderStyle.InSet
                  })
                    .selectedColor($r('app.color.title_emphasis_color'))
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
                    max: 1.00,
                    step: 0.01,
                    style: SliderStyle.InSet
                  })
                    .selectedColor($r('app.color.title_emphasis_color'))
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
                    min: 0.10,
                    max: 1.00,
                    step: 0.01,
                    style: SliderStyle.InSet
                  })
                    .selectedColor($r('app.color.title_emphasis_color'))
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
                    max: 1,
                    step: 0.01,
                    style: SliderStyle.InSet
                  })
                    .selectedColor($r('app.color.title_emphasis_color'))
                    .layoutWeight(1)
                    .onChange((value: number)=>{
                      this.settingData.transparency = value
                    })
                }
                .width(StyleConstants.FULL_WIDTH)

                Row() {
                  Text('圆角半径')
                    .fontSize(16)
                    .fontColor($r('app.color.text_title'))
                    .fontWeight(FontWeight.Medium)
                  Blank()
                  Slider({
                    value:this.settingData.cornerRadius,
                    min: 0,
                    max: 16,
                    step: 1,
                    style: SliderStyle.InSet
                  })
                    .selectedColor($r('app.color.title_emphasis_color'))
                    .layoutWeight(1)
                    .onChange((value: number)=>{
                      this.settingData.cornerRadius = value
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
                    min: 12,
                    max: 24,
                    style: SliderStyle.InSet
                  })
                    .selectedColor($r('app.color.title_emphasis_color'))
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
              .padding(12)
            }
            .width(StyleConstants.FULL_WIDTH)
            .borderRadius(8)
            .visibility(this.settingData.open ? Visibility.Visible : Visibility.Hidden)
            .backgroundColor($r('app.color.setting_item_background'))

            Column().height(16+this.bottomRect/2)
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width(StyleConstants.FULL_WIDTH)
      .padding({ top: 12, left: 12, right: 12 })
    }
    .title('状态栏歌词设置')
    .hideToolBar(true)
    .backgroundColor($r('app.color.page_background'))
  }
}