import { display, window } from "@kit.ArkUI"
import { LogUtil } from "@pura/harmony-utils";
import { PreferencesCache, SBLyricsPre } from "../util/PreferenceCache";
import WindowUtils from "../util/WindowUtils";

const TAG = 'FloatingLyrics'
const BOTTOM_MARGIN = vp2px(60)
const THRESHOLD = vp2px(20)

@Entry
@Component
export struct FloatingLyrics {
  currentLyric: string = '歌词'
  @StorageProp('SBLyricsSetting') @Watch('onLyricStyleChange') settingData: string = ''
  @State floatLyricStyle: SBLyricsPre = PreferencesCache.statusBarLyricsSetting()
  aboutToAppear(): void {

  }

  onLyricStyleChange() {
    this.floatLyricStyle = JSON.parse(this.settingData)
    LogUtil.info('FloatLyric '+ this.floatLyricStyle.width)
    window.findWindow('SBLyrics')?.moveWindowTo(this.floatLyricStyle.x,this.floatLyricStyle.y)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Text(this.currentLyric)
        .textStyle(this.floatLyricStyle.fontSize)
        .textAlign(this.floatLyricStyle.alignment === 0 ? TextAlign.Center : TextAlign.Start)
    }
    .width(`${this.floatLyricStyle.width}%`)
    .backgroundColor(Color.Blue)
    .opacity(this.floatLyricStyle.transparency)
    // .visibility(this.isPlayerShow ? Visibility.None : Visibility.Visible)
    .animation({ duration: 500, curve: Curve.Smooth })
    .borderRadius(8)
  }
}

@Extend(Text)
function textStyle(size: number) {
  .fontSize(size)
  .fontColor(Color.Red)
  .fontWeight(FontWeight.Bold)
  .width('100%')
  .maxLines(1)
  .textOverflow({ overflow: TextOverflow.MARQUEE })
  .padding(5)
}