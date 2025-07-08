import { DialogAction, DialogHelper } from "@pura/harmony-dialog";
import { LogUtil, ToastUtil } from "@pura/harmony-utils";
import { StyleConstants } from "../constants/StyleConstants";
import { Playlist, PlaylistType, Song } from "../type/Adapter";
import { PreferencesCache } from "../util/PreferenceCache";
const TAG = 'SongInfo'

@Reusable
@Component
export struct SongInfo {
  @StorageLink('aggregation_playlist') aggregationPlaylist: Playlist[] = PreferencesCache.getPlaylistCache('aggregation_playlist')
  @Prop playlistId: number | string
  @Prop playlistType: PlaylistType
  @Prop song: Song
  showBorder: boolean = true;
  onTap?: (song: Song) => void;
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

  // 监听highlight属性变化
  aboutToAppear() {
    this.updateHighlightState();
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
      return 'rgba(100, 149, 237, 0.15)'; // 高亮背景色
    }
    return $r('app.color.setting_item_background');
  }

  // 获取边框颜色
  private getBorderColor() {
    if (this.isHighlighting) {
      return 'rgba(100, 149, 237, 0.4)'; // 高亮边框色
    } else if (!this.showBorder) {
      return Color.Transparent;
    }
    return $r('app.color.border_line');
  }

  build() {
    Column() {
      Row() {
        if (this.showIndex) {
          // 序号区域 - 扁平简约设计
          Text((this.index + 1).toString())
            .fontSize(15)
            .fontColor(this.getTextColor($r('app.color.text_secondary')))
            .fontWeight(FontWeight.Medium)
            .width(28)
            .textAlign(TextAlign.Center)
            .margin({ right: 16 })
        }

        // 歌曲信息区域
        Column({ space: 6 }) {
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

          // 艺术家信息
          if (this.song && this.song.artists?.length > 0) {
            Text(this.song.artists.map(artist => artist.name).join(' / '))
              .fontSize(14)
              .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
              .fontColor(this.getTextColor($r('app.color.text_secondary')))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            Text('未知艺术家')
              .fontSize(14)
              .fontWeight(StyleConstants.FONT_WEIGHT_FOUR)
              .fontColor(this.getTextColor($r('app.color.text_secondary')))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

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
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .width(StyleConstants.FULL_WIDTH)
      .height(68)
      .padding({ left: 16, right: 16 })
      .borderRadius(10)
      .onHover((isHover: boolean, event: HoverEvent)=>{
          this.On_Mouse =isHover
      })
      .backgroundColor(this.On_Mouse? 'rgba(100, 149, 237, 0.15)':this.getBackgroundColor())
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
                if(PreferencesCache.addSongToAggregationPlaylist(this.aggregationPlaylist[this.selectedIndex], song)){
                  ToastUtil.showShort(`已存在于[${this.aggregationPlaylist[index].name}]`)
                }else{
                  ToastUtil.showShort(`已添加到[${this.aggregationPlaylist[index].name}]`)
                }
                if(this.playlistId === this.aggregationPlaylist[this.selectedIndex].id){
                  AppStorage.setOrCreate('current_playlist_data', this.aggregationPlaylist[this.selectedIndex])
                }
              },
              onAction: (): void => {}
            })
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
                if(PreferencesCache.addSongToAggregationPlaylist(this.aggregationPlaylist[this.selectedIndex], song)){
                  ToastUtil.showShort(`已存在于[${this.aggregationPlaylist[index].name}]`)
                }else{
                  ToastUtil.showShort(`已添加到[${this.aggregationPlaylist[index].name}]`)
                }
                if(this.playlistId === this.aggregationPlaylist[this.selectedIndex].id){
                  AppStorage.setOrCreate('current_playlist_data', this.aggregationPlaylist[this.selectedIndex])
                }
              },
              onAction: (): void => {}
            })
          }
        }
      ]
    }
  }

  deleteFromAggregationSongs(playlistId: number | string, song: Song){
    try {
      PreferencesCache.deleteSongCache('aggregation_playlist', playlistId, song)
      ToastUtil.showShort("成功删除歌曲")
      LogUtil.info(`[${TAG}]`, `歌曲[${song.name}]删除成功`)
    } catch(error) {
      ToastUtil.showShort("删除歌曲失败!")
      LogUtil.info(`[${TAG}]`, `歌曲[${song.name}]删除失败: ${JSON.stringify(error)}`)
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