import { CustomContentOptions, DialogAction, DialogHelper } from "@pura/harmony-dialog";
import { LogUtil, ToastUtil } from "@pura/harmony-utils";
import { SourceAdapter } from "../adapter";
import { StyleConstants } from "../constants/StyleConstants";
import { Playlist, PlaylistType, Song } from "../type/Adapter";
import { cover } from "../util/AdapterHelper";
import { PlaylistManager } from "../util/PlaylistManager";
import { PreferencesCache } from "../util/PreferenceCache";
import { PushPathHelper } from "../util/PushPathHelper";
import ResourceManager from "../util/ResourceManager";
import { SongDownloadManager } from "../util/SongDownloadManager";
import { AddAggregationPlaylist } from "./CustomTextBuilder";
const TAG = 'PlaylistItem'

@Reusable
@Component
export struct PlaylistItem {
  @State playlistName: string | undefined = undefined
  @State playlistDesc: string | undefined = undefined
  @State isShowMenu: boolean = false
  @Prop playlist: Playlist
  onPlaylistSelected?: (playlist: Playlist) => void;

  build() {
    Row() {
      // 封面图 - 现代直角设计
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(cover(this.playlist?.cover || '', 120) ?? this.playlist?.cover)
          .width(58)
          .height(58)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .draggable(false)
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      }
      .margin({ right: 12 })

      // 歌单信息 - 层次分明的布局
      Column({ space: 12 }) {
        Text(this.playlist?.name || '未知歌单')
          .fontSize(15)
          .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 歌曲信息
        if (this.playlist?.size || this.playlist?.size === 0) {
          Text(`${this.playlist.size}首`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 更多操作按钮
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_more'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.icon_normal'))
          .opacity(0.9)
      }
      .width(48)
      .height(48)
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
      })
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .stateStyles({
        pressed: this.pressedStyles,
        normal: this.normalStyles
      })

    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 16, right: 16, top: 0, bottom: 0 })
    .height(74)
    .onClick(() => {
      if (this.onPlaylistSelected) {
        this.onPlaylistSelected(this.playlist);
      }
    })
    .gesture(
      LongPressGesture({
        fingers: 1,
        repeat: false
      })
        .onAction(() => {
          this.isShowMenu = true
        })
    )
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .animation({ duration: 300, curve: Curve.LinearOutSlowIn })
  }

  @Styles pressedStyles(): void {
    .backgroundColor($r("app.color.homepage_menu_button_pressed"))
    .animation({ duration: 300, curve: Curve.LinearOutSlowIn })
  }

  @Styles normalStyles(): void {
    .backgroundColor('transparent')
    .animation({ duration: 300, curve: Curve.LinearOutSlowIn })
  }

  private generatePlaylistMenu(playlist: Playlist): Array<MenuElement> {
    if(playlist?.type === PlaylistType.AGGREGATION){
      return [
        {
          value: $r('app.string.play_this_playlist'),
          action: () => {
            PushPathHelper.loading("Playing", async () => {
              const playlistDetail = await SourceAdapter.getAggregationPlaylistDetail(playlist)
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
              const playlistDetail = await SourceAdapter.getAggregationPlaylistDetail(playlist)
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
          value: $r('app.string.download_all_songs'),
          action: () => {
            if (this.playlist?.songs && this.playlist.songs.length > 0) {
              const songs = this.playlist.songs.filter(song => song.privilege.playable)
              SongDownloadManager.batchDownloadSongs(songs)
            }
          }
        },
        {
          value: $r('app.string.edit_playlist_info'),
          action: () => {
            let options: CustomContentOptions = {
              title: $r('app.string.create_playlist'),
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
              onAction: (action: number, dialogId: string): void => {
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
      LogUtil.info(`[${TAG}]`, `歌单[${playlist.id}][${playlistName}]更新成功`)
    } catch(error) {
      LogUtil.info(`[${TAG}]`, `歌单[${playlist.id}][${this.playlistName}]更新失败: ${JSON.stringify(error)}`)
    } finally {
      this.playlistName = undefined
      this.playlistDesc = undefined
    }
  }

  deleteFromAggregationPlaylist(playlist: Playlist) {
    try {
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