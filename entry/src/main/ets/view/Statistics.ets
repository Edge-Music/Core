import { StyleConstants } from '../constants/StyleConstants';
import { TitleHeader } from '../component/TitleHeader';
import { playRecordManager } from '../util/PlayRecordManager';
import { PlayRecord, TimeSlotStats, ArtistStats } from '../model/PlayRecord';
import { Song } from '../type/Adapter';
import { PlaylistManager } from '../util/PlaylistManager';
import { PushPathHelper } from '../util/PushPathHelper';
import { ChartOptions, UCharts, UChartsController } from '@ibestservices/ucharts';

@Component
export struct Statistics {
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageProp('topRect') topRect: number = 0;
  @StorageProp('bottomRect') bottomRect: number = 0;
  @State currentTabIndex: number = 0;
  @State playRecords: PlayRecord[] = [];
  @State timeSlotStats: TimeSlotStats = { dawn: 0, morning: 0, afternoon: 0, evening: 0 };
  @State topArtists: ArtistStats[] = [];
  @State chartController: UChartsController = new UChartsController();
  private chartOptions: Partial<ChartOptions> = {};

  async aboutToAppear() {
    // 初始化播放记录管理器
    await playRecordManager.initialize();
    // 加载数据
    this.loadData();
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
      title: $r('app.string.statistics')
    })
  }

  @Builder
  PlayHistoryTab() {
    if (this.playRecords.length === 0) {
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
    } else {
      List() {
        ForEach(this.playRecords, (record: PlayRecord, index: number) => {
          ListItem() {
            this.PlayRecordItem(record, index)
          }
        })
      }
      .width(StyleConstants.FULL_WIDTH)
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
      .alignListItem(ListItemAlign.Start)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .divider({
        strokeWidth: 0.5,
        color: $r('app.color.divider'),
        startMargin: 60,
        endMargin: 0
      })
    }
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
    Scroll() {
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
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
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
      Column() {
        // 标题栏
        this.Title()

        // Tabs
        Tabs({ index: this.currentTabIndex }) {
          TabContent() {
            this.PlayHistoryTab()
          }
          .tabBar('播放历史')

          TabContent() {
            this.StatsTab()
          }
          .tabBar('统计数据')
        }
        .width(StyleConstants.FULL_WIDTH)
        .layoutWeight(1)
        .barMode(BarMode.Fixed)
        .onChange((index: number) => {
          this.currentTabIndex = index;
        })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
      .padding({ top: this.topRect })
      .backgroundColor($r('app.color.page_background'))
    }
    .hideTitleBar(true)
    .mode(NavDestinationMode.STANDARD)
  }
}

