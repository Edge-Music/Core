/**
 * OMSP 3.0 · 本地下载（全新玻璃风，功能对齐旧 view/Download.ets）
 * 两页签：下载中（队列 + 进度 + 暂停/继续 + 全部控制）+ 下载历史（已下载 + 大小 + 播放 + 删除）。
 * 数据复用 SongDownloadManager：download_queue / getAllDownloads / pauseTask / resumeTask /
 * pauseAllTasks / resumeAllTasks / clearCompleted / removeSong / getQueueStats。
 */
import { Song, Playlist, ID } from '../../type/Adapter'
import { PlaylistManager } from '../../util/PlaylistManager'
import { SongDownloadManager, SongDownloadItem, DownloadProgress } from '../../util/SongDownloadManager'
import { cover } from '../../util/AdapterHelper'
import { AmbientBackground } from '../components/AmbientBackground'
import { V3SongActions } from '../util/V3SongActions'
import { ToastUtil } from '@pura/harmony-utils'
import { V3Color, V3Radius, V3Theme } from '../theme/Tokens'

@Component
export struct ImmersiveDownload {
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('current_playing_song') playingSong: Song | null = null
  @StorageLink('download_queue') queue: Map<ID, DownloadProgress> = new Map()
  @StorageProp('aggregation_playlist') aggPlaylists: Playlist[] = []
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @State tab: number = 0 // 0=下载中 1=下载历史
  @State history: SongDownloadItem[] = []

  aboutToAppear(): void {
    this.loadHistory()
  }

  private loadHistory(): void {
    this.history = SongDownloadManager.getAllDownloads().sort((a, b) => b.downloadTime - a.downloadTime)
  }

  private isWide(): boolean {
    return this.widthBp >= WidthBreakpoint.WIDTH_LG
  }

  private queueItems(): DownloadProgress[] {
    return Array.from(this.queue.values())
  }

  private artistNames(song: Song): string {
    return song.artists?.map((a) => a.name).join(' / ') ?? ''
  }

  private fmtSize(bytes: number): string {
    if (!bytes || bytes <= 0) {
      return ''
    }
    const mb: number = bytes / 1024 / 1024
    if (mb >= 1) {
      return `${mb.toFixed(1)} MB`
    }
    return `${(bytes / 1024).toFixed(0)} KB`
  }

  private statusText(p: DownloadProgress): string {
    if (p.status === 'downloading') {
      return `下载中 ${Math.round(p.progress)}%`
    }
    if (p.status === 'paused') {
      return '已暂停'
    }
    if (p.status === 'waiting') {
      return '等待中'
    }
    if (p.status === 'completed') {
      return '已完成'
    }
    if (p.status === 'failed' || p.status === 'error') {
      return '失败'
    }
    if (p.status === 'retrying') {
      return '重试中'
    }
    return ''
  }

  private playHistory(item: SongDownloadItem): void {
    PlaylistManager.loadPlaylist(this.history.map((h) => h.song), item.song)
  }

  // ============ 页签 ============
  @Builder
  Tabs() {
    Row({ space: 10 }) {
      this.TabChip(0, '下载中')
      this.TabChip(1, '下载历史')
    }
    .padding({ left: 20, right: 20 })
  }

  @Builder
  TabChip(idx: number, label: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.tab === idx ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.tab === idx ? '#FFFFFF' : V3Theme.tx2(this.mode))
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .borderRadius(18)
      .backgroundColor(this.tab === idx ? V3Theme.accentFallback(this.mode) : V3Theme.glass2(this.mode))
      .border({ width: 1, color: this.tab === idx ? Color.Transparent : V3Theme.glassBorder(this.mode) })
      .onClick(() => {
        this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
          this.tab = idx
          if (idx === 1) {
            this.loadHistory()
          }
        })
      })
  }

  // ============ 下载中 ============
  @Builder
  QueueRow(p: DownloadProgress) {
    Row({ space: 12 }) {
      Image(cover(p.song?.album?.cover ?? '', 100))
        .width(46)
        .height(46)
        .borderRadius(10)
        .objectFit(ImageFit.Cover)
      Column({ space: 6 }) {
        Text(p.song.name ?? '')
          .fontSize(15)
          .fontColor(V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        // 进度条
        Stack({ alignContent: Alignment.Start }) {
          Row().width('100%').height(4).borderRadius(2).backgroundColor(V3Theme.track(this.mode))
          Row().width(`${Math.round(p.progress)}%`).height(4).borderRadius(2)
            .linearGradient({ angle: 90, colors: [[V3Theme.accentGradStart(this.mode), 0.0], [V3Theme.accentGradEnd(this.mode), 1.0]] })
        }
        .width('100%')
        Text(this.statusText(p))
          .fontSize(11.5)
          .fontColor(V3Theme.tx3(this.mode))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      // 暂停 / 继续
      SymbolGlyph(p.status === 'paused' ? $r('sys.symbol.play_fill') : $r('sys.symbol.pause_fill'))
        .fontSize(18)
        .fontColor([V3Theme.tx2(this.mode)])
        .padding(8)
        .onClick(() => {
          if (p.status === 'paused') {
            SongDownloadManager.resumeTask(p.song.id)
          } else {
            SongDownloadManager.pauseTask(p.song.id)
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 12, top: 10, bottom: 10 })
  }

  @Builder
  DownloadingView() {
    if (this.queueItems().length > 0) {
      Column() {
        // 全部控制
        Row({ space: 10 }) {
          Blank()
          Text('全部继续')
            .fontSize(13)
            .fontColor(V3Theme.tx2(this.mode))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(15)
            .backgroundColor(V3Theme.glass2(this.mode))
            .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
            .onClick(() => {
              SongDownloadManager.resumeAllTasks()
            })
          Text('全部暂停')
            .fontSize(13)
            .fontColor(V3Theme.tx2(this.mode))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(15)
            .backgroundColor(V3Theme.glass2(this.mode))
            .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
            .onClick(() => {
              SongDownloadManager.pauseAllTasks()
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 6 })

        List() {
          ForEach(this.queueItems(), (p: DownloadProgress) => {
            ListItem() {
              this.QueueRow(p)
            }
          }, (p: DownloadProgress) => `${p.song.id}`)
          ListItem() {
            Row().height(this.bottomRect + 24)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .layoutWeight(1)
    } else {
      this.Empty('没有正在下载的歌曲')
    }
  }

  // ============ 下载历史 ============
  @Builder
  HistoryRow(item: SongDownloadItem, index: number) {
    Row({ space: 12 }) {
      Image(cover(item.song?.album?.cover ?? '', 100))
        .width(46)
        .height(46)
        .borderRadius(10)
        .objectFit(ImageFit.Cover)
      Column({ space: 3 }) {
        Text(item.song.name ?? '')
          .fontSize(15)
          .fontColor(this.playingSong?.id === item.song.id ? V3Theme.accentFallback(this.mode) : V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 8 }) {
          Text(this.artistNames(item.song))
            .fontSize(12)
            .fontColor(V3Theme.tx3(this.mode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.fmtSize(item.size).length > 0) {
            Text(this.fmtSize(item.size))
              .fontSize(11)
              .fontColor(V3Theme.tx3(this.mode))
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(17)
        .fontColor([V3Theme.tx3(this.mode)])
        .padding(8)
        .onClick(() => {
          SongDownloadManager.removeSong(item.song.id.toString()).then((ok: boolean) => {
            if (ok) {
              ToastUtil.showShort('已删除下载')
              this.loadHistory()
            }
          })
        })
    }
    .width('100%')
    .padding({ left: 16, right: 8, top: 8, bottom: 8 })
    .onClick(() => {
      this.playHistory(item)
    })
  }

  @Builder
  HistoryView() {
    if (this.history.length > 0) {
      Column() {
        Row() {
          Blank()
          Text('清空历史')
            .fontSize(13)
            .fontColor(V3Theme.tx2(this.mode))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(15)
            .backgroundColor(V3Theme.glass2(this.mode))
            .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
            .onClick(() => {
              SongDownloadManager.clearCompleted()
              this.loadHistory()
              ToastUtil.showShort('已清空下载历史')
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 6 })

        List() {
          ForEach(this.history, (item: SongDownloadItem, index: number) => {
            ListItem() {
              this.HistoryRow(item, index)
            }
          }, (item: SongDownloadItem, index: number) => `${item.song.id}-${index}`)
          ListItem() {
            Row().height(this.bottomRect + 24)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .cachedCount(12)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .layoutWeight(1)
    } else {
      this.Empty('还没有下载的歌曲')
    }
  }

  @Builder
  Empty(text: string) {
    Column() {
      Text(text)
        .fontSize(15)
        .fontColor(V3Theme.tx2(this.mode))
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    NavDestination() {
      Stack() {
        AmbientBackground({
          coverUrl: this.playingSong?.album?.cover ?? '',
          mode: this.mode,
          blurRadius: 72,
          brightnessVal: 0.5,
          saturateVal: 0.42,
          showGlow: false,
          dim: 0.32
        })

        Column({ space: 14 }) {
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(22)
              .fontColor([V3Theme.tx1(this.mode)])
              .padding(6)
              .onClick(() => {
                this.pageStack.pop()
              })
            Text('本地下载')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(V3Theme.tx1(this.mode))
              .margin({ left: 8 })
            Blank()
          }
          .width('100%')
          .padding({ left: 12, right: 16 })

          this.Tabs()

          Column() {
            if (this.tab === 0) {
              this.DownloadingView()
            } else {
              this.HistoryView()
            }
          }
          .layoutWeight(1)
          .width('100%')
          .constraintSize({ maxWidth: this.isWide() ? 900 : '100%' })
        }
        .width('100%')
        .height('100%')
        .padding({ top: this.topRect + 8 })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(V3Color.CANVAS)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
