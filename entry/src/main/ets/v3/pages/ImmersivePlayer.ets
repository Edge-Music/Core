/**
 * OMSP 3.0 · 首页 / 沉浸播放页（对齐设计规范 §4 + W1 宽屏）
 * 断点自适应：
 *  - 窄屏（手机）：沉浸大封面 + 歌名歌手 + 可点歌词行 + 悬浮播控。
 *  - 宽屏（平板/折叠展开）：常驻玻璃侧栏（模式+榜单+我的）+ 居中卡片流 + 收窄播控。
 * 接真实当前播放歌曲。
 */
import { Song, Playlist, SourceConfig } from '../../type/Adapter'
import { cover, playlistCover } from '../../util/AdapterHelper'
import { PlaylistManager } from '../../util/PlaylistManager'
import { PushPathHelper } from '../../util/PushPathHelper'
import { PreferencesCache } from '../../util/PreferenceCache'
import { SourceAdapter } from '../../adapter'
import { PlaylistCover } from '../components/PlaylistCover'
import { V3Recommend, RecMode } from '../recommend/V3Recommend'
import { LyricsLine } from '../../util/LyricsManager'
import { ToastUtil } from '@pura/harmony-utils'
import { AmbientBackground } from '../components/AmbientBackground'
import { PlayerBar } from '../components/PlayerBar'
import { QueueSheet } from '../components/QueueSheet'
import { EffectsSheet } from '../components/EffectsSheet'
import { TimerSheet } from '../components/TimerSheet'
import { ImmersiveMy } from './ImmersiveMy'
import { V3Ambient } from '../util/V3Ambient'
import { V3Color, V3Radius, V3Space, V3Theme } from '../theme/Tokens'

@Component
export struct ImmersivePlayer {
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('current_playing_song') @Watch('onSongChange') song: Song | null = null
  @StorageProp('current_playing_playlist') queue: Song[] = []
  @StorageProp('user_data_source') sources: SourceConfig[] = []
  @StorageProp('index_recommend_toplist') topList: Playlist[] = []
  @StorageProp('user_playlist') userPlaylists: Playlist[] = []
  @StorageProp('current_parsed_lyrics') parsedLyrics: LyricsLine[] = []
  @StorageProp('current_lyrics_index') lyricIndex: number = 0
  @StorageProp('v3_ambient_glow') glow: string = V3Color.ACCENT_GLOW
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('winHeight') winHeight: number = 0
  @StorageProp('winWidth') winWidth: number = 0
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @State fav: boolean = false
  // 官方 SideBarContainer 的显隐（宽屏默认常驻展开，窄屏默认收起为抽屉）
  @State showSidebar: boolean = false
  @State sideTab: string = 'chart' // 侧边栏内容页：'chart' 榜单 / 'playlist' 我的歌单
  @State plFilterSource: string = '' // 歌单数据源过滤（空=全部，否则数据源 url）
  // 统一弹层控制：鸿蒙同节点多个 bindSheet 会互相冲突（只有一个能打开），
  // 故用「单 bindSheet + flag」——sheetShow 控制显隐，activeSheet 决定内容/尺寸。
  @State sheetShow: boolean = false
  @State activeSheet: string = '' // 'my' | 'queue' | 'timer' | 'effects'
  // 卡片流邻居封面（用 @State 保证切歌时两侧刷新——放方法里读 this.song 不会触发重渲染）
  @State prevCover: string = ''
  @State nextCover: string = ''
  // 横滑切歌动画
  @State cardDx: number = 0
  @State cardOpacity: number = 1
  // 当前推荐模式
  @State recMode: RecMode = 'default'
  // 后台续算中标志（避免重复触发）
  private toppingUp: boolean = false

  private modeLabel(mode: RecMode): string {
    return mode === 'fresh' ? '新鲜' : (mode === 'familiar' ? '熟悉' : '默认')
  }

  // 选推荐模式 → 优先用后台预取缓存**秒切**；无缓存再本地即时 + 异步扩池
  private selectMode(mode: RecMode): void {
    this.recMode = mode
    AppStorage.setOrCreate('v3_rec_mode', mode)
    const seenIds: Set<string> = new Set()
    // ① 立即起播：缓存命中优先，否则本地即时生成（radio 队列，允许自动补充）
    const cached: Song[] = V3Recommend.getCached(mode)
    const seed: Song[] = cached.length > 0 ? cached : V3Recommend.generate(mode)
    if (seed.length > 0) {
      PlaylistManager.loadPlaylist(seed, undefined, true)
      PlaylistManager.playSong(seed[0])
      for (const s of seed) {
        seenIds.add(s.id.toString())
      }
      ToastUtil.showShort(`「${this.modeLabel(mode)}模式」· 续算补充中`)
    } else {
      ToastUtil.showShort(`正在生成「${this.modeLabel(mode)}模式」推荐...`)
    }
    // ② 流式补充：各接口独立请求，哪个先返回先压入队列（不等 allSettled）
    V3Recommend.streamRecommend(mode, seenIds, (batch: Song[]) => {
      if (!this.song) {
        PlaylistManager.loadPlaylist(batch, undefined, true)
        PlaylistManager.playSong(batch[0])
      } else {
        PlaylistManager.appendSongs(batch)
      }
    })
    // ③ 后台刷新该模式缓存，供下次秒切
    V3Recommend.generateAsync(mode).then((fresh: Song[]) => {
      if (fresh.length > 0) {
        AppStorage.setOrCreate(`v3_rec_${mode}`, fresh)
      }
    })
  }

  // 点榜单 → 打开榜单详情页（可查看歌曲再决定播放/播放全部）
  private playChart(pl: Playlist): void {
    PushPathHelper.pushPath(this.pageStack, 'ImmersivePlaylist', async () => {
      const detail: Playlist = await SourceAdapter.getPlaylistDetail(pl)
      AppStorage.setOrCreate('current_playlist_data', detail)
      AppStorage.setOrCreate('current_playlist_songs', detail.songs)
    })
  }

  aboutToAppear(): void {
    V3Ambient.loadThemeOverride()
    V3Ambient.updateFromCover(this.song?.album?.cover)
    this.fav = this.song?.meta?.isFavorite ?? false
    this.showSidebar = this.isWide()
    this.refreshNeighbors()
    // 后台预取三模式推荐（含榜单/推荐歌单混入），供点击秒切；容错不阻塞 UI
    V3Recommend.prefetchAll().catch(() => {})
  }

  onSongChange(): void {
    V3Ambient.updateFromCover(this.song?.album?.cover)
    this.fav = this.song?.meta?.isFavorite ?? false
    this.refreshNeighbors()
    this.maybeTopUp()
  }

  // 红心收藏：真实同步到数据源（网易云等），乐观更新 + 失败回滚
  private toggleFav(): void {
    const s: Song | null = this.song
    if (!s) {
      return
    }
    if (!s.source) {
      ToastUtil.showShort('无法收藏：该歌曲缺少数据源')
      return
    }
    const next: boolean = !this.fav
    this.fav = next // 乐观更新
    SourceAdapter.likeSong(s, next).then((ok: boolean) => {
      if (!ok) {
        this.fav = !next // 回滚
        ToastUtil.showShort('操作失败，请稍后重试')
        return
      }
      if (s.meta) {
        s.meta.isFavorite = next
      }
      ToastUtil.showShort(next ? '已收藏到「我喜欢的音乐」' : '已取消收藏')
    }).catch(() => {
      this.fav = !next // 回滚
      ToastUtil.showShort('操作失败，请稍后重试')
    })
  }

  // 队列将播完（剩余 < 5 首）时，后台多源续算补充，无缝续播
  private maybeTopUp(): void {
    // 用户可在设置关闭「歌单自动补充」（默认开启，保持无缝续播）
    if (PreferencesCache.getUserPreference('v3_auto_topup', '1') !== '1') {
      return
    }
    // 仅「电台/推荐」来源的队列才自动补充：歌单/专辑/历史等有界队列，
    // 以及用户手动「下一首/加入队列」后降级的队列，都播完即止，绝不越俎压入
    if (!(AppStorage.get<boolean>('v3_queue_radio') ?? false)) {
      return
    }
    if (this.toppingUp || !this.song || !this.queue || this.queue.length === 0) {
      return
    }
    const idx: number = this.queue.findIndex((s) => s.id === this.song!.id)
    if (idx < 0 || this.queue.length - idx - 1 >= 5) {
      return
    }
    this.toppingUp = true
    V3Recommend.topUp(this.recMode, 20).then((songs: Song[]) => {
      if (songs.length > 0) {
        PlaylistManager.insertSongs(songs)
      }
      this.toppingUp = false
    }).catch(() => {
      this.toppingUp = false
    })
  }

  private refreshNeighbors(): void {
    this.prevCover = this.neighborCover(-1)
    this.nextCover = this.neighborCover(1)
  }

  /** 横滑切歌：卡片滑出→切歌→从另一侧滑入 */
  private animateSwitch(dir: 'next' | 'prev'): void {
    const w: number = 420
    this.getUIContext().animateTo({
      duration: 180,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.changeSong(dir)
        this.cardDx = dir === 'next' ? w : -w
        this.cardOpacity = 0
        this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
          this.cardDx = 0
          this.cardOpacity = 1
        })
      }
    }, () => {
      this.cardDx = dir === 'next' ? -w : w
      this.cardOpacity = 0
    })
  }

  /** 手机封面上限高度，保证信息区+播控完整可见 */
  private coverMaxHeight(): number {
    const avail: number = this.winHeight - this.topRect - this.bottomRect
    const h: number = avail * 0.42
    return h > 0 ? h : 320
  }

  private isWide(): boolean {
    return this.widthBp >= WidthBreakpoint.WIDTH_LG
  }

  private artistNames(): string {
    return this.song?.artists?.map((a) => a.name).join(' / ') ?? '未知艺术家'
  }

  // 真实音质标签：优先当前歌曲实际码率 meta.bitrate，其次最高可播码率
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

  // 数据源名称标签
  private sourceLabel(): string {
    return this.song?.source?.name ?? ''
  }

  // 封面右下角标签（数据源 + 音质），玻璃胶囊
  @Builder
  CoverBadge() {
    Row({ space: 6 }) {
      if (this.sourceLabel().length > 0) {
        Text(this.sourceLabel())
          .fontSize(11)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 120 })
      }
      if (this.sourceLabel().length > 0 && this.qualityLabel().length > 0) {
        Row().width(3).height(3).borderRadius(2).backgroundColor('rgba(255,255,255,0.55)')
      }
      if (this.qualityLabel().length > 0) {
        Text(this.qualityLabel())
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFE7BE')
      }
    }
    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
    .borderRadius(11)
    .backgroundColor('rgba(20,16,10,0.42)')
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN, { colorMode: ThemeColorMode.DARK })
    .border({ width: 1, color: 'rgba(255,255,255,0.14)' })
    .margin({ right: 12, bottom: 12 })
  }

  private lyricAt(offset: number): string {
    const i: number = this.lyricIndex + offset
    if (this.parsedLyrics && i >= 0 && i < this.parsedLyrics.length) {
      return this.parsedLyrics[i].text ?? ''
    }
    return ''
  }

  private hasLyrics(): boolean {
    return this.parsedLyrics !== undefined && this.parsedLyrics.length > 0
  }

  private currentLyric(): string {
    const t: string = this.lyricAt(0)
    return t.length > 0 ? t : (this.hasLyrics() ? '' : '')
  }

  private openLyrics(): void {
    this.pageStack.pushPath({ name: 'ImmersiveLyrics' }, { animated: true })
  }

  // 统一弹层入口
  private openSheet(name: string): void {
    this.activeSheet = name
    this.sheetShow = true
  }

  private changeSong(dir: 'next' | 'prev'): void {
    const s: Song | null = dir === 'next' ? PlaylistManager.playNext() : PlaylistManager.playPrevious()
    if (s) {
      PlaylistManager.playSong(s)
    }
  }

  /** 取播放队列中相对当前的邻居封面（用于卡片流预览） */
  private neighborCover(offset: number): string {
    if (!this.queue || this.queue.length === 0 || !this.song) {
      return ''
    }
    const idx: number = this.queue.findIndex((s) => s.id === this.song!.id)
    if (idx < 0) {
      return ''
    }
    const n: number = this.queue.length
    const target: number = ((idx + offset) % n + n) % n
    return this.queue[target].album?.cover ?? ''
  }

  // ========== 顶部：数据源头像（窄屏；菜单拉手由官方 SideBarContainer 控制按钮承担） ==========
  @Builder
  TopBar() {
    Row() {
      Blank()
      this.SourceAvatar(44)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  private firstSourceAvatar(): string {
    if (this.sources && this.sources.length > 0) {
      return this.sources[0].auth?.user?.avatar ?? ''
    }
    return ''
  }

  @Builder
  SourceAvatar(size: number) {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.firstSourceAvatar().length > 0) {
        Image(cover(this.firstSourceAvatar(), 100))
          .width(size)
          .height(size)
          .borderRadius(size / 2)
          .objectFit(ImageFit.Cover)
          .border({ width: 1.5, color: 'rgba(255,255,255,0.5)' })
      } else {
        Column()
          .width(size)
          .height(size)
          .borderRadius(size / 2)
          .linearGradient({ angle: 150, colors: [['#D3A860', 0.0], ['#B98747', 1.0]] })
          .border({ width: 1.5, color: 'rgba(255,255,255,0.5)' })
      }
      Row()
        .width(size * 0.25)
        .height(size * 0.25)
        .borderRadius(size * 0.125)
        .backgroundColor(V3Color.ONLINE_DOT)
        .border({ width: 2.5, color: '#131009' })
    }
    .onClick(() => {
      this.openSheet('my')
    })
  }

  // ========== 窄屏（手机）布局 ==========
  @Builder
  PhoneLayout() {
    Column() {
      this.TopBar()

      // 弹性中部：封面（按可用高度定尺，绝不挤压底部播控）+ 信息 + 歌词
      Column() {
        // 沉浸大封面（高度受限 + 横滑动画）
        Stack({ alignContent: Alignment.BottomEnd }) {
          Image(cover(this.song?.album?.cover ?? '', 500))
            .width('100%')
            .height('100%')
            .borderRadius(V3Radius.CARD)
            .objectFit(ImageFit.Cover)
            .shadow({ radius: 60, color: 'rgba(0,0,0,0.6)', offsetX: 0, offsetY: 30 })
          Column()
            .width('100%')
            .height('100%')
            .borderRadius(V3Radius.CARD)
            .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
          this.CoverBadge()
        }
        .height(this.coverMaxHeight())
        .aspectRatio(1)
        .translate({ x: this.cardDx })
        .opacity(this.cardOpacity)

        // 歌名 + 歌手 + 收藏
        Row() {
          Column() {
            Text(this.song?.name ?? '暂无播放')
              .fontSize(26)
              .fontWeight(FontWeight.Medium)
              .fontColor(V3Theme.tx1(this.mode))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.artistNames())
              .fontSize(15)
              .fontColor(V3Theme.tx2(this.mode))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .margin({ top: 9 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          SymbolGlyph(this.fav ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(26)
            .fontColor([this.fav ? V3Theme.accentFallback(this.mode) : V3Theme.tx2(this.mode)])
            .onClick(() => {
              this.toggleFav()
            })
        }
        .width('100%')
        .padding({ left: 30, right: 30 })
        .margin({ top: 26 })
        .alignItems(VerticalAlign.Bottom)

        // 可点歌词行（当前句发光 + 加粗）
        if (this.hasLyrics()) {
          Column({ space: 7 }) {
            Text(this.lyricAt(-1))
              .fontSize(13.5)
              .fontWeight(FontWeight.Regular)
              .fontColor(V3Theme.tx2(this.mode))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.lyricAt(0))
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(V3Theme.tx1(this.mode))
              .textShadow({ radius: 20, color: this.glow, offsetX: 0, offsetY: 0 })
              .width('100%')
              .textAlign(TextAlign.Center)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.lyricAt(1))
              .fontSize(13.5)
              .fontWeight(FontWeight.Regular)
              .fontColor(V3Theme.tx2(this.mode))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(96)
          .padding({ left: 30, right: 30 })
          .margin({ top: 18 })
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .clip(true)
          .onClick(() => {
            this.openLyrics()
          })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)

      PlayerBar({ onList: () => { this.openSheet('queue') }, onEffects: () => { this.openSheet('effects') }, onTimer: () => { this.openSheet('timer') } })
        .width('100%')
        .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topRect + V3Space.S, bottom: this.bottomRect + 20 })
  }

  // ========== 宽屏 W1 布局 ==========
  @Builder
  ModeSwitcher() {
    Row() {
      this.ModeChip('fresh', '新鲜')
      this.ModeChip('familiar', '熟悉')
      this.ModeChip('default', '默认')
    }
    .width('100%')
    .padding(4)
    .borderRadius(15)
    .backgroundColor(V3Theme.glass1(this.mode))
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
  }

  @Builder
  ModeChip(key: RecMode, label: string) {
    Text(label)
      .fontSize(12.5)
      .fontWeight(this.recMode === key ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.recMode === key ? V3Theme.accentFallback(this.mode) : V3Theme.tx2(this.mode))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(34)
      .borderRadius(12)
      .backgroundColor(this.recMode === key
        ? (V3Theme.isLight(this.mode) ? '#FFFFFF' : 'rgba(255,255,255,0.14)')
        : 'rgba(0,0,0,0)')
      .border({ width: 1, color: this.recMode === key ? 'rgba(201,154,87,0.55)' : 'rgba(0,0,0,0)' })
      .onClick(() => {
        this.selectMode(key)
      })
  }

  @Builder
  ChartItem(pl: Playlist) {
    Row({ space: 12 }) {
      PlaylistCover({ pl: pl, coverSize: 100, sizeW: 42, radius: 11 })
      Column() {
        Text(pl.name ?? '')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(pl.size ? `${pl.size} 首` : '榜单更新')
          .fontSize(11.5)
          .fontColor(V3Theme.tx2(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 11, right: 11, top: 9, bottom: 9 })
    .borderRadius(15)
    .backgroundColor(V3Theme.glass1(this.mode))
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .onClick(() => {
      this.playChart(pl)
    })
  }

  // 侧边栏内容页签（榜单 / 我的歌单）
  @Builder
  SideTab(key: string, label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.sideTab === key ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.sideTab === key ? V3Theme.accentFallback(this.mode) : V3Theme.tx2(this.mode))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(32)
      .borderRadius(11)
      .backgroundColor(this.sideTab === key
        ? (V3Theme.isLight(this.mode) ? '#FFFFFF' : 'rgba(255,255,255,0.14)')
        : 'rgba(0,0,0,0)')
      .border({ width: 1, color: this.sideTab === key ? 'rgba(201,154,87,0.55)' : 'rgba(0,0,0,0)' })
      .onClick(() => {
        this.sideTab = key
      })
  }

  // 数据源过滤 chip
  @Builder
  SrcChip(url: string, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.plFilterSource === url ? '#FFFFFF' : V3Theme.tx2(this.mode))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(13)
      .backgroundColor(this.plFilterSource === url ? '#C99A57' : V3Theme.glass2(this.mode))
      .border({ width: 1, color: this.plFilterSource === url ? Color.Transparent : V3Theme.glassBorder(this.mode) })
      .maxLines(1)
      .onClick(() => {
        this.plFilterSource = url
      })
  }

  // 侧边栏歌单行（点击进详情）
  @Builder
  SidePlaylistItem(pl: Playlist) {
    Row({ space: 12 }) {
      PlaylistCover({ pl: pl, coverSize: 100, sizeW: 42, radius: 11 })
      Column() {
        Text(pl.name ?? '')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(pl.source?.name ?? '')
          .fontSize(11.5)
          .fontColor(V3Theme.tx3(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 11, right: 11, top: 9, bottom: 9 })
    .borderRadius(15)
    .backgroundColor(V3Theme.glass1(this.mode))
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .onClick(() => {
      this.openSidePlaylist(pl)
    })
  }

  @Builder
  WideSidebar() {
    Column({ space: 18 }) {
      // 搜索入口
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(18)
          .fontColor([V3Theme.tx3(this.mode)])
        Text('搜索歌曲、歌单、歌手')
          .fontSize(14)
          .fontColor(V3Theme.tx3(this.mode))
          .layoutWeight(1)
      }
      .width('100%')
      .height(44)
      .padding({ left: 14, right: 14 })
      .borderRadius(22)
      .backgroundColor(V3Theme.glass2(this.mode))
      .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
      .onClick(() => {
        this.pageStack.pushPath({ name: 'ImmersiveSearch' }, { animated: true })
      })

      Text('推荐模式')
        .fontSize(12)
        .fontColor(V3Theme.tx3(this.mode))
        .width('100%')
      this.ModeSwitcher()

      // 榜单 / 我的歌单 页签
      Row({ space: 8 }) {
        this.SideTab('chart', '榜单')
        this.SideTab('playlist', '我的歌单')
      }
      .width('100%')
      .padding(4)
      .borderRadius(13)
      .backgroundColor(V3Theme.glass1(this.mode))
      .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
      .margin({ top: 2 })

      // 数据源过滤（仅「我的歌单」且多源时显示）
      if (this.sideTab === 'playlist' && this.sources.length > 1) {
        Scroll() {
          Row({ space: 8 }) {
            this.SrcChip('', '全部')
            ForEach(this.sources, (s: SourceConfig) => {
              this.SrcChip(s.url, s.name)
            }, (s: SourceConfig) => s.url)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }

      // 内容滚动区：榜单 或 我的歌单
      Scroll() {
        Column({ space: 10 }) {
          if (this.sideTab === 'chart') {
            if (this.chartDisplay().length > 0) {
              ForEach(this.chartDisplay(), (pl: Playlist) => {
                this.ChartItem(pl)
              }, (pl: Playlist, i: number) => `c-${i}-${pl.id ?? pl.name}`)
            } else {
              Text('暂无榜单，添加数据源后自动加载')
                .fontSize(12)
                .fontColor(V3Theme.tx3(this.mode))
                .width('100%')
                .padding({ top: 16, bottom: 16 })
            }
          } else {
            if (this.filteredPlaylists().length > 0) {
              ForEach(this.filteredPlaylists(), (pl: Playlist) => {
                this.SidePlaylistItem(pl)
              }, (pl: Playlist, i: number) => `p-${i}-${pl.id ?? pl.name}`)
            } else {
              Text('暂无歌单，登录数据源后自动加载')
                .fontSize(12)
                .fontColor(V3Theme.tx3(this.mode))
                .width('100%')
                .padding({ top: 16, bottom: 16 })
            }
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 我的 · 数据源
      Row({ space: 11 }) {
        this.SourceAvatar(38)
        Column() {
          Text('音乐库')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(V3Theme.tx1(this.mode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('我的 · 数据源')
            .fontSize(11)
            .fontColor(V3Theme.tx3(this.mode))
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([V3Theme.tx3(this.mode)])
      }
      .width('100%')
      .padding(11)
      .borderRadius(15)
      .backgroundColor(V3Theme.glass2(this.mode))
      .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
      .onClick(() => {
        this.openSheet('my')
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 22, right: 22, top: this.topRect + 68, bottom: this.bottomRect + 24 })
    .backgroundColor(V3Theme.panel(this.mode))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: { right: 1 }, color: V3Theme.hairline(this.mode) })
  }

  /** 榜单展示列表：仅展示真实榜单，空则返回空（不伪造占位榜单误导点击） */
  private chartDisplay(): Playlist[] {
    return this.topList ?? []
  }

  /** 侧边栏「我的歌单」列表：按数据源过滤（plFilterSource 空=全部） */
  private filteredPlaylists(): Playlist[] {
    const all: Playlist[] = this.userPlaylists ?? []
    if (this.plFilterSource.length === 0) {
      return all
    }
    return all.filter((p) => (p.source?.url ?? '') === this.plFilterSource)
  }

  /** 从侧边栏打开歌单详情（入口更浅） */
  private openSidePlaylist(pl: Playlist): void {
    if (!this.isWide()) {
      this.showSidebar = false
    }
    PushPathHelper.pushPath(this.pageStack, 'ImmersivePlaylist', async () => {
      const detail: Playlist = await SourceAdapter.getPlaylistDetail(pl)
      AppStorage.setOrCreate('current_playlist_data', detail)
      AppStorage.setOrCreate('current_playlist_songs', detail.songs)
    })
  }

  // 直接在 Builder 内读取 @State（prevCover/nextCover），保证切歌时两侧刷新；
  // 参数只传常量 isNext（值参在 @State 变化时不会触发 Builder 重渲染）
  @Builder
  SideCover(isNext: boolean) {
    Image(cover(isNext ? this.nextCover : this.prevCover, 200))
      .width(150)
      .height(150)
      .borderRadius(20)
      .objectFit(ImageFit.Cover)
      .opacity(0.4)
      .scale({ x: 0.9, y: 0.9 })
      .shadow({ radius: 50, color: 'rgba(0,0,0,0.7)', offsetX: 0, offsetY: 20 })
      .backgroundColor('rgba(255,255,255,0.05)')
  }

  @Builder
  WideMain() {
    Column() {
      Blank()
      // 卡片流（两侧邻居 + 居中当前卡，横滑动画）
      Row({ space: 34 }) {
        this.SideCover(false)
        Column() {
          Stack({ alignContent: Alignment.BottomEnd }) {
            Image(cover(this.song?.album?.cover ?? '', 600))
              .width(320)
              .height(320)
              .borderRadius(V3Radius.CARD)
              .objectFit(ImageFit.Cover)
              .shadow({ radius: 90, color: 'rgba(0,0,0,0.8)', offsetX: 0, offsetY: 44 })
            Column()
              .width(320)
              .height(320)
              .borderRadius(V3Radius.CARD)
              .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
            this.CoverBadge()
          }
          .translate({ x: this.cardDx })
          .opacity(this.cardOpacity)

          Text(this.song?.name ?? '暂无播放')
            .fontSize(30)
            .fontWeight(FontWeight.Medium)
            .fontColor(V3Theme.tx1(this.mode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 26 })
          Text(this.artistNames())
            .fontSize(15)
            .fontColor(V3Theme.tx2(this.mode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 10 })
        }
        .width(340)
        .alignItems(HorizontalAlign.Center)

        this.SideCover(true)
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      // 歌词块：独立于卡片列、更宽、固定高度——换行也不挤压卡片流布局
      if (this.hasLyrics()) {
        Column({ space: 8 }) {
          Text(this.lyricAt(0))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(V3Theme.tx1(this.mode))
            .textShadow({ radius: 20, color: this.glow, offsetX: 0, offsetY: 0 })
            .width('100%')
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.lyricAt(1))
            .fontSize(14)
            .fontWeight(FontWeight.Regular)
            .fontColor(V3Theme.tx2(this.mode))
            .width('100%')
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('62%')
        .constraintSize({ maxWidth: 680 })
        .height(84)
        .margin({ top: 22 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .clip(true)
        .onClick(() => {
          this.openLyrics()
        })
      }

      // 收窄居中播控
      PlayerBar({ variant: 'wide', onList: () => { this.openSheet('queue') }, onEffects: () => { this.openSheet('effects') }, onTimer: () => { this.openSheet('timer') } })
        .width(520)
        .margin({ top: 30 })

      Blank()
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // 官方 SideBarContainer：宽屏 Embed（并列，可折叠），窄屏 Overlay（抽屉悬浮）
  @Builder
  Sidebarred() {
    SideBarContainer(this.isWide() ? SideBarContainerType.Embed : SideBarContainerType.Overlay) {
      // 子1：侧边栏（模式 + 榜单 + 我的）
      Column() {
        this.WideSidebar()
      }
      .width('100%')
      .height('100%')

      // 子2：内容区
      Stack({ alignContent: Alignment.Bottom }) {
        if (this.isWide()) {
          this.WideMain()
        } else {
          this.PhoneLayout()
        }
        // 窄屏抽屉打开时的遮罩：点击空白关闭 + 冻结内容点击/滑动
        if (!this.isWide() && this.showSidebar) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.32)')
            .onClick(() => {
              this.getUIContext().animateTo({ duration: 320, curve: Curve.EaseInOut }, () => {
                this.showSidebar = false
              })
            })
        }
      }
      .width('100%')
      .height('100%')
    }
    .showSideBar($$this.showSidebar)
    .sideBarWidth(320)
    .minSideBarWidth(300)
    .maxSideBarWidth(360)
    .autoHide(false)
    .divider(null)
    .showControlButton(false)
    .width('100%')
    .height('100%')
  }

  // 玻璃描边图标按钮（侧边栏开合），替代官方裸图标控制按钮
  @Builder
  SidebarToggle() {
    Stack() {
      SymbolGlyph(this.showSidebar ? $r('sys.symbol.chevron_left') : $r('sys.symbol.list_bullet'))
        .fontSize(20)
        .fontColor([V3Theme.tx1(this.mode)])
    }
    .width(44)
    .height(44)
    .borderRadius(22)
    .backgroundColor('rgba(255,255,255,0.10)')
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN, { colorMode: ThemeColorMode.DARK })
    .border({ width: 1, color: 'rgba(255,255,255,0.20)' })
    .shadow({ radius: 14, color: 'rgba(0,0,0,0.30)', offsetX: 0, offsetY: 4 })
    .position({ x: 16, y: this.topRect + 12 })
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 320, curve: Curve.EaseInOut }, () => {
        this.showSidebar = !this.showSidebar
      })
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        AmbientBackground({
          coverUrl: this.song?.album?.cover ?? '',
          blurRadius: 56,
          brightnessVal: 0.74,
          saturateVal: 0.62,
          showGlow: true,
          mode: this.mode
        })

        this.Sidebarred()

        // 悬浮玻璃开合按钮（始终在最上层）
        this.SidebarToggle()
      }
      .width('100%')
      .height('100%')
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal, distance: 30 })
          .onActionUpdate((e: GestureEvent) => {
            // 仅窄屏抽屉打开时冻结切歌滑动；宽屏侧边栏常驻展开不影响切歌
            if (!this.isWide() && this.showSidebar) {
              return
            }
            // 跟手拖拽（带阻尼）
            this.cardDx = e.offsetX * 0.5
            this.cardOpacity = 1 - Math.min(0.4, Math.abs(e.offsetX) / 600)
          })
          .onActionEnd((e: GestureEvent) => {
            if (!this.isWide() && this.showSidebar) {
              return
            }
            if (e.offsetX < -70) {
              this.animateSwitch('next')
            } else if (e.offsetX > 70) {
              this.animateSwitch('prev')
            } else {
              // 未过阈值：回弹
              this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
                this.cardDx = 0
                this.cardOpacity = 1
              })
            }
          })
      )
    }
    .hideTitleBar(true)
    .backgroundColor(V3Color.CANVAS)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    // 单一 bindSheet：内容与尺寸随 activeSheet 切换（规避同节点多 bindSheet 冲突）
    .bindSheet($$this.sheetShow, this.SheetContent(), {
      detents: this.activeSheet === 'timer'
        ? [SheetSize.MEDIUM, SheetSize.LARGE]
        : (this.isWide()
          ? (this.activeSheet === 'my' ? [660] : (this.activeSheet === 'effects' ? [680] : [640]))
          : (this.activeSheet === 'my'
            ? ['72%', SheetSize.LARGE]
            : (this.activeSheet === 'effects' ? ['80%', SheetSize.LARGE] : ['62%', SheetSize.LARGE]))),
      preferType: this.isWide() ? SheetType.CENTER : SheetType.BOTTOM,
      showClose: false,
      dragBar: !this.isWide(),
      width: !this.isWide() ? '100%' : (this.activeSheet === 'my'
        ? Math.min(1040, (this.winWidth > 0 ? this.winWidth : 1040) - 40)
        : (this.activeSheet === 'timer' ? 560 : 720)),
      backgroundColor: Color.Transparent
    })
  }

  // 单弹层内容分发
  @Builder
  SheetContent() {
    if (this.activeSheet === 'my') {
      ImmersiveMy({
        onClose: () => {
          this.sheetShow = false
        }
      })
    } else if (this.activeSheet === 'queue') {
      QueueSheet()
    } else if (this.activeSheet === 'effects') {
      EffectsSheet()
    } else if (this.activeSheet === 'timer') {
      TimerSheet()
    }
  }
}
