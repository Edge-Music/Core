/**
 * 可拖拽进度轨道（对齐设计规范 §4.2 OmspPlayerBar 进度段）
 * 液态玻璃风格：左时间 + 自定义轨道（底轨 / 暖金渐变已播放 / 拖拽滑块）+ 右时间。
 *
 * 由 PlayerBar 等容器注入 currentTimeMs / durationMs 与 onSeek 回调，
 * 组件自身只负责拖拽交互与展示，不耦合播放服务。
 * accent / glow 跟随封面光感（由父级传入，默认兜底暖金）。
 */
import { V3Color, V3Theme } from '../theme/Tokens'

@Component
export struct ProgressTrack {
  // 当前播放时间（ms）
  @Prop currentTimeMs: number = 0
  // 总时长（ms）
  @Prop durationMs: number = 0
  // 主题模式：'dark' | 'light'
  @Prop mode: string = 'dark'
  // accent / glow（封面取色），不传则用兜底暖金
  @Prop accent: string = V3Color.ACCENT_FALLBACK
  @Prop glow: string = V3Color.ACCENT_GLOW
  // 是否显示两端时间文本
  @Prop showTime: boolean = true
  // 拖拽 / 点击 seek 回调，参数为 [0,1] 比例
  onSeek?: (ratio: number) => void

  @State trackWidth: number = 1
  @State dragging: boolean = false
  @State dragRatio: number = 0

  private ratio(): number {
    if (this.dragging) {
      return this.dragRatio
    }
    if (this.durationMs <= 0) {
      return 0
    }
    const r: number = this.currentTimeMs / this.durationMs
    return r < 0 ? 0 : (r > 1 ? 1 : r)
  }

  private fmt(ms: number): string {
    if (!ms || ms < 0) {
      return '0:00'
    }
    const total: number = Math.floor(ms / 1000)
    const m: number = Math.floor(total / 60)
    const s: number = total % 60
    return `${m}:${s < 10 ? '0' + s : s}`
  }

  private commitSeek(r: number): void {
    const clamped: number = r < 0 ? 0 : (r > 1 ? 1 : r)
    if (this.durationMs > 0 && this.onSeek) {
      this.onSeek(clamped)
    }
  }

  build() {
    Row({ space: 10 }) {
      if (this.showTime) {
        Text(this.fmt(this.dragging ? this.dragRatio * this.durationMs : this.currentTimeMs))
          .fontSize(11)
          .fontColor(V3Theme.tx2(this.mode))
          .width(30)
      }

      // 自定义轨道（可拖拽）
      Stack({ alignContent: Alignment.Start }) {
        // 底轨
        Row()
          .width('100%')
          .height(4)
          .borderRadius(2)
          .backgroundColor(V3Theme.track(this.mode))
        // 已播放（暖金渐变）
        Row()
          .width(`${this.ratio() * 100}%`)
          .height(4)
          .borderRadius(2)
          .linearGradient({
            angle: 90,
            colors: [[V3Theme.accentGradStart(this.mode), 0.0], [V3Theme.accentGradEnd(this.mode), 1.0]]
          })
        // 拖拽滑块
        Row()
          .width(12)
          .height(12)
          .borderRadius(6)
          .backgroundColor(this.accent)
          .shadow({ radius: 10, color: this.glow, offsetX: 0, offsetY: 1 })
          .margin({ left: this.ratio() * this.trackWidth - 6 })
      }
      .layoutWeight(1)
      .height(14)
      .onAreaChange((_o: Area, n: Area) => {
        this.trackWidth = n.width as number
      })
      .onClick((e: ClickEvent) => {
        this.commitSeek((e.x as number) / this.trackWidth)
      })
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal })
          .onActionStart((e: GestureEvent) => {
            this.dragging = true
            this.dragRatio = this.ratio()
          })
          .onActionUpdate((e: GestureEvent) => {
            // 多指抬起等场景下 fingerList 可能为空，直接取下标会崩
            if (!e.fingerList || e.fingerList.length === 0) {
              return
            }
            const lx: number = e.fingerList[0].localX
            let r: number = lx / this.trackWidth
            r = r < 0 ? 0 : (r > 1 ? 1 : r)
            this.dragRatio = r
          })
          .onActionEnd(() => {
            this.commitSeek(this.dragRatio)
            this.dragging = false
          })
      )

      if (this.showTime) {
        Text(this.fmt(this.durationMs))
          .fontSize(11)
          .fontColor(V3Theme.tx3(this.mode))
          .width(30)
          .textAlign(TextAlign.End)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}