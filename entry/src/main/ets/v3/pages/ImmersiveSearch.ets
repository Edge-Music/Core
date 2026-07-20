/**
 * OMSP 3.0 · 搜索（全新玻璃风，复用底层 SourceAdapter.search / PlaylistManager / PushPathHelper）
 * 顶部玻璃搜索框 + 分类分段（歌曲/歌单/歌手/专辑）+ 结果玻璃行 + 搜索历史。
 * 歌曲点即播；歌单/歌手/专辑跳详情（复用 Playlist 路由，加载 current_playlist_*）。
 */
import { SourceAdapter } from '../../adapter'
import { PlaylistManager } from '../../util/PlaylistManager'
import { PushPathHelper } from '../../util/PushPathHelper'
import { PreferencesCache } from '../../util/PreferenceCache'
import { cover } from '../../util/AdapterHelper'
import { Song, Playlist, Artist, Album, SearchResult, SourceConfig } from '../../type/Adapter'
import { AmbientBackground } from '../components/AmbientBackground'
import { V3SongActions } from '../util/V3SongActions'
import { ToastUtil } from '@pura/harmony-utils'
import { V3Color, V3Radius, V3Theme } from '../theme/Tokens'

interface SearchTab {
  key: string
  label: string
}

@Component
export struct ImmersiveSearch {
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('current_playing_song') playingSong: Song | null = null
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @StorageProp('user_data_source') sources: SourceConfig[] = []
  @StorageProp('aggregation_playlist') aggPlaylists: Playlist[] = []

  @State keywords: string = ''
  @State result: SearchResult | null = null
  @State loading: boolean = false
  @State activeTab: string = 'songs'
  @State history: string[] = []
  // 数据源筛选（空数组=全部）
  @State selectedSourceIds: string[] = []

  private tabs: SearchTab[] = [
    { key: 'songs', label: '歌曲' },
    { key: 'playlists', label: '歌单' },
    { key: 'artists', label: '歌手' },
    { key: 'albums', label: '专辑' }
  ]

  aboutToAppear(): void {
    this.loadHistory()
  }

  private isWide(): boolean {
    return this.widthBp >= WidthBreakpoint.WIDTH_LG
  }

  // ============ 搜索历史（PreferencesCache 持久化） ============
  private loadHistory(): void {
    const raw: string = PreferencesCache.getUserPreference('v3_search_history', '')
    if (raw) {
      try {
        this.history = JSON.parse(raw) as string[]
      } catch (e) {
        this.history = []
      }
    }
  }

  private saveHistory(kw: string): void {
    const k: string = kw.trim()
    if (!k) {
      return
    }
    const next: string[] = [k, ...this.history.filter((h) => h !== k)].slice(0, 12)
    this.history = next
    PreferencesCache.setUserPreference('v3_search_history', JSON.stringify(next))
  }

  private clearHistory(): void {
    this.history = []
    PreferencesCache.setUserPreference('v3_search_history', '')
  }

  // ============ 搜索 ============
  private async doSearch(kw: string): Promise<void> {
    const k: string = kw.trim()
    if (!k) {
      return
    }
    this.keywords = k
    this.loading = true
    this.saveHistory(k)
    try {
      this.result = await SourceAdapter.search(k)
    } catch (e) {
      ToastUtil.showShort('搜索失败')
      this.result = null
    }
    this.loading = false
  }

  private artistNames(song: Song): string {
    return song.artists?.map((a) => a.name).join(' / ') ?? ''
  }

  // 数据源筛选：空选=全部；否则按 source.id 命中
  private passSource(src?: SourceConfig): boolean {
    if (this.selectedSourceIds.length === 0) {
      return true
    }
    return src != null && this.selectedSourceIds.includes(`${src.id}`)
  }

  private toggleSource(id: string): void {
    if (this.selectedSourceIds.includes(id)) {
      this.selectedSourceIds = this.selectedSourceIds.filter((s) => s !== id)
    } else {
      this.selectedSourceIds = [...this.selectedSourceIds, id]
    }
  }

  private sourceName(src?: SourceConfig): string {
    return src?.name ?? ''
  }

  private filterSongs(list?: Song[]): Song[] {
    return (list ?? []).filter((s) => this.passSource(s.source))
  }

  private filterPlaylists(list?: Playlist[]): Playlist[] {
    return (list ?? []).filter((p) => this.passSource(p.source))
  }

  private filterArtists(list?: Artist[]): Artist[] {
    return (list ?? []).filter((a) => this.passSource(a.source))
  }

  private filterAlbums(list?: Album[]): Album[] {
    return (list ?? []).filter((a) => this.passSource(a.source))
  }

  private currentCount(): number {
    if (!this.result) {
      return 0
    }
    if (this.activeTab === 'songs') {
      return this.filterSongs(this.result.songs).length
    } else if (this.activeTab === 'playlists') {
      return this.filterPlaylists(this.result.playlists).length
    } else if (this.activeTab === 'artists') {
      return this.filterArtists(this.result.artists).length
    }
    return this.filterAlbums(this.result.albums).length
  }

  // 打开歌单/歌手/专辑详情（复用 Playlist 路由）
  private openPlaylist(pl: Playlist): void {
    PushPathHelper.pushPath(this.pageStack, 'ImmersivePlaylist', async () => {
      const detail = await SourceAdapter.getPlaylistDetail(pl)
      AppStorage.setOrCreate('current_playlist_data', detail)
      AppStorage.setOrCreate('current_playlist_songs', detail.songs)
    })
  }

  private openArtist(ar: Artist): void {
    PushPathHelper.pushPath(this.pageStack, 'ImmersivePlaylist', async () => {
      const detail = await SourceAdapter.getArtistDetail(ar)
      AppStorage.setOrCreate('current_playlist_data', detail)
      AppStorage.setOrCreate('current_playlist_songs', detail.songs)
    })
  }

  private openAlbum(al: Album): void {
    PushPathHelper.pushPath(this.pageStack, 'ImmersivePlaylist', async () => {
      const detail = await SourceAdapter.getAlbumDetail(al)
      AppStorage.setOrCreate('current_playlist_data', detail)
      AppStorage.setOrCreate('current_playlist_songs', detail.songs)
    })
  }

  // ============ 顶部搜索栏 ============
  @Builder
  SearchBar() {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(22)
        .fontColor([V3Theme.tx1(this.mode)])
        .padding(6)
        .onClick(() => {
          this.pageStack.pop()
        })

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(18)
          .fontColor([V3Theme.tx3(this.mode)])
        TextInput({ text: this.keywords, placeholder: '搜索歌曲、歌单、歌手' })
          .layoutWeight(1)
          .fontSize(15)
          .fontColor(V3Theme.tx1(this.mode))
          .placeholderColor(V3Theme.tx3(this.mode))
          .backgroundColor(Color.Transparent)
          .caretColor(V3Theme.accentFallback(this.mode))
          .enterKeyType(EnterKeyType.Search)
          .onChange((v: string) => {
            this.keywords = v
          })
          .onSubmit(() => {
            this.doSearch(this.keywords)
          })
        if (this.keywords.length > 0) {
          SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
            .fontSize(18)
            .fontColor([V3Theme.tx3(this.mode)])
            .onClick(() => {
              this.keywords = ''
              this.result = null
            })
        }
      }
      .layoutWeight(1)
      .height(44)
      .padding({ left: 14, right: 14 })
      .borderRadius(22)
      .backgroundColor(V3Theme.glass2(this.mode))
      .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    }
    .width('100%')
    .padding({ left: 12, right: 16 })
  }

  // ============ 数据源筛选（多源时才显示） ============
  @Builder
  SourceFilter() {
    Scroll() {
      Row({ space: 10 }) {
        // 全部
        Text('全部')
          .fontSize(13)
          .fontColor(this.selectedSourceIds.length === 0 ? '#FFFFFF' : V3Theme.tx2(this.mode))
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .borderRadius(16)
          .backgroundColor(this.selectedSourceIds.length === 0 ? V3Theme.accentFallback(this.mode) : V3Theme.glass2(this.mode))
          .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
          .onClick(() => {
            this.selectedSourceIds = []
          })
        ForEach(this.sources, (src: SourceConfig) => {
          Text(src.name)
            .fontSize(13)
            .fontColor(this.selectedSourceIds.includes(`${src.id}`) ? '#FFFFFF' : V3Theme.tx2(this.mode))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(16)
            .backgroundColor(this.selectedSourceIds.includes(`${src.id}`) ? V3Theme.accentFallback(this.mode) : V3Theme.glass2(this.mode))
            .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
            .onClick(() => {
              this.toggleSource(`${src.id}`)
            })
        }, (src: SourceConfig) => `${src.id}`)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  // 数据源来源小标记
  @Builder
  SourceTag(src?: SourceConfig) {
    if (this.sources.length > 1 && src != null) {
      Text(this.sourceName(src))
        .fontSize(10)
        .fontColor(V3Theme.tx3(this.mode))
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(6)
        .backgroundColor(V3Theme.glass2(this.mode))
        .margin({ left: 8 })
    }
  }

  // ============ 分段 ============
  @Builder
  Tabs() {
    Row({ space: 10 }) {
      ForEach(this.tabs, (t: SearchTab) => {
        Text(t.label)
          .fontSize(14)
          .fontWeight(this.activeTab === t.key ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.activeTab === t.key ? '#FFFFFF' : V3Theme.tx2(this.mode))
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(18)
          .backgroundColor(this.activeTab === t.key ? V3Theme.accentFallback(this.mode) : V3Theme.glass2(this.mode))
          .onClick(() => {
            this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => { this.activeTab = t.key })
          })
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  // ============ 历史 ============
  @Builder
  History() {
    Column() {
      Row() {
        Text('搜索历史')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
        Blank()
        SymbolGlyph($r('sys.symbol.ohos_trash'))
          .fontSize(17)
          .fontColor([V3Theme.tx3(this.mode)])
          .onClick(() => {
            this.clearHistory()
          })
      }
      .width('100%')
      .margin({ bottom: 14 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.history, (h: string) => {
          Text(h)
            .fontSize(13)
            .fontColor(V3Theme.tx2(this.mode))
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(16)
            .backgroundColor(V3Theme.glass2(this.mode))
            .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
            .margin({ right: 10, bottom: 10 })
            .onClick(() => {
              this.doSearch(h)
            })
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 24 })
  }

  // ============ 结果行 ============
  @Builder
  SongRow(song: Song) {
    Row({ space: 12 }) {
      Image(cover(song?.album?.cover ?? '', 200))
        .width(48)
        .height(48)
        .borderRadius(10)
        .objectFit(ImageFit.Cover)
      Column() {
        Text(song.name ?? '')
          .fontSize(15)
          .fontColor(this.playingSong?.id === song.id ? V3Theme.accentFallback(this.mode) : V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row() {
          Text(this.artistNames(song))
            .fontSize(12)
            .fontColor(V3Theme.tx3(this.mode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          this.SourceTag(song.source)
        }
        .width('100%')
        .margin({ top: 3 })
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
    .padding({ left: 20, right: 16, top: 8, bottom: 8 })
    .onClick(() => {
      PlaylistManager.playSong(song)
    })
  }

  @Builder
  CoverRow(title: string, subtitle: string, coverUrl: string | Resource, round: boolean, src: SourceConfig | undefined, onTap: () => void) {
    Row({ space: 12 }) {
      Image(cover(coverUrl, 200))
        .width(48)
        .height(48)
        .borderRadius(round ? 24 : 10)
        .objectFit(ImageFit.Cover)
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor(V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row() {
          Text(subtitle)
            .fontSize(12)
            .fontColor(V3Theme.tx3(this.mode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          this.SourceTag(src)
        }
        .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([V3Theme.tx3(this.mode)])
    }
    .width('100%')
    .padding({ left: 20, right: 16, top: 8, bottom: 8 })
    .onClick(onTap)
  }

  @Builder
  Results() {
    List() {
      if (this.activeTab === 'songs') {
        ForEach(this.filterSongs(this.result?.songs), (song: Song) => {
          ListItem() {
            this.SongRow(song)
          }
        }, (song: Song, i: number) => `s-${song.id}-${i}`)
      } else if (this.activeTab === 'playlists') {
        ForEach(this.filterPlaylists(this.result?.playlists), (pl: Playlist) => {
          ListItem() {
            this.CoverRow(pl.name ?? '', `${pl.size ?? 0} 首`, pl.cover ?? '', false, pl.source, () => {
              this.openPlaylist(pl)
            })
          }
        }, (pl: Playlist, i: number) => `p-${pl.id}-${i}`)
      } else if (this.activeTab === 'artists') {
        ForEach(this.filterArtists(this.result?.artists), (ar: Artist) => {
          ListItem() {
            this.CoverRow(ar.name ?? '', '歌手', ar.avatar ?? '', true, ar.source, () => {
              this.openArtist(ar)
            })
          }
        }, (ar: Artist, i: number) => `a-${ar.id}-${i}`)
      } else {
        ForEach(this.filterAlbums(this.result?.albums), (al: Album) => {
          ListItem() {
            this.CoverRow(al.name ?? '', '专辑', al.cover ?? '', false, al.source, () => {
              this.openAlbum(al)
            })
          }
        }, (al: Album, i: number) => `al-${al.id}-${i}`)
      }
      ListItem() {
        Row().height(this.bottomRect + 20)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .cachedCount(10)
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
          this.SearchBar()
          this.Tabs()
          if (this.sources.length > 1) {
            this.SourceFilter()
          }

          if (this.loading) {
            Column() {
              LoadingProgress()
                .width(46)
                .height(46)
                .color(V3Theme.accentFallback(this.mode))
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
          } else if (this.result && this.currentCount() > 0) {
            this.Results()
          } else if (this.result) {
            Column() {
              Text('未找到相关结果')
                .fontSize(15)
                .fontColor(V3Theme.tx3(this.mode))
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
          } else if (this.history.length > 0) {
            this.History()
          } else {
            Column() {
              Text('搜索你想听的音乐')
                .fontSize(15)
                .fontColor(V3Theme.tx3(this.mode))
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
        .height('100%')
        .padding({ top: this.topRect + 12 })
        .constraintSize({ maxWidth: this.isWide() ? 900 : '100%' })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(V3Color.CANVAS)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
