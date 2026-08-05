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
import { LyricsPortraitPanel } from '../components/LyricsPortraitPanel'
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

  @State isPlaying: boolean = false

  private timer: number = -1
  private player = avPlayerManager
  private wentLandscape: boolean = false

  aboutToAppear(): void {
    this.player.getAVPlayerInstance().then((p) => {
      this.isPlaying = p.getState() === audio.AudioState.STATE_RUNNING
    })
    this.player.addListener('onPlay', () => {
      this.isPlaying = true
    })
    this.player.addListener('onPause', () => {
      this.isPlaying = false
    })
    // 竖屏布局的进度/定时已移入 LyricsPortraitPanel，这里仅需同步播放态（横屏播放键用）
    this.timer = setInterval(async () => {
      const p = await this.player.getAVPlayerInstance()
      this.isPlaying = p.getState() === audio.AudioState.STATE_RUNNING
    }, 500)
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer)
      this.timer = -1
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
      // 竖屏的进度条唤出交互在 LyricsPortraitPanel 内；横屏摆件态无需响应
      onInteract: () => {
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

  // ========== 窄屏（手机）布局 ==========
  @Builder
  PhoneLayout() {
    Column() {
      this.TopControls()
      // 竖屏歌词内容（紧凑头 + 滚动歌词 + 自动隐藏进度条）与播放器 Swiper 右页共用
      LyricsPortraitPanel()
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
