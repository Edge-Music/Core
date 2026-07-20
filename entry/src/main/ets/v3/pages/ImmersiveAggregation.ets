/**
 * OMSP 3.0 · 我的收藏 / 聚合歌单管理（全新玻璃风，功能对齐旧 view/Aggregation.ets）
 * 列出本地聚合歌单 + 创建 + 删除 + 点击进详情。
 * 数据复用：aggregation_playlist(AppStorage) + PreferencesCache.addPlaylistsCache/deletePlaylistCache/deleteCache，
 * 详情复用 SourceAdapter.getAggregationPlaylistDetail → ImmersivePlaylist。
 */
import { Song, Playlist, PlaylistType } from '../../type/Adapter'
import { SourceAdapter } from '../../adapter'
import { PreferencesCache } from '../../util/PreferenceCache'
import { PushPathHelper } from '../../util/PushPathHelper'
import { playlistCover, playlistCountText } from '../../util/AdapterHelper'
import { AmbientBackground } from '../components/AmbientBackground'
import { PlaylistCover } from '../components/PlaylistCover'
import { ToastUtil, DialogUtil } from '@pura/harmony-utils'
import { DialogAction, DialogHelper } from '@pura/harmony-dialog'
import { V3Color, V3Radius, V3Theme } from '../theme/Tokens'

@Component
export struct ImmersiveAggregation {
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('current_playing_song') playingSong: Song | null = null
  @StorageLink('aggregation_playlist') playlists: Playlist[] = []
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('v3_theme_mode') mode: string = 'dark'

  private isWide(): boolean {
    return this.widthBp >= WidthBreakpoint.WIDTH_LG
  }

  private cols(): number {
    return this.isWide() ? 4 : 2
  }

  // 创建聚合歌单
  private createPlaylist(): void {
    DialogHelper.showTextInputDialog({
      title: '新建歌单',
      text: '',
      cancelButton: { style: CancelButtonStyle.INVISIBLE },
      onAction: (action: number, _id: string, value: string) => {
        if (action === DialogAction.SURE) {
          const name: string = value.trim() || '我的歌单'
          const timestamp: number = new Date().getTime()
          const pl: Playlist = {
            id: `aggregation_playlist-${timestamp}`,
            name: name,
            description: '本地聚合歌单',
            size: 0,
            type: PlaylistType.AGGREGATION
          }
          PreferencesCache.addPlaylistsCache('aggregation_playlist', [pl])
          ToastUtil.showShort(`已创建「${name}」`)
        }
      }
    })
  }

  private deletePlaylist(pl: Playlist): void {
    DialogUtil.showPrimaryDialog({
      title: '删除歌单',
      message: `确定删除「${pl.name}」？歌单内歌曲记录会一并移除。`,
      primaryButton: '取消',
      secondaryButton: '删除',
      onAction: (action: number) => {
        if (action === DialogAction.TWO) {
          PreferencesCache.deleteCache(`aggregation_playlist_songs_${pl.id}`)
          PreferencesCache.deletePlaylistCache('aggregation_playlist', pl)
          ToastUtil.showShort('已删除歌单')
        }
      }
    })
  }

  private openDetail(pl: Playlist): void {
    PushPathHelper.pushPath(this.pageStack, 'ImmersivePlaylist', async () => {
      const detail: Playlist = await SourceAdapter.getAggregationPlaylistDetail(pl)
      AppStorage.setOrCreate('current_playlist_data', detail)
      AppStorage.setOrCreate('current_playlist_songs', detail.songs)
    })
  }

  // ============ 歌单卡 ============
  @Builder
  PlaylistCard(pl: Playlist) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        PlaylistCover({ pl: pl, coverSize: 300, sizeW: '100%', radius: 16 })
      }
      .width('100%')
      .aspectRatio(1)
      .borderRadius(16)
      .shadow({ radius: 20, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 8 })

      Text(pl.name ?? '未命名')
        .fontSize(14.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(V3Theme.tx1(this.mode))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 10 })
        .width('100%')
      if (playlistCountText(pl).length > 0) {
        Text(playlistCountText(pl))
          .fontSize(12)
          .fontColor(V3Theme.tx3(this.mode))
          .margin({ top: 3 })
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openDetail(pl)
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.deletePlaylist(pl)
        })
    )
  }

  @Builder
  CreateCard() {
    Column() {
      Column() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(36)
          .fontColor([V3Theme.accentFallback(this.mode)])
      }
      .width('100%')
      .aspectRatio(1)
      .justifyContent(FlexAlign.Center)
      .borderRadius(16)
      .backgroundColor(V3Theme.isLight(this.mode) ? 'rgba(169,122,52,0.10)' : 'rgba(216,176,114,0.10)')
      .border({ width: 1.5, color: 'rgba(201,154,87,0.5)' })
      Text('新建歌单')
        .fontSize(14.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(V3Theme.accentFallback(this.mode))
        .margin({ top: 10 })
        .width('100%')
      Text('长按歌单可删除')
        .fontSize(12)
        .fontColor(V3Theme.tx3(this.mode))
        .margin({ top: 3 })
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.createPlaylist()
    })
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

        Column({ space: 12 }) {
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(22)
              .fontColor([V3Theme.tx1(this.mode)])
              .padding(6)
              .onClick(() => {
                this.pageStack.pop()
              })
            Text('我的收藏')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(V3Theme.tx1(this.mode))
              .margin({ left: 8 })
            Blank()
          }
          .width('100%')
          .padding({ left: 12, right: 16 })

          Scroll() {
            Grid() {
              GridItem() {
                this.CreateCard()
              }
              ForEach(this.playlists ?? [], (pl: Playlist) => {
                GridItem() {
                  this.PlaylistCard(pl)
                }
              }, (pl: Playlist) => `${pl.id}`)
              GridItem() {
                Row().height(this.bottomRect + 24)
              }
            }
            .columnsTemplate('1fr '.repeat(this.cols()).trim())
            .columnsGap(16)
            .rowsGap(20)
            .width('100%')
            .height('auto')
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .padding({ left: 20, right: 20 })
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
