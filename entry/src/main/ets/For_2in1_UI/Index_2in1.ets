import { BreakpointSystem } from '../component/BreakpointSystem'
import { MenuButton } from '../component/MenuButton'
import { StyleConstants } from '../constants/StyleConstants'
import { HomePageMenu } from '../model/HomePageMenu'
import { ComingSoon } from '../view/ComingSoon'
import { HomePageMenuData } from '../viewmodel/HomePageMenuData'
import { MenuIcon } from '../component/MenuIcon'
import { Setting } from '../view/Setting'
import { PreferencesCache } from '../util/PreferenceCache'
import { Artist, Playlist, Song, SourceConfig } from '../type/Adapter'
import { SourceAdapter } from '../adapter'
import { Segment } from '../component/Segment'
import { PlayList } from '../view/Playlist'
import { MiniPlaybackControl } from '../component/MiniPlaybackControl'
import { MultiSearch } from '../view/MultiSearch'
import { HorizontalMode } from '../util/HorizontalCheck'
import { Download } from '../view/Download'
import { ScrollController } from '../util/ScrollController'
import { HeaderAnimation } from '../component/HeaderAnimation'
import { deviceInfo } from '@kit.BasicServicesKit'
import { PipManager } from '../util/PipManager';
import { avPlayerManager } from '../util/AVPlayerManager';
import {FOR_2IN1_UI, IS_2IN1_UI}from '../For_2in1_UI/FOR2IN1'
// 缓存常用值以避免重复计算
const COLUMNS_TEMPLATE_LG = '1fr 1fr 1fr 1fr'
const COLUMNS_TEMPLATE_SM = '1fr 1fr'
const DEFAULT_COVER_SIZE = 256
const TAG = 'Index'
@Component
export struct Index_page {
  @StorageProp('decorHeight') decorHeight: number = 0
  @State version: string = '2.2.0'

  @State blankHeight: number = 0
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm'
  private breakpointSystem = new BreakpointSystem()
  private menuItems = HomePageMenuData
  private scroller: Scroller = new Scroller()
  @StorageLink("user_data_source") adapters: SourceConfig[] = PreferencesCache.getUserDataSource()
  // 使用StorageLink保持数据同步
  @StorageLink("index_recommend_playlist") recommendPlaylist: Playlist[] = PreferencesCache.getPlaylistCache('index_recommend_playlist')
  @StorageLink("index_recommend_songs") recommendSongs: Song[] = PreferencesCache.getSongCache('index_recommend_songs')
  @StorageLink("index_recommend_artists") recommendArtists: Artist[] = PreferencesCache.getArtistCache('index_recommend_artists')
  @StorageLink("index_recommend_toplist") topList: Playlist[] = PreferencesCache.getPlaylistCache('index_recommend_toplist')
  @State loading: boolean = true
  // 避让导航栏高度
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('winHeight') winHeight: number = 0
  @State HorizontalMode_ctrl: string = PreferencesCache.getUserPreference('HorizontalMode_ctrl', '0')
  @State scrollController: ScrollController = new ScrollController({
    onIndexChange: (index) => {
      this.onMenuIconClick(index)
    },
    componentTag: TAG
  }).linkController(this.scroller)
  //2in1 UI控制
  @State zhishi_UI:string =  PreferencesCache.getUserPreference('zhishi_UI','0')
  async aboutToAppear() {
    avPlayerManager.setAudioSession()

    this.zhishi_UI =  PreferencesCache.getUserPreference('zhishi_UI','0')

    // avPlayerManager.avPlayer?.setVolume(Number(PreferencesCache.getUserPreference('Volume','100'))/100)
    // if (PreferencesCache.getUserPreference('Lyic_desktop','0')==='1') {
    //   PipManager.getInstance().init(getContext(this)); // 创建画中画控制器
    //   PipManager.getInstance().setAutoStart(true); // 设置应用退后台时自动启动画中画
    // }
    if (PreferencesCache.getUserPreference(this.version,'0')==='0'){
      try{
        AlertDialog.show(
          {
            title: '更新提示',
            subtitle: '此版本',
            message: '播放页双击歌曲两侧即可弹出调节软件音量，个性化设置中增加允许同时播放（需暂停再次播放后触发），临时解决2in1设备无法使用的问题，全新2in1适配施工中',
            autoCancel: true,
            alignment: DialogAlignment.Bottom,
            gridCount: 4,
            offset: { dx: 0, dy: -20 },
            primaryButton: {
              value: '我知道了',
              action: () => {
                PreferencesCache.setUserPreference(this.version,'1')

                console.info('Callback when the first button is clicked');
              }
            },
            secondaryButton: {
              enabled: true,
              defaultFocus: true,
              style: DialogButtonStyle.HIGHLIGHT,
              value: '已知悉',
              action: () => {
                PreferencesCache.setUserPreference(this.version,'1')
                console.info('Callback when the second button is clicked');
              }
            },
            cancel: () => {
              console.info('Closed callbacks');
            },
            onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
              console.info("reason=" + JSON.stringify(dismissDialogAction.reason))
              console.log("dialog onWillDismiss")
              if (dismissDialogAction.reason === DismissReason.PRESS_BACK) {
                dismissDialogAction.dismiss();
              }
              if (dismissDialogAction.reason === DismissReason.TOUCH_OUTSIDE) {
                dismissDialogAction.dismiss();
              }
            }
          }
        )
      }catch (e) {
      }
    }

    // 注册断点系统
    this.breakpointSystem.register()
    HorizontalMode(this.HorizontalMode_ctrl === '1')
    AppStorage.setOrCreate("pageStack", this.pageStack)
    // 立即初始化数据
    // this.initData()
    this.loading = false
    let productSeries:string=deviceInfo.productSeries
    let devicetype:string =deviceInfo.deviceType
    if (devicetype!='phone'&&productSeries!='VDE'){
      AppStorage.setOrCreate<boolean>('isWideScreen', true)
    }else {
      AppStorage.setOrCreate<boolean>('isWideScreen', false)

    }
    AppStorage.setOrCreate("devicetype", devicetype)
    PreferencesCache.setUserPreference('devicetype', devicetype)
    if(productSeries=='VDE') {
      PreferencesCache.setUserPreference('is_Pura_X', '1')
    }else {
      PreferencesCache.setUserPreference('is_Pura_X', '0')
    }
  }

  async initData() {
    this.loading = true

    try {
      // 并行加载数据并捕获异常
      await Promise.all([
        SourceAdapter.getRecommendList(),
        SourceAdapter.getRecommendSongs(),
        SourceAdapter.getRecommendArtists(),
        SourceAdapter.getTopList(),
        SourceAdapter.getUserPlaylist()
      ])
    } catch (error) {
      console.error('Failed to load data', error)
    } finally {
      this.loading = false
    }
  }

  onPageShow(): void {
    console.info(TAG, 'onPageShow')
    // PipManager.getInstance().init(getContext(this)); // 创建画中画控制器
    // PipManager.getInstance().setAutoStart(true); // 设置应用退后台时自动启动画中画
    // PipManager.getInstance().startPip();
  }

  onPageHide(): void {
    console.info(TAG, 'onPageHide')
    PipManager.getInstance().setAutoStart(false);
  }

  aboutToDisappear() {
    this.breakpointSystem.unregister()
    PipManager.getInstance().unregisterPipStateChangeListener(); // 解注册画中画生命周期及状态回调

  }

  @Builder
  Title() {

    Column(){
      // PC工具栏适配
      if(this.decorHeight > 0){
        Row(){
          Image($r('app.media.icon'))
            .height(this.decorHeight/2)
            .width(this.decorHeight/2)
            .margin({ left: 16 })
          Blank().width(5)
          Text('云享社').fontSize(14).fontWeight(FontWeight.Bold)
        }
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .height(this.decorHeight).backgroundColor('transparent').width('100%')
      }
      else if(this.topRect > 0){
        Row(){}
        .height(px2vp(this.topRect)).backgroundColor('transparent').width('100%')
      }

      Row() {
        Text($r("app.string.homepage"))
          .fontColor($r('app.color.text_title'))
          .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
          .fontSize($r('app.float.title_font_size'))

        Row() {
          MenuIcon({
            icon: $r('app.media.ic_search'),
            active: this.scrollController.currentIndex === 1
          })
            .onClick(() => {
              this.onMenuIconClick(1)
            })
            .clickEffect({ level: ClickEffectLevel.LIGHT })

          MenuIcon({
            icon: $r('app.media.ic_gearshape'),
            active: this.scrollController.currentIndex === 0
          })
            .onClick(() => {
              this.onMenuIconClick(0)
            })
            .clickEffect({ level: ClickEffectLevel.LIGHT })
        }
        .height(StyleConstants.FULL_HEIGHT)
        .alignItems(VerticalAlign.Center)
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(50)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .padding({
        left: 16,
        right: 16
      })
    }

  }

  onMenuIconClick(index: number) {
    if (index === 0) {
      this.pageStack.pushPath({ name: 'Setting' })
    } else if (index === 1) {
      this.pageStack.pushPath({ name: 'MultiSearch' })
    } else if (index === 2) {
      this.initData()
    }
  }

  // 使用Builder模式优化各个部分的渲染
  @Builder
  MenuGrid() {
    Grid() {
      ForEach(this.menuItems, (item: HomePageMenu) => {
        GridItem() {
          MenuButton({
            title: item.title,
            onNavigate: () => {
              this.pageStack.pushPath({ name: item.path })
            }
          })
        }.key(`${item.title}`)
        .padding(4)
      })
    }
    .columnsTemplate(this.currentBreakpoint === 'lg' ? COLUMNS_TEMPLATE_LG : COLUMNS_TEMPLATE_SM)
    .padding(12)
    .width(StyleConstants.FULL_WIDTH)
    .rowsGap(8)
    .columnsGap(8)
  }

  @Builder
  RecommendedSongs() {
    Segment({
      lists: this.recommendSongs,
      type: 'Song',
      title: $r('app.string.hot_songs'),
      actionText: $r('app.string.rotate'),
      loading: this.loading,
      onActionClick: async () => {
        this.recommendSongs = await SourceAdapter.getRecommendSongs()
      },
    }).key('Index-R')
  }

  @Builder
  RecommendedPlaylists() {
    Segment({
      lists: this.recommendPlaylist,
      type: 'Playlist',
      title: $r('app.string.recommended_playlists'),
      actionText: $r('app.string.rotate'),
      loading: this.loading,
      onActionClick: async () => {
        this.recommendPlaylist = await SourceAdapter.getRecommendList()
      },
    }).key('Index-R')
  }

  @Builder
  RecommendedArtists() {
    Segment({
      lists: this.recommendArtists,
      type: 'Artist',
      title: $r('app.string.recommended_artists'),
      actionText: $r('app.string.rotate'),
      loading: this.loading,
      radius: "100%",
      onActionClick: async () => {
        this.recommendArtists = await SourceAdapter.getRecommendArtists()
      },
    }).key('Index-R')
  }

  @Builder
  TopLists() {
    Segment({
      lists: this.topList,
      type: 'TopPlaylist',
      title: $r('app.string.chart'),
      loading: this.loading
    }).key('Index-R')
  }

  @Builder
  EmptyDataSource() {
    Column() {
      Row() {
        Text($r('app.string.add_data_source'))
          .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
          .fontColor($r('app.color.text_click'))
          .fontSize(16)
          .margin({ right: 2 })
          .onClick(() => {
            this.pageStack.pushPath({ name: 'Setting' })
          })
        Text("开启云上漫游！")
          .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
          .fontColor($r('app.color.text_hint'))
          .fontSize(15)
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

  build() {
    NavDestination() {
        Stack({ alignContent: Alignment.Bottom }) {
          Column(){
            List({ scroller: this.scroller }) {
              ListItem() {
                HeaderAnimation({ scrollController: this.scrollController, isShowLoadingProgress: true })
              }

              if (this.adapters.length > 0) {
                ListItem() {
                  this.MenuGrid()
                }

                if (this.loading || (this.recommendPlaylist.length > 0 || this.recommendSongs.length > 0
                  || this.recommendArtists.length > 0 || this.topList.length > 0)) {
                  if(this.recommendPlaylist.length > 0){
                    this.RecommendedSongs()
                  }

                  if(this.recommendSongs.length > 0){
                    this.RecommendedPlaylists()
                  }

                  if(this.recommendArtists.length > 0){
                    this.RecommendedArtists()
                  }

                  if(this.topList.length > 0){
                    this.TopLists()
                  }
                } else if(!this.loading) {
                  ListItem() {
                    Row() {
                      Column() {
                        Text($r('app.string.no_recommendations'))
                          .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
                          .fontColor($r('app.color.text_hint'))
                          .fontSize(16)
                      }
                      .width(StyleConstants.FULL_WIDTH)
                      .height(StyleConstants.FULL_HEIGHT)
                      .justifyContent(FlexAlign.Center)
                    }
                    .height(this.getBlankHeight())
                  }
                }
              } else {
                ListItem() {
                  this.EmptyDataSource()
                }
              }

              ListItem() {
                Row() {
                  Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + px2vp(this.bottomRect) + px2vp(this.topRect) + this.decorHeight + 50 + 32)
                }
              }
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .layoutWeight(1)
            .backToTop(true)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .onWillScroll(this.scrollController.scrollHandlers.onWillScroll)
            .onScrollStop(this.scrollController.scrollHandlers.onScrollStop)
            .scrollBarColor('#e7bb7c')
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)

        }
        .height(StyleConstants.FULL_HEIGHT)
        .width(StyleConstants.FULL_WIDTH)
    }
    .height(StyleConstants.FULL_HEIGHT)
    .width(StyleConstants.FULL_WIDTH)
    .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
    .hideToolBar(true)
    .hideTitleBar(true)
    .hideBackButton(true)
    .backgroundColor($r('app.color.page_background'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM, LayoutSafeAreaEdge.TOP])
    .keyboardShortcut(FunctionKey.F5, [], () => {
      this.initData()
    })
  }

  getBlankHeight(): number {
    let sub = px2vp(this.winHeight) - this.blankHeight - 50 - px2vp(this.bottomRect + this.topRect)
    return sub > 0 ? sub : 0
  }
}
// export  struct Index_page {
//   @State version: string = '2.2.0'
//   public is_2in1_UI:boolean =false
//   @State blankHeight: number = 0
//   @Consume('NavPathStack') pageStack: NavPathStack
//   @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm'
//   private breakpointSystem = new BreakpointSystem()
//   private menuItems = HomePageMenuData
//   private scroller: Scroller = new Scroller()
//   @StorageLink("user_data_source") adapters: SourceConfig[] = PreferencesCache.getUserDataSource()
//   // 使用StorageLink保持数据同步
//   @StorageLink("index_recommend_playlist") recommendPlaylist: Playlist[] = []
//   @StorageLink("index_recommend_songs") recommendSongs: Song[] = []
//   @StorageLink("index_recommend_artists") recommendArtists: Artist[] = []
//   @StorageLink("index_recommend_toplist") topList: Playlist[] = []
//   @State loading: boolean = true
//   // 避让导航栏高度
//   @StorageProp('bottomRect') bottomRect: number = 0
//   @StorageProp('topRect') topRect: number = 0
//   @StorageProp('winHeight') winHeight: number = 0
//   @State zhishi_UI:string =  PreferencesCache.getUserPreference('zhishi_UI','0')
//   @State HorizontalMode_ctrl: string = PreferencesCache.getUserPreference('HorizontalMode_ctrl', '0')
//   // 预先计算并缓存必要的布局值
//   private coverWidth: number = 120
//   private segmentPadding: number = 4
//   @State scrollController: ScrollController = new ScrollController({
//     onIndexChange: (index) => {
//       this.onMenuIconClick(index)
//     },
//     componentTag: TAG
//   }).linkController(this.scroller)
//
//   async aboutToAppear() {
//     avPlayerManager.setAudioSession()
//     // avPlayerManager.avPlayer?.setVolume(Number(PreferencesCache.getUserPreference('Volume','100'))/100)
//     // if (PreferencesCache.getUserPreference('Lyic_desktop','0')==='1') {
//     //   PipManager.getInstance().init(getContext(this)); // 创建画中画控制器
//     //   PipManager.getInstance().setAutoStart(true); // 设置应用退后台时自动启动画中画
//     // }
//     if (PreferencesCache.getUserPreference(this.version,'0')==='0'){
//       try{
//         AlertDialog.show(
//           {
//             title: '更新提示',
//             subtitle: '此版本',
//             message: '播放页双击歌曲两侧即可弹出调节软件音量，个性化设置中增加允许同时播放（需暂停再次播放后触发），临时解决2in1设备无法使用的问题，全新2in1适配施工中',
//             autoCancel: true,
//             alignment: DialogAlignment.Bottom,
//             gridCount: 4,
//             offset: { dx: 0, dy: -20 },
//             primaryButton: {
//               value: '我知道了',
//               action: () => {
//                 PreferencesCache.setUserPreference(this.version,'1')
//
//                 console.info('Callback when the first button is clicked');
//               }
//             },
//             secondaryButton: {
//               enabled: true,
//               defaultFocus: true,
//               style: DialogButtonStyle.HIGHLIGHT,
//               value: '已知悉',
//               action: () => {
//                 PreferencesCache.setUserPreference(this.version,'1')
//                 console.info('Callback when the second button is clicked');
//               }
//             },
//             cancel: () => {
//               console.info('Closed callbacks');
//             },
//             onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
//               console.info("reason=" + JSON.stringify(dismissDialogAction.reason))
//               console.log("dialog onWillDismiss")
//               if (dismissDialogAction.reason === DismissReason.PRESS_BACK) {
//                 dismissDialogAction.dismiss();
//               }
//               if (dismissDialogAction.reason === DismissReason.TOUCH_OUTSIDE) {
//                 dismissDialogAction.dismiss();
//               }
//             }
//           }
//         )
//       }catch (e) {
//       }
//     }
//
//     // 注册断点系统
//     this.breakpointSystem.register()
//     HorizontalMode(this.HorizontalMode_ctrl === '1')
//     AppStorage.setOrCreate("pageStack", this.pageStack)
//     // 立即初始化数据
//     this.initData()
//     let productSeries:string=deviceInfo.productSeries
//     let devicetype:string =deviceInfo.deviceType
//     if (devicetype!='phone'&&productSeries!='VDE'){
//       AppStorage.setOrCreate<boolean>('isWideScreen', true)
//     }else {
//       AppStorage.setOrCreate<boolean>('isWideScreen', false)
//
//     }
//     AppStorage.setOrCreate("devicetype", devicetype)
//     PreferencesCache.setUserPreference('devicetype', devicetype)
//     if(productSeries=='VDE') {
//       PreferencesCache.setUserPreference('is_Pura_X', '1')
//     }else {
//       PreferencesCache.setUserPreference('is_Pura_X', '0')
//     }
//     // if (this.zhishi_UI==='1') {
//     //   this.pageStack.replacePath({ name: 'FOR_2IN1_UI' })
//     //
//     // }
//
//   }
//
//   async initData() {
//     this.loading = true
//
//     try {
//       // 并行加载数据并捕获异常
//       await Promise.all([
//         SourceAdapter.getRecommendList(),
//         SourceAdapter.getRecommendSongs(),
//         SourceAdapter.getRecommendArtists(),
//         SourceAdapter.getTopList(),
//         SourceAdapter.getUserPlaylist()
//       ])
//     } catch (error) {
//       console.error('Failed to load data', error)
//     } finally {
//       this.loading = false
//
//     }
//
//   }
//
//   private generatePlaylistMenu(playlist: Playlist): Array<MenuElement> {
//     return [
//       {
//         value: $r('app.string.play_this_playlist'),
//         action: () => {
//           PushPathHelper.loading("Playing", async () => {
//             const playlistDetail = await SourceAdapter.getPlaylistDetail(playlist)
//             const songs = playlistDetail?.songs?.filter(song => song.privilege.playable)
//             if (!songs || songs.length === 0) {
//               ToastUtil.showShort($r('app.string.no_playable_songs'))
//               return
//             }
//             PlaylistManager.loadPlaylist(songs, songs[0])
//           })
//         }
//       }
//     ]
//   }
//
//   private generateSongMenu(song: Song): Array<MenuElement> {
//     return [
//       {
//         value: $r('app.string.add_to_play_next'),
//         action: () => {
//           PlaylistManager.insertSongs([song])
//         }
//       }
//     ]
//   }
//
//
//   onPageShow(): void {
//     console.info(TAG, 'onPageShow')
//     // PipManager.getInstance().init(getContext(this)); // 创建画中画控制器
//     // PipManager.getInstance().setAutoStart(true); // 设置应用退后台时自动启动画中画
//     // PipManager.getInstance().startPip();
//   }
//
//   onPageHide(): void {
//     console.info(TAG, 'onPageHide')
//     // PipManager.getInstance().setAutoStart(false);
//   }
//
//   aboutToDisappear() {
//     this.breakpointSystem.unregister()
//     // PipManager.getInstance().unregisterPipStateChangeListener(); // 解注册画中画生命周期及状态回调
//
//   }
//
//   @Builder
//   Title() {
//     Row() {
//       Text($r("app.string.homepage"))
//         .fontColor($r('app.color.text_title'))
//         .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
//         .fontSize($r('app.float.title_font_size'))
//
//       Row() {
//         MenuIcon({
//           icon: $r('app.media.ic_search'),
//           active: this.scrollController.currentIndex === 1
//         })
//           .onClick(() => {
//             this.onMenuIconClick(1)
//           })
//           .clickEffect({ level: ClickEffectLevel.LIGHT })
//
//         MenuIcon({
//           icon: $r('app.media.ic_gearshape'),
//           active: this.scrollController.currentIndex === 0
//         })
//           .onClick(() => {
//             this.onMenuIconClick(0)
//           })
//           .clickEffect({ level: ClickEffectLevel.LIGHT })
//       }
//       .height(StyleConstants.FULL_HEIGHT)
//       .alignItems(VerticalAlign.Center)
//     }
//     .width(StyleConstants.FULL_WIDTH)
//     .justifyContent(FlexAlign.SpaceBetween)
//     .alignItems(VerticalAlign.Center)
//     .padding({
//       left: 16,
//       right: 16
//     })
//     .expandSafeArea()
//   }
//
//   onMenuIconClick(index: number) {
//     if (index === 0) {
//       this.pageStack.pushPath({ name: 'Setting' })
//     } else if (index === 1) {
//       this.pageStack.pushPath({ name: 'MultiSearch' })
//     } else if (index === 2) {
//       this.initData()
//     }
//   }
//
//   // 使用Builder模式优化各个部分的渲染
//   @Builder
//   MenuGrid() {
//     Grid() {
//       ForEach(this.menuItems, (item: HomePageMenu) => {
//         GridItem() {
//           MenuButton({
//             title: item.title,
//             onNavigate: () => {
//               this.pageStack.pushPath({ name: item.path })
//             }
//           })
//         }
//         .padding(4)
//       })
//     }
//     .columnsTemplate(this.currentBreakpoint === 'lg' ? COLUMNS_TEMPLATE_LG : COLUMNS_TEMPLATE_SM)
//     .padding(12)
//     .width(StyleConstants.FULL_WIDTH)
//     .rowsGap(8)
//     .columnsGap(8)
//   }
//
//   @Builder
//   RecommendedSongs() {
//     Segment({
//       title: $r('app.string.hot_songs'),
//       actionText: $r('app.string.rotate'),
//       loading: this.loading,
//       onActionClick: async () => {
//         this.recommendSongs = await SourceAdapter.getRecommendSongs()
//       },
//     }) {
//       List({ initialIndex: 0, space: 0 }) {
//         LazyForEach(new LazyData(this.recommendSongs), (item: Song) => {
//           ListItem() {
//             Cover({
//               src: cover(item.album.cover, DEFAULT_COVER_SIZE),
//               title: item.name,
//               subtitle: item.artists.map(artist => artist.name).join(' / '),
//               menuItems: this.generateSongMenu(item)
//             })
//               .width(this.coverWidth)
//               .padding(this.segmentPadding)
//               .onClick(() => {
//                 PushPathHelper.loading("Playing", async () => {
//                   PlaylistManager.insertSongs([item], -1, item)
//                 })
//               })
//           }
//         })
//       }
//       .width('100%')
//       .height('auto')
//       .listDirection(Axis.Horizontal)
//       .scrollBar(BarState.Off)
//       .cachedCount(3) // 缓存更多项以提高性能
//     }
//   }
//
//   @Builder
//   RecommendedPlaylists() {
//     Segment({
//       title: $r('app.string.recommended_playlists'),
//       actionText: $r('app.string.rotate'),
//       loading: this.loading,
//       onActionClick: async () => {
//         this.recommendPlaylist = await SourceAdapter.getRecommendList()
//       },
//     }) {
//       List({ initialIndex: 0, space: 0 }) {
//         LazyForEach(new LazyData(this.recommendPlaylist), (item: Playlist) => {
//           ListItem() {
//             Cover({
//               src: cover(item.cover, DEFAULT_COVER_SIZE),
//               title: item.name,
//               menuItems: this.generatePlaylistMenu(item)
//             })
//               .width(this.coverWidth)
//               .padding(this.segmentPadding)
//               .onClick(async () => {
//                 PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
//                   const playlist = await SourceAdapter.getPlaylistDetail(item)
//                   AppStorage.setOrCreate('current_playlist_data', playlist)
//                 })
//               })
//           }
//         })
//       }
//       .width('100%')
//       .height('auto')
//       .listDirection(Axis.Horizontal)
//       .scrollBar(BarState.Off)
//       .cachedCount(3)
//     }
//   }
//
//   @Builder
//   RecommendedArtists() {
//     Segment({
//       title: $r('app.string.recommended_artists'),
//       actionText: $r('app.string.rotate'),
//       loading: this.loading,
//       radius: "100%",
//       onActionClick: async () => {
//         this.recommendArtists = await SourceAdapter.getRecommendArtists()
//       },
//     }) {
//       List({ initialIndex: 0, space: 0 }) {
//         LazyForEach(new LazyData(this.recommendArtists), (item: Artist) => {
//           ListItem() {
//             Cover({
//               src: cover(item.avatar, DEFAULT_COVER_SIZE),
//               title: item.name,
//               radius: "100%",
//               titleAlign: HorizontalAlign.Center
//             })
//               .width(this.coverWidth)
//               .padding(this.segmentPadding)
//               .onClick(() => {
//                 PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
//                   // 歌手复用歌单UI
//                   const playlist = await SourceAdapter.getArtistDetail(item)
//                   AppStorage.setOrCreate('current_playlist_data', playlist)
//                 })
//               })
//           }
//         })
//       }
//       .width('100%')
//       .height('auto')
//       .listDirection(Axis.Horizontal)
//       .scrollBar(BarState.Off)
//       .cachedCount(3)
//     }
//   }
//
//   @Builder
//   TopLists() {
//     Segment({
//       title: $r('app.string.chart'),
//       loading: this.loading
//     }) {
//       List({ initialIndex: 0, space: 0 }) {
//         LazyForEach(new LazyData(this.topList), (item: Playlist) => {
//           ListItem() {
//             Cover({
//               src: cover(item.cover, DEFAULT_COVER_SIZE),
//               title: item.name,
//               subtitle: item.description,
//               menuItems: this.generatePlaylistMenu(item)
//             })
//               .width(this.coverWidth)
//               .padding(this.segmentPadding)
//               .onClick(async () => {
//                 PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
//                   const playlist = await SourceAdapter.getPlaylistDetail(item)
//                   AppStorage.setOrCreate('current_playlist_data', playlist)
//                 })
//               })
//           }
//         })
//       }
//       .width('100%')
//       .height('auto')
//       .listDirection(Axis.Horizontal)
//       .scrollBar(BarState.Off)
//       .cachedCount(3)
//     }
//   }
//
//   @Builder
//   EmptyDataSource() {
//     Column() {
//       Row() {
//         Text($r('app.string.add_data_source'))
//           .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
//           .fontColor($r('app.color.text_click'))
//           .fontSize(16)
//           .margin({ right: 2 })
//           .onClick(() => {
//             this.pageStack.pushPath({ name: 'Setting' })
//           })
//         Text("开启云上漫游！")
//           .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
//           .fontColor($r('app.color.text_hint'))
//           .fontSize(15)
//       }
//       .width(StyleConstants.FULL_WIDTH)
//       .height(StyleConstants.FULL_HEIGHT)
//       .alignItems(VerticalAlign.Center)
//       .justifyContent(FlexAlign.Center)
//     }
//     .width(StyleConstants.FULL_WIDTH)
//     .height(StyleConstants.FULL_HEIGHT)
//     .alignItems(HorizontalAlign.Center)
//     .justifyContent(FlexAlign.SpaceBetween)
//   }
//
//   build() {
//
//     NavDestination() {
//       Stack({ alignContent: Alignment.Bottom }) {
//         List({ scroller: this.scroller }) {
//           ListItem() {
//             HeaderAnimation({ scrollController: this.scrollController, isShowLoadingProgress: true })
//           }
//
//           if (this.adapters.length > 0) {
//             ListItem() {
//               this.MenuGrid()
//             }
//
//             if (this.loading || (this.recommendPlaylist.length > 0 || this.recommendSongs.length > 0
//               || this.recommendArtists.length > 0 || this.topList.length > 0)) {
//               if(this.recommendPlaylist.length > 0){
//                 ListItem() {
//                   this.RecommendedSongs()
//                 }
//               }
//
//               if(this.recommendSongs.length > 0){
//                 ListItem() {
//                   this.RecommendedPlaylists()
//                 }
//               }
//
//               if(this.recommendArtists.length > 0){
//                 ListItem() {
//                   this.RecommendedArtists()
//                 }
//               }
//
//               if(this.topList.length > 0){
//                 ListItem() {
//                   this.TopLists()
//                 }
//               }
//             } else if(!this.loading) {
//               ListItem() {
//                 Row() {
//                   Column() {
//                     Text($r('app.string.no_recommendations'))
//                       .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
//                       .fontColor($r('app.color.text_hint'))
//                       .fontSize(16)
//                   }
//                   .width(StyleConstants.FULL_WIDTH)
//                   .height(StyleConstants.FULL_HEIGHT)
//                   .justifyContent(FlexAlign.Center)
//                 }
//                 .height(this.getBlankHeight())
//               }
//             }
//           } else {
//             ListItem() {
//               this.EmptyDataSource()
//             }
//           }
//
//           ListItem() {
//             Row() {
//               Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + 16)
//             }
//           }
//         }
//         .width(StyleConstants.FULL_WIDTH)
//         .height(StyleConstants.FULL_HEIGHT)
//         .layoutWeight(1)
//         .backToTop(true)
//         .scrollBar(BarState.Off)
//         .edgeEffect(EdgeEffect.Spring)
//         .onWillScroll(this.scrollController.scrollHandlers.onWillScroll)
//         .onScrollStop(this.scrollController.scrollHandlers.onScrollStop)
//         .expandSafeArea()
//         .scrollBarColor('#e7bb7c')
//
//
//         // Button().onClick(()=>{
//         //   this.pageStack.pushPathByName('FOR_2IN1_UI',null,true)
//         // })
//       }
//       .height(StyleConstants.FULL_HEIGHT)
//       .width(StyleConstants.FULL_WIDTH)
//       // if (this.zhishi_UI==='1'){
//       //   IS_2IN1_UI()
//       //
//       // }
//
//     }
//     .height(StyleConstants.FULL_HEIGHT)
//     .width(StyleConstants.FULL_WIDTH)
//     .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
//     .hideToolBar(true)
//     .hideBackButton(true)
//     .title({
//       builder: this.Title(),
//       height: 50,
//     })
//     .backgroundColor($r('app.color.page_background'))
//     .hideTitleBar(true)
//     .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
//
//
//   }
//
//   getBlankHeight(): number {
//     let sub = px2vp(this.winHeight) - this.blankHeight - 50 - px2vp(this.bottomRect + this.topRect)
//     return sub > 0 ? sub : 0
//   }
// }