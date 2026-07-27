/**
 * OMSP 3.0 · 光感歌词页（对齐设计规范 §窄2 + 横屏摆件态）
 * 断点自适应：
 *  - 窄屏（手机）：紧凑头（封面+歌名+播控）+ 渐隐滚动歌词 + 底部细进度。
 *  - 宽屏（平板/折叠）：横屏摆件态，左封面+信息+播控，右歌词居中渐隐。
 * 点歌词行跳转对应时间，收起箭头返回。接真实歌词与播放进度。
 */
import { Song } from '../../type/Adapter'
import { cover } from '../../util/AdapterHelper'
import { avPlayerManager } from '../../util/AVPlayerManager'
import { PlaylistManager } from '../../util/PlaylistManager'
import { audio } from '@kit.AudioKit'
import { window } from '@kit.ArkUI'
import { ToastUtil } from '@pura/harmony-utils'
import { AmbientBackground } from '../components/AmbientBackground'
import { ProgressTrack } from '../components/ProgressTrack'
import { LyricsView } from '../../component/ChainLyricsViewWrapper'
import { V3Color, V3Theme } from '../theme/Tokens'

@Component
export struct ImmersiveLyrics {
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('current_playing_song') song: Song | null = null
  @StorageProp('v3_ambient_accent') accent: string = V3Color.ACCENT_FALLBACK
  @StorageProp('v3_ambient_glow') glow: string = V3Color.ACCENT_GLOW
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('winHeight') winHeight: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('currentOrientation') orientation: string = 'portrait'
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @StorageLink('freeWindowMode') freeWindowMode:boolean = false

  @State currentTimeMs: number = 0
  @State durationMs: number = 0
  @State isPlaying: boolean = false
  // 窄屏进度条自动隐藏（视频播控式：交互显示，静置数秒后隐藏，歌词更沉浸）
  @State controlsVisible: boolean = true

  private timer: number = -1
  private hideTimer: number = -1
  private player = avPlayerManager
  private wentLandscape: boolean = false

  // 显示进度条并（重新）计时隐藏
  private showControls(): void {
    if (!this.controlsVisible) {
      this.getUIContext().animateTo({ duration: 280, curve: Curve.EaseInOut }, () => {
        this.controlsVisible = true
      })
    }
    this.scheduleHide()
  }

  private scheduleHide(): void {
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer)
      this.hideTimer = -1
    }
    this.hideTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 280, curve: Curve.EaseInOut }, () => {
        this.controlsVisible = false
      })
    }, 4000)
  }

  aboutToAppear(): void {
    this.player.getAVPlayerInstance().then((p) => {
      this.currentTimeMs = p.getCurrentPosition()
      this.durationMs = p.getDurationMs()
      this.isPlaying = p.getState() === audio.AudioState.STATE_RUNNING
    })
    this.player.addListener('onPlay', () => {
      this.isPlaying = true
    })
    this.player.addListener('onPause', () => {
      this.isPlaying = false
    })
    this.timer = setInterval(async () => {
      const p = await this.player.getAVPlayerInstance()
      this.durationMs = p.getDurationMs()
      this.currentTimeMs = p.getCurrentPosition()
    }, 500)
    // 进入后先展示进度条，数秒后自动隐藏
    this.scheduleHide()
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer)
      this.timer = -1
    }
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer)
      this.hideTimer = -1
    }
    // 退出歌词页（含返回键）时若曾切横屏，复位方向
    this.resetOrientation()
  }

  private isWide(): boolean {
    return this.widthBp >= WidthBreakpoint.WIDTH_LG || this.orientation === 'landscape'
  }

  private setLandscape(land: boolean): void {
    if (land) {
      this.wentLandscape = true
    }
    const ctx: Context = this.getUIContext().getHostContext() as Context
    window.getLastWindow(ctx).then((win: window.Window) => {
      // 复位用 UNSPECIFIED 回到 module.json5 默认（auto_rotation_restricted），而非硬锁竖屏
      win.setPreferredOrientation(land ? window.Orientation.LANDSCAPE : window.Orientation.UNSPECIFIED)
    }).catch(() => {
    })
  }

  private resetOrientation(): void {
    if (this.wentLandscape) {
      this.setLandscape(false)
      this.wentLandscape = false
    }
  }

  private artistNames(): string {
    return this.song?.artists?.map((a) => a.name).join(' / ') ?? '未知艺术家'
  }

  // 真实音质标签（读当前歌曲码率），替换原 mock「无损 FLAC」
  private qualityLabel(): string {
    const b: number = this.song?.meta?.bitrate ?? this.song?.privilege?.maxBitrate ?? 0
    if (b >= 999900) {
      return '高清臻音'
    }
    if (b >= 999000) {
      return 'Hi-Res'
    }
    if (b >= 350000) {
      return '无损'
    }
    if (b >= 320000) {
      return '极高'
    }
    if (b >= 192000) {
      return '较高'
    }
    if (b > 0) {
      return '标准'
    }
    return ''
  }

  // 副标题：艺术家 [· 数据源] [· 音质]
  private subtitleText(): string {
    let s: string = this.artistNames()
    const src: string = this.song?.source?.name ?? ''
    if (src.length > 0) {
      s += ` · ${src}`
    }
    const q: string = this.qualityLabel()
    if (q.length > 0) {
      s += ` · ${q}`
    }
    return s
  }

  private commitSeek(r: number): void {
    const clamped: number = r < 0 ? 0 : (r > 1 ? 1 : r)
    if (this.durationMs > 0) {
      this.player.seek(Math.floor(clamped * this.durationMs))
      this.currentTimeMs = Math.floor(clamped * this.durationMs)
    }
  }

  private toggle(): void {
    if (this.isPlaying) {
      this.player.pause()
    } else {
      this.player.play()
    }
  }

  // 复用工程封装的链式歌词组件（物理滚动 + 点击跳转 + 光感高亮发光）
  // 发光色跟随封面光感 accent（this.glow），实现暖金发光
  @Builder
  Lyrics(so: string) {
    LyricsView({
      mode_judge: false,
      glowColor: this.glow,
      glowRadius: 22,
      normalColor: V3Theme.isLight(this.mode) ? 'rgba(10,10,13,0.62)' : V3Theme.tx1(this.mode),
      highlightColor: V3Theme.isLight(this.mode) ? '#6B4A1C' : '#FFFFFF',
      screenOrientation: so,
      onInteract: () => {
        this.showControls()
      }
    })
  }

  @Builder
  PlayCircle(size: number) {
    Stack() {
      SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
        .fontSize(size * 0.4)
        .fontColor([V3Theme.playIcon(this.mode)])
    }
    .width(size)
    .height(size)
    .borderRadius(size / 2)
    .linearGradient({ angle: 160, colors: [[V3Theme.playGradStart(this.mode), 0.0], [V3Theme.playGradEnd(this.mode), 1.0]] })
    .shadow({ radius: 20, color: 'rgba(201,154,87,0.42)', offsetX: 0, offsetY: 6 })
    .onClick(() => {
      this.toggle()
    })
  }

  // ========== 顶部控制（窄屏） ==========
  @Builder
  TopControls() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_down'))
        .fontSize(24)
        .fontColor([V3Theme.tx1(this.mode)])
        .onClick(() => {
          this.pageStack.pop()
        })
      Blank()
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.rectangle_portrait_rotate'))
          .fontSize(17)
          .fontColor([V3Theme.tx1(this.mode)])
        Text('横屏')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
      }
      .height(36)
      .padding({ left: 13, right: 13 })
      .borderRadius(18)
      .backgroundColor(V3Theme.isLight(this.mode) ? 'rgba(255,255,255,0.7)' : 'rgba(40,34,24,0.55)')
      .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
      .onClick(() => {
        this.setLandscape(true)
      })
    }
    .width('100%')
    .padding({ left: 14, right: 14 })
  }

  @Builder
  Header() {
    Row({ space: 15 }) {
      Image(cover(this.song?.album?.cover ?? '', 200))
        .width(62)
        .height(62)
        .borderRadius(14)
        .objectFit(ImageFit.Cover)
        .shadow({ radius: 20, color: 'rgba(0,0,0,0.6)', offsetX: 0, offsetY: 10 })
      Column() {
        Text(this.song?.name ?? '暂无播放')
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.artistNames())
          .fontSize(13)
          .fontColor(V3Theme.tx2(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.PlayCircle(50)
    }
    .width('100%')
    .padding({ left: 22, right: 22 })
  }

  @Builder
  ProgressRow() {
    Row() {
      ProgressTrack({
        currentTimeMs: this.currentTimeMs,
        durationMs: this.durationMs,
        mode: this.mode,
        accent: this.accent,
        glow: this.glow,
        onSeek: (r: number) => {
          this.commitSeek(r)
        }
      })
    }
    .width('100%')
    .padding({ left: 22, right: 22 })
  }

  // ========== 窄屏（手机）布局 ==========
  @Builder
  PhoneLayout() {
    Column() {
      this.TopControls()
      Column() {
        this.Header()
        Row()
          .width('100%')
          .height(1)
          .margin({ top: 20, left: 22, right: 22 })
          .linearGradient({
            angle: 90,
            colors: [['rgba(255,255,255,0)', 0.0], ['rgba(255,255,255,0.14)', 0.3],
              ['rgba(255,255,255,0.14)', 0.7], ['rgba(255,255,255,0)', 1.0]]
          })
      }
      .margin({ top: 14 })

      Stack() {
        this.Lyrics('portrait')

        // 进度条：静置数秒后收起（高度归零，歌词直接延伸到最底部，无避让更沉浸）
        // 可见时底部避让系统手势条；隐藏时归零，歌词铺满到屏幕底缘
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .linearGradientBlur(BlurStyle.COMPONENT_REGULAR,
              { fractionStops: [[0.1, 0], [1, 1]], direction: GradientDirection.Bottom })

          Column(){
            this.ProgressRow()
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
        .position({ x: 0, y: this.controlsVisible ? '90%' : '100%' })
        .width('100%')
        .height('10%')
      }
      .layoutWeight(1)
      .width('100%')
      // 点击歌词空白区域也可唤出进度条（点歌词行走 onInteract）
      .onClick(() => {
        this.showControls()
      })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topRect + 10 })
  }

  // ========== 宽屏（横屏摆件）布局 ==========
  @Builder
  WideLayout() {
    Stack() {
      // 竖屏返回胶囊（转回竖屏）
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.rectangle_portrait_rotate'))
          .fontSize(15)
          .fontColor([V3Theme.tx1(this.mode)])
        Text('竖屏')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
      }
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(17)
      .backgroundColor(V3Theme.isLight(this.mode) ? 'rgba(255,255,255,0.7)' : 'rgba(40,34,24,0.55)')
      .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
      .shadow({ radius: 12, color: 'rgba(0,0,0,0.25)', offsetX: 0, offsetY: 2 })
      .position({ right: 18, top: 18 })
      .zIndex(20)
      .onClick(() => {
        this.setLandscape(false)
      })

      Row() {
        // 左：封面 + 信息 + 播控
        Column({ space: 20 }) {
          Stack() {
            Image(cover(this.song?.album?.cover ?? '', 400))
              .width(196)
              .height(196)
              .borderRadius(22)
              .objectFit(ImageFit.Cover)
              .shadow({ radius: 70, color: 'rgba(0,0,0,0.8)', offsetX: 0, offsetY: 34 })
            Column()
              .width(196)
              .height(196)
              .borderRadius(22)
              .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
          }
          Column() {
            Text(this.song?.name ?? '暂无播放')
              .fontSize(24)
              .fontWeight(FontWeight.Medium)
              .fontColor(V3Theme.tx1(this.mode))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.subtitleText())
              .fontSize(14)
              .fontColor(V3Theme.tx2(this.mode))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Center)

          Row({ space: 24 }) {
            SymbolGlyph($r('sys.symbol.backward_end_fill'))
              .fontSize(22)
              .fontColor([V3Theme.tx1(this.mode)])
              .onClick(() => {
                const prev = PlaylistManager.playPrevious()
                if (prev) {
                  PlaylistManager.playSong(prev)
                }
              })
            this.PlayCircle(52)
            SymbolGlyph($r('sys.symbol.forward_end_fill'))
              .fontSize(22)
              .fontColor([V3Theme.tx1(this.mode)])
              .onClick(() => {
                const next = PlaylistManager.playNext()
                if (next) {
                  PlaylistManager.playSong(next)
                }
              })
          }
        }
        .width(360)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 30, right: 30 })

        // 右：歌词居中
        Column() {
          this.Lyrics('landscape')
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      Stack() {
        AmbientBackground({
          coverUrl: this.song?.album?.cover ?? '',
          blurRadius: 64,
          brightnessVal: 0.58,
          saturateVal: 0.50,
          showGlow: true,
          mode: this.mode
        })

        if (this.isWide()) {
          this.WideLayout()
        } else {
          this.PhoneLayout()
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(V3Color.CANVAS)
    .hideTitleBar(this.freeWindowMode&&this.isWide()?false:true)
    .title("",{barStyle:BarStyle.STACK})
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onBackPressed(() => {
      // 系统返回键：先复位方向再走默认返回
      this.resetOrientation()
      return false
    })
  }
}
