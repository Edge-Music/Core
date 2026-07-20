/**
 * 悬浮胶囊播控条（对齐设计规范 §4.2 OmspPlayerBar）
 * 液态玻璃胶囊：进度（可拖拽 seek）+ 上一首 / 播放暂停 / 下一首 + 更多。
 * 接真实播放服务 avPlayerManager / PlaylistManager，accent 跟随封面光感。
 */
import { avPlayerManager } from '../../util/AVPlayerManager'
import { PlaylistManager, PlayMode } from '../../util/PlaylistManager'
import { Song } from '../../type/Adapter'
import { SourceAdapter } from '../../adapter'
import { SongDownloadManager } from '../../util/SongDownloadManager'
import { V3SongActions } from '../util/V3SongActions'
import { Playlist } from '../../type/Adapter'
import { audio } from '@kit.AudioKit'
import { ToastUtil } from '@pura/harmony-utils'
import { V3Color, V3Radius, V3Space, V3Theme } from '../theme/Tokens'

@Component
export struct PlayerBar {
  // 'phone'：上一首/播放/下一首 + 更多；'wide'：播放模式/上一首/播放/下一首/列表
  @Prop variant: string = 'phone'
  // 列表/音效/定时回调（由 ImmersivePlayer 传入并弹对应 sheet）
  onList?: () => void
  onEffects?: () => void
  onTimer?: () => void
  // 键值对应 V3AmbientKey.ACCENT / .GLOW（装饰器要求字符串字面量）
  @StorageProp('v3_ambient_accent') accent: string = V3Color.ACCENT_FALLBACK
  @StorageProp('v3_ambient_glow') glow: string = V3Color.ACCENT_GLOW
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @StorageProp('current_playing_playMode') playMode: number = PlayMode.LOOP
  @StorageProp('current_playing_song') currentSong: Song | null = null
  @StorageProp('aggregation_playlist') aggPlaylists: Playlist[] = []

  // 「更多」菜单项：音效/定时/收藏/下载
  private moreMenu(): MenuElement[] {
    return [
      {
        value: '音效设置',
        action: () => {
          if (this.onEffects) {
            this.onEffects()
          } else {
            ToastUtil.showShort('音效设置')
          }
        }
      },
      {
        value: '定时播放',
        action: () => {
          if (this.onTimer) {
            this.onTimer()
          } else {
            ToastUtil.showShort('定时播放')
          }
        }
      },
      {
        value: '收藏到喜欢',
        action: () => {
          const s: Song | null = this.currentSong
          if (!s) {
            return
          }
          if (!s.source) {
            ToastUtil.showShort('无法收藏：该歌曲缺少数据源')
            return
          }
          SourceAdapter.likeSong(s, true).then((ok: boolean) => {
            ToastUtil.showShort(ok ? '已收藏到「我喜欢的音乐」' : '收藏失败，请稍后重试')
          })
        }
      },
      {
        value: '添加到歌单',
        action: () => {
          if (this.currentSong) {
            V3SongActions.addToPlaylist(this.currentSong, this.aggPlaylists)
          }
        }
      },
      {
        value: '下载',
        action: () => {
          const s: Song | null = this.currentSong
          if (!s) {
            return
          }
          const ok: boolean = SongDownloadManager.downloadSong(s.id.toString(), s)
          ToastUtil.showShort(ok ? '已加入下载队列' : '下载失败')
        }
      }
    ]
  }

  @State currentTimeMs: number = 0
  @State durationMs: number = 0
  @State isPlaying: boolean = false
  @State trackWidth: number = 1
  @State dragging: boolean = false
  @State dragRatio: number = 0
  @State playScale: number = 1

  private timer: number = -1
  private player = avPlayerManager

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
      if (this.dragging) {
        return
      }
      const p = await this.player.getAVPlayerInstance()
      this.durationMs = p.getDurationMs()
      this.currentTimeMs = p.getCurrentPosition()
    }, 500)
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

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

  private next(): void {
    const s = PlaylistManager.playNext()
    if (s) {
      PlaylistManager.playSong(s)
    }
  }

  private prev(): void {
    const s = PlaylistManager.playPrevious()
    if (s) {
      PlaylistManager.playSong(s)
    }
  }

  @Builder
  ModeButton() {
    Stack() {
      if (this.playMode === PlayMode.RANDOM) {
        SymbolGlyph($r('sys.symbol.shuffle')).fontSize(20).fontColor([V3Theme.tx3(this.mode)])
      } else if (this.playMode === PlayMode.SINGLE) {
        SymbolGlyph($r('sys.symbol.repeat_1')).fontSize(20).fontColor([V3Theme.tx3(this.mode)])
      } else {
        SymbolGlyph($r('sys.symbol.repeat')).fontSize(20).fontColor([V3Theme.tx3(this.mode)])
      }
    }
    .width(28)
    .height(28)
    .onClick(() => {
      PlaylistManager.switchPlayMode()
    })
  }

  @Builder
  PlayButton() {
    Stack() {
      SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
        .fontSize(22)
        .fontColor([V3Theme.playIcon(this.mode)])
    }
    .width(56)
    .height(56)
    .borderRadius(28)
    .linearGradient({ angle: 160, colors: [[V3Theme.playGradStart(this.mode), 0.0], [V3Theme.playGradEnd(this.mode), 1.0]] })
    .shadow({ radius: 22, color: 'rgba(201,154,87,0.42)', offsetX: 0, offsetY: 6 })
    .scale({ x: this.playScale, y: this.playScale })
    .onClick(() => {
      this.toggle()
    })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
          this.playScale = 0.9
        })
      } else if (e.type === TouchType.Up) {
        this.getUIContext().animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
          this.playScale = 1
        })
      }
    })
  }

  @Builder
  Progress() {
    Row({ space: 10 }) {
      Text(this.fmt(this.dragging ? this.dragRatio * this.durationMs : this.currentTimeMs))
        .fontSize(11)
        .fontColor(V3Theme.tx2(this.mode))
        .width(30)

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

      Text(this.fmt(this.durationMs))
        .fontSize(11)
        .fontColor(V3Theme.tx3(this.mode))
        .width(30)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      this.Progress()

      // 控制区（手机与宽屏一致：模式/上一首/播放/下一首/列表/更多）
      Row({ space: this.variant === 'wide' ? 28 : 18 }) {
        this.ModeButton()
        SymbolGlyph($r('sys.symbol.backward_end_fill'))
          .fontSize(24)
          .fontColor([V3Theme.tx1(this.mode)])
          .onClick(() => {
            this.prev()
          })
        this.PlayButton()
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(24)
          .fontColor([V3Theme.tx1(this.mode)])
          .onClick(() => {
            this.next()
          })
        SymbolGlyph($r('sys.symbol.music_note_list'))
          .fontSize(20)
          .fontColor([V3Theme.tx3(this.mode)])
          .onClick(() => {
            if (this.onList) {
              this.onList()
            }
          })
        SymbolGlyph($r('sys.symbol.more'))
          .fontSize(21)
          .fontColor([V3Theme.tx3(this.mode)])
          .bindMenu(this.moreMenu())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 14 })
    }
    .padding({ left: 18, right: 18, top: V3Space.M, bottom: 17 })
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      colorMode: V3Theme.isLight(this.mode) ? ThemeColorMode.LIGHT : ThemeColorMode.DARK
    })
    .backgroundColor(V3Theme.glass1(this.mode))
    .borderRadius(V3Radius.CONTROL)
    .border({ width: 1, color: V3Theme.glassInner(this.mode) })
    .shadow({ radius: 40, color: V3Color.SHADOW_AMBIENT, offsetX: 0, offsetY: 8 })
  }
}
