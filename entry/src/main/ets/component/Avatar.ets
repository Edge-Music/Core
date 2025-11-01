import { ImageKnifeComponent } from "@ohos/imageknife";
import { AnimationConstants } from "../constants/AnimationConstants";

/**
 * 现代化头像组件
 * - 支持加载状态
 * - 优化圆角处理
 * - 增加悬停效果
 * - 统一尺寸规范
 */
@Component
export struct Avatar {
  @Prop url: ResourceStr = ''
  @Prop radius: number | string = "50%"
  @Prop avatarSize: number = 40 // 默认尺寸（重命名避免与保留属性冲突）
  @Prop enableHover: boolean = false // 是否启用悬停效果

  @State private isHovered: boolean = false
  @State private isLoaded: boolean = false

  build() {
    Stack() {
      // 占位背景
      Column()
        .width(this.avatarSize)
        .height(this.avatarSize)
        .backgroundColor($r('app.color.surface_2'))
        .borderRadius(this.radius)
        .opacity(this.isLoaded ? 0 : 1)
        .animation({
          duration: AnimationConstants.DURATION_FAST,
          curve: AnimationConstants.CURVE_DECELERATE
        })

      // 头像图片
      Image(this.url ?? $r('app.media.ic_placeholder'))
        .width(this.avatarSize)
        .height(this.avatarSize)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.radius)
        .clip(true)
        .opacity(this.isLoaded ? 1 : 0)
        .scale({
          x: this.isHovered && this.enableHover ? 1.05 : 1,
          y: this.isHovered && this.enableHover ? 1.05 : 1
        })
        .shadow(this.isHovered && this.enableHover ? ShadowStyle.OUTER_DEFAULT_MD : ShadowStyle.OUTER_DEFAULT_SM)
        .onComplete(() => {
          this.isLoaded = true
        })
        .animation({
          duration: AnimationConstants.DURATION_FAST,
          curve: AnimationConstants.CURVE_DECELERATE
        })
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .onHover((isHover: boolean) => {
      if (this.enableHover) {
        this.isHovered = isHover
      }
    })
    .hoverEffect(this.enableHover ? HoverEffect.Highlight : HoverEffect.None)
  }
}