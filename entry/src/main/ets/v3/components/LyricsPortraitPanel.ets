/**
 * LyricsPortraitPanel —— 竖屏歌词面板（从 ImmersiveLyrics 竖屏布局抽取的可复用内容）
 *
 * 内容：紧凑头（封面+歌名+歌手+圆形播放键）+ 渐变分隔线 + 渐隐滚动歌词 + 底部细进度条
 * （进度条视频播控式：交互显示，静置数秒后自动隐藏）。
 *
 * 复用方：
 * 1. ImmersiveLyrics 歌词页竖屏布局（页面自行提供顶部「收起/横屏」控制条与安全区 padding）；
 * 2. ImmersivePlayer 滑动分页（Swiper）模式右页（无页面级控制条，通过 topPadding 避让状态栏）。
 */
import { Song } from '../../type/Adapter'
import { cover } from '../../util/AdapterHelper'
import { avPlayerManager } from '../../util/AVPlayerManager'
import { audio } from '@kit.AudioKit'
import { ProgressTrack } from './ProgressTrack'
import { LyricsView } from '../../component/ChainLyricsViewWrapper'
import { V3Color, V3Theme } from '../theme/Tokens'

@Component
export struct LyricsPortraitPanel {
  @StorageLink('current_playing_song') song: Song | null = null
  @StorageProp('v3_ambient_accent') accent: string = V3Color.ACCENT_FALLBACK
  @StorageProp('v3_ambient_glow') glow: string = V3Color.ACCENT_GLOW
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  /** 顶部留白（vp）：嵌入播放器 Swiper 右页时传入 topRect 避让状态栏；歌词页内复用时传 0 */
  @Prop topPadding: number = 0
  /** 是否可见/活动：离屏（Swiper 另一页）时冻结歌词组件的切行动画，避免播放中白跑动画 */
  @Prop active: boolean = true

  @State currentTimeMs: number = 0
  @State durationMs: number = 0
  @State isPlaying: boolean = false
  // 进度条自动隐藏（视频播控式：交互显示，静置数秒后隐藏，歌词更沉浸）
  @State controlsVisible: boolean = true

  private timer: number = -1
  private hideTimer: number = -1
  private player = avPlayerManager

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
  }

  private artistNames(): string {
    return this.song?.artists?.map((a) => a.name).join(' / ') ?? '未知艺术家'
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
  Lyrics() {
    LyricsView({
      mode_judge: false,
      glowColor: this.glow,
      glowRadius: 22,
      normalColor: V3Theme.isLight(this.mode) ? 'rgba(10,10,13,0.62)' : V3Theme.tx1(this.mode),
      highlightColor: V3Theme.isLight(this.mode) ? '#6B4A1C' : '#FFFFFF',
      screenOrientation: 'portrait',
      active: this.active,
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

  build() {
    Column() {
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
        this.Lyrics()

        // 进度条：静置数秒后收起（高度归零，歌词直接延伸到最底部，无避让更沉浸）
        // 可见时底部避让系统手势条；隐藏时归零，歌词铺满到屏幕底缘
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .linearGradientBlur(BlurStyle.COMPONENT_REGULAR,
              { fractionStops: [[0.1, 0], [1, 1]], direction: GradientDirection.Bottom })

          Column() {
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
    .padding({ top: this.topPadding })
  }
}
