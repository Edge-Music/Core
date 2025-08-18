import { LazyData } from "@pie/lazy-data";
import { CustomContentOptions, DialogAction, DialogHelper } from "@pura/harmony-dialog";
import { HeaderAnimation } from "../component/HeaderAnimation";
import { MiniPlaybackControl } from "../component/MiniPlaybackControl";
import { PlaylistItem } from "../component/PlaylistItem";
import { TitleHeader } from "../component/TitleHeader";
import { StyleConstants } from "../constants/StyleConstants";
import { Playlist, PlaylistType, Song } from "../type/Adapter";
import { PreferencesCache } from "../util/PreferenceCache";
import { PushPathHelper } from "../util/PushPathHelper";
import { ScrollController } from "../util/ScrollController";
import { LogUtil } from "@pura/harmony-utils";
import { AddAggregationPlaylist } from "../component/CustomTextBuilder";
import ResourceManager from "../util/ResourceManager";

const TAG = 'Aggregation'

@Component
export struct Aggregation {

  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('aggregation_playlist') aggregationPlaylist: Playlist[] = PreferencesCache.getPlaylistCache('aggregation_playlist')
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('winHeight') winHeight: number = 0
  private scroller: Scroller = new Scroller()

  @State groupHeight: number = 0
  @State aggregationData: LazyData<Playlist> = new LazyData<Playlist>(this.aggregationPlaylist)
  @State playlistName: string | undefined = undefined
  @State playlistDesc: string | undefined = undefined
  @State playlistCover: Resource | string = $r('app.media.icon_startwindow')
  @State scrollController: ScrollController = new ScrollController({
    onIndexChange: (index): void => this.onMenuIconClick(index),
    componentTag: TAG
  }).linkController(this.scroller)

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column(){
          this.Title()

          this.AggregatePlayList()
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)

        MiniPlaybackControl()

        this.AddButton()
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .hideToolBar(true)
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_background'))
    .mode(NavDestinationMode.STANDARD)
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  @Builder
  Title() {
    TitleHeader({
      title: $r('app.string.aggregation'),
      backActive: this.scrollController.currentIndex === 0
    })
  }

  @Builder
  AggregatePlayList() {
    List({ scroller: this.scroller }){
      ListItem() {
        HeaderAnimation({ scrollController: this.scrollController, isShowLoadingProgress: true })
      }

      if(this.aggregationPlaylist.length === 0){
        ListItem() {
          Column() {
            Text($r('app.string.no_aggregation_playlist'))
              .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      } else {
        ListItemGroup(){
          ForEach(this.aggregationPlaylist, (playlist: Playlist, index: number) => {
            ListItem(){
              PlaylistItem({
                playlist: playlist,
                onPlaylistSelected: (item: Playlist) => {
                  let tmpSongs: Song[] = JSON.parse(PreferencesCache.getCache(`aggregation_playlist_songs_${playlist.id}`, '[]'))
                  PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                    AppStorage.setOrCreate('current_playlist_data', item)
                    AppStorage.setOrCreate('current_playlist_songs', tmpSongs)
                  })
                }
              })
            }
          })
        }
        .visibility(this.aggregationPlaylist.length > 0 ? Visibility.Visible : Visibility.None)
        .onAreaChange((_: Area, newValue: Area) => {
          this.groupHeight = newValue.height as number
        })

        ListItem(){
          Row(){
            // 监控ListItemGroup高度变化，随时调整List下方补充高度，winHeight - group高度 - 标题高度 - 避让高度
            Blank().height(this.getBlankHeight())
          }
        }
      }

      // 底部空白区域
      ListItem() {
        Column() {
          Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + this.bottomRect)
        }
      }
    }
    .backToTop(true)
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .layoutWeight(1)
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
    .onWillScroll(this.scrollController.scrollHandlers.onWillScroll)
    .onScrollStop(this.scrollController.scrollHandlers.onScrollStop)
  }

  onMenuIconClick(index: number) {
    if (index === 0 && this.pageStack.size() > 1) {
      this.pageStack.pop()
    }
  }

  @Builder
  CustomTextBuilder() {
    AddAggregationPlaylist({
      playlistName: this.playlistName,
      playlistDesc: this.playlistDesc
    })
  }

  @Builder
  AddButton() {
    Button({ type: ButtonType.Circle }){
      Text('󰀵')
        .fontColor($r('app.color.text_title'))
        .fontSize(36)
        .fontWeight(700)

    }
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK)
    .width(48)
    .height(48)
    .margin({
      right: 25,
      bottom: (this.bottomRect/2+StyleConstants.PLAYER_CONTROL_HEIGHT+40)
    })
    .onClick(() => {
      let options: CustomContentOptions = {
        title: $r('app.string.create_playlist'),
        contentBuilder: (): void => {
          this.CustomTextBuilder()
        },
        onAction: (action) => {
          if(action === DialogAction.TWO){
            this.createAggregationPlaylist()
          }
        }
      }
      DialogHelper.showCustomContentDialog(options)
    })
  }

  getBlankHeight(): Length {
    let sub = this.winHeight - this.groupHeight - 50 - (this.bottomRect+this.topRect)
    return sub > 0 ? sub : 0
  }

  createAggregationPlaylist(){
    let playlistName: string = this.playlistName?.trim() && this.playlistName.trim() !== '' ? this.playlistName.trim() : ResourceManager.getStringValueSync($r('app.string.default_playlist_name'))
    let playlistDesc: string = this.playlistDesc?.trim() && this.playlistDesc?.trim() !== '' ? this.playlistDesc?.trim() : ResourceManager.getStringValueSync($r('app.string.default_playlist_desc'))
    try {
      const timestamp: number = new Date().getTime();
      const playlist: Playlist = {
        id: `aggregation_playlist-${timestamp}`,
        name: playlistName,
        description: playlistDesc,
        cover: this.playlistCover,
        size: 0,
        type: PlaylistType.AGGREGATION
      }
      PreferencesCache.addPlaylistsCache('aggregation_playlist', [playlist])
      LogUtil.info(`[${TAG}]`, `歌单[${playlist.id}][${playlistName}]添加成功: ${JSON.stringify(playlist)}`)
      this.playlistCover = $r('app.media.icon_startwindow')
    } catch(error) {
      LogUtil.info(`[${TAG}]`, `歌单[${this.playlistName}]添加失败: ${JSON.stringify(error)}`)
    } finally {
      this.playlistName = undefined
      this.playlistDesc = undefined
    }
  }
}