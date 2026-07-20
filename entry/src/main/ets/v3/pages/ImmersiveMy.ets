/**
 * OMSP 3.0 · 我的（对齐设计规范 §5 + 屏04/W2）
 * 以 bindContentCover 原生弹层呈现（由播放页挂载），非独立路由。
 * 断点自适应：窄屏底部升起 / 宽屏居中双栏模态；背景仍是当前封面模糊环境。
 * 点数据源头像 → 标题与歌单列表切换到该源；聚合源=特殊「本地」（多源聚合）。
 */
import { Song, Playlist, SourceConfig, PlaylistType } from '../../type/Adapter'
import { cover, playlistCover, playlistCountText } from '../../util/AdapterHelper'
import { SourceAdapter } from '../../adapter'
import { PushPathHelper } from '../../util/PushPathHelper'
import { AmbientBackground } from '../components/AmbientBackground'
import { PlaylistCover } from '../components/PlaylistCover'
import { V3Color, V3Radius, V3Theme } from '../theme/Tokens'

@Component
export struct ImmersiveMy {
  // 关闭弹层回调（bindContentCover）
  onClose?: () => void
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('current_playing_song') song: Song | null = null
  @StorageProp('user_data_source') sources: SourceConfig[] = []
  @StorageLink('user_playlist') playlists: Playlist[] = []
  // 本地聚合歌单（用户在本地创建、混合多数据源歌曲）
  @StorageProp('aggregation_playlist') aggPlaylists: Playlist[] = []
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('winWidth') winWidth: number = 0
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  // 当前选中的数据源：'local'=聚合源（本地），否则为 source.id.toString()
  @State selectedSourceId: string = 'local'

  private isWide(): boolean {
    return this.widthBp >= WidthBreakpoint.WIDTH_LG
  }

  // 弹层实际容器宽（'my' sheet 上限 1040，小屏取屏宽），用于宽屏双栏的响应式布局
  private containerW(): number {
    const w: number = this.winWidth > 0 ? this.winWidth : 1040
    return Math.min(1040, w)
  }

  // 左栏宽度：小容器收窄，避免右侧网格被挤没
  private leftPanelW(): number {
    return this.containerW() < 920 ? 260 : 340
  }

  // 右侧歌单网格列数：按可用宽度动态 2~4 列（每列约 200vp）
  private gridCols(): string {
    const avail: number = this.containerW() - this.leftPanelW() - 76
    let cols: number = Math.floor(avail / 200)
    if (cols < 2) {
      cols = 2
    }
    if (cols > 4) {
      cols = 4
    }
    return new Array<string>(cols).fill('1fr').join(' ')
  }

  private firstChar(name: string): string {
    return name && name.length > 0 ? name.substring(0, 1) : '源'
  }

  private sourceAvatarUrl(s: SourceConfig): string {
    return s.auth?.user?.avatar ?? ''
  }

  private allUserPlaylists(): Playlist[] {
    // 不再过滤 key_ 开头的特殊歌单（每日推荐/私人FM 等数据源推荐歌单也应展示）
    return this.playlists ?? []
  }

  private isLocal(): boolean {
    return this.selectedSourceId === 'local'
  }

  private selectedSource(): SourceConfig | null {
    for (const s of this.sources ?? []) {
      if (s.id.toString() === this.selectedSourceId) {
        return s
      }
    }
    return null
  }

  private selectedName(): string {
    if (this.isLocal()) {
      return '音乐库'
    }
    const s: SourceConfig | null = this.selectedSource()
    return s ? s.name : '音乐库'
  }

  // 选中本地=聚合歌单(aggregation_playlist)；选中数据源=该源的用户歌单(按 source.id 过滤)
  private listPlaylists(): Playlist[] {
    if (this.isLocal()) {
      return this.aggPlaylists ?? []
    }
    return this.allUserPlaylists().filter((p) => (p.source?.id?.toString() ?? '') === this.selectedSourceId)
  }

  private close(): void {
    if (this.onClose) {
      this.onClose()
    }
  }

  private openDataSource(): void {
    this.close()
    this.pageStack.pushPath({ name: 'ImmersiveSourceManager' }, { animated: true })
  }

  private openAggregate(route: string): void {
    this.close()
    this.pageStack.pushPath({ name: route }, { animated: true })
  }

  private openPlaylist(pl: Playlist): void {
    this.close()
    PushPathHelper.pushPath(this.pageStack, 'ImmersivePlaylist', async () => {
      const detail: Playlist = pl.type === PlaylistType.AGGREGATION
        ? await SourceAdapter.getAggregationPlaylistDetail(pl)
        : await SourceAdapter.getPlaylistDetail(pl)
      AppStorage.setOrCreate('current_playlist_data', detail)
      AppStorage.setOrCreate('current_playlist_songs', detail.songs)
    })
  }

  // ============ 复用块 ============
  // 多数据源头像堆叠（音乐库=聚合，展示已登录源的真实头像）
  @Builder
  StackedAvatars(size: number) {
    Row() {
      if (this.sources && this.sources.length > 0) {
        ForEach(this.sources.slice(0, 3), (s: SourceConfig, i: number) => {
          if (this.sourceAvatarUrl(s).length > 0) {
            Image(cover(this.sourceAvatarUrl(s), 100))
              .width(size)
              .height(size)
              .borderRadius(size / 2)
              .objectFit(ImageFit.Cover)
              .border({ width: 2, color: 'rgba(26,22,16,0.95)' })
              .margin({ left: i === 0 ? 0 : -size * 0.34 })
              .zIndex(3 - i)
          } else {
            Text(this.firstChar(s.name))
              .fontSize(size * 0.4)
              .fontColor('#FFFFFF')
              .width(size)
              .height(size)
              .borderRadius(size / 2)
              .textAlign(TextAlign.Center)
              .backgroundColor('rgba(120,110,95,0.9)')
              .border({ width: 2, color: 'rgba(26,22,16,0.95)' })
              .margin({ left: i === 0 ? 0 : -size * 0.34 })
              .zIndex(3 - i)
          }
        }, (s: SourceConfig) => s.id.toString())
      } else {
        Stack() {
          SymbolGlyph($r('sys.symbol.square_stack_3d_fill'))
            .fontSize(size * 0.5)
            .fontColor([V3Color.PLAY_ICON])
        }
        .width(size)
        .height(size)
        .borderRadius(16)
        .backgroundColor('rgba(216,176,114,0.85)')
      }
    }
  }

  // 聚合源（本地）圆形入口
  @Builder
  AggregateAvatar(size: number) {
    Column({ space: 7 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.square_stack_3d_fill'))
          .fontSize(size * 0.44)
          .fontColor([V3Color.PLAY_ICON])
      }
      .width(size)
      .height(size)
      .borderRadius(14)
      .backgroundColor('rgba(216,176,114,0.85)')
      .border({
        width: 2,
        color: this.selectedSourceId === 'local' ? '#D8B072' : 'rgba(0,0,0,0)'
      })
      Text('本地')
        .fontSize(11)
        .fontColor(this.selectedSourceId === 'local' ? V3Color.ACCENT_FALLBACK : V3Theme.tx2(this.mode))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(size + 8)
        .textAlign(TextAlign.Center)
    }
    .width(size + 8)
    .onClick(() => {
      this.selectedSourceId = 'local'
    })
  }

  // 数据源头像：真实头像圆图；选中态金色描边
  @Builder
  SourceAvatar(s: SourceConfig, size: number) {
    Column({ space: 7 }) {
      if (this.sourceAvatarUrl(s).length > 0) {
        Image(cover(this.sourceAvatarUrl(s), 100))
          .width(size)
          .height(size)
          .borderRadius(size / 2)
          .objectFit(ImageFit.Cover)
          .border({
            width: 2,
            color: this.selectedSourceId === s.id.toString() ? '#D8B072' : (V3Theme.isLight(this.mode) ? 'rgba(10,10,13,0.18)' : 'rgba(255,255,255,0.28)')
          })
      } else {
        Text(this.firstChar(s.name))
          .fontSize(size * 0.4)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .width(size)
          .height(size)
          .borderRadius(size / 2)
          .textAlign(TextAlign.Center)
          .backgroundColor(V3Theme.glass2(this.mode))
          .border({
            width: 2,
            color: this.selectedSourceId === s.id.toString() ? '#D8B072' : (V3Theme.isLight(this.mode) ? 'rgba(10,10,13,0.18)' : 'rgba(255,255,255,0.28)')
          })
      }
      Text(s.name)
        .fontSize(11)
        .fontColor(this.selectedSourceId === s.id.toString() ? V3Color.ACCENT_FALLBACK : V3Theme.tx2(this.mode))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(size + 8)
        .textAlign(TextAlign.Center)
    }
    .width(size + 8)
    .onClick(() => {
      this.selectedSourceId = s.id.toString()
    })
  }

  @Builder
  AddSourceAvatar(size: number) {
    Column({ space: 7 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(size * 0.4)
          .fontColor([V3Theme.accentFallback(this.mode)])
      }
      .width(size)
      .height(size)
      .borderRadius(size / 2)
      .backgroundColor(V3Theme.isLight(this.mode) ? 'rgba(169,122,52,0.14)' : 'rgba(255,255,255,0.06)')
      .borderWidth(1.8)
      .borderColor(V3Theme.isLight(this.mode) ? 'rgba(169,122,52,0.85)' : 'rgba(255,255,255,0.45)')
      .borderStyle(BorderStyle.Dashed)
      Text('添加')
        .fontSize(11)
        .fontColor(V3Theme.tx2(this.mode))
    }
    .width(size + 8)
    .onClick(() => {
      this.openDataSource()
    })
  }

  // 顶部卡片：跟随选中源。本地=音乐库(聚合源,多源头像堆叠)；数据源=该源头像+名称(无聚合源标签)
  @Builder
  CurrentSourceCard() {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        if (this.isLocal()) {
          this.StackedAvatars(50)
        } else {
          this.SingleAvatar(this.selectedSource(), 50)
        }
        Row().width(12).height(12).borderRadius(6).backgroundColor('#7FB08A')
          .border({ width: 2.5, color: 'rgba(30,26,20,0.9)' })
      }
      Column() {
        Row({ space: 7 }) {
          Text(this.selectedName())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(V3Theme.tx1(this.mode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.isLocal()) {
            Text('聚合源')
              .fontSize(10)
              .fontColor('#D8B072')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .backgroundColor('rgba(216,176,114,0.14)')
              .border({ width: 1, color: 'rgba(216,176,114,0.3)' })
          }
        }
        Row({ space: 7 }) {
          Row().width(6).height(6).borderRadius(3).backgroundColor('#7FB08A')
          Text(this.isLocal()
            ? `${(this.sources ?? []).length} 个数据源 · ${(this.aggPlaylists ?? []).length} 个歌单`
            : `已登录 · ${this.listPlaylists().length} 个歌单`)
            .fontSize(12.5)
            .fontColor(V3Theme.tx2(this.mode))
        }
        .margin({ top: 5 })
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 16 })
    .borderRadius(20)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 16, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
    .onClick(() => {
      this.openDataSource()
    })
  }

  // 单个数据源头像（卡片用），无头像则首字母
  @Builder
  SingleAvatar(s: SourceConfig | null, size: number) {
    if (s !== null && this.sourceAvatarUrl(s).length > 0) {
      Image(cover(this.sourceAvatarUrl(s), 100))
        .width(size)
        .height(size)
        .borderRadius(size / 2)
        .objectFit(ImageFit.Cover)
        .border({ width: 1.5, color: 'rgba(255,255,255,0.4)' })
    } else {
      Text(s !== null ? this.firstChar(s.name) : '源')
        .fontSize(size * 0.4)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .width(size)
        .height(size)
        .borderRadius(size / 2)
        .textAlign(TextAlign.Center)
        .backgroundColor('rgba(255,255,255,0.16)')
        .border({ width: 1.5, color: 'rgba(255,255,255,0.4)' })
    }
  }

  @Builder
  SourceRow() {
    Column() {
      Text('已登录数据源')
        .fontSize(12)
        .fontColor(V3Theme.tx3(this.mode))
        .letterSpacing(1.4)
        .width('100%')
        .margin({ bottom: 11 })
      Scroll() {
        Row({ space: 14 }) {
          this.AggregateAvatar(48)
          ForEach(this.sources ?? [], (s: SourceConfig) => {
            this.SourceAvatar(s, 48)
          }, (s: SourceConfig) => s.id.toString())
          this.AddSourceAvatar(48)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .align(Alignment.Start)
    }
    .width('100%')
  }

  @Builder
  AggregateCard(icon: Resource, label: string, route: string) {
    Column({ space: 9 }) {
      Stack() {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([V3Theme.accentFallback(this.mode)])
      }
      .width(30)
      .height(30)
      .borderRadius(9)
      .backgroundColor(V3Theme.isLight(this.mode) ? 'rgba(169,122,52,0.14)' : 'rgba(216,176,114,0.16)')
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(V3Theme.tx1(this.mode))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .borderRadius(V3Radius.CHIP)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 14, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 4 })
    .onClick(() => {
      this.openAggregate(route)
    })
  }

  @Builder
  AggregateRow() {
    Column() {
      Text('聚合歌单 · 跨数据源')
        .fontSize(12)
        .fontColor(V3Theme.tx3(this.mode))
        .letterSpacing(1.4)
        .width('100%')
        .margin({ bottom: 8 })
      Row({ space: 10 }) {
        this.AggregateCard($r('sys.symbol.clock'), '最近播放', 'ImmersiveStatistics')
        this.AggregateCard($r('sys.symbol.heart'), '我的收藏', 'ImmersiveAggregation')
        this.AggregateCard($r('sys.symbol.arrow_down_to_line'), '本地下载', 'ImmersiveDownload')
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  PlaylistListItem(pl: Playlist) {
    Row({ space: 13 }) {
      PlaylistCover({ pl: pl, coverSize: 100, sizeW: 48, radius: 10 })
      Column() {
        Text(pl.name ?? '未命名歌单')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (playlistCountText(pl).length > 0) {
          Text(playlistCountText(pl))
            .fontSize(12)
            .fontColor(V3Theme.tx2(this.mode))
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([V3Theme.tx3(this.mode)])
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      this.openPlaylist(pl)
    })
  }

  @Builder
  PlaylistGridItem(pl: Playlist) {
    Column() {
      Stack() {
        PlaylistCover({ pl: pl, coverSize: 200, sizeW: '100%', radius: 16 })
      }
      .width('100%')
      .aspectRatio(1)
      .borderRadius(16)
      .shadow({ radius: 14, color: 'rgba(0,0,0,0.32)', offsetX: 0, offsetY: 6 })
      Text(pl.name ?? '未命名歌单')
        .fontSize(14.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(V3Theme.tx1(this.mode))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 11 })
      if (playlistCountText(pl).length > 0) {
        Text(playlistCountText(pl))
          .fontSize(12)
          .fontColor(V3Theme.tx2(this.mode))
          .margin({ top: 4 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openPlaylist(pl)
    })
  }

  @Builder
  EmptyPlaylist() {
    Column() {
      Text(this.isLocal() ? '还没有本地聚合歌单' : '该数据源暂无歌单')
        .fontSize(14)
        .fontColor(V3Theme.tx2(this.mode))
    }
    .width('100%')
    .padding({ top: 30, bottom: 30 })
    .justifyContent(FlexAlign.Center)
  }

  // ============ 窄屏 Sheet ============
  @Builder
  PhoneLayout() {
    Column() {
      Scroll() {
        Column({ space: 15 }) {
          this.CurrentSourceCard()
          this.SourceRow()
          this.AggregateRow()

          Column() {
            Row() {
              Text(`${this.selectedName()} · 歌单`)
                .fontSize(12)
                .fontColor(V3Theme.tx3(this.mode))
                .letterSpacing(1.4)
              Blank()
              if (this.isLocal()) {
                Text('管理 ›')
                  .fontSize(12)
                  .fontColor(V3Theme.accentFallback(this.mode))
                  .onClick(() => {
                    this.close()
                    this.pageStack.pushPath({ name: 'ImmersiveAggregation' }, { animated: true })
                  })
              }
            }
            .width('100%')
            .margin({ bottom: 8 })
            if (this.listPlaylists().length > 0) {
              ForEach(this.listPlaylists(), (pl: Playlist) => {
                this.PlaylistListItem(pl)
              }, (pl: Playlist) => pl.id.toString())
            } else {
              this.EmptyPlaylist()
            }
          }
          .width('100%')

          Row().height(this.bottomRect + 16)
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
  }

  // ============ 宽屏双栏模态 ============
  @Builder
  WideLayout() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        // 左栏
        Column({ space: 20 }) {
          this.CurrentSourceCard()
          this.SourceRow()
          Column({ space: 9 }) {
            Row({ space: 10 }) {
              this.AggregateCard($r('sys.symbol.clock'), '最近播放', 'ImmersiveStatistics')
              this.AggregateCard($r('sys.symbol.heart'), '我的收藏', 'ImmersiveAggregation')
            }
            .width('100%')
            Row({ space: 10 }) {
              this.AggregateCard($r('sys.symbol.arrow_down_to_line'), '本地下载', 'ImmersiveDownload')
              Column().layoutWeight(1)
            }
            .width('100%')
          }
          .width('100%')
        }
        .width(this.leftPanelW())
        .height('100%')
        .padding(this.containerW() < 920 ? 18 : 26)
        .border({ width: { right: 1 }, color: V3Theme.hairline(this.mode) })

        // 右栏：歌单网格
        Column() {
          Row() {
            Text(`${this.selectedName()} · 歌单`)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(V3Theme.tx1(this.mode))
            if (this.isLocal()) {
              Text('管理 ›')
                .fontSize(13)
                .fontColor(V3Theme.accentFallback(this.mode))
                .margin({ left: 12 })
                .onClick(() => {
                  this.close()
                  this.pageStack.pushPath({ name: 'ImmersiveAggregation' }, { animated: true })
                })
            }
            Blank()
          }
          .width('100%')
          .margin({ bottom: 20, right: 56 })

          if (this.listPlaylists().length > 0) {
            Scroll() {
              Grid() {
                ForEach(this.listPlaylists(), (pl: Playlist) => {
                  GridItem() {
                    this.PlaylistGridItem(pl)
                  }
                }, (pl: Playlist) => pl.id.toString())
              }
              .columnsTemplate(this.gridCols())
              .columnsGap(20)
              .rowsGap(22)
              .width('100%')
              .padding({ left: 8, right: 8, top: 6, bottom: 40 })
            }
            .layoutWeight(1)
            .width('100%')
            .scrollBar(BarState.Off)
            .align(Alignment.TopStart)
          } else {
            this.EmptyPlaylist()
          }
        }
        .layoutWeight(1)
        .height('100%')
        .padding({ left: 30, right: 30, top: 30 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')

      // 设置 + 关闭
      Row({ space: 12 }) {

        Stack() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([V3Theme.tx1(this.mode)])
        }
        .width(38)
        .height(38)
        .borderRadius(19)
        .backgroundColor(V3Theme.glass2(this.mode))
        .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
        .onClick(() => {
          this.close()
        })
      }
      .margin({ top: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }

  build() {
    Stack() {
      // 暖色暮光玻璃底（复用封面取色环境层），替代系统灰色毛玻璃
      AmbientBackground({
        coverUrl: this.song?.album?.cover ?? '',
        mode: this.mode,
        blurRadius: 60,
        brightnessVal: 0.64,
        saturateVal: 0.58,
        showGlow: true,
        dim: 0.32
      })
      // 顶部一层白色玻璃提亮，形成液态玻璃质感
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(255,255,255,0.06)')

      Column() {
        if (this.isWide()) {
          this.WideLayout()
        } else {
          this.PhoneLayout()
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    // 弹层背景透明，圆角由内容承担；手机底部 sheet 顶部圆角更明显
    .borderRadius({
      topLeft: this.isWide() ? 30 : 40,
      topRight: this.isWide() ? 30 : 40,
      bottomLeft: this.isWide() ? 30 : 0,
      bottomRight: this.isWide() ? 30 : 0
    })
    .clip(true)
  }
}
