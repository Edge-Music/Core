import { ID } from '../type/Adapter';
import { StyleConstants } from '../constants/StyleConstants';
import { AnimationConstants } from '../constants/AnimationConstants';
import { DownloadProgress, SongDownloadItem, SongDownloadManager } from '../util/SongDownloadManager';
import { MiniPlaybackControl } from '../component/MiniPlaybackControl';
import { TitleHeader } from '../component/TitleHeader';
import { ScrollController } from '../util/ScrollController';
import { HeaderAnimation } from '../component/HeaderAnimation';
import { HeaderPlaceholder } from '../component/HeaderPlaceholder';
import { HeaderComponent } from '../component/HeaderComponent';
import { FooterPlaceholder } from '../component/FooterPlaceholder';
import { PlaylistManager } from '../util/PlaylistManager';
import { PushPathHelper } from '../util/PushPathHelper';

const TAG = 'Download'

@Component
export struct Download {
  @State groupHeight: number = 0;
  @State groupHeight1: number = 0;
  @State scrollOffsetY: number = 0
  @State startScrollOffsetY: number = 0
  @State scrollOffsetEndY: number = 0
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageProp('bottomRect') bottomRect: number = 0;
  @StorageProp('topRect') topRect: number = 0;
  @StorageProp('winHeight') winHeight: number = 0;
  @StorageLink('download_queue') queue: Map<ID, DownloadProgress> = new Map();
  @State downloadHistory: SongDownloadItem[] = [];
  @State currentTabIndex: number = 0;
  private tabsController: TabsController = new TabsController();
  private scroller: Scroller = new Scroller();
  @State scrollController: ScrollController = new ScrollController({
    onIndexChange: (index): void => this.onMenuIconClick(index),
    componentTag: TAG
  }).linkController(this.scroller)
  private scroller1: Scroller = new Scroller();
  @State scrollController1: ScrollController = new ScrollController({
    onIndexChange: (index): void => this.onMenuIconClick(index),
    componentTag: TAG
  }).linkController(this.scroller1)

  subTitles: Resource[] = [$r('app.string.downloading'), $r('app.string.download_history')]
  @State capsuleOffset: number = 0
  @State capsuleWidth: number = 0
  @State titleWidths: number[] = []
  private readonly BUTTON_GAP: number = 10
  @State capsuleScaleX: number = 0.9
  @State capsuleScaleY: number = 1.0
  uiContext: UIContext | undefined = undefined;
  @State @Watch('onChangeSubTitleIndex') subTitleIndex: number = 0
  @State downloadButtonStatus: number = 1
  @State enableDownloadButton: boolean = false
  @State enableClearButton: boolean = false
  @State timer: number = -1

  aboutToAppear(): void {
    if(this.timer === -1) {
      this.timer = setInterval(() => {
        const stats = SongDownloadManager.getQueueStats();
        this.enableClearButton = stats.completed > 0
        this.enableDownloadButton = stats.completed != stats.total
        this.downloadButtonStatus = stats.completed != stats.total && stats.paused > 0 ? 0 : 1
      }, 500)
    }
    this.uiContext = this.getUIContext();
    this.loadDownloadHistory();
  }

  aboutToDisappear(): void {
    this.timer = -1
  }

  loadDownloadHistory(): void {
    try {
      const history = SongDownloadManager.getAllDownloads();
      // 按下载时间倒序排列
      this.downloadHistory = history.sort((a, b) => b.downloadTime - a.downloadTime);
    } catch (error) {
      this.downloadHistory = [];
    }
  }

  onMenuIconClick(index: number) {
    if (index === 0 && this.pageStack.size() > 1) {
      this.pageStack.pop()
    }
  }

  getStatusText(item: DownloadProgress): string {
    switch (item.status) {
      case 'waiting':
        if (item.queuePosition !== undefined) {
          const totalWaiting = Array.from(this.queue.values()).filter(p => p.status === 'waiting').length;
          return `等待中 ${item.queuePosition}/${totalWaiting}`;
        }
        return '等待中';
      case 'downloading':
        return `下载中 ${Math.round(item.progress)}%`;
      case 'completed':
        return '已完成';
      case 'paused':
        return '已暂停';
      case 'retrying':
        return `重试中 ${item.retryCount}/3`;
      case 'failed':
        return '下载失败';
      case 'error':
        return '下载失败';
      default:
        return '';
    }
  }

  getStatusColor(status: string): ResourceStr {
    switch (status) {
      case 'downloading':
      case 'retrying':
        return $r('app.color.text_click');
      case 'completed':
        return $r('app.color.text_hint');
      case 'paused':
        return $r('app.color.text_secondary');
      case 'failed':
      case 'error':
        return $r('app.color.error');
      default:
        return $r('app.color.text_secondary');
    }
  }

  shouldShowPauseButton(): boolean {
    const stats = SongDownloadManager.getQueueStats();
    return stats.downloading > 0 || stats.waiting > 0;
  }

  shouldShowResumeButton(): boolean {
    const stats = SongDownloadManager.getQueueStats();
    return stats.paused > 0;
  }

  shouldShowClearButton(): boolean {
    const stats = SongDownloadManager.getQueueStats();
    return stats.completed > 0;
  }

  onPauseAll(): void {
    SongDownloadManager.pauseAll();
  }

  onResumeAll(): void {
    SongDownloadManager.resumeAll();
  }

  onClearCompleted(): void {
    SongDownloadManager.clearCompleted();
    this.loadDownloadHistory();
  }

  @Builder
  Title() {
    TitleHeader({
      title: $r('app.string.download_short'),
      backActive: this.scrollController.currentIndex === 0,
      midContent: () => {
        this.TabsTitles()
      },
      rightContent: () => {
        this.ButtonS()
      }
    })
  }

  @Builder
  ButtonS() {
    // 控制按钮组
    Row({ space: 8 }) {
      // 清除已完成按钮
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.clean'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.text_primary'))
      }
      .width(40)
      .height(40)
      .onClick(() => {
        this.onClearCompleted();
      })
      .enabled(this.enableClearButton ? true : false)
      .backgroundColor('transparent')

      // 暂停/继续按钮
      Button({ type: ButtonType.Circle }) {
        Image(this.downloadButtonStatus === 0 ? $r('app.media.ic_download') : $r('app.media.ic_pause'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.text_primary'))
      }
      .width(40)
      .height(40)
      .onClick(() => {
        if(this.downloadButtonStatus === 0) {
          this.onResumeAll();
        } else {
          this.onPauseAll();
        }
      })
      .enabled(this.enableDownloadButton ? true : false)
      .backgroundColor('transparent')
    }
  }

  @Builder
  TabBar() {
    Row() {
      Text($r('app.string.downloading'))
        .fontSize(16)
        .fontWeight(this.currentTabIndex === 0 ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTabIndex === 0 ? $r('app.color.text_click') : $r('app.color.text_secondary'))
        .padding({ bottom: 8 })
        .borderRadius(0)
        .onClick(() => {
          this.currentTabIndex = 0;
          this.tabsController.changeIndex(0);
        })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text($r('app.string.download_history'))
        .fontSize(16)
        .fontWeight(this.currentTabIndex === 1 ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTabIndex === 1 ? $r('app.color.text_click') : $r('app.color.text_secondary'))
        .padding({ bottom: 8 })
        .borderRadius(0)
        .onClick(() => {
          this.currentTabIndex = 1;
          this.tabsController.changeIndex(1);
          this.loadDownloadHistory();
        })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  DownloadingTab() {
    List({ scroller: this.scroller }) {
      HeaderPlaceholder()

      ListItem(){
        HeaderAnimation({ scrollController: this.scrollController })
      }

      if (this.queue.size === 0) {
        ListItem() {
          Column() {
            Text($r('app.string.no_download_tasks'))
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
          ForEach(Array.from(this.queue.entries()), (item: [string, DownloadProgress]) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text(item[1].song.name)
                      .fontSize(16)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ bottom: 4 })

                    Text(item[1].song.artists?.map(artist => artist.name).join(' / ') || '未知艺术家')
                      .fontSize(14)
                      .fontColor($r('app.color.text_secondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Column() {
                    Text(this.getStatusText(item[1]))
                      .fontSize(14)
                      .fontColor(this.getStatusColor(item[1].status))
                      .fontWeight(FontWeight.Medium)

                    // 显示错误信息
                    if (item[1].errorMessage && (item[1].status === 'failed' || item[1].status === 'error')) {
                      Text(item[1].errorMessage)
                        .fontSize(12)
                        .fontColor($r('app.color.error'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: 2 })
                    }
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width(StyleConstants.FULL_WIDTH)
              }
              .width(StyleConstants.FULL_WIDTH)
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
              .margin({ bottom: 8 })
            }
            .width(StyleConstants.FULL_WIDTH)
            .padding({ left: 16, right: 16 })
          })
        }
        .onAreaChange((_: Area, newValue: Area) => {
          this.groupHeight = newValue.height as number
        })

        ListItem(){
          Row(){
            Blank().height(this.getBlankHeight(this.groupHeight))
          }
        }
      }

      FooterPlaceholder()
    }
    .backToTop(true)
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
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

  @Builder
  HistoryTab() {
    List({ scroller: this.scroller1 }) {
      HeaderPlaceholder()

      ListItem(){
        HeaderAnimation({ scrollController: this.scrollController1 })
      }

      if (this.downloadHistory.length === 0) {
        ListItem() {
          Column() {
            Text($r('app.string.no_download_history'))
              .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(400)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      } else {
        ListItemGroup(){
          ForEach(this.downloadHistory, (item: SongDownloadItem) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text(item.song.name)
                      .fontSize(16)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ bottom: 4 })

                    Text(item.song.artists?.map(artist => artist.name).join(' / ') || '未知艺术家')
                      .fontSize(14)
                      .fontColor($r('app.color.text_secondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Column() {
                    Text($r('app.string.completed'))
                      .fontSize(14)
                      .fontColor($r('app.color.text_hint'))
                      .fontWeight(FontWeight.Medium)
                  }
                }
                .width(StyleConstants.FULL_WIDTH)
              }
              .width(StyleConstants.FULL_WIDTH)
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
              .margin({ bottom: 8 })
              .onClick(() => {
                PushPathHelper.loading("Playing", async () => {
                  PlaylistManager.insertSongs([item.song], 0, item.song);
                })
              })
              .clickEffect({ level: ClickEffectLevel.LIGHT })
            }
            .width(StyleConstants.FULL_WIDTH)
            .padding({ left: 16, right: 16 })
          }, (item: SongDownloadItem) => item.song.id.toString())
        }.onAreaChange((_: Area, newValue: Area) => {
          this.groupHeight1 = newValue.height as number
        })

        ListItem(){
          Row(){
            Blank().height(this.getBlankHeight(this.groupHeight1))
          }
        }
      }

      FooterPlaceholder()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
    .onWillScroll(this.scrollController1.scrollHandlers.onWillScroll)
    .onScrollStop(this.scrollController1.scrollHandlers.onScrollStop)
    .onDidScroll(() => {
      this.scrollOffsetY = this.scroller1.currentOffset().yOffset
    })
    .onTouch((event) => {
      switch (event.type) {
        case TouchType.Down:
          this.startScrollOffsetY = this.scroller1.currentOffset().yOffset
      }
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          Tabs({ barPosition: BarPosition.Start, controller: this.tabsController }) {
            TabContent() {
              this.DownloadingTab()
            }

            TabContent() {
              this.HistoryTab()
            }
          }
          .barMode(BarMode.Fixed)
          .barHeight(0)
          .layoutWeight(1)
          .onChange((index: number) => {
            this.currentTabIndex = index;
            this.subTitleIndex = index
            if (index === 1) {
              this.loadDownloadHistory();
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

  private updateCapsulePosition(index: number) {
    this.tabsController.changeIndex(index);
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

  getBlankHeight(height: number): Length {
    let sub = this.winHeight - height - 50 - (this.bottomRect+this.topRect)
    return sub > 0 ? sub : 0
  }

  onChangeSubTitleIndex() {
    this.updateCapsulePosition(this.subTitleIndex)
  }
}