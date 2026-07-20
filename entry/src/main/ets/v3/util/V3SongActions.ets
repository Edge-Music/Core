/**
 * OMSP 3.0 · 歌曲操作菜单（可复用）
 * 把旧版 SongInfo 的丰富操作统一收口，供 3.0 各列表页歌曲行 bindMenu 复用：
 * 下一首播放 / 收藏 / 添加到歌单 / 下载 / 查看歌手 / 查看专辑。
 * 底层全部复用既有能力：PlaylistManager / SourceAdapter / PreferencesCache / SongDownloadManager。
 */
import { Song, Playlist, Artist, Album } from '../../type/Adapter'
import { PlaylistManager } from '../../util/PlaylistManager'
import { SourceAdapter } from '../../adapter'
import { PreferencesCache } from '../../util/PreferenceCache'
import { SongDownloadManager } from '../../util/SongDownloadManager'
import { PushPathHelper } from '../../util/PushPathHelper'
import { ToastUtil } from '@pura/harmony-utils'
import { DialogHelper } from '@pura/harmony-dialog'

export class V3SongActions {
  /** 构造某首歌的操作菜单 */
  static menu(song: Song, pageStack: NavPathStack, aggPlaylists: Playlist[]): MenuElement[] {
    const items: MenuElement[] = [
      {
        value: '下一首播放',
        action: () => {
          PlaylistManager.insertSongs([song])
          // 用户开始手动管理队列 → 降级为非电台，停止自动补充，尊重用户掌控
          AppStorage.setOrCreate('v3_queue_radio', false)
          ToastUtil.showShort('已添加到下一首')
        }
      },
      {
        value: '收藏到喜欢',
        action: () => {
          if (!song.source) {
            ToastUtil.showShort('无法收藏：该歌曲缺少数据源')
            return
          }
          SourceAdapter.likeSong(song, true).then((ok: boolean) => {
            ToastUtil.showShort(ok ? '已收藏到「我喜欢的音乐」' : '收藏失败，请稍后重试')
          })
        }
      },
      {
        value: '添加到歌单',
        action: () => {
          V3SongActions.addToPlaylist(song, aggPlaylists)
        }
      },
      {
        value: '下载',
        action: () => {
          const ok: boolean = SongDownloadManager.downloadSong(song.id.toString(), song)
          ToastUtil.showShort(ok ? '已加入下载队列' : '下载失败')
        }
      }
    ]
    if (song.artists && song.artists.length > 0) {
      items.push({
        value: '查看歌手',
        action: () => {
          V3SongActions.viewArtist(song.artists![0], pageStack)
        }
      })
    }
    if (song.album && (song.album.name ?? '').length > 0) {
      items.push({
        value: '查看专辑',
        action: () => {
          V3SongActions.viewAlbum(song.album!, pageStack)
        }
      })
    }
    return items
  }

  static addToPlaylist(song: Song, aggPlaylists: Playlist[]): void {
    if (!aggPlaylists || aggPlaylists.length === 0) {
      ToastUtil.showShort('请先在音乐库创建聚合歌单')
      return
    }
    DialogHelper.showSelectDialog({
      title: '添加到歌单',
      confirm: '返回',
      selectedIndex: -1,
      radioContent: aggPlaylists.map((p) => p.name ?? '未命名'),
      onCheckedChanged: (index: number) => {
        PreferencesCache.addSongToAggregationPlaylist(aggPlaylists[index], song).then((exist: boolean) => {
          ToastUtil.showShort(exist ? `已存在于[${aggPlaylists[index].name}]` : `已添加到[${aggPlaylists[index].name}]`)
        })
      },
      onAction: (): void => {}
    })
  }

  private static viewArtist(artist: Artist, pageStack: NavPathStack): void {
    PushPathHelper.pushPath(pageStack, 'ImmersivePlaylist', async () => {
      const detail: Playlist = await SourceAdapter.getArtistDetail(artist)
      AppStorage.setOrCreate('current_playlist_data', detail)
      AppStorage.setOrCreate('current_playlist_songs', detail.songs)
    })
  }

  private static viewAlbum(album: Album, pageStack: NavPathStack): void {
    PushPathHelper.pushPath(pageStack, 'ImmersivePlaylist', async () => {
      const detail: Playlist = await SourceAdapter.getAlbumDetail(album)
      AppStorage.setOrCreate('current_playlist_data', detail)
      AppStorage.setOrCreate('current_playlist_songs', detail.songs)
    })
  }
}
