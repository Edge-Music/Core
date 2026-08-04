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
import { ProgressTrack } from './ProgressTrack'
import { deviceInfo } from '@kit.BasicServicesKit'
import { EventHelper } from '../../util/EventHelper'

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
        value: (this.currentSong?.meta?.isFavorite ?? false) ? '取消收藏' : '收藏到喜欢',
        action: () => {
          const s: Song | null = this.currentSong
          if (!s) {
            return
          }
          if (!s.source) {
            ToastUtil.showShort('无法操作：该歌曲缺少数据源')
            return
          }
          const want: boolean = !(s.meta?.isFavorite ?? false)
          SourceAdapter.likeSong(s, want).then((ok: boolean) => {
            if (ok) {
              EventHelper.postFavoriteToggle(want)
            }
            ToastUtil.showShort(ok
              ? (want ? '已收藏到「我喜欢的音乐」' : '已取消收藏')
              : '操作失败，请稍后重试')
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
  desktopLyrics(){
    Stack(){
      SymbolGlyph($r('sys.symbol.lyrics_square')).fontSize(20).fontColor([V3Theme.tx3(this.mode)])
    }
    .width(28)
    .height(28)
    .onClick(() => {
      if (deviceInfo.sdkApiVersion >= 23) {
        avPlayerManager.avSession?.isDesktopLyricVisible().then((visible: boolean) => {
          console.info(`isDesktopLyricVisible: ${visible}`);
          avPlayerManager.avSession?.setDesktopLyricVisible(!visible);
        })
      }

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

  build() {
    Column() {
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

      // 控制区（手机与宽屏一致：模式/上一首/播放/下一首/列表/更多）
      Row({ space: this.variant === 'wide' ? 28 : 18 }) {
        if (deviceInfo.sdkApiVersion >= 23){
          this.desktopLyrics()
        }
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
