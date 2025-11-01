import { AnimationConstants } from "../constants/AnimationConstants"

/**
 * 现代化菜单图标组件
 * - 使用新动画常量
 * - 官方交互API
 * - 统一尺寸规范
 * - 增强视觉反馈
 */
@Component
export struct MenuIcon {
  @Prop active: boolean = false
  @Prop icon?: Resource = undefined
  @Prop iconSize: number = 40 // 统一尺寸规范

  @State private isPressed: boolean = false

  build() {
    Button({ type: ButtonType.Circle }) {
      Image(this.icon)
        .width(24)
        .height(24)
        .fillColor(this.active ? $r('app.color.accent_primary') : $r('app.color.text_primary'))
        .scale(this.active ? { x: 1.08, y: 1.08 } : { x: 1, y: 1 })
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .backgroundColor(this.active ? $r('app.color.surface_2') : Color.Transparent)
    .backgroundBlurStyle(this.active ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
    .shadow(this.active ? ShadowStyle.OUTER_DEFAULT_SM : ShadowStyle.OUTER_DEFAULT_XS)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    .hoverEffect(HoverEffect.Highlight)
    .stateStyles({
      normal: {
        .scale({ x: 1, y: 1 })
      },
      pressed: {
        .scale({ x: 0.95, y: 0.95 })
      }
    })
    .animation({
      duration: AnimationConstants.DURATION_FAST,
      curve: AnimationConstants.CURVE_DECELERATE
    })
  }
}