import { CustomContentOptions, DialogAction, DialogHelper } from "@pura/harmony-dialog";
import { LogUtil, ToastUtil } from "@pura/harmony-utils";
import { SourceAdapter } from "../adapter";
import { StyleConstants } from "../constants/StyleConstants";
import { AnimationConstants } from "../constants/AnimationConstants";
import { Playlist, PlaylistType, Song } from "../type/Adapter";
import { cover } from "../util/AdapterHelper";
import { VibrationControl } from "../util/DeviceController";
import { PlaylistManager } from "../util/PlaylistManager";
import { PreferencesCache } from "../util/PreferenceCache";
import { PushPathHelper } from "../util/PushPathHelper";
import ResourceManager from "../util/ResourceManager";
import { SongDownloadManager } from "../util/SongDownloadManager";
import { AddAggregationPlaylist } from "./CustomTextBuilder";
const TAG = 'PlaylistItem'

@Component
export struct PlaylistItem {
  @State playlistName: string | undefined = undefined
  @State playlistDesc: string | undefined = undefined
  @State isShowMenu: boolean = false
  @State selectedIndex: number = 0
  @State isHovered: boolean = false // 悬停状态
  @State isPressed: boolean = false // 按压状态
  @Prop playlist: Playlist
  onPlaylistSelected?: (playlist: Playlist) => void;

  @StorageLink('aggregation_playlist') aggregationPlaylist: Playlist[] = PreferencesCache.getPlaylistCache('aggregation_playlist')

  build() {
    // 外层包装 - 添加间距
    Column() {
      Row({ space: 8 }) {
        // 现代化封面 - 移除不必要的Stack，直接使用Image
        Image(cover(this.playlist?.cover || '', 120) ?? this.playlist?.cover)
          .width(48)
          .height(48)
          .aspectRatio(1)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .backgroundColor($r('app.color.skeleton_loading'))
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
          .draggable(false)
          .clip(true)
          .animation({
            duration: AnimationConstants.DURATION_FAST,
            curve: AnimationConstants.CURVE_DECELERATE
          })

        // 歌单信息 - 与SongInfo一致的布局
        Column({ space: 6 }) {
          Text(this.playlist?.name || '未知歌单')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_title'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(StyleConstants.FULL_WIDTH)

          // 歌曲数量信息
          if (this.playlist?.size || this.playlist?.size === 0) {
            Text(`${this.playlist.size}首`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width(StyleConstants.FULL_WIDTH)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 现代化更多按钮 - 与SongInfo一致
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_more'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.icon_normal'))
            .opacity(0.9)
        }
        .width(48)
        .height(48)
        .backgroundColor(Color.Transparent)
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .hoverEffect(HoverEffect.Highlight)
        .bindMenu(
          this.isShowMenu,
          this.generatePlaylistMenu(this.playlist),
          {
            onDisappear: () => {
              this.isShowMenu = false
            }
          })
        .onClick(() => {
          this.isShowMenu = true
          VibrationControl.handlePresetVibration()
        })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(68)
      .padding({ left: 12, right: 12 })
      .borderRadius(10)
      .backgroundColor(this.getBackgroundColor())
      .backgroundBlurStyle(this.isHovered || this.isPressed ? BlurStyle.COMPONENT_THICK : BlurStyle.NONE)
      // .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .onClick(() => {
        if (this.onPlaylistSelected) {
          this.onPlaylistSelected(this.playlist);
        }
      })
      .onHover((isHover: boolean) => {
        this.isHovered = isHover;
      })
      .gesture(
        LongPressGesture({
          fingers: 1,
          repeat: false
        })
          .onAction(() => {
            this.isShowMenu = true
            VibrationControl.handlePresetVibration()
          })
      )
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
      .hoverEffect(HoverEffect.Highlight)
      .stateStyles({
        pressed: {
          .scale({ x: 0.98, y: 0.98 })
        },
        normal: {
          .scale({ x: 1, y: 1 })
        }
      })
      .animation({
        duration: AnimationConstants.DURATION_FAST,
        curve: AnimationConstants.CURVE_DECELERATE
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
  }

  // 获取背景颜色 - 增强视觉反馈
  private getBackgroundColor(): ResourceColor {
    if (this.isPressed) {
      return $r('app.color.interactive_pressed')
    }
    if (this.isHovered) {
      return $r('app.color.card_hover')
    }
    return $r('app.color.card_background')
  }

  private generatePlaylistMenu(playlist: Playlist): Array<MenuElement> {
    if(playlist?.type === PlaylistType.AGGREGATION){
      return [
        {
          value: $r('app.string.play_this_playlist'),
          action: () => {
            PushPathHelper.loading("Playing", async () => {
              const songs = JSON.parse(PreferencesCache.getCache(`aggregation_playlist_songs_${playlist.id}`, '[]')) as Song[]
              const playableSongs = songs.filter(song => song.privilege.playable)
              if (!playableSongs || playableSongs.length === 0) {
                ToastUtil.showShort("此歌单无可播放歌曲")
                return
              }
              PlaylistManager.loadPlaylist(playableSongs, playableSongs[0])
            })
          }
        },
        {
          value: $r('app.string.add_to_play_next'),
          action: () => {
            PushPathHelper.loading("Playing", async () => {
              const songs = JSON.parse(PreferencesCache.getCache(`aggregation_playlist_songs_${playlist.id}`, '[]')) as Song[]
              const playableSongs = songs.filter(song => song.privilege.playable)
              if (!playableSongs || playableSongs.length === 0) {
                ToastUtil.showShort("此歌单无可播放歌曲")
                return
              }
              PlaylistManager.insertSongs(playableSongs)
            })
          }
        },
        {
          value: $r('app.string.download_all_songs'),
          action: () => {
            const songs = JSON.parse(PreferencesCache.getCache(`aggregation_playlist_songs_${playlist.id}`, '[]')) as Song[]
            const playableSongs = songs.filter(song => song.privilege.playable)
            if (playableSongs.length > 0) {
              SongDownloadManager.batchDownloadSongs(playableSongs)
            }
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
                const songs = JSON.parse(PreferencesCache.getCache(`aggregation_playlist_songs_${playlist.id}`, '[]')) as Song[]
                PreferencesCache.addSongsToAggregationPlaylist(this.aggregationPlaylist[this.selectedIndex], songs)
              },
              onAction: (): void => {}
            })
          }
        },
        {
          value: $r('app.string.edit_playlist_info'),
          action: () => {
            let options: CustomContentOptions = {
              title: $r('app.string.edit_playlist_info'),
              contentBuilder: (): void => {
                this.CustomTextBuilder()
              },
              onAction: (action) => {
                if(action === DialogAction.TWO){
                  this.updateAggregationPlaylist(playlist)
                }
              }
            }
            this.playlistName = playlist.name
            this.playlistDesc = playlist.description
            DialogHelper.showCustomContentDialog(options)
          }
        },
        {
          value: $r('app.string.delete_playlist'),
          action: () => {
            DialogHelper.showAlertDialog({
              primaryTitle: `是否删除歌单[${playlist.name}]？`,
              primaryButton: $r('app.string.cancel'),
              secondaryButton: $r('app.string.confirm'),
              onAction: (action: number, _: string): void => {
                if(action === DialogAction.TWO){
                  this.deleteFromAggregationPlaylist(playlist)
                }
              }
            })
          }
        }
      ]
    }else{
      return [
        {
          value: $r('app.string.play_this_playlist'),
          action: () => {
            PushPathHelper.loading("Playing", async () => {
              const playlistDetail = await SourceAdapter.getPlaylistDetail(playlist)
              const songs = playlistDetail?.songs?.filter(song => song.privilege.playable)
              if (!songs || songs.length === 0) {
                ToastUtil.showShort("此歌单无可播放歌曲")
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
                ToastUtil.showShort("此歌单无可播放歌曲")
                return
              }
              PlaylistManager.insertSongs(songs)
            })
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
              onCheckedChanged: async (index) => {
                this.selectedIndex = index
                const playlistDetail = await SourceAdapter.getPlaylistDetail(playlist)
                PreferencesCache.addSongsToAggregationPlaylist(this.aggregationPlaylist[this.selectedIndex], playlistDetail.songs as Song[])
              },
              onAction: (): void => {}
            })
          }
        },
        {
          value: $r('app.string.download_all_songs'),
          action: () => {
            if (this.playlist?.songs && this.playlist.songs.length > 0) {
              const songs = this.playlist.songs.filter(song => song.privilege.playable)
              SongDownloadManager.batchDownloadSongs(songs)
            }
          }
        }
      ]
    }
  }

  updateAggregationPlaylist(playlist: Playlist) {
    let playlistName: string = this.playlistName?.trim() && this.playlistName.trim() !== '' ? this.playlistName.trim() : ResourceManager.getStringValueSync($r('app.string.default_playlist_name'))
    let playlistDesc: string = this.playlistDesc?.trim() && this.playlistDesc?.trim() !== '' ? this.playlistDesc?.trim() : ResourceManager.getStringValueSync($r('app.string.default_playlist_desc'))
    try {
      PreferencesCache.updatePlaylistsCache(
        'aggregation_playlist',
        playlist,
        playlistName,
        playlistDesc)
      LogUtil.info(`[${TAG}]`, `歌单[${playlist.id}][${playlistName}]更新成功: ${JSON.stringify(playlist)}`)
    } catch(error) {
      LogUtil.info(`[${TAG}]`, `歌单[${playlist.id}][${this.playlistName}]更新失败: ${JSON.stringify(error)}`)
    } finally {
      this.playlistName = undefined
      this.playlistDesc = undefined
    }
  }

  deleteFromAggregationPlaylist(playlist: Playlist) {
    try {
      PreferencesCache.deleteCache(`aggregation_playlist_songs_${playlist.id}`)
      PreferencesCache.deletePlaylistCache('aggregation_playlist', playlist)
      ToastUtil.showShort("成功删除歌单")
      LogUtil.info(`[${TAG}]`, `歌单[${playlist.id}][${playlist.name}]删除成功`)
    } catch(error) {
      ToastUtil.showShort("删除歌单失败!")
      LogUtil.info(`[${TAG}]`, `歌单[${playlist.id}][${playlist.name}]删除失败: ${JSON.stringify(error)}`)
    }
  }

  @Builder
  CustomTextBuilder() {
    AddAggregationPlaylist({
      playlistName: this.playlistName,
      playlistDesc: this.playlistDesc
    })
  }

}