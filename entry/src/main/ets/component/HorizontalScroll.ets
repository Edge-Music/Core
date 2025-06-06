import { LazyData } from "@pie/lazy-data"
import { ToastUtil } from "@pura/harmony-utils"
import { SourceAdapter } from "../adapter"
import { StyleConstants } from "../constants/StyleConstants"
import { Album, Artist, Playlist, Song } from "../type/Adapter"
import { cover } from "../util/AdapterHelper"
import { PlaylistManager } from "../util/PlaylistManager"
import { PreferencesCache } from "../util/PreferenceCache"
import { PushPathHelper } from "../util/PushPathHelper"
import { Cover } from "./Cover"

const DEFAULT_COVER_SIZE = 256

@Component
export struct HorizontalScroll {
  @Consume('NavPathStack') pageStack: NavPathStack
  @Prop lists: Object[]
  type: string = ''
  private coverWidth: number = 120
  private segmentPadding: number = 4
  private radius: string | number = 8
  @StorageLink('2in1title') title:string='首页'
  @StorageLink('2in1page_judge') page_judge:string = 'index'
  build() {
    Scroll() {
      Row() {
        if(this.type === 'Song') this.SongCover()
        if(this.type === 'Playlist') this.PlaylistCover()
        if(this.type === 'Artist') this.ArtistCover()
        if(this.type === 'TopPlaylist') this.TopPlaylistCover()
        if(this.type === 'Template') this.TemplateCover()
        if(this.type === 'Album') this.AlbumCover()
      }
      .padding({ left: 6, right: 6 })
      .alignItems(VerticalAlign.Top)
      .justifyContent(FlexAlign.Start)
    }
    .scrollBar(BarState.Off)
    .scrollable(ScrollDirection.Horizontal)
    .edgeEffect(EdgeEffect.Spring)
    .width(StyleConstants.FULL_WIDTH)
  }
  @Builder
  AlbumCover(){
    ForEach(this.lists, (item: Album) => {
      Cover({
        src: cover(item.cover, 256),
        title: item.name,
        subTitle: item.artists?.map(artist => artist.name).join(' / '),
      })
        .width(120)
        .padding(4)
        .onClick(() => {
          PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
            const album = await SourceAdapter.getAlbumDetail(item)
            AppStorage.setOrCreate('current_playlist_data', album)
          })
        })
    })
  }

  @Builder
  TemplateCover(){
    ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], () => {
      ListItem(){
        Cover({
          loading: true,
          src: $r('app.media.ic_placeholder'),
          title: '',
          radius: this.radius
        })
          .width(120)
          .padding(4)
      }
      .key('Template')
    })
  }

  @Builder
  TopPlaylistCover(){
    List({ initialIndex: 0, space: 0 }) {
      LazyForEach(new LazyData(this.lists), (item: Playlist, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.cover, DEFAULT_COVER_SIZE),
            title: item.name,
            subTitle: item.description,
            menuItems: this.generatePlaylistMenu(item)
          })
            .width(this.coverWidth)
            .padding(this.segmentPadding)
            .onClick(async () => {
              PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                const playlist = await SourceAdapter.getPlaylistDetail(item)
                AppStorage.setOrCreate('current_playlist_data', playlist)
              })
            })
        }
        .key(`${item.name}-${index}`)
      })
    }
    .width('100%')
    .height('auto')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .cachedCount(3)
  }

  @Builder
  ArtistCover() {
    List({ initialIndex: 0, space: 0 }) {
      LazyForEach(new LazyData(this.lists), (item: Artist, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.avatar, DEFAULT_COVER_SIZE),
            title: item.name,
            radius: "100%",
            titleAlign: HorizontalAlign.Center
          })
            .width(this.coverWidth)
            .padding(this.segmentPadding)
            .onClick(() => {
              PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                // 歌手复用歌单UI
                const playlist = await SourceAdapter.getArtistDetail(item)
                AppStorage.setOrCreate('current_playlist_data', playlist)
              })
            })
        }
        .key(`${item.name}-${index}`)
      })
    }
    .width('100%')
    .height('auto')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .cachedCount(3)
  }

  @Builder
  PlaylistCover() {
    List({ initialIndex: 0, space: 0 }) {
      LazyForEach(new LazyData(this.lists), (item: Playlist, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.cover, DEFAULT_COVER_SIZE),
            title: item.name,
            menuItems: this.generatePlaylistMenu(item)
          })
            .width(this.coverWidth)
            .padding(this.segmentPadding)
            .onClick(async () => {
                PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                  const playlist = await SourceAdapter.getPlaylistDetail(item)
                  AppStorage.setOrCreate('current_playlist_data', playlist)
                })


            })
        }
        .key(`${item.name}-${index}`)
      })
    }
    .width('100%')
    .height('auto')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .cachedCount(3)
  }

  @Builder
  SongCover(){
    List({ initialIndex: 0, space: 0 }) {
      LazyForEach(new LazyData(this.lists), (item: Song, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.album.cover, DEFAULT_COVER_SIZE),
            title: item.name,
            subTitle: item.artists.map(artist => artist.name).join(' / '),
            menuItems: this.generateSongMenu(item)
          })
            .width(this.coverWidth)
            .padding(this.segmentPadding)
            .onClick(() => {
              PushPathHelper.loading("Playing", async () => {
                PlaylistManager.insertSongs([item], -1, item)
              })
            })
        }
        .key(`${item.name}-${index}`)
      })
    }
    .width('100%')
    .height('auto')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .cachedCount(3) // 缓存更多项以提高性能
  }

  private generateSongMenu(song: Song): Array<MenuElement> {
    return [
      {
        value: $r('app.string.add_to_play_next'),
        action: () => {
          PlaylistManager.insertSongs([song])
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