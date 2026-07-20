/**
 * OMSP 3.0 · 听歌统计（全新玻璃风，功能对齐旧 view/Statistics.ets）
 * 两页签：播放历史（列表，可播/菜单）+ 统计数据（总览卡 + 时段统计柱 + 最喜欢歌手）。
 * 数据复用 playRecordManager：getAllRecords / getTimeSlotStats / getTopArtists / getTotalPlayCount / getRecordCount。
 */
import { Song, Playlist } from '../../type/Adapter'
import { PlaylistManager } from '../../util/PlaylistManager'
import { playRecordManager } from '../../util/PlayRecordManager'
import { PlayRecord } from '../../model/PlayRecord'
import { cover } from '../../util/AdapterHelper'
import { AmbientBackground } from '../components/AmbientBackground'
import { V3SongActions } from '../util/V3SongActions'
import { V3Color, V3Radius, V3Theme } from '../theme/Tokens'

interface SlotBar {
  label: string
  value: number
}

interface TopArtistItem {
  artistName: string
  playCount: number
}

@Component
export struct ImmersiveStatistics {
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('current_playing_song') playingSong: Song | null = null
  @StorageProp('aggregation_playlist') aggPlaylists: Playlist[] = []
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @State tab: number = 0 // 0=播放历史 1=统计数据
  @State records: PlayRecord[] = []
  @State totalPlay: number = 0
  @State recordCount: number = 0
  @State slots: SlotBar[] = []
  @State topArtists: TopArtistItem[] = []

  async aboutToAppear(): Promise<void> {
    // 关键：播放记录是异步从偏好加载的，必须先 initialize 再读，否则拿到空数据
    await playRecordManager.initialize()
    this.loadData()
  }

  private loadData(): void {
    this.records = playRecordManager.getAllRecords()
    this.totalPlay = playRecordManager.getTotalPlayCount()
    this.recordCount = playRecordManager.getRecordCount()
    const ts = playRecordManager.getTimeSlotStats()
    this.slots = [
      { label: '凌晨', value: ts.dawn },
      { label: '上午', value: ts.morning },
      { label: '下午', value: ts.afternoon },
      { label: '晚上', value: ts.evening }
    ]
    this.topArtists = playRecordManager.getTopArtists(5).map((a): TopArtistItem => {
      return { artistName: a.artistName, playCount: a.playCount }
    })
  }

  private isWide(): boolean {
    return this.widthBp >= WidthBreakpoint.WIDTH_LG
  }

  private artistNames(song: Song): string {
    return song.artists?.map((a) => a.name).join(' / ') ?? ''
  }

  private playRecord(rec: PlayRecord): void {
    PlaylistManager.loadPlaylist(this.records.map((r) => r.song), rec.song)
  }

  private slotMax(): number {
    let m: number = 1
    for (const s of this.slots) {
      if (s.value > m) {
        m = s.value
      }
    }
    return m
  }

  private artistMax(): number {
    let m: number = 1
    for (const a of this.topArtists) {
      if (a.playCount > m) {
        m = a.playCount
      }
    }
    return m
  }

  // ============ 页签 ============
  @Builder
  Tabs() {
    Row({ space: 10 }) {
      this.TabChip(0, '播放历史')
      this.TabChip(1, '统计数据')
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
        })
      })
  }

  // ============ 播放历史 ============
  @Builder
  HistoryRow(rec: PlayRecord, index: number) {
    Row({ space: 12 }) {
      Text(`${index + 1}`)
        .fontSize(13)
        .fontColor(V3Theme.tx3(this.mode))
        .width(24)
        .textAlign(TextAlign.Center)
      Image(cover(rec.song?.album?.cover ?? '', 100))
        .width(44)
        .height(44)
        .borderRadius(9)
        .objectFit(ImageFit.Cover)
      Column({ space: 3 }) {
        Text(rec.song.name ?? '')
          .fontSize(15)
          .fontColor(this.playingSong?.id === rec.song.id ? V3Theme.accentFallback(this.mode) : V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.artistNames(rec.song))
          .fontSize(12)
          .fontColor(V3Theme.tx3(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(`${rec.playCount} 次`)
        .fontSize(12)
        .fontColor(V3Theme.tx3(this.mode))
      SymbolGlyph($r('sys.symbol.more'))
        .fontSize(18)
        .fontColor([V3Theme.tx3(this.mode)])
        .padding(8)
        .bindMenu(V3SongActions.menu(rec.song, this.pageStack, this.aggPlaylists))
    }
    .width('100%')
    .padding({ left: 12, right: 8, top: 8, bottom: 8 })
    .onClick(() => {
      this.playRecord(rec)
    })
  }

  @Builder
  HistoryView() {
    if (this.records.length > 0) {
      List() {
        ForEach(this.records, (rec: PlayRecord, index: number) => {
          ListItem() {
            this.HistoryRow(rec, index)
          }
        }, (rec: PlayRecord, index: number) => `${rec.song.id}-${index}`)
        ListItem() {
          Row().height(this.bottomRect + 24)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .cachedCount(12)
      .edgeEffect(EdgeEffect.Spring)
    } else {
      this.Empty('还没有播放记录')
    }
  }

  // ============ 统计数据 ============
  @Builder
  StatCard(value: string, label: string) {
    Column({ space: 6 }) {
      Text(value)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(V3Theme.accentFallback(this.mode))
      Text(label)
        .fontSize(13)
        .fontColor(V3Theme.tx2(this.mode))
    }
    .layoutWeight(1)
    .padding({ top: 22, bottom: 22 })
    .borderRadius(20)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 16, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
  }

  @Builder
  SlotColumn(s: SlotBar) {
    Column({ space: 8 }) {
      Text(`${s.value}`)
        .fontSize(11)
        .fontColor(V3Theme.tx3(this.mode))
      // 柱子（按最大值归一化，最高 120）
      Column()
        .width(28)
        .height(Math.max(6, (s.value / this.slotMax()) * 120))
        .borderRadius(8)
        .linearGradient({ angle: 180, colors: [[V3Theme.accentGradStart(this.mode), 0.0], [V3Theme.accentGradEnd(this.mode), 1.0]] })
      Text(s.label)
        .fontSize(12)
        .fontColor(V3Theme.tx2(this.mode))
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ArtistRow(a: TopArtistItem, index: number) {
    Row({ space: 12 }) {
      Text(`${index + 1}`)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(index < 3 ? V3Theme.accentFallback(this.mode) : V3Theme.tx3(this.mode))
        .width(26)
        .textAlign(TextAlign.Center)
      Text(a.artistName)
        .fontSize(15)
        .fontColor(V3Theme.tx1(this.mode))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      // 进度条
      Stack({ alignContent: Alignment.Start }) {
        Row().width(120).height(6).borderRadius(3).backgroundColor(V3Theme.track(this.mode))
        Row().width(120 * (a.playCount / this.artistMax())).height(6).borderRadius(3)
          .linearGradient({ angle: 90, colors: [[V3Theme.accentGradStart(this.mode), 0.0], [V3Theme.accentGradEnd(this.mode), 1.0]] })
      }
      Text(`${a.playCount}`)
        .fontSize(13)
        .fontColor(V3Theme.tx3(this.mode))
        .width(40)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  StatsView() {
    Scroll() {
      Column({ space: 20 }) {
        // 总览卡
        Row({ space: 14 }) {
          this.StatCard(`${this.totalPlay}`, '总播放次数')
          this.StatCard(`${this.recordCount}`, '播放歌曲数')
        }
        .width('100%')

        // 时段统计
        Column({ space: 14 }) {
          Text('时段统计')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(V3Theme.tx1(this.mode))
            .width('100%')
          if (this.totalPlay > 0) {
            Row() {
              ForEach(this.slots, (s: SlotBar) => {
                this.SlotColumn(s)
              }, (s: SlotBar) => s.label)
            }
            .width('100%')
            .height(170)
            .alignItems(VerticalAlign.Bottom)
          } else {
            Text('暂无统计数据')
              .fontSize(13)
              .fontColor(V3Theme.tx3(this.mode))
              .padding({ top: 20, bottom: 20 })
          }
        }
        .width('100%')
        .padding(18)
        .borderRadius(20)
        .backgroundColor(V3Theme.glass1(this.mode))
        .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
        .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
        .shadow({ radius: 16, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })

        // 最喜欢的歌手
        Column({ space: 4 }) {
          Text('最喜欢的歌手')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(V3Theme.tx1(this.mode))
            .width('100%')
            .margin({ bottom: 6 })
          if (this.topArtists.length > 0) {
            ForEach(this.topArtists, (a: TopArtistItem, index: number) => {
              this.ArtistRow(a, index)
            }, (a: TopArtistItem, index: number) => `${a.artistName}-${index}`)
          } else {
            Text('暂无数据')
              .fontSize(13)
              .fontColor(V3Theme.tx3(this.mode))
              .padding({ top: 12, bottom: 12 })
          }
        }
        .width('100%')
        .padding(18)
        .borderRadius(20)
        .backgroundColor(V3Theme.glass1(this.mode))
        .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
        .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
        .shadow({ radius: 16, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })

        Row().height(this.bottomRect + 24)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
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
          // 顶栏
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(22)
              .fontColor([V3Theme.tx1(this.mode)])
              .padding(6)
              .onClick(() => {
                this.pageStack.pop()
              })
            Text('听歌统计')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(V3Theme.tx1(this.mode))
              .margin({ left: 8 })
            Blank()
          }
          .width('100%')
          .padding({ left: 12, right: 16 })

          this.Tabs()

          if (this.tab === 0) {
            Column() {
              this.HistoryView()
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 8, right: 8 })
            .constraintSize({ maxWidth: this.isWide() ? 900 : '100%' })
          } else {
            this.StatsView()
          }
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
