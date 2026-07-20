/**
 * OMSP 3.0 · 歌单/专辑/歌手 详情（全新玻璃风，复用底层数据模型）
 * 数据：current_playlist_data(Playlist meta) + current_playlist_songs(Song[])。
 * 播放：PlaylistManager.loadPlaylist(可播歌, 起始歌)；点某首从该首起播。
 * 断点自适应：宽屏=左封面信息 + 右歌曲列表；窄屏=顶封面信息 + 下列表。
 */
import { Song, Playlist } from '../../type/Adapter'
import { PlaylistManager, PlayMode } from '../../util/PlaylistManager'
import { SongsDataSource } from '../../util/SongsDataSource'
import { SongDownloadManager } from '../../util/SongDownloadManager'
import { cover, playlistCover } from '../../util/AdapterHelper'
import { AmbientBackground } from '../components/AmbientBackground'
import { V3SongActions } from '../util/V3SongActions'
import { ToastUtil } from '@pura/harmony-utils'
import { V3Color, V3Radius, V3Theme } from '../theme/Tokens'

@Component
export struct ImmersivePlaylist {
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('current_playlist_data') playlist: Playlist | null = null
  @StorageLink('current_playlist_songs') songs: Song[] = []
  @StorageLink('current_playing_song') playingSong: Song | null = null
  @StorageProp('aggregation_playlist') aggPlaylists: Playlist[] = []
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @State private ds: SongsDataSource = new SongsDataSource()
  @State private keyword: string = ''
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.reloadList()
  }

  private reloadList(): void {
    this.ds.clearData()
    this.ds.pushMultiData(this.filtered())
  }

  // 歌单内搜索过滤（名称/艺术家/专辑）
  private filtered(): Song[] {
    const all: Song[] = this.songs ?? []
    const k: string = this.keyword.trim().toLowerCase()
    if (!k) {
      return all
    }
    return all.filter((s) =>
      (s.name ?? '').toLowerCase().includes(k)
      || (s.artists ?? []).some((a) => (a.name ?? '').toLowerCase().includes(k))
      || (s.album?.name ?? '').toLowerCase().includes(k))
  }

  private downloadAll(): void {
    const list: Song[] = this.playableSongs()
    if (list.length === 0) {
      ToastUtil.showShort('无可下载歌曲')
      return
    }
    SongDownloadManager.batchDownloadSongs(list)
    ToastUtil.showShort(`已加入下载队列 · ${list.length} 首`)
  }

  private playlistMenu(): MenuElement[] {
    return [
      {
        value: '下载全部',
        action: () => {
          this.downloadAll()
        }
      }
    ]
  }

  private isWide(): boolean {
    return this.widthBp >= WidthBreakpoint.WIDTH_LG
  }

  private playableSongs(): Song[] {
    return (this.songs ?? []).filter((s) => s && s.privilege?.playable && !s.id.toString().startsWith('promo_'))
  }

  private playAll(): void {
    const list: Song[] = this.playableSongs()
    if (list.length === 0) {
      ToastUtil.showShort('该歌单暂无可播放歌曲')
      return
    }
    PlaylistManager.switchPlayMode(PlayMode.LOOP)
    PlaylistManager.loadPlaylist(list, list[0])
  }

  private shuffle(): void {
    const list: Song[] = this.playableSongs()
    if (list.length === 0) {
      ToastUtil.showShort('该歌单暂无可播放歌曲')
      return
    }
    PlaylistManager.switchPlayMode(PlayMode.RANDOM)
    const start: Song = list[Math.floor(list.length / 2) % list.length]
    PlaylistManager.loadPlaylist(list, start)
  }

  private playFrom(song: Song): void {
    if (song.privilege?.playable === false) {
      ToastUtil.showShort('该歌曲不可播放')
      return
    }
    PlaylistManager.loadPlaylist(this.playableSongs(), song)
  }

  private artistNames(song: Song): string {
    return song.artists?.map((a) => a.name).join(' / ') ?? ''
  }

  private headCover(): string | Resource {
    return playlistCover(this.playlist ?? undefined, 500)
  }

  private subtitle(): string {
    const n: number = this.songs?.length ?? 0
    const creator: string = this.playlist?.creator?.name ?? ''
    return creator.length > 0 ? `${creator} · ${n} 首` : `${n} 首`
  }

  // ============ 头部（封面 + 信息 + 播放全部） ============
  @Builder
  Header() {
    Column({ space: 16 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(this.headCover())
          .width(this.isWide() ? 240 : 150)
          .height(this.isWide() ? 240 : 150)
          .borderRadius(V3Radius.CARD)
          .objectFit(ImageFit.Cover)
          .shadow({ radius: 60, color: 'rgba(0,0,0,0.5)', offsetX: 0, offsetY: 24 })
        Column()
          .width(this.isWide() ? 240 : 150)
          .height(this.isWide() ? 240 : 150)
          .borderRadius(V3Radius.CARD)
          .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
      }
      Column({ space: 6 }) {
        Text(this.playlist?.name ?? '歌单')
          .fontSize(this.isWide() ? 26 : 21)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(this.isWide() ? TextAlign.Start : TextAlign.Center)
        Text(this.subtitle())
          .fontSize(13)
          .fontColor(V3Theme.tx3(this.mode))
      }
      .width('100%')
      .alignItems(this.isWide() ? HorizontalAlign.Start : HorizontalAlign.Center)

      // 播放全部 + 随机
      Row({ space: 12 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.play_fill'))
            .fontSize(18)
            .fontColor([V3Theme.playIcon(this.mode)])
          Text('播放全部')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(V3Theme.playIcon(this.mode))
        }
        .layoutWeight(1)
        .height(46)
        .justifyContent(FlexAlign.Center)
        .borderRadius(23)
        .linearGradient({ angle: 160, colors: [[V3Theme.playGradStart(this.mode), 0.0], [V3Theme.playGradEnd(this.mode), 1.0]] })
        .onClick(() => {
          this.playAll()
        })
        Row() {
          SymbolGlyph($r('sys.symbol.shuffle'))
            .fontSize(19)
            .fontColor([V3Theme.tx1(this.mode)])
        }
        .width(46)
        .height(46)
        .justifyContent(FlexAlign.Center)
        .borderRadius(23)
        .backgroundColor(V3Theme.glass2(this.mode))
        .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
        .onClick(() => {
          this.shuffle()
        })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(this.isWide() ? HorizontalAlign.Start : HorizontalAlign.Center)
  }

  // ============ 歌曲行 ============
  @Builder
  SongRow(song: Song, index: number) {
    Row({ space: 12 }) {
      // 序号 / 正在播放
      Stack({ alignContent: Alignment.Center }) {
        if (this.playingSong?.id === song.id) {
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .fontSize(16)
            .fontColor([V3Theme.accentFallback(this.mode)])
        } else {
          Text(`${index + 1}`)
            .fontSize(13)
            .fontColor(V3Theme.tx3(this.mode))
        }
      }
      .width(26)

      Image(cover(song?.album?.cover ?? '', 100))
        .width(44)
        .height(44)
        .borderRadius(9)
        .objectFit(ImageFit.Cover)
        .opacity(song.privilege?.playable === false ? 0.4 : 1)

      Column({ space: 3 }) {
        Text(song.name ?? '')
          .fontSize(15)
          .fontColor(this.playingSong?.id === song.id
            ? V3Theme.accentFallback(this.mode)
            : (song.privilege?.playable === false ? V3Theme.tx3(this.mode) : V3Theme.tx1(this.mode)))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.artistNames(song))
          .fontSize(12)
          .fontColor(V3Theme.tx3(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.more'))
        .fontSize(18)
        .fontColor([V3Theme.tx3(this.mode)])
        .padding(8)
        .bindMenu(V3SongActions.menu(song, this.pageStack, this.aggPlaylists))
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .onClick(() => {
      this.playFrom(song)
    })
  }

  // 歌单内搜索框（常驻，跟随列表列宽，两侧留白）
  @Builder
  SearchBar() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(16)
        .fontColor([V3Theme.tx3(this.mode)])
      TextInput({ text: this.keyword, placeholder: '在歌单内搜索' })
        .layoutWeight(1)
        .fontSize(14)
        .fontColor(V3Theme.tx1(this.mode))
        .placeholderColor(V3Theme.tx3(this.mode))
        .backgroundColor(Color.Transparent)
        .caretColor(V3Theme.accentFallback(this.mode))
        .onChange((v: string) => {
          this.keyword = v
          this.reloadList()
        })
      if (this.keyword.length > 0) {
        SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
          .fontSize(16)
          .fontColor([V3Theme.tx3(this.mode)])
          .onClick(() => {
            this.keyword = ''
            this.reloadList()
          })
      }
    }
    .width('100%')
    .height(40)
    .margin({ bottom: 10 })
    .padding({ left: 14, right: 12 })
    .borderRadius(20)
    .backgroundColor(V3Theme.glass2(this.mode))
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
  }

  @Builder
  SongList() {
    List({ scroller: this.scroller }) {
      LazyForEach(this.ds, (song: Song, index: number) => {
        ListItem() {
          this.SongRow(song, index)
        }
      }, (song: Song, index: number) => `${song.id}-${index}`)
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

  build() {
    NavDestination() {
      Stack() {
        AmbientBackground({
          coverUrl: typeof this.headCover() === 'string' ? this.headCover() as string : (this.playingSong?.album?.cover ?? ''),
          mode: this.mode,
          blurRadius: 72,
          brightnessVal: 0.5,
          saturateVal: 0.42,
          showGlow: false,
          dim: 0.32
        })

        Column() {
          // 顶栏（返回 + 歌单菜单）
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(22)
              .fontColor([V3Theme.tx1(this.mode)])
              .padding(6)
              .onClick(() => {
                this.pageStack.pop()
              })
            Blank()
            SymbolGlyph($r('sys.symbol.more'))
              .fontSize(20)
              .fontColor([V3Theme.tx1(this.mode)])
              .padding(6)
              .bindMenu(this.playlistMenu())
          }
          .width('100%')
          .padding({ left: 12, right: 16 })

          if (this.isWide()) {
            // 宽屏：左封面信息 + 右（搜索框 + 列表）
            Row({ space: 32 }) {
              Column() {
                this.Header()
              }
              .width(320)
              .padding({ top: 10 })
              Column() {
                this.SearchBar()
                this.SongList()
              }
              .layoutWeight(1)
              .height('100%')
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 24, right: 24 })
            .alignItems(VerticalAlign.Top)
          } else {
            // 窄屏：顶封面信息 + 搜索框 + 下列表
            Column() {
              this.Header()
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 6, bottom: 12 })
            Column() {
              this.SearchBar()
              this.SongList()
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 12, right: 12 })
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
