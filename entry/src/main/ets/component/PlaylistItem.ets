import { ToastUtil } from "@pura/harmony-utils";
import { SourceAdapter } from "../adapter";
import { StyleConstants } from "../constants/StyleConstants";
import { Playlist } from "../type/Adapter";
import { cover } from "../util/AdapterHelper";
import { PlaylistManager } from "../util/PlaylistManager";
import { PushPathHelper } from "../util/PushPathHelper";

@Reusable
@Component
export struct PlaylistItem {
  @Prop playlist: Playlist
  onPlaylistSelected?: (playlist: Playlist) => void;

  build() {
    Row() {
      // 封面图 - 现代直角设计
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(cover(this.playlist?.cover || '', 120))
          .width(58)
          .height(58)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
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
        if (this.playlist?.size) {
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
      .bindMenu(this.generatePlaylistMenu(this.playlist))
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
      }
    ]
  }
}