import { PreferencesCache } from "../util/PreferenceCache";
import {HorizontalMode}from '../util/HorizontalCheck'
import ResourceManager from "../util/ResourceManager";
import { PipManager } from '../util/PipManager';
import { deviceInfo } from "@kit.BasicServicesKit";
import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem } from "@kit.ArkUI";

@Component
  //'0'关。'1'开。!!!!(开关颜色日后调)
export struct Personalized_settings_Component {
  @State text_name: string = '';
  @State setUserPreference_name: string = '';
  // 右侧组件类型：0-Toggle 1-Segment
  @State componentType: number = 0
  @State lyricTypeIndex: number[] = []
  private text_ctrl: string = PreferencesCache.getUserPreference(this.setUserPreference_name)

  @State lyricsTypeOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '原词' }, { text: '翻译' }, { text: '罗马音' }] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.BACKGROUND_REGULAR,
    selectedBackgroundColor: $r('app.color.title_emphasis_color'),
    fontSize: 12
  })

  aboutToAppear(): void {
    this.lyricTypeIndex = [parseInt(PreferencesCache.getUserPreference(this.setUserPreference_name, '0'))]
  }

  build() {
    Column(){
      Row(){
        Text(this.text_name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
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
          .visibility(this.componentType === 1 ? Visibility.Visible : Visibility.None)
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
      PreferencesCache.setUserPreference(this.setUserPreference_name, this.text_ctrl)
    }else {
      this.text_ctrl ='0'
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
  @Builder
  HorizontalMode_Ctrl(){
    Column(){
      Row(){
        Text($r('app.string.system_rotary_switch'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.HorizontalMode_ctrl==='1'?true:false})
          .selectedColor($r('app.color.title_emphasis_color'))
          .onChange((isOn: boolean) => {
            if (isOn) {
              this.HorizontalMode_ctrl ='1'
              HorizontalMode(this.getUIContext().getHostContext() as Context, this.HorizontalMode_ctrl==='1')
              PreferencesCache.setUserPreference('HorizontalMode_ctrl', this.HorizontalMode_ctrl)
            }else {
              this.HorizontalMode_ctrl ='0'
              HorizontalMode(this.getUIContext().getHostContext() as Context, this.HorizontalMode_ctrl==='1')
              PreferencesCache.setUserPreference('HorizontalMode_ctrl', this.HorizontalMode_ctrl)
            }

          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

    }
    .padding(16)
    .backgroundColor($r('app.color.setting_item_background'))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination(){
      Column(){
        List({ space: 8, initialIndex: 0 }){
          ListItem(){this.HorizontalMode_Ctrl()}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.mini_music_control_bottom')), setUserPreference_name:'miniplaying_bottom_judge'})}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.swipe_cover_switch_songs')), setUserPreference_name:'img_playing_ctrl'})}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.simultaneous_playback')), setUserPreference_name:'playing_mix'})}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.enable_sidebar_ui')), setUserPreference_name:'zhishi_UI'})}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.double_tap_switch_songs')), setUserPreference_name:'double_tap_switch_songs'})}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.flip_mute')), setUserPreference_name:'flip_mute'})}
          // ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.Lyic_desktop')), setUserPreference_name:'Lyic_desktop'})}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.setting_fade_in_fade_out')), setUserPreference_name:'fade_in_out'})}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.slide_up_hide_title')), setUserPreference_name:'slide_up_hide_title'})}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.playing_title_show_lyrics')), setUserPreference_name:'playing_title_show_lyrics'})}
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.enable_wave_lyrics')), setUserPreference_name:'enable_wave_lyrics'})}
          if (deviceInfo.sdkApiVersion>19){
            ListItem(){ Personalized_settings_Component({text_name: '开启流光背景', setUserPreference_name:'UV_background'})}
          }
          ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.pip_lyrics_type')), setUserPreference_name:'pip_lyrics_type', componentType: 1})}

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
