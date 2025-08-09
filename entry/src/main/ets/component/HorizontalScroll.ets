
import { DialogHelper } from "@pura/harmony-dialog"
import { ToastUtil } from "@pura/harmony-utils"
import { SourceAdapter } from "../adapter"
import { Album, Artist, Playlist, Song } from "../type/Adapter"
import { cover } from "../util/AdapterHelper"
import { PlaylistManager } from "../util/PlaylistManager"
import { PreferencesCache } from "../util/PreferenceCache"
import { PushPathHelper } from "../util/PushPathHelper"
import { Cover } from "./Cover"

const DEFAULT_COVER_SIZE = 256
const MIN_SCALE = 0.85

@Component
export struct HorizontalScroll {
  @Consume('NavPathStack') pageStack: NavPathStack
  @Prop lists: Object[]
  @State selectedIndex: number = 0
  type: string = ''
  private coverWidth: number = 120
  private segmentPadding: number = 8
  private radius: string | number = 15
  @StorageLink('2in1title') title:string='首页'
  @StorageLink('2in1page_judge') page_judge:string = 'index'
  @StorageLink('aggregation_playlist') aggregationPlaylist: Playlist[] = PreferencesCache.getPlaylistCache('aggregation_playlist')

  private scroller: Scroller = new Scroller()
  @State private scaleList: number[] = []
  private listWidth: number = 0
  @State private isInitialLoad: boolean = true

  aboutToAppear() {
    this.updateScale(0)
  }

  updateScale(scrollOffset: number) {
    const itemCount = this.type === 'Template' ? 10 : this.lists.length
    if (itemCount === 0) return

    const newScaleList: number[] = []
    const itemWidthWithPadding = this.coverWidth + this.segmentPadding
    const useCubicCurve = PreferencesCache.getUserPreference('advanced_scaling_curve', '0') === '1'

    for (let i = 0; i < itemCount; i++) {
      const itemCenterPos = i * itemWidthWithPadding + this.coverWidth / 2
      const visibleCenterPos = itemCenterPos - scrollOffset
      const distanceFromFocus = visibleCenterPos - this.coverWidth * 1
      const effectiveDistance = Math.max(0, distanceFromFocus)
      const focusDistance = this.coverWidth * 2.0 // Make shrinking faster
      const normalizedDistance = effectiveDistance / focusDistance

      const clampedDistance = Math.min(1.0, normalizedDistance)
      let curvedDistance: number;
      if (useCubicCurve) {
        // Apply a non-linear curve (cubic ease-out on distance for faster shrinking)
        curvedDistance = 1 - Math.pow(1 - clampedDistance, 3)
      } else {
        curvedDistance = clampedDistance
      }

      const scale = 1.0 - curvedDistance * (1.0 - MIN_SCALE)
      newScaleList.push(scale)
    }
    this.scaleList = newScaleList
  }

  private handleScrollStop() {
    const xOffset = this.scroller.currentOffset().xOffset;
    const itemWidth = this.coverWidth + this.segmentPadding;

    if (itemWidth <= 0) {
      return;
    }

    const closestIndex = Math.round(xOffset / itemWidth);
    const targetOffset = closestIndex * itemWidth;

    this.scroller.scrollTo({
      xOffset: targetOffset,
      yOffset: 0,
      animation: { duration: 300, curve: Curve.Ease }
    });
  }

  build() {
    Column() {
      if (this.type === 'Song') {
        this.SongCover()
      } else if (this.type === 'Playlist') {
        this.PlaylistCover()
      } else if (this.type === 'Artist') {
        this.ArtistCover()
      } else if (this.type === 'TopPlaylist') {
        this.TopPlaylistCover()
      } else if (this.type === 'Template') {
        this.TemplateCover()
      } else if (this.type === 'Album') {
        this.AlbumCover()
      }
    }.width('100%')
  }

  @Builder
  AlbumCover(){
    List({ scroller: this.scroller, initialIndex: 0, space: this.segmentPadding }) {
      ForEach(this.lists, (item: Album, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.cover, 256),
            title: item.name,
            subTitle: item.artists?.map(artist => artist.name).join(' / '),
            radius: this.radius,
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 })
            .onClick(() => {
              PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                const album = await SourceAdapter.getAlbumDetail(item)
                AppStorage.setOrCreate('current_playlist_data', album)
              })
            })
        }
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .key(`${item.id}-${item.name}-${index}`)
      })
    }
    .margin({ top: 10 })
    .clip(false)
    .width('100%')
    .height('auto')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      if (this.isInitialLoad && newValue.width > 0) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
        this.updateScale(0)
        this.isInitialLoad = false
      } else {
        this.updateScale(this.scroller.currentOffset().xOffset)
      }
    })
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    .onScrollStop(() => this.handleScrollStop())
  }

  @Builder
  TemplateCover(){
    List({ scroller: this.scroller, initialIndex: 0, space: this.segmentPadding }) {
      ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], (item: number, index: number) => {
        ListItem() {
          Cover({
            loading: true,
            src: $r('app.media.ic_placeholder'),
            title: '',
            radius: this.radius
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 })
        }
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .key(`template-${index}`)
      })
    }
    .margin({ top: 10 })
    .clip(false)
    .width('100%')
    .height('auto')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      if (this.isInitialLoad && newValue.width > 0) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
        this.updateScale(0)
        this.isInitialLoad = false
      } else {
        this.updateScale(this.scroller.currentOffset().xOffset)
      }
    })
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    .onScrollStop(() => this.handleScrollStop())
  }

  @Builder
  TopPlaylistCover(){
    List({ scroller: this.scroller, initialIndex: 0, space: this.segmentPadding }) {
      ForEach(this.lists, (item: Playlist, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.cover, DEFAULT_COVER_SIZE),
            title: item.name,
            subTitle: item.description,
            menuItems: this.generatePlaylistMenu(item),
            radius: this.radius
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 })
            .onClick(async () => {
              PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                const playlist = await SourceAdapter.getPlaylistDetail(item)
                AppStorage.setOrCreate('current_playlist_data', playlist)
              })
            })
        }
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .key(`${item.id}-${item.name}-${index}`)
      })
    }
    .margin({ top: 10 })
    .clip(false)
    .width('100%')
    .height('auto')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      if (this.isInitialLoad && newValue.width > 0) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
        this.updateScale(0)
        this.isInitialLoad = false
      } else {
        this.updateScale(this.scroller.currentOffset().xOffset)
      }
    })
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    .onScrollStop(() => this.handleScrollStop())
  }

  @Builder
  ArtistCover() {
    List({ scroller: this.scroller, initialIndex: 0, space: this.segmentPadding }) {
      ForEach(this.lists, (item: Artist, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.avatar, DEFAULT_COVER_SIZE),
            title: item.name,
            radius: "100%",
            titleAlign: HorizontalAlign.Center
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 })
            .onClick(() => {
              PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                const playlist = await SourceAdapter.getArtistDetail(item)
                AppStorage.setOrCreate('current_playlist_data', playlist)
              })
            })
        }
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .key(`${item.id}-${item.name}-${index}`)
      })
    }
    .margin({ top: 10 })
    .clip(false)
    .width('100%')
    .height('auto')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      if (this.isInitialLoad && newValue.width > 0) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
        this.updateScale(0)
        this.isInitialLoad = false
      } else {
        this.updateScale(this.scroller.currentOffset().xOffset)
      }
    })
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    .onScrollStop(() => this.handleScrollStop())
  }

  @Builder
  PlaylistCover() {
    List({ scroller: this.scroller, initialIndex: 0, space: this.segmentPadding }) {
      ForEach(this.lists, (item: Playlist, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.cover, DEFAULT_COVER_SIZE),
            title: item.name,
            menuItems: this.generatePlaylistMenu(item),
            radius: this.radius
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 })
            .onClick(async () => {
                PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                  const playlist = await SourceAdapter.getPlaylistDetail(item)
                  AppStorage.setOrCreate('current_playlist_data', playlist)
                })
            })
        }
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .key(`${item.id}-${item.name}-${index}`)
      })
    }
    .margin({ top: 10 })
    .clip(false)
    .width('100%')
    .height('auto')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      if (this.isInitialLoad && newValue.width > 0) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
        this.updateScale(0)
        this.isInitialLoad = false
      } else {
        this.updateScale(this.scroller.currentOffset().xOffset)
      }
    })
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    .onScrollStop(() => this.handleScrollStop())
  }

  @Builder
  SongCover(){
    List({ scroller: this.scroller, initialIndex: 0, space: this.segmentPadding }) {
      ForEach(this.lists, (item: Song, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.album.cover, DEFAULT_COVER_SIZE),
            title: item.name,
            subTitle: item.artists.map(artist => artist.name).join(' / '),
            menuItems: this.generateSongMenu(item),
            radius: this.radius
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 })
            .onClick(() => {
              PushPathHelper.loading("Playing", async () => {
                PlaylistManager.insertSongs([item], -1, item)
              })
            })
        }
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .key(`${item.id}-${item.name}-${index}`)
      })
    }
    .margin({ top: 10 })
    .clip(false)
    .width('100%')
    .height('auto')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      if (this.isInitialLoad && newValue.width > 0) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
        this.updateScale(0)
        this.isInitialLoad = false
      } else {
        this.updateScale(this.scroller.currentOffset().xOffset)
      }
    })
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    .onScrollStop(() => this.handleScrollStop())
  }

  private generateSongMenu(song: Song): Array<MenuElement> {
    return [
      {
        value: $r('app.string.add_to_play_next'),
        action: () => {
          PlaylistManager.insertSongs([song])
        }
      },
      {
        value: $r('app.string.add_to_playlist'),
        action: () => {
          DialogHelper.showSelectDialog({
            title: $r('app.string.add_to_playlist'),
            confirm: $r('app.string.back'),
            selectedIndex: -1,
            radioContent: this.aggregationPlaylist.map(playlist => playlist.name),
            onCheckedChanged: (index) => {
              this.selectedIndex = index
              if(PreferencesCache.addSongToAggregationPlaylist(this.aggregationPlaylist[this.selectedIndex], song)){
                ToastUtil.showShort(`[${song.name}]存在于[${this.aggregationPlaylist[index].name}]`)
              }else{
                ToastUtil.showShort(`[${song.name}]添加到[${this.aggregationPlaylist[index].name}]`)
              }
            },
            onAction: (): void => {}
          })
        }
      }
    ]
  }

  private generatePlaylistMenu(playlist: Playlist): Array<MenuElement> {
    return [
      {
        value: $r('app.string.play_this_playlist'),
        action: () => {
          PushPathHelper.loading("Playing", async () => {
            const playlistDetail = await SourceAdapter.getPlaylistDetail(playlist)
            const songs = playlistDetail?.songs?.filter(song => song.privilege.playable)
            if (!songs || songs.length === 0) {
              ToastUtil.showShort($r('app.string.no_playable_songs'))
              return
            }
            PlaylistManager.loadPlaylist(songs, songs[0])
          })
        }
      }
    ]
  }
}
