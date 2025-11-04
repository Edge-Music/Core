import { StyleConstants } from '../constants/StyleConstants';
import { TitleHeader } from '../component/TitleHeader';
import { playRecordManager } from '../util/PlayRecordManager';
import { PlayRecord, TimeSlotStats, ArtistStats } from '../model/PlayRecord';
import { Song } from '../type/Adapter';
import { PlaylistManager } from '../util/PlaylistManager';
import { PushPathHelper } from '../util/PushPathHelper';
import { ChartOptions, UCharts, UChartsController } from '@ibestservices/ucharts';
import { HeaderComponent } from '../component/HeaderComponent';
import { ScrollController } from '../util/ScrollController';
import { HeaderPlaceholder } from '../component/HeaderPlaceholder';
import { HeaderAnimation } from '../component/HeaderAnimation';
import { FooterPlaceholder } from '../component/FooterPlaceholder';

const TAG = 'Statistics'
@Component
export struct Statistics {
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageProp('topRect') topRect: number = 0;
  @StorageProp('bottomRect') bottomRect: number = 0;
  @State currentTabIndex: number = 0;
  private tabsController: TabsController = new TabsController();
  @State playRecords: PlayRecord[] = [];
  @State timeSlotStats: TimeSlotStats = { dawn: 0, morning: 0, afternoon: 0, evening: 0 };
  @State topArtists: ArtistStats[] = [];
  @State chartController: UChartsController = new UChartsController();
  private chartOptions: Partial<ChartOptions> = {};
  @State scrollOffsetY: number = 0
  @State startScrollOffsetY: number = 0

  subTitles: string[] = ['播放历史', '统计数据']
  @State capsuleOffset: number = 0
  @State capsuleWidth: number = 0
  @State titleWidths: number[] = []
  private readonly BUTTON_GAP: number = 10
  @State capsuleScaleX: number = 0.9
  @State capsuleScaleY: number = 1.0
  uiContext: UIContext | undefined = undefined;
  @State @Watch('onChangeSubTitleIndex') subTitleIndex: number = 0

  @StorageProp('winHeight') winHeight: number = 0;
  @State groupHeight: number = 0;

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

  async aboutToAppear() {
    this.uiContext = this.getUIContext();
    // 初始化播放记录管理器
    await playRecordManager.initialize();
    // 加载数据
    this.loadData();
  }

  onMenuIconClick(index: number) {
    if (index === 0 && this.pageStack.size() > 1) {
      this.pageStack.pop()
    }
  }

  loadData() {
    // 获取播放记录
    this.playRecords = playRecordManager.getAllRecords();
    // 获取时段统计
    this.timeSlotStats = playRecordManager.getTimeSlotStats();
    // 获取最喜欢的歌手
    this.topArtists = playRecordManager.getTopArtists(5);
    // 更新图表
    this.updateChart();
  }

  updateChart() {
    const seriesData: number[] = [
      this.timeSlotStats.dawn,
      this.timeSlotStats.morning,
      this.timeSlotStats.afternoon,
      this.timeSlotStats.evening
    ];

    this.chartOptions = {
      type: "column",
      categories: ["凌晨", "上午", "下午", "晚上"],
      series: [
        {
          name: "播放次数",
          data: seriesData
        } as ESObject
      ],
      padding: [15, 15, 0, 15],
      xAxis: {
        disableGrid: true,
        fontSize: 12,
        fontColor: '#666666'
      } as ESObject,
      yAxis: {
        data: [{ min: 0 } as ESObject],
        fontSize: 12,
        fontColor: '#666666'
      } as ESObject,
      extra: {
        column: {
          type: "group",
          width: 40,
          activeBgColor: "#000000",
          activeBgOpacity: 0.08
        } as ESObject
      } as ESObject,
      color: ['#4A90E2']
    } as Partial<ChartOptions>;
  }

  @Builder
  Title() {
    TitleHeader({
      title: $r('app.string.statistics'),
      backActive: this.scrollController.currentIndex === 0,
      midContent: () => {
        this.TabsTitles()
      }
    })
  }

  @Builder
  PlayHistoryTab() {
    List({ scroller: this.scroller }) {
      HeaderPlaceholder()

      ListItem(){
        HeaderAnimation({ scrollController: this.scrollController })
      }

      if (this.playRecords.length === 0) {
        ListItem() {
          // 空状态
          Column() {
            Image($r('app.media.ic_music'))
              .width(100)
              .height(100)
              .fillColor($r('app.color.text_hint'))
              .opacity(0.3)
              .margin({ bottom: 16 })

            Text('暂无播放记录')
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
          }
          .width(StyleConstants.FULL_WIDTH)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      } else {
        ListItemGroup() {
          ForEach(this.playRecords, (record: PlayRecord, index: number) => {
            ListItem() {
              this.PlayRecordItem(record, index)
            }
          })
        }
        .divider({
          strokeWidth: 0.5,
          color: $r('app.color.divider'),
          startMargin: 40,
          endMargin: 0
        })
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
    .layoutWeight(1)
    .padding({ left: 16, right: 16 })
    .alignListItem(ListItemAlign.Start)
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
  PlayRecordItem(record: PlayRecord, index: number) {
    Row() {
      // 排名
      Text((index + 1).toString())
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(index < 3 ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
        .width(30)
        .textAlign(TextAlign.Center)

      // 歌曲信息
      Column({ space: 4 }) {
        Text(record.song.name)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(record.song.artists.map(a => a.name).join('/'))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      // 播放次数
      Text(`${record.playCount}次`)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ top: 12, bottom: 12 })
    .onClick(() => {
      PushPathHelper.loading("Playing", async () => {
        PlaylistManager.insertSongs([record.song], 0, record.song);
      })
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT })
  }

  @Builder
  StatsTab() {
    List({ scroller: this.scroller1 }) {
      HeaderPlaceholder()

      ListItem(){
        HeaderAnimation({ scrollController: this.scrollController1 })
      }

      ListItem() {
        Column() {
          // 总览卡片
          Row({ space: 12 }) {
            // 总播放次数
            Column({ space: 4 }) {
              Text(playRecordManager.getTotalPlayCount().toString())
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.accent_primary'))

              Text('总播放次数')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .layoutWeight(1)
            .padding(16)
            .backgroundColor($r('app.color.surface_1'))
            .borderRadius(12)

            // 歌曲数量
            Column({ space: 4 }) {
              Text(playRecordManager.getRecordCount().toString())
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.accent_primary'))

              Text('播放歌曲数')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .layoutWeight(1)
            .padding(16)
            .backgroundColor($r('app.color.surface_1'))
            .borderRadius(12)
          }
          .width(StyleConstants.FULL_WIDTH)
          .padding({ left: 16, right: 16, top: 16 })

          // 时段统计标题
          Text('时段统计')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width(StyleConstants.FULL_WIDTH)
            .padding({ left: 16, right: 16, top: 24, bottom: 12 })

          // 图表
          if (playRecordManager.getTotalPlayCount() > 0) {
            UCharts({
              controller: this.chartController,
              onReady: () => {
                this.chartController.updateData(this.chartOptions);
              }
            })
              .width(StyleConstants.FULL_WIDTH)
              .height(300)
              .padding({ left: 16, right: 16 })
          } else {
            // 无数据提示
            Column() {
              Image($r('app.media.ic_gearshape'))
                .width(80)
                .height(80)
                .fillColor($r('app.color.text_hint'))
                .opacity(0.3)
                .margin({ bottom: 12 })

              Text('暂无统计数据')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(300)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }

          // 最喜欢的歌手
          Text('最喜欢的歌手')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width(StyleConstants.FULL_WIDTH)
            .padding({ left: 16, right: 16, top: 24, bottom: 12 })

          if (this.topArtists.length > 0) {
            Column({ space: 0 }) {
              ForEach(this.topArtists, (artist: ArtistStats, index: number) => {
                this.TopArtistItem(artist, index)
              })
            }
            .width(StyleConstants.FULL_WIDTH)
            .padding({ left: 16, right: 16 })
            .borderRadius(12)
            .backgroundColor($r('app.color.surface_1'))
          } else {
            Column() {
              Text('暂无数据')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(100)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .padding({ bottom: this.bottomRect + 16 })
      }

      FooterPlaceholder()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
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

  @Builder
  TopArtistItem(artist: ArtistStats, index: number) {
    Row() {
      // 排名
      Text((index + 1).toString())
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(index < 3 ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
        .width(30)
        .textAlign(TextAlign.Center)

      // 歌手名称
      Text(artist.artistName)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .margin({ left: 12 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 播放次数
      Text(`${artist.playCount}次`)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(48)
    .padding({ left: 12, right: 12 })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          // Tabs
          Tabs({ index: this.currentTabIndex, controller: this.tabsController }) {
            TabContent() {
              this.PlayHistoryTab()
            }

            TabContent() {
              this.StatsTab()
            }
          }
          .width(StyleConstants.FULL_WIDTH)
          .barHeight(0)
          .layoutWeight(1)
          .barMode(BarMode.Fixed)
          .onChange((index: number) => {
            this.currentTabIndex = index;
            this.subTitleIndex = index;
          })
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)

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
    .hideTitleBar(true)
    .hideToolBar(true)
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

  onChangeSubTitleIndex() {
    this.updateCapsulePosition(this.subTitleIndex)
  }

  private updateCapsulePosition(index: number) {
    this.tabsController.changeIndex(index)
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

  getBlankHeight(): Length {
    let sub = this.winHeight - this.groupHeight - 50 - (this.bottomRect+this.topRect)
    return sub > 0 ? sub : 0
  }
}

