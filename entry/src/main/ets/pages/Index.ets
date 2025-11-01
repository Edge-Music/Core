import { BreakpointSystem } from '../component/BreakpointSystem'
import { MenuButton } from '../component/MenuButton'
import { StyleConstants } from '../constants/StyleConstants'
import { AnimationConstants } from '../constants/AnimationConstants'
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
import { PipManager } from '../util/PipManager'
import { avPlayerManager } from '../util/AVPlayerManager'
import { IS_2IN1_UI } from '../For_2in1_UI/FOR2IN1'
import { Aggregation } from '../view/Aggregation'
import { LogUtil, ToastUtil, WantUtil } from '@pura/harmony-utils'
import { BusinessError } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { HeaderComponent } from '../component/HeaderComponent'
import { HeaderPlaceholder } from '../component/HeaderPlaceholder'
import { Statistics } from '../view/Statistics'
import { FooterPlaceholder } from '../component/FooterPlaceholder'

// 缓存常用值以避免重复计算
const COLUMNS_TEMPLATE_LG = '1fr 1fr 1fr 1fr' // 宽屏4列（1×4布局）
const COLUMNS_TEMPLATE_SM = '1fr 1fr' // 窄屏2列（2×2布局）
const TAG = 'Index'

// 隐私协议弹窗组件
@CustomDialog
struct PrivacyPolicyDialog {
  controller?: CustomDialogController;
  onAgree: () => void = () => {};
  onDisagree: () => void = () => {};

  build() {
    Column({ space: 20 }) {
      // 标题
      Text($r('app.string.privacy_policy_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_title'))
        .margin({ top: 10 })

      // 内容
      Column({ space: 12 }) {
        Text($r('app.string.privacy_policy_main_text'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Start)
          .width('100%')

        Text($r('app.string.privacy_policy_detail_text'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Start)
          .width('100%')

        // 查看协议链接
        Row() {
          Text($r('app.string.privacy_policy_link_prefix'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))

          Text($r('app.string.privacy_policy_link_text'))
            .fontSize(14)
            .fontColor($r('app.color.text_click'))
            .decoration({ type: TextDecorationType.Underline })
            .onClick(() => {
              WantUtil.toWebBrowser("https://music.yby.zone/policy.html")
                .catch((err: BusinessError) => {
                  LogUtil.error(TAG, "打开隐私协议失败！", err.message);
                  ToastUtil.showShort("跳转到浏览器失败！");
                });
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 4, right: 4 })

      // 按钮区域
      Row({ space: 12 }) {
        Button($r('app.string.privacy_policy_disagree'))
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(8)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            if (this.controller) {
              this.controller.close();
            }
            this.onDisagree();
          })

        Button($r('app.string.privacy_policy_agree'))
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.text_click'))
          .borderRadius(8)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            if (this.controller) {
              this.controller.close();
            }
            this.onAgree();
          })
      }
      .width('100%')
      .margin({ bottom: 10 })
    }
    .padding(20)
    .borderRadius(12)
    .backgroundColor($r('app.color.page_background'))
    .width('90%')
  }
}

@Entry
@Component
struct Index {
  @Provide('NavPathStack') pageStack: NavPathStack = new NavPathStack()

  @Builder
  PageMap(name: string) {
    if (name === 'ComingSoon') {
      ComingSoon()
    } else if (name === 'Setting') {
      Setting()
    } else if (name === 'Playlist') {
      PlayList()
    } else if (name === 'MultiSearch') {
      MultiSearch()
    } else if (name === 'Index_page') {
      Index_page()
    } else if (name === 'Download') {
      Download()
    } else if (name === 'Aggregation') {
      Aggregation()
    } else if (name === 'Statistics') {
      Statistics()
    }
  }

  aboutToAppear(): void {
    this.pageStack.replacePath({ name: 'Index_page' })
  }

  build() {
    Navigation(this.pageStack) {
      // empty
    }
    .navDestination(this.PageMap)
    .hideNavBar(true)
    .mode(NavigationMode.Stack)
  }
}

@Component
struct Index_page {
  @StorageProp('decorHeight') decorHeight: number = 0
  @State blankHeight: number = 0
  @State limit: number = 10
  @State page_judge: string = 'index'
  @State title: string = '首页'
  @State scrollOffsetY: number = 0
  @State startScrollOffsetY: number = 0
  @State scrollOffsetEndY: number = 0
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm'
  @StorageLink("user_data_source") adapters: SourceConfig[] = PreferencesCache.getUserDataSource()
  // 使用StorageLink保持数据同步
  @StorageLink("index_recommend_playlist") recommendPlaylist: Playlist[] =
    PreferencesCache.getPlaylistCache('index_recommend_playlist')
  @StorageLink("index_recommend_songs") recommendSongs: Song[] = PreferencesCache.getSongCache('index_recommend_songs')
  @StorageLink("index_recommend_artists") recommendArtists: Artist[] =
    PreferencesCache.getArtistCache('index_recommend_artists')
  @StorageLink("index_recommend_toplist") topList: Playlist[] =
    PreferencesCache.getPlaylistCache('index_recommend_toplist')
  @StorageLink('user_playlist') playlists: Playlist[] = []
  @State loading: boolean = false
  // 避让导航栏高度
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('winHeight') winHeight: number = 0
  @StorageProp('windowStatus') windowStatus: string = 'FULL_SCREEN'
  @State HorizontalMode_ctrl: string = PreferencesCache.getUserPreference('HorizontalMode_ctrl', '1')
  //2in1 UI控制
  @StorageProp('zhishi_UI') zhishi_UI: string = PreferencesCache.getUserPreference('zhishi_UI', '0')
  private policyVersion: string = 'privacy_policy_2025'
  private breakpointSystem = new BreakpointSystem()
  private menuItems = HomePageMenuData
  private scroller: Scroller = new Scroller()
  @State scrollController: ScrollController = new ScrollController({
    onIndexChange: (index) => {
      this.onMenuIconClick(index)
    },
    componentTag: TAG
  }).linkController(this.scroller)

  // 隐私协议弹窗控制器
  private privacyDialogController: CustomDialogController | null = new CustomDialogController({
    builder: PrivacyPolicyDialog({
      onAgree: () => {
        this.onPrivacyAgree();
      },
      onDisagree: () => {
        this.onPrivacyDisagree();
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: true,
    onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
      // 阻止用户通过返回键或点击外部关闭弹窗
      if (dismissDialogAction.reason === DismissReason.PRESS_BACK ||
          dismissDialogAction.reason === DismissReason.TOUCH_OUTSIDE) {
        dismissDialogAction.dismiss();
      }
    }
  })

  async aboutToAppear() {
    avPlayerManager.setAudioSession()

    this.zhishi_UI = PreferencesCache.getUserPreference('zhishi_UI', '0')
    if (this.zhishi_UI === '1') {
      this.limit = 20
    }

    // avPlayerManager.avPlayer?.setVolume(Number(PreferencesCache.getUserPreference('Volume','100'))/100)
    if (PreferencesCache.getUserPreference('Lyic_desktop', '0') === '1') {
      PipManager.getInstance().init(this.getUIContext().getHostContext() as Context); // 创建画中画控制器
      PipManager.getInstance().setAutoStart(true); // 设置应用退后台时自动启动画中画
    }
    // 检查用户是否已同意隐私协议
    if (PreferencesCache.getUserPreference(this.policyVersion, '0') === '0') {
      // 延迟显示弹窗，确保UI已完全加载
      setTimeout(() => {
        if (this.privacyDialogController) {
          this.privacyDialogController.open();
        }
      }, 500);
    }

    // 注册断点系统
    this.breakpointSystem.register(this.getUIContext())
    HorizontalMode(this.getUIContext().getHostContext() as Context, this.HorizontalMode_ctrl === '1')
    AppStorage.setOrCreate("pageStack", this.pageStack)
    let productSeries: string = deviceInfo.productSeries
    let deviceType: string = deviceInfo.deviceType
    if (deviceType != 'phone' && productSeries != 'VDE') {
      AppStorage.setOrCreate<boolean>('isWideScreen', true)
    } else {
      AppStorage.setOrCreate<boolean>('isWideScreen', false)

    }
    AppStorage.setOrCreate("devicetype", deviceType)
    PreferencesCache.setUserPreference('devicetype', deviceType)
    if (productSeries == 'VDE') {
      PreferencesCache.setUserPreference('is_Pura_X', '1')
    } else {
      PreferencesCache.setUserPreference('is_Pura_X', '0')
    }
  }

  // 处理用户同意隐私协议
  private onPrivacyAgree() {
    LogUtil.info(TAG, '用户同意隐私协议');
    PreferencesCache.setUserPreference(this.policyVersion, '1');
  }

  // 处理用户不同意隐私协议
  private onPrivacyDisagree() {
    LogUtil.info(TAG, '用户不同意隐私协议，退出应用');
    ToastUtil.showShort($r('app.string.privacy_policy_required_message'));
    // 退出应用
    setTimeout(() => {
      let context = getContext(this) as common.UIAbilityContext;
      context.terminateSelf();
    }, 500);
  }

  async initData() {
    this.loading = true
    SourceAdapter.getAllRecommend().then(() => {
      LogUtil.info(`[${TAG}]`, `首页刷新数据成功`)
    }).finally(() => {
      this.loading = false
    })

  }

  onPageShow(): void {
    console.info(TAG, 'onPageShow')
    PipManager.getInstance().init(this.getUIContext().getHostContext() as Context); // 创建画中画控制器
    PipManager.getInstance().setAutoStart(true); // 设置应用退后台时自动启动画中画
    PipManager.getInstance().startPip();
  }

  onPageHide(): void {
    console.info(TAG, 'onPageHide')
    PipManager.getInstance().setAutoStart(false);
  }

  aboutToDisappear() {
    this.breakpointSystem.unregister()
    PipManager.getInstance().unregisterPipStateChangeListener(); // 解注册画中画生命周期及状态回调
    // 清理弹窗控制器
    if (this.privacyDialogController) {
      this.privacyDialogController = null;
    }
  }

  @Builder
  Title() {

    Column() {
      // PC工具栏适配
      Row()
        .height(this.topRect > this.decorHeight ? this.topRect : this.decorHeight)
        .backgroundColor('transparent')
        .width('100%')

      Row() {
        Text($r("app.string.homepage"))
          .fontColor($r('app.color.text_title'))
          .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
          .fontSize($r('app.float.title_font_size'))

        Row({space:4}) {
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
      .height(StyleConstants.TITLE_HEIGHT)
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
    // 使用Grid布局实现响应式：窄屏2×2，宽屏1×4
    Grid() {
      ForEach(this.menuItems, (item: HomePageMenu) => {
        GridItem() {
          MenuButton({
            title: item.title,
            onNavigate: () => {
              this.pageStack.pushPath({ name: item.path })
            }
          })
        }
        .padding(4)
      })
    }
    .columnsTemplate(this.currentBreakpoint === 'sm' ? COLUMNS_TEMPLATE_SM : COLUMNS_TEMPLATE_LG)
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
      loading: this.loading,
    })
  }

  @Builder
  RecommendedPlaylists() {
    Segment({
      lists: this.recommendPlaylist,
      type: 'Playlist',
      title: $r('app.string.recommended_playlists'),
      loading: this.loading,
    })
  }

  @Builder
  RecommendedArtists() {
    Segment({
      lists: this.recommendArtists,
      type: 'Artist',
      title: $r('app.string.recommended_artists'),
      loading: this.loading,
      radius: "100%",
    })
  }

  @Builder
  TopLists() {
    Segment({
      lists: this.topList,
      type: 'TopPlaylist',
      title: $r('app.string.chart'),
      loading: this.loading
    })
  }

  @Builder
  ForYouSection() {
    Segment({
      lists: this.playlists.filter(playlist =>
      playlist.id && playlist.id.toString().startsWith('key_')
      ),
      type: 'Capsule',
      title: $r('app.string.for_you'),
      loading: this.loading
    })
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
      if (this.zhishi_UI === '1') {
        IS_2IN1_UI({
          page_judge: this.page_judge,
          title: this.title
        })
      } else {
        Stack({ alignContent: Alignment.Bottom }) {

          Column() {
            List({ scroller: this.scroller }) {
              HeaderPlaceholder()

              ListItem() {
                HeaderAnimation({ scrollController: this.scrollController, isShowLoadingProgress: true })
              }

              if (this.adapters.length > 0) {
                ListItem() {
                  this.MenuGrid()
                }

                // 专属于你模块
                ListItem() {
                  this.ForYouSection()
                }
                .visibility(this.loading || this.playlists.filter(playlist =>
                playlist.id && playlist.id.toString().startsWith('key_')
                ).length > 0 ? Visibility.Visible : Visibility.None)

                ListItem() {
                  this.RecommendedSongs()
                }
                .visibility(this.loading || this.recommendPlaylist.length > 0 ? Visibility.Visible : Visibility.None)

                ListItem() {
                  this.RecommendedPlaylists()
                }
                .visibility(this.loading || this.recommendSongs.length > 0 ? Visibility.Visible : Visibility.None)

                ListItem() {
                  this.RecommendedArtists()
                }
                .visibility(this.loading || this.recommendArtists.length > 0 ? Visibility.Visible : Visibility.None)

                ListItem() {
                  this.TopLists()
                }
                .visibility(this.loading || this.topList.length > 0 ? Visibility.Visible : Visibility.None)

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
                .visibility(this.hasRecommendation() ? Visibility.Visible : Visibility.None)

              } else {
                ListItem() {
                  this.EmptyDataSource()
                }
              }

              FooterPlaceholder()
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .layoutWeight(1)
            .backToTop(true)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
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
          .zIndex(0)

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
        .height(StyleConstants.FULL_HEIGHT)
        .width(StyleConstants.FULL_WIDTH)
      }
    }
    .height(StyleConstants.FULL_HEIGHT)
    .width(StyleConstants.FULL_WIDTH)
    // .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
    .hideToolBar(true)
    .hideTitleBar(true)
    .hideBackButton(true)
    .backgroundColor($r('app.color.page_background'))
    .onBackPressed(() => {
      if (this.page_judge !== 'index') {
        this.page_judge = 'index'
        this.title = '首页'
        return true
      }
      return false
    })
  }

  hasRecommendation(): boolean {
    return !this.loading
      && this.recommendPlaylist.length === 0
      && this.recommendSongs.length === 0
      && this.recommendArtists.length === 0
      && this.topList.length === 0
  }

  getBlankHeight(): number {
    let sub = this.winHeight - this.blankHeight - 50 - (this.bottomRect + this.topRect)
    return sub > 0 ? sub : 0
  }
}
