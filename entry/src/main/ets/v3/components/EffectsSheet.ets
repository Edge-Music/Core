/**
 * OMSP 3.0 · 音效面板 Sheet（玻璃风）
 * 全新 3.0 UI，底层复用 AudioEffectManager（EQ / 声道平衡 / DRC）。
 * 包含：EQ 开关 + 预设 + 10 段图形均衡；声道平衡；DRC 开关 + 预设。
 */
import { V3Theme } from '../theme/Tokens'
import {
  AudioEffectManager,
  EQ_BANDS,
  EQ_PRESETS,
  DRC_PRESETS,
  EqPresetItem,
  DrcPresetItem
} from '../../util/AudioEffectManager'
import { avPlayerManager } from '../../util/AVPlayerManager'
import { PreferencesCache } from '../../util/PreferenceCache'

@Component
export struct EffectsSheet {
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @State private eqEnabled: boolean = false
  @State private eqGains: number[] = new Array<number>(10).fill(0)
  @State private eqPreset: string = 'Default'
  @State private balance: number = 0
  @State private drcEnabled: boolean = false
  @State private drcPreset: string = 'Default'
  // 应用内音量（0~100，对应 avPlayer.setVolume 的 0.0~1.0）
  @State private volume: number = 100

  aboutToAppear(): void {
    this.eqEnabled = AudioEffectManager.isEqEnabled()
    this.eqGains = AudioEffectManager.getEqGains()
    this.eqPreset = AudioEffectManager.getEqPresetId()
    this.balance = AudioEffectManager.getBalance()
    this.drcEnabled = AudioEffectManager.isDrcEnabled()
    this.drcPreset = AudioEffectManager.getDrcPresetId()
    this.volume = Number(PreferencesCache.getUserPreference('Volume', '100'))
  }

  private refreshEq(): void {
    this.eqGains = AudioEffectManager.getEqGains()
    this.eqPreset = AudioEffectManager.getEqPresetId()
  }

  // ================= EQ 卡片 =================
  @Builder
  EqCard() {
    Column({ space: 14 }) {
      Row() {
        Text('均衡器 EQ')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.eqEnabled })
          .selectedColor(V3Theme.accentFallback(this.mode))
          .onChange((v: boolean) => {
            this.eqEnabled = v
            AudioEffectManager.setEqEnabled(v)
          })
      }
      .width('100%')
      this.EqContent()
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor(V3Theme.glass1(this.mode))
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
  }

  // ================= DRC 卡片 =================
  @Builder
  DrcCard() {
    Column({ space: 14 }) {
      Row() {
        Text('动态范围 DRC')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.drcEnabled })
          .selectedColor(V3Theme.accentFallback(this.mode))
          .onChange((v: boolean) => {
            this.drcEnabled = v
            AudioEffectManager.setDrcEnabled(v)
          })
      }
      .width('100%')
      this.DrcContent()
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor(V3Theme.glass1(this.mode))
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
  }

  // ================= 预设 chips =================
  // group: 'eq' | 'drc'，active 在内部读取 @State（避免 @Builder 值传参不响应）
  @Builder
  PresetChip(label: string, id: string, group: string, onTap: () => void) {
    Text(label)
      .fontSize(13)
      .fontColor((group === 'eq' ? this.eqPreset : this.drcPreset) === id ? '#FFFFFF' : V3Theme.tx2(this.mode))
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(16)
      .backgroundColor((group === 'eq' ? this.eqPreset : this.drcPreset) === id
        ? V3Theme.accentFallback(this.mode)
        : V3Theme.glass2(this.mode))
      .border({
        width: 1,
        color: (group === 'eq' ? this.eqPreset : this.drcPreset) === id
          ? Color.Transparent
          : V3Theme.glassBorder(this.mode)
      })
      .onClick(onTap)
  }

  // ================= EQ 图形均衡 =================
  @Builder
  EqGraph() {
    Row() {
      ForEach(EQ_BANDS, (label: string, i: number) => {
        Column() {
          Text(`${this.eqGains[i] > 0 ? '+' : ''}${this.eqGains[i].toFixed(0)}`)
            .fontSize(10)
            .fontColor(this.eqGains[i] !== 0 ? V3Theme.accentFallback(this.mode) : V3Theme.tx3(this.mode))
            .height(14)
          Slider({
            value: this.eqGains[i],
            min: -12,
            max: 12,
            step: 1,
            direction: Axis.Vertical,
            reverse: true
          })
            .blockColor('#FFFFFF')
            .selectedColor(V3Theme.accentFallback(this.mode))
            .trackColor(V3Theme.track(this.mode))
            .trackThickness(4)
            .height(130)
            .enabled(this.eqEnabled)
            .opacity(this.eqEnabled ? 1 : 0.4)
            .onChange((v: number) => {
              AudioEffectManager.setEqBand(i, v)
              this.eqGains = AudioEffectManager.getEqGains()
              this.eqPreset = 'Custom'
            })
          Text(label)
            .fontSize(10)
            .fontColor(V3Theme.tx3(this.mode))
            .height(14)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  EqContent() {
    Column({ space: 12 }) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(EQ_PRESETS, (p: EqPresetItem) => {
            this.PresetChip(p.label, p.id, 'eq', () => {
              AudioEffectManager.applyEqPreset(p.id)
              this.eqEnabled = true
              this.refreshEq()
            })
          })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      this.EqGraph()
    }
    .width('100%')
  }

  // ================= 声道平衡 =================
  @Builder
  BalanceContent() {
    Column({ space: 6 }) {
      Row() {
        Text('L')
          .fontSize(12)
          .fontColor(V3Theme.tx2(this.mode))
        Blank()
        Text(this.balanceLabel())
          .fontSize(12)
          .fontColor(V3Theme.accentFallback(this.mode))
        Blank()
        Text('R')
          .fontSize(12)
          .fontColor(V3Theme.tx2(this.mode))
      }
      .width('100%')
      Slider({ value: this.balance, min: -1, max: 1, step: 0.05 })
        .blockColor('#FFFFFF')
        .selectedColor(Color.Transparent)
        .trackColor(V3Theme.track(this.mode))
        .trackThickness(4)
        .width('100%')
        .onChange((v: number) => {
          this.balance = v
          AudioEffectManager.setBalance(v)
        })
    }
    .width('100%')
  }

  private balanceLabel(): string {
    if (Math.abs(this.balance) < 0.03) {
      return '居中'
    }
    const pct: number = Math.round(Math.abs(this.balance) * 100)
    return this.balance < 0 ? `左 ${pct}%` : `右 ${pct}%`
  }

  // ================= 应用内音量 =================
  @Builder
  VolumeContent() {
    Column({ space: 6 }) {
      Row() {
        Text('0')
          .fontSize(12)
          .fontColor(V3Theme.tx2(this.mode))
        Blank()
        Text(`${Math.round(this.volume)}%`)
          .fontSize(12)
          .fontColor(V3Theme.accentFallback(this.mode))
        Blank()
        Text('100')
          .fontSize(12)
          .fontColor(V3Theme.tx2(this.mode))
      }
      .width('100%')
      Slider({ value: this.volume, min: 0, max: 100, step: 1 })
        .blockColor('#FFFFFF')
        .selectedColor(V3Theme.accentFallback(this.mode))
        .trackColor(V3Theme.track(this.mode))
        .trackThickness(4)
        .width('100%')
        .onChange((v: number, mode: SliderChangeMode) => {
          this.volume = v
          avPlayerManager.avPlayer?.setVolume(v / 100)
          // 仅在拖动结束/点击时落盘，避免拖动过程中持续磁盘 IO（同 ClockScreensaver 字号滑杆）
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
            PreferencesCache.setUserPreference('Volume', v.toString())
          }
        })
    }
    .width('100%')
  }

  // ================= DRC =================
  @Builder
  DrcContent() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(DRC_PRESETS, (p: DrcPresetItem) => {
          this.PresetChip(p.label, p.id, 'drc', () => {
            AudioEffectManager.applyDrcPreset(p.id)
            this.drcEnabled = true
            this.drcPreset = p.id
          })
        })
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .opacity(this.drcEnabled ? 1 : 0.4)
    .enabled(this.drcEnabled)
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
        Text('音效设置')
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .margin({ bottom: 4 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Scroll() {
        Column({ space: 16 }) {
          this.EqCard()

          this.DrcCard()

          // 声道平衡（无开关，常驻）
          Column({ space: 14 }) {
            Row() {
              Text('声道平衡')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(V3Theme.tx1(this.mode))
              Blank()
              Text('复位')
                .fontSize(13)
                .fontColor(V3Theme.tx3(this.mode))
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor(V3Theme.glass2(this.mode))
                .onClick(() => {
                  AudioEffectManager.resetBalance()
                  this.balance = 0
                })
            }
            .width('100%')
            this.BalanceContent()
          }
          .width('100%')
          .padding(18)
          .borderRadius(24)
          .backgroundColor(V3Theme.glass1(this.mode))
          .border({ width: 1, color: V3Theme.glassBorder(this.mode) })

          // 应用内音量（无开关，常驻，复位到 100）
          Column({ space: 14 }) {
            Row() {
              Text('应用内音量')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(V3Theme.tx1(this.mode))
              Blank()
              Text('复位')
                .fontSize(13)
                .fontColor(V3Theme.tx3(this.mode))
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor(V3Theme.glass2(this.mode))
                .onClick(() => {
                  this.volume = 100
                  avPlayerManager.avPlayer?.setVolume(1)
                  PreferencesCache.setUserPreference('Volume', '100')
                })
            }
            .width('100%')
            this.VolumeContent()
          }
          .width('100%')
          .padding(18)
          .borderRadius(24)
          .backgroundColor(V3Theme.glass1(this.mode))
          .border({ width: 1, color: V3Theme.glassBorder(this.mode) })

          Row().height(this.bottomRect + 20)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
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
