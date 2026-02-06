import { PreferencesCache } from "../util/PreferenceCache";
import ResourceManager from "../util/ResourceManager";
import { PipManager } from '../util/PipManager';
import { deviceInfo } from "@kit.BasicServicesKit";
import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem, window } from "@kit.ArkUI";
import { notificationManager } from "@kit.NotificationKit";
import { common } from "@kit.AbilityKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { sensor } from "@kit.SensorServiceKit";
import WindowUtil from "../util/WindowUtil";
import { AppUtil } from "@pura/harmony-utils";

@Component
  //'0'关。'1'开。!!!!(开关颜色日后调)
export struct Personalized_settings_Component {
  @State handlePopup: boolean = false
  @State text_name: string = '';
  @State setUserPreference_name: string = '';
  // 右侧组件类型：0-Toggle 1-Segment
  @State componentType: number = 0
  @State lyricTypeIndex: number[] = []
  @State subWindowIndex: number[] = []
  @Prop showPopup: boolean = false
  @Prop popupMessage: string = ''
  private text_ctrl: string = PreferencesCache.getUserPreference(this.setUserPreference_name)
  private windowStage: window.WindowStage = AppUtil.getWindowStage()

  @State lyricsTypeOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '原词' }, { text: '翻译' }, { text: '罗马音' }] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.BACKGROUND_REGULAR,
    selectedBackgroundColor: $r('app.color.title_emphasis_color'),
    fontSize: 12,
    selectedFontSize: 12
  })

  @State subWindowOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '左手' }, { text: '智感' }, { text: '右手' }, { text: '关闭' }] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.BACKGROUND_REGULAR,
    selectedBackgroundColor: $r('app.color.title_emphasis_color'),
    fontSize: 12,
    selectedFontSize: 12
  })

  aboutToAppear(): void {
    this.lyricTypeIndex = [parseInt(PreferencesCache.getUserPreference('pip_lyrics_type', '0'))]
    this.subWindowIndex = [parseInt(PreferencesCache.getUserPreference('sub_window_show_type', '2'))]
  }

  build() {
    Column(){
      Row(){
        Text(this.text_name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))

        Text('󰄀')
          .margin({ left: 2 })
          .fontSize(16)
          .fontColor($r('app.color.text_title'))
          .onClick(() => {
            this.handlePopup = true
          })
          .visibility(this.showPopup ? Visibility.Visible : Visibility.None)
          .bindPopup($$this.handlePopup, {
            message: this.popupMessage,
            placement: Placement.Top,
            onWillDismiss: () => {
              this.handlePopup = false
            }
          })

        Blank()
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: PreferencesCache.getUserPreference(this.setUserPreference_name)==='1'?true:false})
          .selectedColor($r('app.color.title_emphasis_color'))
          .onChange((isOn: boolean) => {
            this.onSwitchChangeHandler(isOn)
          })
          .visibility(this.componentType === 0 ? Visibility.Visible : Visibility.None)

        SegmentButton({
          options: this.lyricsTypeOptions,
          selectedIndexes: this.lyricTypeIndex,
          onItemClicked:(data: number)=>{
            this.lyricTypeIndex = [data]
            PreferencesCache.setUserPreference(this.setUserPreference_name, `${data}`)
            AppStorage.setOrCreate(this.setUserPreference_name, data)
          }
        })
          .visibility(this.componentType === 1 && this.setUserPreference_name == 'pip_lyrics_type' ? Visibility.Visible : Visibility.None)
          .width(180)
          .margin({right:6})

        SegmentButton({
          options: this.subWindowOptions,
          selectedIndexes: this.subWindowIndex,
          onItemClicked:(data: number)=>{
            this.lyricTypeIndex = [data]
            PreferencesCache.setUserPreference(this.setUserPreference_name, `${data}`)
            AppStorage.setOrCreate(this.setUserPreference_name, data)
            if(data === 3) {
              const subWindow: window.Window = window.findWindow('MultiFuncSubWindow')
              WindowUtil.destroyMultiFuncSubWindow(subWindow)
            } else {
              WindowUtil.createMultiFuncSubWindow(this.windowStage).then(() => {
                const subWindow: window.Window = window.findWindow('MultiFuncSubWindow')
                let settingData = PreferencesCache.multiFuncSubWindow(this.windowStage, 0)
                subWindow.moveWindowTo(settingData.x, settingData.y);
              })
            }
          }
        })
          .visibility(this.componentType === 1 && this.setUserPreference_name == 'sub_window_show_type' ? Visibility.Visible : Visibility.None)
          .width(180)
          .margin({right:6})
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

    }
    .padding(16)
    .backgroundColor($r('app.color.setting_item_background'))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  private onSwitchChangeHandler(isOn: boolean) {
    if (isOn) {
      this.text_ctrl ='1'
      if (this.setUserPreference_name ==='pressure_change') {
        try {
          const TAG: string = '[PublishOperation]';
          const DOMAIN_NUMBER: number = 0xFF00;
          let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
          notificationManager.isNotificationEnabled().then((data: boolean) => {
            hilog.info(DOMAIN_NUMBER, TAG, "isNotificationEnabled success, data: " + JSON.stringify(data));
            if(!data){
              notificationManager.requestEnableNotification(context).then(() => {
                hilog.info(DOMAIN_NUMBER, TAG, `[ANS] requestEnableNotification success`);
              }).catch(() => {
                // if(1600004 == err.code){
                //   hilog.error(DOMAIN_NUMBER, TAG, `[ANS] requestEnableNotification refused, code is ${err.code}, message is ${err.message}`);
                // } else {
                //   hilog.error(DOMAIN_NUMBER, TAG, `[ANS] requestEnableNotification failed, code is ${err.code}, message is ${err.message}`);
                // }
              });
            }
          }).catch(() => {
            // hilog.error(DOMAIN_NUMBER, TAG, `isNotificationEnabled fail, code is ${err.code}, message is ${err.message}`);
          });

          sensor.on(sensor.SensorId.BAROMETER, (data: sensor.BarometerResponse) => {
            //过去气压获取
            let prevAtmospheric_pressure : number = AppStorage.get('Atmospheric_pressure') ?? data.pressure
            //过去差值获取
            let Atmospheric_pressure_change_prev:number = AppStorage.get('Atmospheric_pressure_change')??0
            // 计算累积差值
            let Atmospheric_pressure_change:number = prevAtmospheric_pressure - data.pressure + Atmospheric_pressure_change_prev
            if (Atmospheric_pressure_change>=50||Atmospheric_pressure_change<=-50){
              console.info('jizhishi_debug Succeeded in invoking on. Atmospheric_pressure_change: ' + Atmospheric_pressure_change);
              Atmospheric_pressure_change = 0

              let notificationRequest: notificationManager.NotificationRequest = {
                id: 114514,
                notificationSlotType:notificationManager.SlotType.SERVICE_INFORMATION,
                content: {
                  notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
                  normal: {
                    title: '气压变化超50百帕',
                    text: '当前气压:'+data.pressure.toFixed(3)+'百帕',
                    // additionalText: 'test_additionalText',
                  }
                }
              };
              notificationManager.publish(notificationRequest, () => {
                // if (err) {
                //   hilog.error(DOMAIN_NUMBER, TAG, `Failed to publish notification. Code is ${err.code}, message is ${err.message}`);
                //   return;
                // }
                // hilog.info(DOMAIN_NUMBER, TAG, 'Succeeded in publishing notification.');
              });
            }

            AppStorage.setOrCreate('Atmospheric_pressure_change',Atmospheric_pressure_change)
            AppStorage.setOrCreate('Atmospheric_pressure',data.pressure)
            console.info('jizhishi_debug Succeeded in invoking on. Atmospheric pressure: ' + data.pressure);
          }, { interval: 100000000 });
          // setTimeout(() => {
          //   sensor.off(sensor.SensorId.BAROMETER);
          // }, 500);
        } catch (error) {
          // let e: BusinessError = error as BusinessError;
          // console.error(`jizhishi_debug Failed to invoke on. Code: ${e.code}, message: ${e.message}`);
        }
      }
      PreferencesCache.setUserPreference(this.setUserPreference_name, this.text_ctrl)
    }else {
      this.text_ctrl ='0'
      if (this.setUserPreference_name ==='pressure_change'){
        sensor.off(sensor.SensorId.BAROMETER);
      }
        PreferencesCache.setUserPreference(this.setUserPreference_name, this.text_ctrl)
    }

    AppStorage.setOrCreate(this.setUserPreference_name, this.text_ctrl)

    if (PreferencesCache.getUserPreference('Lyic_desktop','0')==='1') {
      PipManager.getInstance().init(this.getUIContext().getHostContext() as Context); // 创建画中画控制器
      PipManager.getInstance().setAutoStart(true); // 设置应用退后台时自动启动画中画
    }else {
      PipManager.getInstance().setAutoStart(false)
    }
  }
}


@Component
export struct Personalized_settings{
  @Consume('NavPathStack') pageStack: NavPathStack;
  @State HorizontalMode_ctrl:string =  PreferencesCache.getUserPreference('HorizontalMode_ctrl','1')
  @StorageProp('bottomRect') bottomRect: number = 0

  build() {
    NavDestination(){
      Column(){
        List({ space: 8, initialIndex: 0 }){
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.mini_music_control_bottom')), setUserPreference_name:'miniplaying_bottom_judge'})}
          ListItem(){
            Personalized_settings_Component({
              text_name: ResourceManager.getStringValueSync($r('app.string.swipe_cover_switch_songs')),
              setUserPreference_name:'img_playing_ctrl',
              showPopup: true,
              popupMessage: '开启后可在播放界面左/右滑动封面切歌'
            })
          }
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.simultaneous_playback')), setUserPreference_name:'playing_mix'})}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.enable_sidebar_ui')), setUserPreference_name:'zhishi_UI'})}
          ListItem(){
            Personalized_settings_Component({
              text_name: ResourceManager.getStringValueSync($r('app.string.flip_mute')),
              setUserPreference_name:'flip_mute',
              showPopup: true,
              popupMessage: '开启后在播放界面反扣屏幕，可暂停播放，屏幕向上自动恢复播放'
            })
          }
          // ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.Lyic_desktop')), setUserPreference_name:'Lyic_desktop'})}
          ListItem(){
            Personalized_settings_Component({
              text_name: ResourceManager.getStringValueSync($r('app.string.setting_fade_in_fade_out')),
              setUserPreference_name:'fade_in_out',
              showPopup: true,
              popupMessage: '切歌/暂停/播放时音量会渐强/渐弱'
            })
          }
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.slide_up_hide_title')), setUserPreference_name:'slide_up_hide_title'})}
          ListItem(){
            Personalized_settings_Component({
              text_name: ResourceManager.getStringValueSync($r('app.string.playing_title_show_lyrics')),
              setUserPreference_name:'playing_title_show_lyrics',
              showPopup: true,
              popupMessage: '开启后播控界面顶部返回按钮被歌词展示替代，可点击顶部区域在展示原词/翻译/罗马音/关闭之间轮换'
            })
          }
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.enable_wave_lyrics')), setUserPreference_name:'enable_wave_lyrics'})}
          if (deviceInfo.sdkApiVersion>19){
            ListItem(){ Personalized_settings_Component({text_name: '开启流光背景', setUserPreference_name:'UV_background'})}
          }
          ListItem(){
            Personalized_settings_Component({
              text_name: '气压剧烈变化提醒',
              setUserPreference_name:'pressure_change',
              showPopup: true,
              popupMessage: '需设备支持,开启后返回首页后才会开启，测试功能，建议进入设置打开横幅功能'
            })
          }
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.pip_lyrics_type')), setUserPreference_name:'pip_lyrics_type', componentType: 1})}
          ListItem(){
            Personalized_settings_Component({
              text_name: ResourceManager.getStringValueSync($r('app.string.sub_window_show_type')),
              setUserPreference_name:'sub_window_show_type',
              componentType: 1,
              showPopup: true,
              popupMessage: '按住上滑/下滑→松手：上一首/下一首\n' +
                '按住左滑/右滑：音量+10/-10\n' +
                '单击：返回上一页\n' +
                '双击：暂停/播放\n' +
                '三击：切换播放模式\n' +
                '长按1s：红心/取消红心'
            })
          }

          ListItem(){ Column().height(16+this.bottomRect/2)}
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .padding({ top: 12, left: 12, right: 12 })
    }
    .title($r('app.string.custom_settings'))
    .hideToolBar(true)
    .backgroundColor($r('app.color.page_background'))
    .expandSafeArea()

  }
}
