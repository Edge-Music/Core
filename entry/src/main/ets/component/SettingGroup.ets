import { StyleConstants } from "../constants/StyleConstants"
import { SettingItem } from "../model/SettingItem"

@Component
export struct SettingGroup {
  @Prop title: ResourceStr = ''
  @Prop subtitle: string = ''
  @Prop items: SettingItem[] = []
  @State pressedIndex: number = -1

  @Builder
  ArrowIcon(index: number) {
    Image($r('app.media.ic_chevron_right'))
      .width(20)
      .height(20)
      .fillColor($r('app.color.icon_normal'))
      .margin({ left: 4 })
      .scale({ x: this.pressedIndex === index ? 0.9 : 1, y: this.pressedIndex === index ? 0.9 : 1 })
      .opacity(this.pressedIndex === index ? 0.8 : 1)
      .translate({ x: this.pressedIndex === index ? 4 : 0 })
      .animation({
        duration: 150,
        curve: Curve.FastOutSlowIn,
        onFinish: () => {
          this.pressedIndex = -1
        }
      })
  }

  @Builder
  SettingToggle(item: SettingItem, index: number) {
    Row() {
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(16)
          .fontColor($r('app.color.text_title'))
          .fontWeight(FontWeight.Medium)

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Blank()

      Toggle({ type: ToggleType.Switch, isOn: item.value as boolean })
        .onChange(item.onChange)
        .selectedColor($r('app.color.setting_button_normal'))
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      left: 16,
      right: 16,
      top: 12,
      bottom: 12
    })
    .onClick(() => {
      this.pressedIndex = index
      item.onClick?.()
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT })
  }

  @Builder
  SettingTextSwitch(item: SettingItem, index: number) {
    Row() {
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(16)
          .fontColor($r('app.color.text_title'))
          .fontWeight(FontWeight.Medium)

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Blank()

      Text(item.value as string)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))

      this.ArrowIcon(index)
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      left: 16,
      right: 16,
      top: 12,
      bottom: 12
    })
    .onClick(() => {
      this.pressedIndex = index
      item.onClick?.()
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT })
  }

  @Builder
  SettingTextInput(item: SettingItem, index: number) {
    Row() {
      Column({ space: 4 }) {
        Row() {
          Text(item.title)
            .fontSize(16)
            .fontColor($r('app.color.text_title'))
            .fontWeight(FontWeight.Medium)

          Text(`(${item.value as string})`)
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(VerticalAlign.Bottom)

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width("calc(100% - 160px)")
        }
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Blank()

      this.ArrowIcon(index)
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      left: 16,
      right: 16,
      top: 12,
      bottom: 12
    })
    .onClick(() => {
      this.pressedIndex = index
      item.onClick?.()
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT })

  }

  @Builder
  SettingButton(item: SettingItem, index: number) {
    Row() {
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(16)
          .fontColor($r('app.color.text_title'))
          .fontWeight(FontWeight.Medium)

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Blank()

      this.ArrowIcon(index)
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      left: 16,
      right: 16,
      top: 12,
      bottom: 12
    })
    .onClick(() => {
      this.pressedIndex = index
      item.onClick?.()
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT })
  }

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 16, bottom: 8, left: 16 })
        .alignSelf(ItemAlign.Start)

      if (this.subtitle) {
        Text(this.subtitle)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: 16, left: 16 })
          .alignSelf(ItemAlign.Start)
      }

      Column({ space: 1 }) {
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
          // 如果是最后一个元素，不绘制分隔线
          if (index !== this.items.length-1){
            Divider()
              .strokeWidth(0.5)
              .color($r('app.color.divider'))
              .margin({ left: 16, right: 16 })
          }
        })
      }
      .backgroundColor($r('app.color.setting_item_background'))
      .borderRadius(8)
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 12, right: 12 })
    .transition({ opacity: 250, scale: { x: 1, y: 1 } })
    .animation({
      delay: 50,
      duration: 250,
      curve: Curve.FastOutSlowIn
    })
  }
}