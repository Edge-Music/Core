import { SourceAdapter } from "../adapter";
import { FooterPlaceholder } from "../component/FooterPlaceholder";
import { HeaderAnimation } from "../component/HeaderAnimation";
import { HeaderPlaceholder } from "../component/HeaderPlaceholder";
import { MiniPlaybackControl } from "../component/MiniPlaybackControl";
import { Segment } from "../component/Segment";
import { SearchFilter, SearchFilterType } from "../component/SearchFilter";
import { SearchResultList } from "../component/SearchResultList";
import { SourceFilter } from "../component/SourceFilter";
import { TitleHeader } from "../component/TitleHeader";
import { StyleConstants } from "../constants/StyleConstants";
import { AnimationConstants } from "../constants/AnimationConstants";
import { Album, Artist, ID, Playlist, SearchResult, Song, SourceConfig } from "../type/Adapter";
import { HeaderComponent } from "../component/HeaderComponent";
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
  @State selectedFilter: SearchFilterType = SearchFilterType.ALL
  @State selectedSourceIds: Set<ID> = new Set<ID>()
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

  async search() {
    this.loading = true
    this.nullResultFlag = true
    this.result = await SourceAdapter.search(this.keywords)
    this.loading = false
  }

  /**
   * 根据数据源筛选歌曲
   */
  private filterSongsBySource(songs: Song[] | undefined): Song[] {
    if (!songs) {
      return []
    }
    if (this.selectedSourceIds.size === 0) {
      return songs
    }
    const filtered: Song[] = []
    for (let i = 0; i < songs.length; i++) {
      const song = songs[i]
      const source = song.source as SourceConfig
      if (source && this.selectedSourceIds.has(source.id)) {
        filtered.push(song)
      }
    }
    return filtered
  }

  /**
   * 根据数据源筛选歌单
   */
  private filterPlaylistsBySource(playlists: Playlist[] | undefined): Playlist[] {
    if (!playlists) {
      return []
    }
    if (this.selectedSourceIds.size === 0) {
      return playlists
    }
    const filtered: Playlist[] = []
    for (let i = 0; i < playlists.length; i++) {
      const playlist = playlists[i]
      const source = playlist.source as SourceConfig
      if (source && this.selectedSourceIds.has(source.id)) {
        filtered.push(playlist)
      }
    }
    return filtered
  }

  /**
   * 根据数据源筛选歌手
   */
  private filterArtistsBySource(artists: Artist[] | undefined): Artist[] {
    if (!artists) {
      return []
    }
    if (this.selectedSourceIds.size === 0) {
      return artists
    }
    const filtered: Artist[] = []
    for (let i = 0; i < artists.length; i++) {
      const artist = artists[i]
      const source = artist.source as SourceConfig
      if (source && this.selectedSourceIds.has(source.id)) {
        filtered.push(artist)
      }
    }
    return filtered
  }

  /**
   * 根据数据源筛选专辑
   */
  private filterAlbumsBySource(albums: Album[] | undefined): Album[] {
    if (!albums) {
      return []
    }
    if (this.selectedSourceIds.size === 0) {
      return albums
    }
    const filtered: Album[] = []
    for (let i = 0; i < albums.length; i++) {
      const album = albums[i]
      const source = album.source as SourceConfig
      if (source && this.selectedSourceIds.has(source.id)) {
        filtered.push(album)
      }
    }
    return filtered
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

            // 类型筛选器
            ListItem() {
              SearchFilter({ selectedFilter: $selectedFilter })
            }

            // 数据源筛选器
            ListItem() {
              SourceFilter({ selectedSourceIds: $selectedSourceIds })
            }

            ListItemGroup(){
              if(this.result){
                // 歌曲列表
                if(this.isFilteredNullResult(this.filterSongsBySource(this.result.songs)) &&
                   (this.selectedFilter === SearchFilterType.ALL || this.selectedFilter === SearchFilterType.SONGS)){
                  ListItem() {
                    SearchResultList({
                      items: this.filterSongsBySource(this.result.songs),
                      type: 'Song',
                      title: "歌曲"
                    })
                  }
                }
                // 歌单列表
                if(this.isFilteredNullResult(this.filterPlaylistsBySource(this.result.playlists)) &&
                   (this.selectedFilter === SearchFilterType.ALL || this.selectedFilter === SearchFilterType.PLAYLISTS)){
                  ListItem() {
                    SearchResultList({
                      items: this.filterPlaylistsBySource(this.result.playlists),
                      type: 'Playlist',
                      title: "歌单"
                    })
                  }
                }
                // 艺人列表
                if(this.isFilteredNullResult(this.filterArtistsBySource(this.result.artists)) &&
                   (this.selectedFilter === SearchFilterType.ALL || this.selectedFilter === SearchFilterType.ARTISTS)){
                  ListItem() {
                    SearchResultList({
                      items: this.filterArtistsBySource(this.result.artists),
                      type: 'Artist',
                      title: "歌手"
                    })
                  }
                }
                // 专辑列表
                if(this.isFilteredNullResult(this.filterAlbumsBySource(this.result.albums)) &&
                   (this.selectedFilter === SearchFilterType.ALL || this.selectedFilter === SearchFilterType.ALBUMS)){
                  ListItem() {
                    SearchResultList({
                      items: this.filterAlbumsBySource(this.result.albums),
                      type: 'Album',
                      title: "专辑"
                    })
                  }
                }
                // 如果结果为空
                if(this.isAllResultsEmpty()){
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
          .onDidScroll(() => {
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

        MiniPlaybackControl({
          scrollOffsetY: this.scrollOffsetY,
          startScrollOffsetY: this.startScrollOffsetY
        })

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

  /**
   * 判断过滤后的结果是否非空
   * @param list
   * @returns
   */
  isFilteredNullResult(list: Song[] | Playlist[] | Artist[] | Album[]): boolean {
    return list.length > 0
  }

  /**
   * 判断所有过滤后的结果是否都为空
   */
  isAllResultsEmpty(): boolean {
    if (!this.result) {
      return true
    }

    const filteredSongs = this.filterSongsBySource(this.result.songs)
    const filteredPlaylists = this.filterPlaylistsBySource(this.result.playlists)
    const filteredArtists = this.filterArtistsBySource(this.result.artists)
    const filteredAlbums = this.filterAlbumsBySource(this.result.albums)

    // 根据当前选中的类型筛选器判断
    switch (this.selectedFilter) {
      case SearchFilterType.SONGS:
        return filteredSongs.length === 0
      case SearchFilterType.PLAYLISTS:
        return filteredPlaylists.length === 0
      case SearchFilterType.ARTISTS:
        return filteredArtists.length === 0
      case SearchFilterType.ALBUMS:
        return filteredAlbums.length === 0
      default:
        // ALL: 所有类型都为空才显示空结果
        return filteredSongs.length === 0 &&
               filteredPlaylists.length === 0 &&
               filteredArtists.length === 0 &&
               filteredAlbums.length === 0
    }
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