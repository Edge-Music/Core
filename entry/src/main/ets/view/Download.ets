import { ID, Song } from '../type/Adapter';
import { StyleConstants } from '../constants/StyleConstants';
import { DownloadProgress, SongDownloadManager } from '../util/SongDownloadManager';
import { SlideDownControl } from '../util/SlideDownController';
import { MiniPlaybackControl } from '../component/MiniPlaybackControl';
import { TitleHeader } from '../component/TitleHeader';
import { ToastUtil } from '@pura/harmony-utils';

@Component
export struct Download {
  @Consume('NavPathStack') pageStack: NavPathStack;
  @State currentIndex: number = -1;
  @StorageProp('bottomRect') bottomRect: number = 0;
  @StorageProp('topRect') topRect: number = 0;
  @StorageProp('winHeight') winHeight: number = 0;
  @StorageLink('download_queue') queue: Map<ID, DownloadProgress> = new Map();
  private scrollController: Scroller = new Scroller();

  @Builder
  Title() {
    TitleHeader({
      title: $r('app.string.download'),
      backActive: this.currentIndex === 0
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          // 标题
          this.Title()

          // 下载列表
          List({ scroller: this.scrollController }) {
            if (this.queue.size === 0) {
              ListItem() {
                Column() {
                  Text('暂无下载任务')
                    .fontSize(16)
                    .fontColor($r('app.color.text_secondary'))
                }
                .width(StyleConstants.FULL_WIDTH)
                .height(200)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
              }
            } else {
              ForEach(Array.from(this.queue.entries()), (item: [string, DownloadProgress]) => {
                ListItem() {
                  Column() {
                    // 歌曲信息
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

                      Text(`${Math.round(item[1].progress)}%`)
                        .fontSize(14)
                        .fontColor($r('app.color.text_click'))
                        .fontWeight(FontWeight.Medium)
                    }
                    .width(StyleConstants.FULL_WIDTH)
                    .padding({ bottom: 12 })
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

            // 底部空白区域
            ListItem() {
              Column() {
                Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + 16)
              }
              .width(StyleConstants.FULL_WIDTH)
              .backgroundColor('transparent')
            }
          }
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
          .scrollBar(BarState.Off)
          .expandSafeArea()
          .onWillScroll((scrollOffset: number, scrollState: ScrollState, scrollSource: ScrollSource) => {
            if (scrollState === ScrollState.Scroll) {
              const positionY = this.scrollController.currentOffset().yOffset;
              if (positionY < 0) {
                const index = SlideDownControl.calculateCurrentIndex(this.scrollController.currentOffset().yOffset, 2);
                this.currentIndex = index;
              } else {
                this.currentIndex = -1;
              }
            }
          })
          .onScrollStop(() => {
            if (this.currentIndex === 0) {
              this.pageStack.pop();
            }
            this.currentIndex = -1;
          })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)

        // 底部迷你播控组件
        MiniPlaybackControl()
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
    .hideToolBar(true)
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_background'))
    .mode(NavDestinationMode.STANDARD)
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .expandSafeArea()
    .gesture(
      SwipeGesture({
        direction: SwipeDirection.Vertical,
      }).onAction((event) => {
        if (event.angle < 0) {
          // 向上滑
        } else {
          // 向下滑，返回上一页
          this.pageStack.pop();
        }
      })
    )
  }
} 