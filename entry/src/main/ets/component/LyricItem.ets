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

  // 性能优化：缓存计算结果
  private isCurrent: boolean = false
  private cachedStyle: LyricStyle | null = null

  private getStyle(): LyricStyle {
    this.updateCachedStyle()
    return this.cachedStyle!
  }

  // 计算当前项高度（包括间距）
  static getItemHeight(showTranslation: boolean, item: LyricsLine): number {
    const hasTranslationContent = showTranslation &&
      ((item.translation && item.translation.trim().length > 0) ||
        (item.transliteration && item.transliteration.length > 0))
    const baseHeight = hasTranslationContent ?
      StyleConstants.LYRIC_HEIGHT_WITH_TRANSLATION :
      StyleConstants.LYRIC_HEIGHT_NO_TRANSLATION
    return baseHeight + StyleConstants.LYRIC_LINE_SPACING
  }

  build() {
    Column({ space: 4 }) {
      // 原文歌词
      Text(this.item.text)
        .fontSize(AnimationConstants.LYRIC_NORMAL_FONT_SIZE)
        .fontWeight(this.getStyle().fontWeight)
        .fontColor(this.getStyle().fontColor)
        .textShadow(this.getStyle().textShadow)
        .opacity(this.getStyle().opacity)
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
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getStyle().fontColor)
          .opacity(this.getStyle().opacity * 0.85)
          .textAlign(TextAlign.Center)
          .transition(TransitionEffect.OPACITY
            .animation({
              duration: AnimationConstants.DURATION_NORMAL,
              curve: AnimationConstants.CURVE_DECELERATE
            }))
      }

      // 音译歌词 - 只在有音译时显示
      if (this.showTranslation && this.item.transliteration && this.item.transliteration.length > 0) {
        Text(this.item.transliteration)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getStyle().fontColor)
          .opacity(this.getStyle().opacity * 0.85)
          .textAlign(TextAlign.Center)
          .transition(TransitionEffect.OPACITY
            .animation({
              duration: AnimationConstants.DURATION_NORMAL,
              curve: AnimationConstants.CURVE_DECELERATE
            }))
      }
    }
    .padding({ left: 16, right: 16 })
    .width('95%')
    .scale({ 
      x: this.index === this.currentLyricsIndex ? 1.1 : 1.0, 
      y: this.index === this.currentLyricsIndex ? 1.1 : 1.0 
    })
    .animation({
      duration: AnimationConstants.LYRIC_FONT_SIZE_DURATION,
      curve: Curve.EaseOut
    })
    .renderGroup(true) // 启用渲染组优化，减少复杂动画性能消耗
  }

  private updateCachedStyle() {
    const newIsCurrent = this.index === this.currentLyricsIndex

    if (this.isCurrent !== newIsCurrent || this.cachedStyle === null) {
      this.isCurrent = newIsCurrent
      this.cachedStyle = this.createLyricStyle(this.isCurrent)
    }
  }

  private createLyricStyle(isCurrent: boolean): LyricStyle {
    return new LyricStyle(
      FontWeight.Medium,
      isCurrent ? Color.White : 'rgba(255, 255, 255, 0.85)',
      isCurrent ? {
        radius: 12,
        color: 'rgba(255, 255, 255, 0.6)',
        offsetX: 0,
        offsetY: 0
      } : {
        radius: 0,
        color: Color.Transparent,
        offsetX: 0,
        offsetY: 0
      },
      isCurrent ? 1 : 0.9,
    )
  }
}

class LyricStyle {
  fontWeight: FontWeight;
  fontColor: ResourceColor;
  textShadow: ShadowOptions;
  opacity: number;

  constructor(fontWeight: FontWeight, fontColor: ResourceColor, textShadow: ShadowOptions, opacity: number) {
    this.fontWeight = fontWeight;
    this.fontColor = fontColor;
    this.textShadow = textShadow;
    this.opacity = opacity;
  }
}
