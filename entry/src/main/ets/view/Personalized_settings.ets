import { PreferencesCache } from "../util/PreferenceCache";
import {HorizontalMode}from '../util/HorizontalCheck'
import { ResourceManager } from "../util/ResourceManager";
import { PipManager } from '../util/PipManager';

@Component
  //'0'关。'1'开。!!!!(开关颜色日后调)
export struct Personalized_settings_Component {
  @State text_name: string = '';
  @State setUserPreference_name: string = '';
  private  text_ctrl:string =  PreferencesCache.getUserPreference(this.setUserPreference_name)
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
          .switchPointColor($r('app.color.text_primary'))
          .selectedColor($r('app.color.Personalized_settings_button_background'))
          .onChange((isOn: boolean) => {
            if (isOn) {
              this.text_ctrl ='1'
              PreferencesCache.setUserPreference(this.setUserPreference_name, this.text_ctrl)
            }else {
              this.text_ctrl ='0'
              PreferencesCache.setUserPreference(this.setUserPreference_name, this.text_ctrl)
            }
            if (PreferencesCache.getUserPreference('Lyic_desktop','0')==='1') {
              PipManager.getInstance().init(getContext(this)); // 创建画中画控制器
              PipManager.getInstance().setAutoStart(true); // 设置应用退后台时自动启动画中画
            }else {
              PipManager.getInstance().setAutoStart(false)
            }


          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

    }
    .padding(16)
    .backgroundColor($r('app.color.card_background_two'))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }
}


@Component
export struct Personalized_settings{
  @Consume('NavPathStack') pageStack: NavPathStack;
  @State HorizontalMode_ctrl:string =  PreferencesCache.getUserPreference('HorizontalMode_ctrl','0')
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
          .switchPointColor($r('app.color.text_primary'))
          .selectedColor($r('app.color.Personalized_settings_button_background'))
          .onChange((isOn: boolean) => {
            if (isOn) {
              this.HorizontalMode_ctrl ='1'
              HorizontalMode(this.HorizontalMode_ctrl==='1')
              PreferencesCache.setUserPreference('HorizontalMode_ctrl', this.HorizontalMode_ctrl)
            }else {
              this.HorizontalMode_ctrl ='0'
              HorizontalMode(this.HorizontalMode_ctrl==='1')
              PreferencesCache.setUserPreference('HorizontalMode_ctrl', this.HorizontalMode_ctrl)
            }

          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

    }
    .padding(16)
    .backgroundColor($r('app.color.card_background_two'))
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
          ListItem(){ Personalized_settings_Component({text_name: '允许同时播放', setUserPreference_name:'playing_mix'})}
          ListItem(){ Personalized_settings_Component({text_name: '只是UI_阿尔法1', setUserPreference_name:'zhishi_UI'})}
          // ListItem(){ Personalized_settings_Component({text_name: ResourceManager.getStringValueSync($r('app.string.Lyic_desktop')), setUserPreference_name:'Lyic_desktop'})}
          ListItem(){ Column().height(16+px2vp(this.bottomRect/2))}
        }
        .width('100%')
        .height('100%')
      }
      .padding({ top: 16, left: 16, right: 16 })
    }
    .title($r('app.string.custom_settings')).hideToolBar(true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])

  }
}