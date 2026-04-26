import { StyleConstants } from '../constants/StyleConstants';
import { AnimationConstants } from '../constants/AnimationConstants';
import { LyricsLine } from '../util/LyricsManager';

@Reusable
@Component
export struct LyricItem {
  @Prop item: LyricsLine
  @Prop index: number
  @Prop showTranslation: boolean
  @Prop currentLyricsIndex: number
  /** 歌词字体大小 */
  @Prop lyricFontSize: number = 18
  /** 高亮放大比例 */
  @Prop highlightScale: number = 1.1
  /** 翻译字体大小 */
  @Prop translationFontSize: number = 16
  /** 罗马音字体大小 */
  @Prop transliterationFontSize: number = 12

  build() {
    Column({ space: 4 }) {
      // 原文歌词
      Text(this.item.text)
        .fontSize(this.index === this.currentLyricsIndex ? this.lyricFontSize * this.highlightScale : this.lyricFontSize)
        .fontWeight(this.index === this.currentLyricsIndex ? FontWeight.Bolder : FontWeight.Medium)
        .fontColor(this.index === this.currentLyricsIndex ? Color.White : 'rgba(255, 255, 255, 0.85)')
        .textShadow(this.index === this.currentLyricsIndex ? {
          radius: 12,
          color: 'rgba(255, 255, 255, 0.6)',
          offsetX: 0,
          offsetY: 0
        } : undefined)
        .opacity(this.index === this.currentLyricsIndex ? 1 : 0.9)
        .textAlign(TextAlign.Center)
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 1.05, y: 1.05 }))
          .animation({
            duration: AnimationConstants.DURATION_FAST,
            curve: AnimationConstants.CURVE_DECELERATE
          }))

      // 翻译歌词 - 只在有翻译时显示
      if (this.showTranslation && this.item.translation && this.item.translation.trim().length > 0) {
        Text(this.item.translation)
          .fontSize(this.translationFontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.index === this.currentLyricsIndex ? Color.White : 'rgba(255, 255, 255, 0.85)')
          .opacity(this.index === this.currentLyricsIndex ? 0.85 : 0.75)
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16, top: 2 })
      }

      // 罗马音歌词 - 只在有罗马音时显示
      if (this.showTranslation && this.item.transliteration && this.item.transliteration.length > 0) {
        Text(this.item.transliteration)
          .fontSize(this.transliterationFontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.index === this.currentLyricsIndex ? Color.White : 'rgba(255, 255, 255, 0.85)')
          .opacity(this.index === this.currentLyricsIndex ? 0.85 : 0.75)
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16, top: 2 })
      }
    }
    .width('100%')
    .padding({ left: 32, right: 32, top: 8, bottom: 8 })
    .scale({
      x: this.index === this.currentLyricsIndex ? this.highlightScale : 1.0,
      y: this.index === this.currentLyricsIndex ? this.highlightScale : 1.0
    })
    .animation({
      duration: AnimationConstants.LYRIC_FONT_SIZE_DURATION,
      curve: Curve.EaseOut
    })
    .renderGroup(true)
  }
}
