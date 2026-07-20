/**
 * OMSP 3.0 · 定时播放 Sheet（玻璃风）
 * 全新 3.0 UI，复用底层：EventHelper.postPauseTimer / AppStorage 'playing_pause_time'。
 * 预设分钟 chips + 自定义 + 倒计时展示 + 取消。
 */
import { EventHelper } from '../../util/EventHelper'
import { DialogAction, DialogHelper } from '@pura/harmony-dialog'
import { ToastUtil } from '@pura/harmony-utils'
import { V3Theme } from '../theme/Tokens'

@Component
export struct TimerSheet {
  @StorageLink('playing_pause_time') pauseAt: number = -1
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @State remaining: string = ''
  @State selected: number = -1
  private timerId: number = -1
  private readonly options: number[] = [10, 15, 20, 30, 45, 60, 90, 120]

  aboutToAppear(): void {
    if (this.pauseAt > 0) {
      const mins: number = Math.floor((this.pauseAt - Date.now()) / 60000)
      this.selected = this.options.includes(mins) ? mins : -1
    }
    this.tick()
    this.timerId = setInterval(() => {
      this.tick()
    }, 1000)
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  private tick(): void {
    if (this.pauseAt <= 0) {
      this.remaining = ''
      this.selected = -1
      return
    }
    const rest: number = this.pauseAt - Date.now()
    if (rest <= 0) {
      this.remaining = ''
      this.selected = -1
      return
    }
    const h: number = Math.floor(rest / 3600000)
    const m: number = Math.floor((rest % 3600000) / 60000)
    const s: number = Math.floor((rest % 60000) / 1000)
    this.remaining = h > 0
      ? `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
      : `${m}:${s.toString().padStart(2, '0')}`
  }

  private setTimer(minutes: number): void {
    const end: number = Date.now() + minutes * 60000
    this.pauseAt = end
    this.selected = minutes
    EventHelper.postPauseTimer(end)
  }

  private cancelTimer(): void {
    this.pauseAt = -1
    this.selected = -1
    this.remaining = ''
    EventHelper.postPauseTimer(-1)
  }

  private customTimer(): void {
    DialogHelper.showTextInputDialog({
      title: '自定义分钟数',
      text: this.pauseAt > 0 ? Math.floor((this.pauseAt - Date.now()) / 60000).toString() : '',
      inputType: InputType.Number,
      cancelButton: { style: CancelButtonStyle.INVISIBLE },
      onAction: (action: number, _id: string, value: string) => {
        if (action === DialogAction.SURE) {
          const min: number = parseInt(value)
          if (isNaN(min) || min <= 0) {
            ToastUtil.showShort('请输入有效的分钟数')
            return
          }
          this.setTimer(min)
        }
      }
    })
  }

  @Builder
  Chip(minutes: number) {
    Column() {
      Text(`${minutes}`)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selected === minutes ? '#FFFFFF' : V3Theme.tx1(this.mode))
      Text('分钟')
        .fontSize(11)
        .fontColor(this.selected === minutes ? 'rgba(255,255,255,0.9)' : V3Theme.tx3(this.mode))
        .margin({ top: 2 })
    }
    .width(76)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .borderRadius(18)
    .backgroundColor(this.selected === minutes ? V3Theme.accentFallback(this.mode) : V3Theme.glass2(this.mode))
    .border({ width: 1, color: this.selected === minutes ? Color.Transparent : V3Theme.glassBorder(this.mode) })
    .onClick(() => {
      this.setTimer(minutes)
    })
  }

  build() {
    Column() {
      // 抓手 + 标题
      Column() {
        Row()
          .width(38)
          .height(4)
          .borderRadius(2)
          .backgroundColor(V3Theme.track(this.mode))
          .margin({ top: 10, bottom: 8 })
        Text('定时播放')
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Scroll() {
        Column({ space: 18 }) {
          // 倒计时卡（仅在定时激活时显示）
          if (this.remaining.length > 0) {
            Row() {
              Row({ space: 12 }) {
                SymbolGlyph($r('sys.symbol.timer'))
                  .fontSize(24)
                  .fontColor([V3Theme.accentFallback(this.mode)])
                Column() {
                  Text('剩余时间')
                    .fontSize(12)
                    .fontColor(V3Theme.tx3(this.mode))
                  Text(this.remaining)
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(V3Theme.accentFallback(this.mode))
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)
              Text('取消')
                .fontSize(14)
                .fontColor('#FFFFFF')
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .borderRadius(18)
                .backgroundColor(V3Theme.accentFallback(this.mode))
                .onClick(() => {
                  this.cancelTimer()
                })
            }
            .width('100%')
            .padding(16)
            .borderRadius(20)
            .backgroundColor(V3Theme.glass1(this.mode))
            .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
          }

          // 预设网格
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(this.options, (m: number) => {
              Column() {
                this.Chip(m)
              }
              .margin({ bottom: 12 })
            })
          }
          .width('100%')

          // 自定义
          Row() {
            Text('自定义时间')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(V3Theme.tx1(this.mode))
          }
          .width('100%')
          .height(52)
          .justifyContent(FlexAlign.Center)
          .borderRadius(26)
          .backgroundColor(V3Theme.glass2(this.mode))
          .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
          .onClick(() => {
            this.customTimer()
          })

          Row().height(this.bottomRect + 16)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(V3Theme.canvas(this.mode))
    .borderRadius({
      topLeft: this.widthBp >= WidthBreakpoint.WIDTH_LG ? 30 : 40,
      topRight: this.widthBp >= WidthBreakpoint.WIDTH_LG ? 30 : 40,
      bottomLeft: this.widthBp >= WidthBreakpoint.WIDTH_LG ? 30 : 0,
      bottomRight: this.widthBp >= WidthBreakpoint.WIDTH_LG ? 30 : 0
    })
    .clip(true)
  }
}
