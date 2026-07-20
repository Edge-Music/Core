/**
 * 沉浸氛围背景（对齐设计规范 §1.1 / §4.1 / §2.3 双主题）
 * 深色=暮光发光；浅色=低饱和暖白 wash。主题跟随封面明度（v3_theme_mode）。
 */
import { cover } from '../../util/AdapterHelper'
import { V3Theme } from '../theme/Tokens'

@Component
export struct AmbientBackground {
  @Prop coverUrl: string = ''
  // 深色模糊/亮度/饱和度（浅色内部另用一套）
  @Prop blurRadius: number = 56
  @Prop brightnessVal: number = 0.66
  @Prop saturateVal: number = 0.52
  @Prop showGlow: boolean = true
  @Prop dim: number = 0
  // 由父页传入（播放页跟随封面；其余页暂固定 dark）
  @Prop mode: string = 'dark'

  build() {
    Stack() {
      // 1. 强模糊封面环境层（浅色提亮、深色压暗）
      // §1.2 光感过渡：主题/明度/饱和度变化以 450ms 缓动，避免跳变
      Image(cover(this.coverUrl, 400))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .scale({ x: 1.5, y: 1.5 })
        .blur(this.blurRadius)
        .saturate(V3Theme.isLight(this.mode) ? 0.5 : this.saturateVal)
        .brightness(V3Theme.isLight(this.mode) ? 1.2 : this.brightnessVal)
        .animation({ duration: 450, curve: Curve.EaseInOut })

      if (V3Theme.isLight(this.mode)) {
        // ===== 浅色：暖白 wash =====
        Column()
          .width('100%')
          .height('100%')
          .radialGradient({
            center: ['60%', '10%'],
            radius: '70%',
            colors: this.showGlow
              ? [['rgba(200,168,120,0.22)', 0.0], ['rgba(0,0,0,0)', 0.55]]
              : [['rgba(0,0,0,0)', 0.0], ['rgba(0,0,0,0)', 1.0]]
          })
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [['rgba(248,246,241,0.50)', 0.0], ['rgba(238,237,233,0.86)', 0.66],
              ['rgba(232,231,227,0.96)', 1.0]]
          })
        Column()
          .width('100%')
          .height('100%')
          .radialGradient({
            center: ['50%', '42%'],
            radius: '100%',
            colors: [['rgba(0,0,0,0)', 0.52], ['rgba(120,108,90,0.12)', 1.0]]
          })
        if (this.dim > 0) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(`rgba(255,255,255,${this.dim})`)
        }
      } else {
        // ===== 深色：暮光发光 =====
        Column()
          .width('100%')
          .height('100%')
          .radialGradient({
            center: ['60%', '12%'],
            radius: '70%',
            colors: this.showGlow
              ? [['rgba(158,118,66,0.24)', 0.0], ['rgba(0,0,0,0)', 0.55]]
              : [['rgba(0,0,0,0)', 0.0], ['rgba(0,0,0,0)', 1.0]]
          })
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [['rgba(14,12,9,0.05)', 0.0], ['rgba(10,10,13,0.52)', 0.62], ['rgba(8,8,10,0.82)', 1.0]]
          })
        Column()
          .width('100%')
          .height('100%')
          .radialGradient({
            center: ['50%', '42%'],
            radius: '100%',
            colors: [['rgba(0,0,0,0)', 0.52], ['rgba(0,0,0,0.42)', 1.0]]
          })
        if (this.dim > 0) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(`rgba(0,0,0,${this.dim})`)
        }
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor(V3Theme.canvas(this.mode))
    .animation({ duration: 450, curve: Curve.EaseInOut })
  }
}
