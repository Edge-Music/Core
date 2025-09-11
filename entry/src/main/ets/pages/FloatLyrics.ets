import { display, window } from "@kit.ArkUI"
import { PreferencesCache, SBLyricsPre } from "../util/PreferenceCache";

const TAG = 'FloatingLyrics'

@Entry
@Component
export struct FloatingLyrics {

  @StorageLink('test_index') currentLyric: string = '歌词'
  @StorageProp('SBLyricsSetting') @Watch('onLyricStyleChange') settingData: string = PreferencesCache.getUserPreference('status_bar_lyrics_setting')
  @StorageProp('currentOrientation') @Watch('onLyricStyleChange') currentOrientation: string = 'portrait'
  @State floatLyricStyle: SBLyricsPre = PreferencesCache.statusBarLyricsSetting()
  private uiContext = this.getUIContext()
  private timerID: number = -1
  aboutToAppear(): void {
    if(this.timerID === -1) {
      this.timerID = setInterval(() => {
        this.onLyricStyleChange()
      }, 500)
    }
  }

  aboutToDisappear(): void {
    this.timerID = -1
  }

  onLyricStyleChange() {
    let displayW = display.getDefaultDisplaySync().width;
    let displayH = display.getDefaultDisplaySync().height;
    const showWidth = this.floatLyricStyle.width*displayW-this.uiContext.vp2px(8)
    const showHeight = this.uiContext.vp2px(this.floatLyricStyle.fontSize+8)
    this.floatLyricStyle = JSON.parse(this.settingData)
    window.findWindow('SBLyrics')?.resize(showWidth, showHeight)

    const offsetX_1 = this.floatLyricStyle.x*displayW + this.uiContext.vp2px(4)
    const offsetX_2 = this.floatLyricStyle.x*displayW - showWidth - this.uiContext.vp2px(4)
    const offsetX = Math.min(offsetX_1, Math.max(this.uiContext.vp2px(4), offsetX_2))
    const offsetY_1 = this.floatLyricStyle.y*displayH
    const offsetY_2 = this.floatLyricStyle.y*displayH - showHeight
    const offsetY = Math.min(offsetY_1, Math.max(0, offsetY_2))
    window.findWindow('SBLyrics')?.moveWindowTo(offsetX, offsetY)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backdropBlur(this.floatLyricStyle.transparency*1000)
        .backgroundColor(`rgba(255, 255, 255, ${this.floatLyricStyle.transparency})`)
        .borderRadius(8)

      Text(this.currentLyric)
        .textStyle(this.floatLyricStyle)
        .textAlign(this.floatLyricStyle.alignment === 0 ? TextAlign.Center : TextAlign.Start)
    }
    .borderRadius(8)
    .height(this.floatLyricStyle.fontSize + 8)
    .animation({ duration: 500, curve: Curve.Smooth })
  }
}

@Extend(Text)
function textStyle(style: SBLyricsPre) {
  .fontSize(style.fontSize)
  .fontColor(style.fontColor)
  .fontWeight(FontWeight.Bold)
  .width('100%')
  .maxLines(1)
  .textOverflow({ overflow: TextOverflow.MARQUEE })
}