import { StyleConstants } from '../constants/StyleConstants';
import { avPlayerManager } from '../util/AVPlayerManager';
import { EventHelper } from '../util/EventHelper';
import { LyricsLine } from '../util/LyricsManager';

const waveFactor: number = 0.2; // 跟随强度系数

@Reusable
@Component
export struct LyricItem {
  @Prop item: LyricsLine
  @Prop index: number
  @Prop showTranslation: boolean
  @Prop currentLyricsIndex: number

  build(){
    Column() {
      // 原文歌词
      Text(this.item.text)
        .fontSize(20)
        .fontWeight(this.getLyricStyle(this.index).fontWeight)
        .fontColor(this.getLyricStyle(this.index).fontColor)
        .margin({ top: 4, bottom: this.showTranslation && this.item.translation ? 0 : 4 })
        .padding({
          left: 16,
          right: 16,
          top: 8,
          bottom: 8
        })
        .textAlign(TextAlign.Center)
        .borderRadius(8)
        .backgroundColor(this.getLyricStyle(this.index).background)
        .opacity(this.getLyricStyle(this.index).opacity)

      // 翻译歌词 (仅当启用显示翻译且该行有翻译时显示)
      if (this.showTranslation && this.item.translation) {
        Text(this.item.translation)
          .fontSize(16)
          .fontWeight(FontWeight.Normal)
          .fontColor(this.getLyricStyle(this.index).fontColor)
          .opacity(this.getLyricStyle(this.index).opacity * 0.9)
          .margin({ bottom: 4 })
          .padding({
            left: 16,
            right: 16,
            top: 4,
            bottom: 4
          })
          .textAlign(TextAlign.Center)
          .borderRadius(8)
          .backgroundColor('transparent')
      }

      // 音译歌词 (仅当启用显示翻译且该行有翻译时显示)
      if (this.showTranslation && this.item.transliteration) {
        Text(this.item.transliteration)
          .fontSize(16)
          .fontWeight(FontWeight.Normal)
          .fontColor(this.getLyricStyle(this.index).fontColor)
          .opacity(this.getLyricStyle(this.index).opacity * 0.9)
          .margin({ bottom: 4 })
          .padding({
            left: 16,
            right: 16,
            top: 4,
            bottom: 4
          })
          .textAlign(TextAlign.Center)
          .borderRadius(8)
          .backgroundColor('transparent')

      }
    }
    .width(StyleConstants.FULL_WIDTH)
  }

  // 获取歌词显示样式
  private getLyricStyle(index: number) {
    const isCurrent = index === this.currentLyricsIndex

    return new LyricStyle(
      isCurrent ? StyleConstants.FONT_WEIGHT_SEVEN : StyleConstants.FONT_WEIGHT_FIVE,
      isCurrent ? Color.White : 'rgba(255, 255, 255, 0.6)',
      isCurrent ? 'rgba(255, 255, 255, 0.1)' : 'transparent',
      isCurrent ? 1 : 0.7,
    )
  }
}

class LyricStyle {
  fontWeight: FontWeight;
  fontColor: string | Color;
  background: string;
  opacity: number;

  constructor(fontWeight: FontWeight, fontColor: string | Color, background: string, opacity: number) {
    this.fontWeight = fontWeight;
    this.fontColor = fontColor;
    this.background = background;
    this.opacity = opacity;
  }
}