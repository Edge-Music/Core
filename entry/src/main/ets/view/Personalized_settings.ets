import { PreferencesCache } from "../util/PreferenceCache";
import {HorizontalMode}from '../util/HorizontalCheck'
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
          .switchPointColor('#46B1E3')
          .selectedColor('#A6C2BE')
          .onChange((isOn: boolean) => {
            if (isOn) {
              this.text_ctrl ='1'
              PreferencesCache.setUserPreference(this.setUserPreference_name, this.text_ctrl)
            }else {
              this.text_ctrl ='0'
              PreferencesCache.setUserPreference(this.setUserPreference_name, this.text_ctrl)
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
  @Builder
  HorizontalMode_Ctrl(){
    Column(){
      Row(){
        Text('受控制中心的旋转开关控制')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.HorizontalMode_ctrl==='1'?true:false})
          .switchPointColor('#46B1E3')
          .selectedColor('#A6C2BE')
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
          ListItem(){ Personalized_settings_Component({text_name:'mini播放器置于最底部',setUserPreference_name:'miniplaying_bottom_judge'})}
          ListItem(){ Personalized_settings_Component({text_name:'播放页滑动封面切换下一首/上一首',setUserPreference_name:'img_playing_ctrl'})}
        }
      }.padding(16)
    }.title('个性化设置').hideToolBar(true)

  }
}