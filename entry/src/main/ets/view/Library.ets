import { TitleHeader } from "../component/TitleHeader";
import { StyleConstants } from "../constants/StyleConstants";
import { ID, Playlist, SourceConfig } from "../type/Adapter";
import { PushPathHelper } from "../util/PushPathHelper";
import { SourceAdapter } from "../adapter";
import { MiniPlaybackControl } from "../component/MiniPlaybackControl";
import FormUtils from "../util/FormUtils"
import { cover } from "../util/AdapterHelper";
import { promptAction, UIContext } from "@kit.ArkUI";
import { PreferencesCache } from "../util/PreferenceCache";
import { HeaderAnimation } from "../component/HeaderAnimation";
import { ScrollController } from "../util/ScrollController";
import { ResponseCacheUtil } from "../util/ResponseCacheUtil";
import { HeaderComponent } from "../component/HeaderComponent";
import { LogUtil } from "@pura/harmony-utils";
import { HeaderPlaceholder } from "../component/HeaderPlaceholder";
import { PlaylistsDataSource } from "../util/PlaylistsDataSource";
import { PlaylistItem } from "../component/PlaylistItem";
import { FooterPlaceholder } from "../component/FooterPlaceholder";

const TAG = 'Library'
@Builder
export function LibraryBuilder(){
  Library()
}

@Component
struct Library {
  subTitles: Resource[] = [$r('app.string.all_playlists'), $r('app.string.custom_playlists'), $r('app.string.collection_playlists')]
  @State groupHeight: number = 0
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageLink('user_playlist') playlists: Playlist[] = [];
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm';
  @State isLoading: boolean = false;
  private scroller: Scroller = new Scroller();
  @StorageProp('bottomRect') bottomRect: number = 0;
  @StorageProp('topRect') topRect: number = 0;
  @StorageProp('winHeight') winHeight: number = 0;
  @StorageProp("user_data_source") adapters: SourceConfig[] = []
  @StorageLink("show_user_data_source") @Watch('onChangeSIndex') showAdapters: SourceConfig[] = PreferencesCache.getShowUserDataSource()
  @State @Watch('onChangeSIndex') sIndex: number = 0
  @State @Watch('onChangeSubTitleIndex') subTitleIndex: number = 0
  @State isExpanded: boolean = false
  @State capsuleOffset: number = 0
  @State capsuleWidth: number = 0
  @State titleWidths: number[] = []
  private readonly BUTTON_GAP: number = 10
  @State capsuleScaleX: number = 0.9
  @State capsuleScaleY: number = 1.0
  uiContext: UIContext | undefined = undefined;
  @State avatarScale: number = 1
  @State scrollOffsetY: number = 0
  @State startScrollOffsetY: number = 0
  @State scrollOffsetEndY: number = 0
  @State playlistsDataSource: PlaylistsDataSource = new PlaylistsDataSource()
  @State scrollController: ScrollController = new ScrollController({
    onIndexChange: (index) => {
      this.onMenuIconClick(index)
    },
    componentTag: TAG
  }).linkController(this.scroller)

  onChangeSubTitleIndex() {
    this.updateCapsulePosition(this.subTitleIndex)
    this.playlistsDataSource.clearData()
    this.initPlaylistsData()
  }

  onChangeSIndex() {
    this.playlistsDataSource.clearData()
    this.initPlaylistsData()
  }

  onMenuIconClick(index: number) {
    if (index === 0 && this.pageStack.size() > 1) {
      this.pageStack.pop();
    } else if (index === 2) {
      // 触发刷新
      this.refreshData();
    }
  }

  async refreshData() {
    this.isLoading = true;

    try {
      this.playlists = await SourceAdapter.getUserPlaylist();
      ResponseCacheUtil.clear()
    } finally {
      this.isLoading = false;
    }
  }

  aboutToAppear(): void {
    this.uiContext = this.getUIContext();
    if (this.playlists[1]?.cover){
      FormUtils.updateRecommendedCards(this.playlists[1].cover as string)
    }
    this.initPlaylistsData()
  }

  initPlaylistsData() {
    const t_playlists = this.playlists.filter(playlist => {
      let match: boolean = true

      // 筛选展示的数据源
      const showAdapterIDs: ID[] = this.showAdapters.map(adapter => adapter.id)
      match = match && showAdapterIDs.includes(playlist.source?.id as ID)

      switch(this.subTitleIndex){
        case 0:
          break
        case 1:
          match = match && (playlist.creator?.id == playlist.source?.auth?.user?.id)
          break
        case 2:
          match = match && (playlist.creator?.id != playlist.source?.auth?.user?.id)
          break
      }
      return match
    })
    this.playlistsDataSource.pushMultiData(t_playlists)
    this.playlistsDataSource.reloadData()
  }

  @Builder
  Title() {
    TitleHeader({
      title: $r('app.string.library'),
      backActive: this.scrollController.currentIndex === 0,
      rightContent: () => {
        this.ButtonS()
      },
      midContent: () => {
        this.TabsTitles()
      }
    })
  }

  @Builder
  TabsTitles(){
    Stack(){
      Row(){
        Row()
          .width(this.capsuleWidth)
          .height(10)
          .backgroundColor($r('app.color.title_emphasis_color'))
          .borderRadius(5)
          .margin({ bottom: -20 })
          .scale({ x: this.capsuleScaleX, y: this.capsuleScaleY })
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      }
      .height(35)
      .layoutWeight(1)
      .align(Alignment.BottomStart)
      .padding({ left: this.capsuleOffset })
      .animation({ duration: 500, curve: Curve.FastOutSlowIn })

      Row({ space: this.BUTTON_GAP }){
        ForEach(this.subTitles, (str: string, index: number) => {
          Text(str)
            .fontColor($r('app.color.text_secondary'))
            .fontWeight(FontWeight.Bold)
            .fontSize('20fp')
            .backgroundColor('transparent')
            .onClick(() => this.updateCapsulePosition(index))
            .onAreaChange((_, area) => {
              this.titleWidths[index] = area.width as number
              if (index === this.subTitleIndex) {
                this.capsuleWidth = area.width as number
              }
            })
            .margin({ bottom: -5 })
        })
      }
      .height(35)
      .align(Alignment.BottomStart)
      .layoutWeight(1)
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          this.uiContext?.animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
            this.capsuleScaleX = 0.75
            this.capsuleScaleY = 1.1
          })
        } else if (event.type === TouchType.Up) {
          this.uiContext?.animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
            this.capsuleScaleX = 0.9
            this.capsuleScaleY = 1.0
          })
        }
      })
    }
    .height(35)
    .layoutWeight(1)
    .padding({ left: 15 })
    .align(Alignment.BottomStart)
  }

  @Builder
  ButtonS(){
    Button({ type: ButtonType.Circle }){
      Image(cover(this.adapters[this.sIndex].auth?.user?.avatar, 200) ?? $r('app.media.portrait'))
        .width(35)
        .height(35)
        .borderRadius(17.5)
    }
    .scale({ x: this.avatarScale, y: this.avatarScale})
    .shadow(ShadowStyle.OUTER_DEFAULT_XS)
    .backgroundColor('transparent')
    .onClick(() => {
      this.isExpanded = !this.isExpanded
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .bindContextMenu(this.isExpanded, this.SwitchSourceMenu(),{
      onDisappear: () => {
        if(this.isExpanded){
          this.isExpanded = false
        }
      }
    })
  }

  @Builder
  SwitchSourceMenu(){
    Menu(){
      ForEach(this.adapters, (adapter: SourceConfig, sIndex) => {
        MenuItem(this.SourceMenuContent(adapter, sIndex))
          .backgroundColor(this.getBackgroundColor(adapter))
          .border({
            width: 1,
            color: this.getBorderColor(adapter),
            style: BorderStyle.Solid
          })
          .margin(5)
          .borderRadius(20)
          .onClick(() => {
            const exists: boolean = this.showAdapters.some(adapterShow => adapterShow.id === adapter.id)
            if(!exists){
              PreferencesCache.addShowUserDataSource(adapter)
            }else{
              PreferencesCache.deleteShowUserDataSource(adapter.id)
            }
            this.sIndex = sIndex
          })
      })
    }
  }

  @Builder
  SourceMenuContent(sourceConfig: SourceConfig, sIndex: number){
    Row() {
      Row({ space: 5}) {
        Image(cover(sourceConfig.auth?.user?.avatar ?? ''))
          .width(20)
          .borderRadius(10)
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        Text((sourceConfig.auth?.user?.name ?? '') + '（' + sourceConfig.name + '）')
          .maxLines(1)
          .fontColor($r('app.color.text_primary'))
          .fontSize('15fp')
          .fontWeight(FontWeight.Bold)
      }
    }
    .padding({
      left: 10,
      right: 10,
      top: 5,
      bottom: 5
    })
    .height(40)
  }

  private updateCapsulePosition(index: number) {
    let offset = 0
    for (let i = 0; i < index; i++) {
      offset += (this.titleWidths[i] || 0) + this.BUTTON_GAP
    }

    this.uiContext?.animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
      this.capsuleOffset = offset
    })

    this.uiContext?.animateTo({ duration: 150, curve: Curve.EaseIn }, () => {
      this.capsuleScaleX = 0.9
      this.capsuleScaleY = 1
      this.capsuleWidth = this.titleWidths[index]
      this.subTitleIndex = index
    })
  }

  private getBackgroundColor(sourceConfig: SourceConfig) {
    if (this.judgeHighLighting(sourceConfig)) {
      return 'rgba(100, 149, 237, 0.15)'; // 高亮背景色
    }
    return Color.Transparent;
  }

  judgeHighLighting(sourceConfig: SourceConfig): boolean {
    const result: boolean = this.showAdapters.some(adapter => adapter.id === sourceConfig.id)
    return result
  }

  private getBorderColor(sourceConfig: SourceConfig) {
    if (this.judgeHighLighting(sourceConfig)) {
      return 'rgba(100, 149, 237, 0.4)'; // 高亮边框色
    }
    return Color.Transparent;
  }

  showToast(msg: string) {
    promptAction.showToast({ message: msg, backgroundColor: Color.Transparent, backgroundBlurStyle: BlurStyle.BACKGROUND_THIN, bottom: StyleConstants.PLAYER_CONTROL_HEIGHT + 32 })
  }

  @Builder
  EmptyState() {
    Column() {
      Text('暂无歌单')
        .fontSize(16)
        .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      Text('您还没有创建或收藏任何歌单')
        .fontSize(14)
        .fontColor($r('app.color.text_hint'))
        .margin({ bottom: 24 })

      Button() {
        Row() {
          Image($r('app.media.ic_plus'))
            .width(18)
            .height(18)
            .fillColor(Color.White)
            .margin({ right: 8 })

          Text('创建歌单')
            .fontSize(16)
            .fontColor(Color.White)
        }
      }
      .width(150)
      .height(44)
      .borderRadius(22)
      .backgroundColor('#6A5ACD')
      .onClick(() => {
        // 创建歌单的逻辑
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          // 主内容
          List({ scroller: this.scroller }) {
            HeaderPlaceholder()
            // 下拉提示动画
            ListItem(){
              HeaderAnimation({ scrollController: this.scrollController, isShowLoadingProgress: true })
            }
            // 如果没有歌单，显示空状态
            if (this.playlists.length === 0) {
              ListItem() {
                this.EmptyState()
              }
              .width(StyleConstants.FULL_WIDTH)
            } else {
              // 我的歌单部分
              ListItemGroup() {
                LazyForEach(this.playlistsDataSource, (playlist: Playlist, index: number) => {
                  ListItem() {
                    PlaylistItem({
                      playlist: playlist,
                      onPlaylistSelected: () => {
                        PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                          AppStorage.setOrCreate('current_playlist_data', playlist)
                          const t_playlist = await SourceAdapter.getPlaylistDetail(playlist)
                          AppStorage.setOrCreate('current_playlist_songs', t_playlist.songs)
                        })
                      }
                    })
                  }
                }, (playlist: Playlist, index: number) => `${playlist.id}-${index}`)
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
            }

            FooterPlaceholder()
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
          .scrollBar(BarState.Off)
          .backToTop(true)
          .onWillScroll(this.scrollController.scrollHandlers.onWillScroll)
          .onScrollStop(this.scrollController.scrollHandlers.onScrollStop)
          .onDidScroll((_: number, scrollState: ScrollState) => {
            this.scrollOffsetY = this.scroller.currentOffset().yOffset
            LogUtil.info(`[${TAG}]`, `scrollState: ${scrollState} CURRENT_Y: ${this.scrollOffsetY}, END_Y: ${this.scrollOffsetEndY} parseInt: ${parseFloat(this.scrollOffsetY.toFixed(2))}`)
          })
          .onTouch((event) => {
            switch (event.type) {
              case TouchType.Down:
                this.startScrollOffsetY = this.scroller.currentOffset().yOffset
                break
            }
          })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)

        // 底部迷你播控组件
        MiniPlaybackControl({
          scrollOffsetY: this.scrollOffsetY,
          startScrollOffsetY: this.startScrollOffsetY
        })

        HeaderComponent({
          scrollOffsetY: this.scrollOffsetY,
          startScrollOffsetY: this.startScrollOffsetY,
          hasHeaderBuilder: false,
          titleBuilder: () => {
            this.Title()
          }
        })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    // .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
    .hideToolBar(true)
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_background'))
    .mode(NavDestinationMode.STANDARD)
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  getBlankHeight(): Length {
    let sub = this.winHeight - this.groupHeight - 50 - (this.bottomRect+this.topRect)
    return sub > 0 ? sub : 0
  }
}