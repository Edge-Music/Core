import { DialogAction, DialogHelper } from "@pura/harmony-dialog";
import { LogUtil, ToastUtil } from "@pura/harmony-utils";
import { StyleConstants } from "../constants/StyleConstants";
import { Playlist, PlaylistType, Song } from "../type/Adapter";
import { PlaylistManager } from "../util/PlaylistManager";
import { PreferencesCache } from "../util/PreferenceCache";
import { SongCacheManager } from "../util/SongCacheManager";
import { SongDownloadManager } from "../util/SongDownloadManager";
import { pasteboard } from '@kit.BasicServicesKit';
import { VibrationControl } from "../util/DeviceController";

const TAG = 'SongInfo'

@Component
export struct SongInfo {
  @StorageLink('aggregation_playlist') aggregationPlaylist: Playlist[] = PreferencesCache.getPlaylistCache('aggregation_playlist')
  @Prop playlistId: number | string
  @Prop playlistType: PlaylistType
  @Prop song: Song
  @Prop cover: string | Resource
  showBorder: boolean = true;
  onTap?: (song: Song) => void;
  deleteSong?: (song: Song) => void;
  @Prop active: boolean = false;
  @Prop disabled: boolean = false;
  @Prop index: number = 0;
  @Prop isShowMenu: boolean
  @Prop showIndex: boolean = true;
  @Watch('updateHighlightState') @Prop highlight: boolean = false; // 新增高亮参数
  @BuilderParam rightSlot?: () => void;
  @State On_Mouse:boolean =false
  // 用于高亮动画的状态变量
  @State private isHighlighting: boolean = false;
  @State selectedIndex: number = 0
  // 歌曲下载状态
  @State isDownloaded: boolean = false;
  @State isCached: boolean = false;

  // 监听highlight属性变化
  aboutToAppear() {
    this.updateHighlightState();
    this.checkDownloadStatus();
  }

  // 检查歌曲下载状态
  private checkDownloadStatus() {
    if (this.song && this.song.id) {
      this.isDownloaded = SongDownloadManager.hasSong(this.song.id.toString());
      const key = `${this.song.id}_${this.song.source?.id}`;
      this.isCached = SongCacheManager.has(key);
    }
  }

  updateHighlightState() {
    if (this.highlight) {
      this.isHighlighting = true;
      // 高亮持续0.3秒后自动消失
      setTimeout(() => {
        this.isHighlighting = false;
      }, 300);
    }
  }

  private getTextColor(defaultColor: Resource) {
    if (this.disabled) {
      return $r('app.color.text_hint');
    }
    if (this.active) {
      return $r('app.color.text_click');
    }
    return defaultColor;
  }

  // 获取背景颜色
  private getBackgroundColor() {
    if (this.isHighlighting) {
      return $r('app.color.interactive_hover'); // 使用新配色
    }
    return $r('app.color.card_background');
  }

  // 复制歌曲信息到剪贴板
  private copySongInfo() {
    if (!this.song) {
      return;
    }

    let copyText = '';

    // 构建艺术家信息
    if (this.song.artists && this.song.artists.length > 0) {
      const artistNames = this.song.artists.map(artist => artist.name).join(' / ');
      copyText = `${artistNames} - ${this.song.name || '未知歌曲'}`;
    } else {
      // 如果没有艺术家信息，只复制歌曲名称
      copyText = this.song.name || '未知歌曲';
    }

    try {
      // 创建剪贴板数据
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, copyText);

      // 获取系统剪贴板
      const systemPasteboard = pasteboard.getSystemPasteboard();

      // 将数据写入剪贴板
      systemPasteboard.setData(pasteData).then(() => {
        LogUtil.info(TAG, `歌曲信息已复制到剪贴板: ${copyText}`);
        ToastUtil.showShort($r('app.string.copied_to_clipboard'));
        VibrationControl.handlePresetVibration()
      }).catch((err: Error) => {
        LogUtil.error(TAG, '复制到剪贴板失败', err.message);
        ToastUtil.showShort($r('app.string.copy_failed'));
      });
    } catch (error) {
      LogUtil.error(TAG, '创建剪贴板数据失败', error);
      ToastUtil.showShort($r('app.string.copy_failed'));
    }
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        if (this.showIndex) {
          // 序号区域 - 扁平简约设计
          Text((this.index + 1).toString())
            .width(28)
            .maxFontSize(15)
            .minFontSize(10)
            .maxLines(1)
            .fontColor(this.getTextColor($r('app.color.text_secondary')))
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
        }

        Image(this.cover)
          .aspectRatio(1)
          .borderRadius(8)
          .height(48)
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)

        // 歌曲信息区域
        Column({ space: 6 }) {

          Row({ space: 2 }) {

            // 歌曲名称（包含别名）
            Text() {
              Span(this.song?.name || '未知歌曲')
                .fontSize(16)
                .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
                .fontColor(this.getTextColor($r('app.color.text_title')))

              if (this.song && this.song.tns && this.song.tns.length > 0) {
                Span(` (${this.song.tns.join('/')})`)
                  .fontSize(16)
                  .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
                  .fontColor(this.getTextColor($r('app.color.text_secondary')))
              }
            }
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          // 艺术家信息和下载状态
          Row({ space: 2 }) {

            // 下载状态标签
            Image($r('app.media.ic_downloaded'))
              .width(12)
              .aspectRatio(1)
              .visibility(this.isDownloaded ? Visibility.Visible : Visibility.None)

            // 下载状态标签
            Image($r('app.media.ic_cached'))
              .width(12)
              .aspectRatio(1)
              .visibility(!this.isDownloaded && this.isCached ? Visibility.Visible : Visibility.None)

            if (this.song && this.song.artists?.length > 0) {
              Text(this.song.artists.map(artist => artist.name).join(' / '))
                .fontSize(14)
                .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
                .fontColor(this.getTextColor($r('app.color.text_secondary')))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            } else {
              Text('未知艺术家')
                .fontSize(14)
                .fontWeight(StyleConstants.FONT_WEIGHT_FOUR)
                .fontColor(this.getTextColor($r('app.color.text_secondary')))
                .layoutWeight(1)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .gesture(
          LongPressGesture({ repeat: false, duration: 500 })
            .onAction(() => {
              this.copySongInfo();
            })
        )

        if(this.isShowMenu){
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_more'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.icon_normal'))
              .opacity(0.9)
          }
          .width(48)
          .height(48)
          .bindMenu(this.generateSongMenu(this.song))
          .onClick(() => {
            VibrationControl.handlePresetVibration()
          })
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .stateStyles({
            pressed: this.pressedMenuStyles,
            normal: this.normalMenuStyles
          })
        }

        // 右侧插槽 - 简约处理
        if (this.rightSlot) {
          this.rightSlot()
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(68)
      .padding({ left: 12, right: 12 })
      .borderRadius(10)
      .onHover((isHover: boolean, _: HoverEvent)=>{
          this.On_Mouse =isHover
      })
      .backgroundColor(this.On_Mouse ? $r('app.color.card_hover') : this.getBackgroundColor())
      // .border({
      //   width: 1,
      //   color: this.getBorderColor(),
      //   style: BorderStyle.Solid
      // })
      .opacity(this.disabled ? 0.6 : 1)
      .animation({
        duration: 300,
        curve: Curve.EaseInOut,
        iterations: 1
      })
      .onClick(() => {
        if (!this.disabled && this.onTap && this.song) {
          this.onTap(this.song);
        }
      })
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .stateStyles({
        pressed: this.pressedStyles,
        normal: this.normalStyles
      })
    }

    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
  }

  generateSongMenu(song: Song): Array<MenuElement> {
    if(this.playlistType === PlaylistType.AGGREGATION) {
      return [
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
                PreferencesCache.addSongToAggregationPlaylist(this.aggregationPlaylist[this.selectedIndex], song).then((result: boolean) => {
                  if(result){
                    ToastUtil.showShort(`[${song.name}]存在于[${this.aggregationPlaylist[index].name}]`)
                  }else{
                    ToastUtil.showShort(`[${song.name}]添加到[${this.aggregationPlaylist[index].name}]`)
                  }
                })
              },
              onAction: (): void => {}
            })
          }
        },
        {
          value: $r('app.string.download_this_song'),
          action: () => {
            this.downloadSong()
          }
        },
        {
          value: $r('app.string.add_to_play_next'),
          action: () => {
            PlaylistManager.insertSongs([song])
          }
        },
        {
          value: $r('app.string.delete_song'),
          action: () => {
            DialogHelper.showAlertDialog({
              primaryTitle: `是否删除歌曲[${song.name}]？`,
              primaryButton: $r('app.string.cancel'),
              secondaryButton: $r('app.string.confirm'),
              onAction: (action: number): void => {
                if(action === DialogAction.TWO){
                  this.deleteFromAggregationSongs(this.playlistId, song)
                  if(this.deleteSong) {
                    this.deleteSong(song)
                  }
                }
              }
            })
          }
        }
      ]
    } else {
      return [
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
                PreferencesCache.addSongToAggregationPlaylist(this.aggregationPlaylist[this.selectedIndex], song).then((result: boolean) => {
                  if(result){
                    ToastUtil.showShort(`[${song.name}]存在于[${this.aggregationPlaylist[index].name}]`)
                  }else{
                    ToastUtil.showShort(`[${song.name}]添加到[${this.aggregationPlaylist[index].name}]`)
                  }
                })
                if(this.playlistId === this.aggregationPlaylist[this.selectedIndex].id){
                  AppStorage.setOrCreate('current_playlist_data', this.aggregationPlaylist[this.selectedIndex])
                }
              },
              onAction: (): void => {}
            })
          }
        },
        {
          value: $r('app.string.download_this_song'),
          action: () => {
            this.downloadSong()
          }
        },
        {
          value: $r('app.string.add_to_play_next'),
          action: () => {
            PlaylistManager.insertSongs([song])
          }
        }
      ]
    }
  }

  async deleteFromAggregationSongs(playlistId: number | string, song: Song) {
    try {
      PreferencesCache.deleteSongCache('aggregation_playlist', playlistId, song)
      ToastUtil.showShort("成功删除歌曲")
      LogUtil.info(`[${TAG}]`, `歌曲[${song.name}]删除成功`)
    } catch(error) {
      ToastUtil.showShort("删除歌曲失败!")
      LogUtil.info(`[${TAG}]`, `歌曲[${song.name}]删除失败: ${JSON.stringify(error)}`)
    }
  }

  async downloadSong() {
    if (this.song) {
      const success = SongDownloadManager.downloadSong(
        this.song.id.toString(),
        this.song
      );
      if (success) {
        ToastUtil.showShort($r('app.string.added_to_the_download_queue'));
        // 下载完成后更新状态
        this.checkDownloadStatus();
      }
    }
  }

  @Styles pressedStyles(): void {
    .borderWidth(1)
    .borderColor($r('app.color.text_click'))
  }

  @Styles normalStyles(): void {
    .borderWidth(0)
  }

  @Styles pressedMenuStyles(): void {
    .backgroundColor($r("app.color.homepage_menu_button_pressed"))
    .animation({ duration: 300, curve: Curve.LinearOutSlowIn })
  }

  @Styles normalMenuStyles(): void {
    .backgroundColor('transparent')
    .animation({ duration: 300, curve: Curve.LinearOutSlowIn })
  }
}