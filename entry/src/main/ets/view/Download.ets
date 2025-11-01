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
  private scroller: Scroller = new Scroller();
  private tabsController: TabsController = new TabsController();
  @State scrollController: ScrollController = new ScrollController({
    onIndexChange: (index): void => this.onMenuIconClick(index),
    componentTag: TAG
  }).linkController(this.scroller)

  aboutToAppear(): void {
    this.loadDownloadHistory();
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
    Row() {
      TitleHeader({
        title: $r('app.string.download'),
        backActive: this.scrollController.currentIndex === 0
      })

      Blank()

      // 控制按钮组
      Row({ space: 8 }) {
        // 清除已完成按钮
        if (this.shouldShowClearButton()) {
          Text($r('app.string.clear_completed'))
            .fontSize(14)
            .fontColor($r('app.color.text_click'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(16)
            .backgroundColor($r('app.color.card_background'))
            .onClick(() => {
              this.onClearCompleted();
            })
        }

        // 暂停/继续按钮
        if (this.shouldShowPauseButton()) {
          Text($r('app.string.pause_all'))
            .fontSize(14)
            .fontColor($r('app.color.text_click'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(16)
            .backgroundColor($r('app.color.card_background'))
            .onClick(() => {
              this.onPauseAll();
            })
        } else if (this.shouldShowResumeButton()) {
          Text($r('app.string.resume_all'))
            .fontSize(14)
            .fontColor($r('app.color.text_click'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(16)
            .backgroundColor($r('app.color.card_background'))
            .onClick(() => {
              this.onResumeAll();
            })
        }
      }
      .padding({ right: 16 })
    }
    .width(StyleConstants.FULL_WIDTH)
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

      ListItem() {
        this.TabBar()
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
          .height(400)
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
            Blank().height(this.getBlankHeight())
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
    List() {
      HeaderPlaceholder()

      ListItem(){
        HeaderAnimation({ scrollController: this.scrollController })
      }

      ListItem() {
        this.TabBar()
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
        }
      }

      FooterPlaceholder()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          Tabs({ barPosition: BarPosition.Start, controller: this.tabsController }) {
            TabContent() {
              this.DownloadingTab()
            }
            .tabBar(SubTabBarStyle.of($r('app.string.downloading')))

            TabContent() {
              this.HistoryTab()
            }
            .tabBar(SubTabBarStyle.of($r('app.string.download_history')))
          }
          .barMode(BarMode.Fixed)
          .barHeight(0)
          .onChange((index: number) => {
            this.currentTabIndex = index;
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

  getBlankHeight(): Length {
    let sub = this.winHeight - this.groupHeight - 50 - (this.bottomRect+this.topRect)
    return sub > 0 ? sub : 0
  }
}