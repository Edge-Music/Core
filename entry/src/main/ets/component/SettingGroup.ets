import { StyleConstants } from "../constants/StyleConstants"
import { AnimationConstants } from "../constants/AnimationConstants"
import { SettingItem } from "../model/SettingItem"

@Component
export struct SettingGroup {
  @Prop title: ResourceStr = ''
  @Prop subtitle: string = ''
  @Prop items: SettingItem[] = []
  @State pressedIndex: number = -1
  @State hoveredIndex: number = -1 // 悬停状态

  // 现代化箭头图标 - 增强动画效果
  @Builder
  ArrowIcon(index: number) {
    Image($r('app.media.ic_chevron_right'))
      .width(20)
      .height(20)
      .fillColor($r('app.color.icon_normal'))
      .margin({ left: 8 })
      .scale({
        x: this.pressedIndex === index ? 0.85 : 1,
        y: this.pressedIndex === index ? 0.85 : 1
      })
      .opacity(this.hoveredIndex === index ? 1 : 0.7)
      .translate({ x: this.pressedIndex === index ? 6 : (this.hoveredIndex === index ? 2 : 0) })
      .animation({
        duration: AnimationConstants.DURATION_FAST,
        curve: AnimationConstants.CURVE_DECELERATE,
        onFinish: () => {
          this.pressedIndex = -1
        }
      })
  }

  // 现代化Toggle设置项 - 增强视觉效果
  @Builder
  SettingToggle(item: SettingItem, index: number) {
    Row() {
      Column({ space: 6 }) {
        Text(item.title)
          .fontSize(16)
          .fontColor($r('app.color.text_title'))
          .fontWeight(FontWeight.Bold)

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: item.value as boolean })
        .onChange(item.onChange)
        .selectedColor($r('app.color.accent_primary'))
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.hoveredIndex === index ? $r('app.color.card_hover') : Color.Transparent)
    .backgroundBlurStyle(this.hoveredIndex === index ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
    .borderRadius(8)
    .onClick(() => {
      this.pressedIndex = index
      item.onClick?.()
    })
    .onHover((isHover: boolean) => {
      this.hoveredIndex = isHover ? index : -1
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .hoverEffect(HoverEffect.Highlight)
    .animation({
      duration: AnimationConstants.DURATION_FAST,
      curve: AnimationConstants.CURVE_DECELERATE
    })
  }

  // 现代化文本切换设置项
  @Builder
  SettingTextSwitch(item: SettingItem, index: number) {
    Row() {
      Column({ space: 6 }) {
        Text(item.title)
          .fontSize(16)
          .fontColor($r('app.color.text_title'))
          .fontWeight(FontWeight.Bold)

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .layoutWeight(1)

      Text(item.value as string)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent_primary'))

      this.ArrowIcon(index)
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.hoveredIndex === index ? $r('app.color.card_hover') : Color.Transparent)
    .backgroundBlurStyle(this.hoveredIndex === index ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
    .borderRadius(8)
    .onClick(() => {
      this.pressedIndex = index
      item.onClick?.()
    })
    .onHover((isHover: boolean) => {
      this.hoveredIndex = isHover ? index : -1
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .hoverEffect(HoverEffect.Highlight)
    .animation({
      duration: AnimationConstants.DURATION_FAST,
      curve: AnimationConstants.CURVE_DECELERATE
    })
  }

  // 现代化文本输入设置项
  @Builder
  SettingTextInput(item: SettingItem, index: number) {
    Row() {
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Text(item.title)
            .fontSize(16)
            .fontColor($r('app.color.text_title'))
            .fontWeight(FontWeight.Bold)

          Text(`(${item.value as string})`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent_primary'))
        }
        .alignItems(VerticalAlign.Bottom)

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .width("calc(100% - 160px)")
        }
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .layoutWeight(1)

      this.ArrowIcon(index)
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.hoveredIndex === index ? $r('app.color.card_hover') : Color.Transparent)
    .backgroundBlurStyle(this.hoveredIndex === index ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
    .borderRadius(8)
    .onClick(() => {
      this.pressedIndex = index
      item.onClick?.()
    })
    .onHover((isHover: boolean) => {
      this.hoveredIndex = isHover ? index : -1
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .hoverEffect(HoverEffect.Highlight)
    .animation({
      duration: AnimationConstants.DURATION_FAST,
      curve: AnimationConstants.CURVE_DECELERATE
    })
  }

  // 现代化按钮设置项
  @Builder
  SettingButton(item: SettingItem, index: number) {
    Row() {
      Column({ space: 6 }) {
        Text(item.title)
          .fontSize(16)
          .fontColor($r('app.color.text_title'))
          .fontWeight(FontWeight.Bold)

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .layoutWeight(1)

      this.ArrowIcon(index)
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.hoveredIndex === index ? $r('app.color.card_hover') : Color.Transparent)
    .backgroundBlurStyle(this.hoveredIndex === index ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
    .borderRadius(8)
    .onClick(() => {
      this.pressedIndex = index
      item.onClick?.()
    })
    .onHover((isHover: boolean) => {
      this.hoveredIndex = isHover ? index : -1
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .hoverEffect(HoverEffect.Highlight)
    .animation({
      duration: AnimationConstants.DURATION_FAST,
      curve: AnimationConstants.CURVE_DECELERATE
    })
  }

  build() {
    Column({ space: 12 }) {
      // 现代化标题
      Text(this.title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 16, bottom: 4, left: 16 })
        .alignSelf(ItemAlign.Start)

      if (this.subtitle) {
        Text(this.subtitle)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_hint'))
          .margin({ bottom: 8, left: 16 })
          .alignSelf(ItemAlign.Start)
      }

      // 现代化设置项容器 - 增强视觉效果
      Column({ space: 2 }) {
        ForEach(this.items, (item: SettingItem, index: number) => {
          if (item.type === 'toggle') {
            this.SettingToggle(item, index)
          } else if (item.type === 'text-switch') {
            this.SettingTextSwitch(item, index)
          } else if (item.type === 'text-input') {
            this.SettingTextInput(item, index)
          } else if (item.type === 'button') {
            this.SettingButton(item, index)
          }
          // 现代化分隔线
          if (index !== this.items.length - 1) {
            Divider()
              .strokeWidth(0.5)
              .color($r('app.color.divider'))
              .margin({ left: 16, right: 16 })
              .opacity(0.5)
          }
        })
      }
      .backgroundColor($r('app.color.surface_1'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
      .borderRadius(12)
      .padding({ top: 4, bottom: 4 })
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 12, right: 12, bottom: 12 })
    .transition(TransitionEffect.OPACITY.animation({
      duration: AnimationConstants.DURATION_NORMAL,
      curve: AnimationConstants.CURVE_DECELERATE
    }))
  }
}