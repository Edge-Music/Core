import { ID } from '../type/Adapter';
import { StyleConstants } from '../constants/StyleConstants';
import { DownloadProgress } from '../util/SongDownloadManager';
import { MiniPlaybackControl } from '../component/MiniPlaybackControl';
import { TitleHeader } from '../component/TitleHeader';
import { ScrollController } from '../util/ScrollController';
import { HeaderAnimation } from '../component/HeaderAnimation';
import { HeaderPlaceholder } from '../component/HeaderPlaceholder';
import { HeaderComponent } from '../util/HeaderComponent';
import { FooterPlaceholder } from '../component/FooterPlaceholder';

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
  private scroller: Scroller = new Scroller();
  @State scrollController: ScrollController = new ScrollController({
    onIndexChange: (index): void => this.onMenuIconClick(index),
    componentTag: TAG
  }).linkController(this.scroller)

  onMenuIconClick(index: number) {
    if (index === 0 && this.pageStack.size() > 1) {
      this.pageStack.pop()
    }
  }

  @Builder
  Title() {
    TitleHeader({
      title: $r('app.string.download'),
      backActive: this.scrollController.currentIndex === 0
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          // 下载列表
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
              .onAreaChange((oldValue: Area, newValue: Area) => {
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
            FooterPlaceholder()
          }
          .backToTop(true)
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
          .scrollBar(BarState.Off)
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

        // 底部迷你播控组件
        MiniPlaybackControl()

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