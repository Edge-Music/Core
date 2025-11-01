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
  @Prop offsetY: number = 0 // 波浪动画偏移量

  // 性能优化：缓存计算结果
  private isCurrent: boolean = false
  private cachedStyle: LyricStyle | null = null

  // 获取当前样式（性能优化版本）
  private getStyle(): LyricStyle {
    this.updateCachedStyle()
    return this.cachedStyle!
  }

  build(){
    Column() {
      // 现代化原文歌词 - 使用文字阴影替代背景，一次性应用所有样式
      Text(this.item.text)
        .fontSize(22)
        .fontWeight(this.getStyle().fontWeight)
        .fontColor(this.getStyle().fontColor)
        .textShadow(this.getStyle().textShadow)
        .opacity(this.getStyle().opacity)
        .margin({ top: 6, bottom: this.showTranslation && this.item.translation ? 2 : 6 })
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .textAlign(TextAlign.Center)
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 1.05, y: 1.05 }))
          .animation({
            duration: AnimationConstants.DURATION_FAST,
            curve: AnimationConstants.CURVE_DECELERATE
          }))

      // 现代化翻译歌词 - 增强字重
      if (this.showTranslation && this.item.translation) {
        Text(this.item.translation)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getStyle().fontColor)
          .opacity(this.getStyle().opacity * 0.85)
          .margin({ bottom: 2 })
          .padding({ left: 16, right: 16, top: 2 })
          .textAlign(TextAlign.Center)
      }

      // 现代化音译歌词 - 增强字重
      if (this.showTranslation && this.item.transliteration) {
        Text(this.item.transliteration)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getStyle().fontColor)
          .opacity(this.getStyle().opacity * 0.85)
          .margin({ bottom: 4 })
          .padding({ left: 16, right: 16, top: 2 })
          .textAlign(TextAlign.Center)
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .translate({ y: this.offsetY })
    .animation({
      duration: AnimationConstants.DURATION_NORMAL,
      curve: AnimationConstants.CURVE_SPRING
    })
  }

  // 性能优化：更新缓存的样式对象
  private updateCachedStyle() {
    const newIsCurrent = this.index === this.currentLyricsIndex

    // 只有当高亮状态改变时才重新计算样式
    if (this.isCurrent !== newIsCurrent || this.cachedStyle === null) {
      this.isCurrent = newIsCurrent
      this.cachedStyle = this.createLyricStyle(this.isCurrent)
    }
  }

  // 创建歌词样式对象 - 一次性计算所有样式属性
  private createLyricStyle(isCurrent: boolean): LyricStyle {
    return new LyricStyle(
      isCurrent ? FontWeight.Bolder : FontWeight.Medium,
      isCurrent ? Color.White : 'rgba(255, 255, 255, 0.85)', // 提高非高亮歌词亮度
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
      isCurrent ? 1 : 0.9, // 提高非高亮歌词透明度
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