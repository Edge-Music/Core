import { StyleConstants } from "../constants/StyleConstants"
import { Song, Playlist, Artist, Album } from "../type/Adapter"
import { cover } from "../util/AdapterHelper"
import { PushPathHelper } from "../util/PushPathHelper"
import { SourceAdapter } from "../adapter"
import { PlaylistManager } from "../util/PlaylistManager"
import { SongDownloadManager } from "../util/SongDownloadManager"
import { PreferencesCache } from "../util/PreferenceCache"
import { ToastUtil } from "@pura/harmony-utils"

/**
 * 搜索结果列表组件 - 高密度展示
 */
@Component
export struct SearchResultList {
  @Consume('NavPathStack') pageStack: NavPathStack
  @Prop items: (Song | Playlist | Artist | Album)[]
  @Prop type: string
  @Prop title: string
  @State isExpanded: boolean = false
  @StorageLink('aggregation_playlist') aggregationPlaylist: Playlist[] = PreferencesCache.getPlaylistCache('aggregation_playlist')

  @Builder
  private ItemRow(item: Song | Playlist | Artist | Album) {
    Column() {
      Row({ space: 8 }) {
      // 封面/头像 - 与 SongInfo 一致
      Image(this.getItemCover(item))
        .width(48)
        .height(48)
        .aspectRatio(1)
        .borderRadius(this.type === 'Artist' ? 24 : 8)
        .backgroundColor($r('app.color.skeleton_loading'))
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)

      // 信息区域 - 与 SongInfo 一致的布局
      Column({ space: 6 }) {
        // 标题
        Text(this.getItemTitle(item))
          .fontSize(16)
          .fontColor($r('app.color.text_title'))
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width(StyleConstants.FULL_WIDTH)

        // 副标题
        Row({ space: 2 }) {
          Text(this.getItemSubtitle(item))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width(StyleConstants.FULL_WIDTH)
        .alignItems(VerticalAlign.Center)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 更多按钮 - 与 SongInfo 一致的样式
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_more'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.icon_normal'))
          .opacity(0.9)
      }
      .width(48)
      .height(48)
      .bindMenu(this.generateItemMenu(item))
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .backgroundColor(Color.Transparent)
    }
    .shadow(ShadowStyle.OUTER_DEFAULT_XS)
    .width(StyleConstants.FULL_WIDTH)
    .height(68)
    .padding({ left: 12, right: 12 })
    .borderRadius(10)
    .backgroundColor($r('app.color.card_background'))
    .onClick(() => {
      this.handleItemClick(item)
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .hoverEffect(HoverEffect.Highlight)
    .animation({
      duration: 300,
      curve: Curve.EaseInOut,
      iterations: 1
    })
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
  }

  private getItemCover(item: Song | Playlist | Artist | Album): ResourceStr {
    switch (this.type) {
      case 'Song':
        return cover((item as Song).album?.cover || '', 128)
      case 'Playlist':
        return cover((item as Playlist).cover || '', 128)
      case 'Artist':
        return cover((item as Artist).avatar || '', 128)
      case 'Album':
        return cover((item as Album).cover || '', 128)
      default:
        return $r("app.media.icon")
    }
  }

  private getItemTitle(item: Song | Playlist | Artist | Album): string {
    switch (this.type) {
      case 'Song':
        return (item as Song).name
      case 'Playlist':
        return (item as Playlist).name || ''
      case 'Artist':
        return (item as Artist).name
      case 'Album':
        return (item as Album).name
      default:
        return ''
    }
  }

  private getItemSubtitle(item: Song | Playlist | Artist | Album): string {
    switch (this.type) {
      case 'Song':
        const song = item as Song
        return song.artists?.map(artist => artist.name).join(' / ') || ''
      case 'Playlist':
        const playlist = item as Playlist
        return playlist.creator?.name || `${playlist.size || 0} 首歌曲`
      case 'Artist':
        return '歌手'
      case 'Album':
        const album = item as Album
        return album.artists?.map(artist => artist.name).join(' / ') || ''
      default:
        return ''
    }
  }

  private getTypeLabel(): string {
    switch (this.type) {
      case 'Song':
        return '歌曲'
      case 'Playlist':
        return '歌单'
      case 'Artist':
        return '歌手'
      case 'Album':
        return '专辑'
      default:
        return ''
    }
  }

  private handleItemClick(item: Song | Playlist | Artist | Album) {
    switch (this.type) {
      case 'Song':
        // 播放歌曲
        const song = item as Song
        PlaylistManager.playSong(song)
        break
      case 'Playlist':
        // 跳转到歌单详情页
        PushPathHelper.pushPath(this.pageStack, 'Playlist', async () => {
          const playlist = item as Playlist
          const playlistDetail = await SourceAdapter.getPlaylistDetail(playlist)
          AppStorage.setOrCreate('current_playlist_data', playlistDetail)
          AppStorage.setOrCreate('current_playlist_songs', playlistDetail.songs)
        })
        break
      case 'Artist':
        // 跳转到艺人页面（复用歌单UI）
        PushPathHelper.pushPath(this.pageStack, 'Playlist', async () => {
          const artist = item as Artist
          const playlist = await SourceAdapter.getArtistDetail(artist)
          AppStorage.setOrCreate('current_playlist_data', playlist)
          AppStorage.setOrCreate('current_playlist_songs', playlist.songs)
        })
        break
      case 'Album':
        // 跳转到专辑页面（复用歌单UI）
        PushPathHelper.pushPath(this.pageStack, 'Playlist', async () => {
          const album = item as Album
          const albumDetail = await SourceAdapter.getAlbumDetail(album)
          AppStorage.setOrCreate('current_playlist_data', albumDetail)
          AppStorage.setOrCreate('current_playlist_songs', albumDetail.songs)
        })
        break
    }
  }

  // 生成菜单项
  private generateItemMenu(item: Song | Playlist | Artist | Album): Array<MenuElement> {
    switch (this.type) {
      case 'Song':
        return this.generateSongMenu(item as Song)
      case 'Playlist':
        return this.generatePlaylistMenu(item as Playlist)
      case 'Artist':
        return this.generateArtistMenu(item as Artist)
      case 'Album':
        return this.generateAlbumMenu(item as Album)
      default:
        return []
    }
  }

  // 歌曲菜单
  private generateSongMenu(song: Song): Array<MenuElement> {
    return [
      {
        value: '播放此歌曲',
        action: () => {
          PlaylistManager.playSong(song)
        }
      },
      {
        value: $r('app.string.add_to_play_next'),
        action: () => {
          PlaylistManager.insertSongs([song])
          ToastUtil.showShort('已添加到下一首播放')
        }
      },
      {
        value: $r('app.string.add_to_playlist'),
        action: () => {
          // 添加到聚合歌单的逻辑
          if (this.aggregationPlaylist.length > 0) {
            // 这里可以显示选择歌单的对话框
            ToastUtil.showShort('请在聚合页面管理歌单')
          }
        }
      },
      {
        value: $r('app.string.download_this_song'),
        action: () => {
          const success = SongDownloadManager.downloadSong(
            song.id.toString(),
            song
          );
          if (success) {
            ToastUtil.showShort('已添加到下载队列');
          }
        }
      }
    ]
  }

  // 歌单菜单
  private generatePlaylistMenu(playlist: Playlist): Array<MenuElement> {
    return [
      {
        value: $r('app.string.play_this_playlist'),
        action: () => {
          PushPathHelper.loading("Playing", async () => {
            const playlistDetail = await SourceAdapter.getPlaylistDetail(playlist)
            const songs = playlistDetail?.songs?.filter(song => song.privilege.playable)
            if (!songs || songs.length === 0) {
              ToastUtil.showShort('此歌单无可播放歌曲')
              return
            }
            PlaylistManager.loadPlaylist(songs, songs[0])
          })
        }
      },
      {
        value: $r('app.string.add_to_play_next'),
        action: () => {
          PushPathHelper.loading("Playing", async () => {
            const playlistDetail = await SourceAdapter.getPlaylistDetail(playlist)
            const songs = playlistDetail?.songs?.filter(song => song.privilege.playable)
            if (!songs || songs.length === 0) {
              ToastUtil.showShort('此歌单无可播放歌曲')
              return
            }
            PlaylistManager.insertSongs(songs)
            ToastUtil.showShort('已添加到播放队列')
          })
        }
      }
    ]
  }

  // 艺人菜单
  private generateArtistMenu(artist: Artist): Array<MenuElement> {
    return [
      {
        value: '查看艺人详情',
        action: () => {
          this.handleItemClick(artist)
        }
      }
    ]
  }

  // 专辑菜单
  private generateAlbumMenu(album: Album): Array<MenuElement> {
    return [
      {
        value: '查看专辑详情',
        action: () => {
          this.handleItemClick(album)
        }
      }
    ]
  }

  build() {
    Column({ space: 0 }) {
      // 标题
      Row() {
        Text(this.title)
          .fontSize(18)
          .fontColor($r('app.color.text_title'))
          .fontWeight(FontWeight.Bold)
        
        Blank()
        
        Text(`${this.items.length}`)
          .fontSize(14)
          .fontColor($r('app.color.text_hint'))
      }
      .width(StyleConstants.FULL_WIDTH)
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 列表 - 与 SongInfo 一致的间距
      Column({ space: 0 }) {
        ForEach(this.isExpanded ? this.items : this.items.slice(0, 10), (item: Song | Playlist | Artist | Album) => {
          this.ItemRow(item)
        })

        // 查看更多/收起按钮
        if (this.items.length > 10) {
          Row() {
            Text(this.isExpanded ? '收起' : `查看全部 ${this.items.length} 个结果`)
              .fontSize(14)
              .fontColor($r('app.color.accent_primary'))
              .fontWeight(FontWeight.Medium)

            Image($r('app.media.ic_chevron_right'))
              .width(16)
              .height(16)
              .fillColor($r('app.color.accent_primary'))
              .margin({ left: 4 })
              .rotate({ angle: this.isExpanded ? 90 : 0 })
              .animation({
                duration: 300,
                curve: Curve.EaseInOut
              })
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .borderRadius(12)
          .backgroundColor($r('app.color.interactive_normal'))
          .margin({ top: 8 })
          .onClick(() => {
            this.isExpanded = !this.isExpanded
          })
          .clickEffect({ level: ClickEffectLevel.LIGHT })
        }
      }
      .padding({ left: 8, right: 8 })
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ top: 8, bottom: 16 })
  }
}
