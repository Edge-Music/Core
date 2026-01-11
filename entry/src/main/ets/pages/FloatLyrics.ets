import { display, window } from "@kit.ArkUI"
import { LogUtil } from "@pura/harmony-utils";
import { PreferencesCache, SBLyricsPre } from "../util/PreferenceCache";
import { resourceManager } from "@kit.LocalizationKit";
import WindowUtil from "../util/WindowUtil";
import { LyricsLine } from "../util/LyricsManager";
import { StyleConstants } from "../constants/StyleConstants";

const TAG = 'FloatingLyrics'

@Entry
@Component
export struct FloatingLyrics {

  private scroller: Scroller = new Scroller()
  @StorageProp('deviceType') deviceType: resourceManager.DeviceType = resourceManager.DeviceType.DEVICE_TYPE_PHONE
  @StorageLink('test_index') currentLyric: string = '歌词'
  @StorageLink('current_line_lyrics') currentLineLyric: LyricsLine = new LyricsLine(0, '')
  @StorageLink('current_lyrics_index') @Watch("onTimeUpdate") private currentLyricsIndex: number = 0
  @StorageProp('current_parsed_lyrics') private parsedLyrics: Array<LyricsLine> = []
  @StorageProp('SBLyricsSetting') @Watch('onLyricStyleChange') settingData: string = PreferencesCache.getUserPreference('status_bar_lyrics_setting')
  @StorageProp('currentOrientation') @Watch('onLyricStyleChange') currentOrientation: string = 'portrait'
  @StorageProp('displayW') displayW: number = 0
  @StorageProp('displayH') displayH: number = 0
  @State floatLyricStyle: SBLyricsPre = PreferencesCache.statusBarLyricsSetting()
  private floatWindow: window.Window | undefined
  private uiContext = this.getUIContext()
  private oldOffsetY: number = this.floatLyricStyle.y
  @State timerID: number = -1
  @State lastShadowStatus: boolean = false

  aboutToAppear(): void {
    this.lastShadowStatus = this.floatLyricStyle.showShadow

    if(this.timerID === -1) {
      this.timerID = setInterval(() => {
        this.onLyricStyleChange()
      }, 500)
    }
  }

  aboutToDisappear(): void {
    clearInterval(this.timerID)
    this.timerID = -1
  }

  onLyricStyleChange() {
    this.floatLyricStyle = JSON.parse(this.settingData)
    if((this.deviceType === resourceManager.DeviceType.DEVICE_TYPE_PC ||
      this.deviceType === resourceManager.DeviceType.DEVICE_TYPE_TABLET ||
      this.deviceType === resourceManager.DeviceType.DEVICE_TYPE_2IN1) && this.floatLyricStyle.showShadow != this.lastShadowStatus) {

      this.lastShadowStatus = this.floatLyricStyle.showShadow
      WindowUtil.resetFloatLyricsWindow()
      return
    }
    const showWidth = this.floatLyricStyle.width*this.displayW-this.uiContext.vp2px(8)
    const showHeight = this.uiContext.vp2px(this.floatLyricStyle.lines === 0 ? this.floatLyricStyle.fontSize+8 : this.floatLyricStyle.fontSize*2+16)

    const offsetX_1 = this.floatLyricStyle.x*this.displayW + this.uiContext.vp2px(4)
    const offsetX_2 = this.floatLyricStyle.x*this.displayW - showWidth - this.uiContext.vp2px(4)
    const offsetX = Math.min(offsetX_1, Math.max(this.uiContext.vp2px(4), offsetX_2))
    const offsetY_1 = this.floatLyricStyle.y*this.displayH
    const offsetY_2 = this.floatLyricStyle.y*this.displayH - showHeight
    const offsetY = Math.min(offsetY_1, Math.max(0, offsetY_2))
    if(!this.floatWindow) {
      try {
        this.floatWindow = window.findWindow('SBLyrics')
      } catch (error) {
        LogUtil.error(`[${TAG}]`, `No lyrics floating window found: ${JSON.stringify(error)}`)
      }
    }
    this.floatWindow?.resize(showWidth, showHeight)
    if(this.oldOffsetY != this.floatLyricStyle.y) {
      this.floatWindow?.moveWindowTo(offsetX, offsetY)
      this.oldOffsetY = this.floatLyricStyle.y
    }
    this.floatWindow?.setWindowCornerRadius(this.floatLyricStyle.cornerRadius)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      List({
        initialIndex: this.currentLyricsIndex,
        scroller: this.scroller,
        space: 4
      }) {
        ForEach(this.parsedLyrics, (item: LyricsLine) => {
          ListItem(){
            Text(this.getShowLyricByItem(item))
              .textStyle(this.floatLyricStyle)
              .textAlign(this.floatLyricStyle.alignment === 0 ? TextAlign.Center : TextAlign.Start)
              .width('100%')
          }
          .width(StyleConstants.FULL_WIDTH)
        })
      }
      .width(StyleConstants.FULL_WIDTH)
      .enableScrollInteraction(false)
      .scrollBar(BarState.Off)
    }
    .padding(4)
    .backdropBlur(this.floatLyricStyle.transparency*100)
    .backgroundColor(`rgba(255, 255, 255, ${this.floatLyricStyle.transparency})`)
    .height(this.floatLyricStyle.lines === 0 ? this.floatLyricStyle.fontSize+8 : this.floatLyricStyle.fontSize*2+16)
    .animation({ duration: 500, curve: Curve.Smooth })
  }

  getShowLyric(): string {
    let result: string = ''
    switch (this.floatLyricStyle.lyricsType) {
      case 0:
        result = this.currentLineLyric.text
        break;
      case 1:
        result = this.currentLineLyric.translation ?? this.currentLineLyric.text
        break;
      case 2:
        result = this.currentLineLyric.transliteration ?? this.currentLineLyric.translation ?? this.currentLineLyric.text
        break;
      default:
        result = this.currentLineLyric.text
        break;
    }
    return result
  }

  getShowLyricByItem(item: LyricsLine): string {
    let result: string = ''
    switch (this.floatLyricStyle.lyricsType) {
      case 0:
        result = item.text
        break;
      case 1:
        result = item.translation ?? item.text
        break;
      case 2:
        result = item.transliteration ?? item.translation ?? item.text
        break;
      default:
        result = item.text
        break;
    }
    return result
  }

  onTimeUpdate() {
    if(this.currentLyricsIndex !== -1) {
      this.scroller.scrollToIndex(this.currentLyricsIndex, true)
    }
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