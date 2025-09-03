import { ToastUtil } from "@pura/harmony-utils";
import { SourceAdapter } from "../adapter";
import { FooterPlaceholder } from "../component/FooterPlaceholder";
import { HeaderAnimation } from "../component/HeaderAnimation";
import { HeaderPlaceholder } from "../component/HeaderPlaceholder";
import { MiniPlaybackControl } from "../component/MiniPlaybackControl";
import { Segment } from "../component/Segment";
import { TitleHeader } from "../component/TitleHeader";
import { StyleConstants } from "../constants/StyleConstants";
import { Album, Artist, Playlist, SearchResult, Song } from "../type/Adapter";
import { HeaderComponent } from "../util/HeaderComponent";
import { PlaylistManager } from "../util/PlaylistManager";
import { PushPathHelper } from "../util/PushPathHelper";
import ResourceManager from "../util/ResourceManager";
import { ScrollController } from "../util/ScrollController";

const TAG = 'MultiSearch'

@Component
export struct MultiSearch {
  @State groupHeight: number = 0
  @Consume('NavPathStack') pageStack: NavPathStack;
  @State keywords: string = '';
  @State result: SearchResult | null = null;
  @State loading: boolean = false;
  @State nullResultFlag: boolean = true
  @State scrollOffsetY: number = 0
  @State startScrollOffsetY: number = 0
  @State placeholderOffset: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('winHeight') winHeight: number = 0
  private scroller: Scroller = new Scroller();
  @State scrollController: ScrollController = new ScrollController({
    onIndexChange: (index): void => this.onMenuIconClick(index),
    componentTag: TAG
  }).linkController(this.scroller)

  private generatePlaylistMenu(playlist: Playlist) {
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
    // {
    //   value: '收藏此歌单',
    //   action: () => {
    //   }
    // }
    ] as MenuElement[]
  }

  private generateSongMenu(song: Song) {
    return [
      {
        value: $r('app.string.add_to_play_next'),
        action: () => {
          PlaylistManager.insertSongs([song])
        }
      },
    // {
    //   value: '收藏到歌单',
    //   action: () => {
    //   }
    // }
    ] as MenuElement[]
  }

  async search() {
    this.loading = true
    this.nullResultFlag = true
    this.result = await SourceAdapter.search(this.keywords)
    this.loading = false
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }){
        Column(){

          List({ scroller: this.scroller}){
            HeaderPlaceholder({ offsetY: this.placeholderOffset+10 })

            ListItem(){
              HeaderAnimation({ scrollController: this.scrollController })
            }

            ListItemGroup(){
              if(this.result){
                // 歌曲
                if(this.isNullResult(this.result.songs)){
                  Segment({
                    lists: this.result.songs,
                    type: 'Song',
                    title: "歌曲",
                    loading: this.loading,
                  })
                }
                // 歌单
                if(this.isNullResult(this.result.playlists)){
                  Segment({
                    lists: this.result.playlists,
                    type: 'Playlist',
                    title: "歌单",
                    loading: this.loading,
                  })
                }
                // 艺人
                if(this.isNullResult(this.result.artists)){
                  Segment({
                    lists: this.result.artists,
                    type: 'Artist',
                    title: "歌手",
                    loading: this.loading,
                    radius: "100%",
                  })
                }
                // 专辑
                if(this.isNullResult(this.result.albums)){
                  Segment({
                    lists: this.result.albums,
                    type: 'Album',
                    title: "专辑",
                    loading: this.loading,
                  })
                }
                // 如果结果为空
                if(this.nullResultFlag){
                  ListItem(){
                    this.EmptySearchResult(ResourceManager.getStringValueSync($r('app.string.search_no_result')))
                  }
                }
              } else {
                ListItem(){
                  this.EmptySearchResult(ResourceManager.getStringValueSync($r('app.string.start_search')))
                }
              }

            }
            .onAreaChange((_: Area, newValue: Area) => {
              this.groupHeight = newValue.height as number
            })

            ListItem(){
              Row(){
                // 监控ListItemGroup高度变化，随时调整List下方补充高度，winHeight - group高度 - 标题高度 - 避让高度
                Blank().height(this.getBlankHeight())
              }
            }

            FooterPlaceholder()
          }
          .backToTop(true)
          .layoutWeight(1)
          .height(StyleConstants.FULL_HEIGHT)
          .width(StyleConstants.FULL_WIDTH)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .sticky(StickyStyle.Header | StickyStyle.Footer)
          .onWillScroll(this.scrollController.scrollHandlers.onWillScroll)
          .onScrollStop(this.scrollController.scrollHandlers.onScrollStop)
          .onDidScroll((_: number, scrollState: ScrollState) => {
            this.scrollOffsetY = this.scroller.currentOffset().yOffset
          })
          .onTouch((event) => {
            switch (event.type) {
              case TouchType.Down:
                this.startScrollOffsetY = this.scroller.currentOffset().yOffset
            }
          })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)

        MiniPlaybackControl()

        HeaderComponent({
          scrollOffsetY: this.scrollOffsetY,
          startScrollOffsetY: this.startScrollOffsetY,
          hasHeaderBuilder: true,
          titleBuilder: () => {
            this.Title()
          },
          headerBuilder: () => {
            this.SearchComponent()
          }
        })
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

  /**
   * 判断结果非空公共方法
   * @param list
   * @returns
   */
  isNullResult(list: Song[] | Playlist[] | Artist[] | Album[] | undefined) {
    if(list && list.length > 0){
      this.nullResultFlag = false
      return true
    }
    return false
  }

  getBlankHeight(): Length {
    let sub = this.winHeight - this.groupHeight - 50 - (this.bottomRect+this.topRect) - this.placeholderOffset - 10
    return sub > 0 ? sub : 0
  }

  @Builder
  SearchComponent() {
    Row() {
      Search({ value: this.keywords, placeholder: $r('app.string.search_what_you_want') })
        .searchButton(ResourceManager.getStringValueSync($r('app.string.search')))
        .onSubmit(async (value: string) => {
          this.keywords = value
          await this.search()
        })
        .margin(0)
        .defaultFocus(true)
        .backgroundBlurStyle(BlurStyle.Regular)
        .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    }
    .onAreaChange((_: Area, newValue: Area) => {
      this.placeholderOffset = newValue.height as number
    })
    .padding({
      top: 8,
      bottom: 4,
      left: 12,
      right: 12
    })

  }

  @Builder
  Title() {
    TitleHeader({
      title: $r('app.string.search'),
      backActive: this.scrollController.currentIndex === 0
    })
  }

  @Builder
  EmptySearchResult(reason: string) {
    Column() {
      Row() {
        Text(reason)
          .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
          .fontColor($r('app.color.text_hint'))
          .fontSize(16)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  onMenuIconClick(index: number) {
    if (index === 0 && this.pageStack.size() > 1) {
      this.pageStack.pop();
    } else if (index === 1) {
      // 触发other
    }
  }
}