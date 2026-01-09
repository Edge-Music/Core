
import { SongInfo } from "../component/SongInfo";
import { TitleHeader } from "../component/TitleHeader";
import { StyleConstants } from "../constants/StyleConstants";
import { AnimationConstants } from "../constants/AnimationConstants";
import { Playlist, PlaylistType, Song } from "../type/Adapter";
import { BreakpointConstants } from "../constants/BreakpointConstants";
import { cover } from "../util/AdapterHelper";
import { PushPathHelper } from "../util/PushPathHelper";
import { PlaylistManager, PlayMode } from "../util/PlaylistManager";
import { MiniPlaybackControl } from "../component/MiniPlaybackControl";
import { SongDownloadManager } from "../util/SongDownloadManager";
import { ScrollController } from "../util/ScrollController";
import { HeaderAnimation } from "../component/HeaderAnimation";
import ResourceManager from "../util/ResourceManager";
import { ToastUtil } from "@pura/harmony-utils";
import { PreferencesCache } from "../util/PreferenceCache";
import { DialogHelper } from "@pura/harmony-dialog";
import { SongsDataSource } from "../util/SongsDataSource";
import { HeaderPlaceholder } from "../component/HeaderPlaceholder";
import { FooterPlaceholder } from "../component/FooterPlaceholder";
import { HeaderComponent } from "../component/HeaderComponent";

const TAG = 'PlayList'

@Component
export struct PlayList {
  @State searchContext: string = ResourceManager.getStringValueSync($r('app.string.search'))
  @State groupHeight: number = 0;
  @State selectedIndex: number = 0
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageLink('current_playlist_data') playlist: Playlist | null = AppStorage.get('current_playlist_data') as Playlist
  @StorageLink('current_playlist_songs') songs: Song[] = []
  @StorageLink('aggregation_playlist') aggregationPlaylist: Playlist[] = PreferencesCache.getPlaylistCache('aggregation_playlist')
  @Watch('onBreakpointChange') @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm'
  @State private songsDataSource: SongsDataSource = new SongsDataSource()
  private scroller: Scroller = new Scroller();
  @State isLoading: boolean = false;
  // 点击跳转后的闪烁效果索引
  @State billingIndex: number = -1
  // 是否为宽屏模式
  @State isWideScreen: boolean = false
  @State scrollOffsetY: number = 0
  @State startScrollOffsetY: number = 0
  @State scrollOffsetEndY: number = 0
  @State placeholderOffset: number = 0
  @StorageLink("cache_data_create_time") cacheTime: number = -1
  @StorageLink("current_playing_song") song: Song | null = null
  @StorageProp('bottomRect') bottomRect: number = 0;
  @StorageProp('topRect') topRect: number = 0;
  @StorageProp('winHeight') winHeight: number = 0;
  @State touch:number = -1
  // 搜索相关状态
  @State searchKeywords: string = ''
  @State filteredSongs: Song[] = []
  @State isSearching: boolean = false
  @State scrollController: ScrollController = new ScrollController({
    onIndexChange: (index) => {
      this.onMenuIconClick(index)
    },
    componentTag: TAG
  }).linkController(this.scroller)

  @Builder
  Title() {
    TitleHeader({
      title: this.playlist?.name,
      backActive: this.scrollController.currentIndex === 0,
    })
  }

  aboutToAppear(): void {
    // 初始化歌单数据
    this.initSongsData_()

    // 设置屏幕模式
    this.isWideScreen = this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM;
  }

  initSongsData_() {
    this.songsDataSource.pushMultiData(this.songs)
    this.songsDataSource.reloadData()
  }

  // 监听屏幕断点变化
  onBreakpointChange() {
    this.isWideScreen = this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM;
  }

  aboutToDisappear(): void {
    // 清空
    this.playlist = null;
    // this.prefetcher = null;
    // this.sourceOk = false;
  }

  onMenuIconClick(index: number) {
    if (index === 0 && this.pageStack.size() > 1) {
      this.pageStack.pop()
    }
  }

  // 歌曲列表逻辑
  @Builder
  SongListSection() {
    Column() {

      List({ scroller: this.scroller }) {
        HeaderPlaceholder({ offsetY: this.placeholderOffset+10 })

        ListItem() {
          // 下拉提示动画
          HeaderAnimation({ scrollController: this.scrollController })
        }

        ListItem() {
          // 手机端歌单信息头部
          this.MobilePlaylistHeader()
        }

        ListItemGroup() {
          if (this.isSearching) {
            ForEach(this.filteredSongs, (song: Song, index: number) => {
              ListItem() {
                SongInfo({
                  playlistId: this.playlist?.id,
                  song: song,
                  cover: cover(song?.album?.cover ?? "", 512),
                  index: index,
                  active: this.song?.id === song.id,
                  highlight: this.billingIndex === index,
                  onTap: (song: Song) => {
                    this.onSongTap(song, index);
                  },
                  rightSlot: () => {
                  },
                  isShowMenu: true
                })
              }
            })
          } else {
            LazyForEach(this.songsDataSource, (song: Song, index: number) => {
              ListItem() {
                SongInfo({
                  playlistId: this.playlist?.id,
                  playlistType: this.playlist?.type,
                  song: song,
                  cover: cover(song?.album?.cover ?? "", 512),
                  index: index,
                  touch:this.touch === index,
                  active: this.song?.id === song.id,
                  highlight: this.billingIndex === index,
                  onTap: (song: Song) => {
                    this.onSongTap(song, index);
                  },
                  deleteSong: (_: Song) => {
                    if(this.playlist?.type === PlaylistType.AGGREGATION) {
                      this.getUIContext().animateTo({
                        duration: AnimationConstants.DURATION_SLOW,
                        curve: AnimationConstants.CURVE_DECELERATE,
                        onFinish: () => {
                          this.songsDataSource.reloadData()
                        }
                      }, () => {
                        this.songsDataSource.deleteData(index)
                      })
                    }
                  },
                  isShowMenu: true
                })
              }
              .onTouch((event)=>{
                this.touch = index
                console.log('jizhishidebug_t'+this.touch)
                if(event.type ===TouchType.Up||event.type ===TouchType.Cancel){
                  this.touch = -1
                }
              })
              .transition(
                TransitionEffect.opacity(0)
                  .combine(TransitionEffect.translate({ x: '-200vp' }))
              )
            }, (song: Song, index: number) => `${song.id}-${index}`)
          }
        }
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.groupHeight = newValue.height as number
        })

        ListItem() {
          Row() {
            Blank().height(this.countSubVp())
          }
        }

        FooterPlaceholder()
      }
      .backToTop(true)
      .sticky(StickyStyle.Header | StickyStyle.Footer)
      .height(StyleConstants.FULL_HEIGHT)
      .width(StyleConstants.FULL_WIDTH)
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
      .listDirection(Axis.Vertical)
      .divider({ strokeWidth: 0 })
      .cachedCount(5)
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
    .layoutWeight(1)
  }

  // 处理封面点击，确保在任何屏幕模式下都能正确滚动和高亮
  private handleCoverClick(_song: Song, index: number) {

    // 触发滚动到对应位置
    // this.scrollController.scrollToIndex(index, true);
    // 使用ListItemGroup之后会导致scrollToIndex方法失效，无法穿透滚动，使用scrollTo滚动指定距离
    // 滚动位置为每个歌曲卡片高度(68) + 上下padding距离(2*4)，并向上便宜3个卡片的距离，使后面的滚动可以屏幕居中
    this.scroller.scrollTo({ xOffset: 0, yOffset: (68 + 8) * (index - 3), animation: true })
    // 设置高亮效果
    this.billingIndex = index;

    // 延迟重置闪烁索引
    setTimeout(() => {
      this.billingIndex = -1;
    }, 1000);
  }



  // 手机端歌单信息头部
  @Builder
  MobilePlaylistHeader() {
    if (this.playlist && !this.isWideScreen) {
      Column({ space: 12 }) {
        // 封面和基本信息
        Row({ space: 14 }) {
          // 封面
          Image(cover(this.playlist.cover || '', 200))
            .width(100)
            .height(100)
            .borderRadius(10)
            .backgroundColor($r('app.color.skeleton_loading'))
            .shadow({
              radius: 10,
              color: $r("app.color.shadow_medium"),
              offsetX: 0,
              offsetY: 3
            })

          // 信息
          Column({ space: 6 }) {
            Text(this.playlist.name)
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Bold)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (this.playlist.creator) {
              Text(this.playlist.creator.name || '未知')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
            }

            Row({ space: 4 }) {
              Text(`${this.songs?.length || 0}`)
                .fontSize(12)
                .fontColor($r('app.color.accent_primary'))
                .fontWeight(FontWeight.Medium)
              Text('首')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width(StyleConstants.FULL_WIDTH)
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        // 描述（如果有且不为空）
        if (this.playlist.description && this.playlist.description.trim().length > 0) {
          Text(this.playlist.description)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(16)
            .padding({ left: 16, right: 16, bottom: 8 })
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      // .backgroundColor($r('app.color.surface_1'))
      .borderRadius({ bottomLeft: 16, bottomRight: 16 })
    }
  }

  handlePlaylistPlayAll(song: Song) {
    PushPathHelper.loading("Playing", async () => {
      PlaylistManager.loadPlaylist(this.songs?.filter(song => song.privilege.playable) || [], song);
    })
  }

  onSongTap(song: Song, _index: number) {
    this.handlePlaylistPlayAll(song);
  }

  // 小屏幕布局
  @Builder
  MobileLayout() {
    Column() {
      this.SongListSection()
    }
    .height(StyleConstants.FULL_HEIGHT)
    .width(StyleConstants.FULL_WIDTH)
  }

  // 左侧面板 - 宽屏模式（大卡片设计，歌曲数量在底部）
  @Builder
  LeftPanel() {
    Column() {
      if (this.playlist) {
          // 歌单封面 - 完全居中
          Column() {
            Image(cover(this.playlist.cover || '', 400))
              .width(200)
              .height(200)
              .borderRadius(20)
              .backgroundColor($r('app.color.skeleton_loading'))
              .shadow({
                radius: 24,
                color: $r("app.color.shadow_medium"),
                offsetX: 0,
                offsetY: 12
              })
              .clip(true)
          }
          .width(StyleConstants.FULL_WIDTH)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 20, bottom: 20 })

          // 歌单信息
          Column({ space: 12 }) {
            // 创作者信息（如果有）
            if (this.playlist.creator) {
              Row() {
                Text('创建者: ')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                Text(this.playlist.creator.name || '未知')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .fontWeight(FontWeight.Medium)
              }
              .justifyContent(FlexAlign.Center)
            }

            // 歌单描述（如果有）
            if (this.playlist.description) {
              Column({ space: 8 }) {
                Text('歌单简介')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .margin({ top: 8, bottom: 4 })

                Text(this.playlist.description.length > 50 ? `${this.playlist.description.slice(0, 50)}...` :
                this.playlist.description)
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .width('90%')
                  .textAlign(TextAlign.Center)
              }
              .alignItems(HorizontalAlign.Center)
              .margin({ top: 8 })
              .width(StyleConstants.FULL_WIDTH)
            }
          }
          .width(StyleConstants.FULL_WIDTH)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .padding({ left: 16, right: 16 })
          .layoutWeight(1) // 使中间部分可以自适应伸缩

          // 歌曲数量 - 放在底部
          Row() {
            Text('共')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
            Text(`${this.songs?.length || 0}`)
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Bold)
            Text('首歌曲')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .justifyContent(FlexAlign.Center)
          .padding({ bottom: 24, top: 12 })
          .width(StyleConstants.FULL_WIDTH)
        }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .padding({ left: 16, right: 16, top: 80, bottom: 16 })
  }

  // 右侧面板 - 宽屏模式
  @Builder
  RightPanel() {
    Column() {
      // 歌曲列表组件
      this.SongListSection()
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  // 宽屏布局
  @Builder
  WideScreenLayout() {
    Row() {
      // 左侧面板 (1份宽度)
      Column() {
        this.LeftPanel()
      }
      .width('33%') // 1/3 的宽度
      .height(StyleConstants.FULL_HEIGHT)
      .backgroundColor($r('app.color.page_background'))

      // 右侧面板 (2份宽度)
      Column() {
        this.RightPanel()
      }
      .width('67%') // 2/3 的宽度
      .height(StyleConstants.FULL_HEIGHT)
      .backgroundColor($r('app.color.page_background'))
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          Column() {
            if (this.playlist && this.songs && this.songs.length > 0) {
              // 根据屏幕宽度选择布局
              if (this.isWideScreen) {
                // 宽屏布局
                this.WideScreenLayout()
              } else {
                // 小屏幕布局
                this.SongListSection()
              }
            } else {
              // 显示空状态
              List({ scroller: this.scroller }) {
                HeaderPlaceholder()
                ListItem() {
                  // 下拉提示动画
                  HeaderAnimation({ scrollController: this.scrollController })
                }

                ListItem() {
                  Column() {
                    Text($r('app.string.no_songs_available'))
                      .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
                      .fontColor($r('app.color.text_hint'))
                      .fontSize(16)
                  }
                  .width(StyleConstants.FULL_WIDTH)
                  .height(StyleConstants.FULL_HEIGHT)
                  .justifyContent(FlexAlign.Center)
                }

                ListItem() {
                  Column() {
                    // 底部避让空间，高度为播控高度(64) + 播控底部padding高度(16)
                    Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + 16)
                  }
                }
              }
              .onWillScroll(this.scrollController.scrollHandlers.onWillScroll)
              .onScrollStop(this.scrollController.scrollHandlers.onScrollStop)
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.FULL_HEIGHT)
            }
          }
          .layoutWeight(1)
          .width(StyleConstants.FULL_WIDTH)
        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)

        // 底部迷你播放控制器 - 直接放在Stack底部
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
            this.ListHeader()
          }
        })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .hideToolBar(true)
    .hideTitleBar(true)
    .systemTransition(NavigationSystemTransitionType.EXPLODE)
    .backgroundColor($r('app.color.page_background'))
    .mode(NavDestinationMode.STANDARD)
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
  }

  @Builder
  ListHeader() {
    Column() {
      if (this.isWideScreen) {
        // 宽屏布局：一行显示所有元素
        Row({ space: 8 }) {
          // 播放全部按钮
          Row() {
            Image($r('app.media.ic_repeat'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.text_primary'))
          }
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .stateStyles({
            pressed: this.pressedStyles,
            normal: this.normalStyles
          })
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          .height(36)
          .width(36)
          .borderRadius(18)
          .backgroundColor($r('app.color.setting_item_background'))
          .backgroundBlurStyle(BlurStyle.Regular)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            if (this.songs && this.songs.length > 0) {
              const song = this.songs.find(song => song.privilege.playable)
              this.handlePlaylistPlayAll(song || this.songs[0])
              PlaylistManager.switchPlayMode(PlayMode.LOOP)
            }
          })

          // 搜索框
          Search({ value: this.searchKeywords, placeholder: $r('app.string.search_songs') })
            .searchButton(ResourceManager.getStringValueSync($r('app.string.search')))
            .onSubmit((value: string) => {
              this.searchKeywords = value
              this.filterSongs()
            })
            .onChange((value: string) => {
              this.searchKeywords = value
            })
            .margin(0)
            .backgroundBlurStyle(BlurStyle.Regular)
            .shadow(ShadowStyle.OUTER_DEFAULT_SM)
            .layoutWeight(1)

          // 更多选项按钮
          Row() {
            Image($r('app.media.ic_more'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.text_primary'))
          }
          .width(36)
          .height(36)
          .borderRadius(18)
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          .backgroundColor($r('app.color.setting_item_background'))
          .backgroundBlurStyle(BlurStyle.Regular)
          .justifyContent(FlexAlign.Center)
          .bindMenu(this.generatePlaylistMenu())
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .stateStyles({
            pressed: this.pressedStyles,
            normal: this.normalStyles
          })
        }
        .width('67%')
        .padding({
          top: 8,
          bottom: 4,
          left: 12,
          right: 12
        })
      } else {
        // 小屏幕布局：搜索框和按钮一行显示
        Row({ space: 8 }) {
          // 播放全部按钮
          Row() {
            Image($r('app.media.ic_repeat'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.text_primary'))
          }
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .stateStyles({
            pressed: this.pressedStyles,
            normal: this.normalStyles
          })
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          .height(36)
          .width(36)
          .borderRadius(18)
          .backgroundColor($r('app.color.setting_item_background'))
          .backgroundBlurStyle(BlurStyle.Regular)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            if (this.songs && this.songs.length > 0) {
              const song = this.songs.find(song => song.privilege.playable)
              this.handlePlaylistPlayAll(song || this.songs[0])
              PlaylistManager.switchPlayMode(PlayMode.LOOP)
            }
          })

          // 搜索框
          Search({ value: this.searchKeywords, placeholder: $r('app.string.search_songs') })
            .searchButton(ResourceManager.getStringValueSync($r('app.string.search')))
            .onSubmit((value: string) => {
              this.searchKeywords = value
              this.filterSongs()
            })
            .onChange((value: string) => {
              this.searchKeywords = value
            })
            .margin(0)
            .backgroundBlurStyle(BlurStyle.Regular)
            .shadow(ShadowStyle.OUTER_DEFAULT_SM)
            .layoutWeight(1)

          // 更多选项按钮
          Row() {
            Image($r('app.media.ic_more'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.text_primary'))

          }
          .width(36)
          .height(36)
          .borderRadius(18)
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          .backgroundColor($r('app.color.setting_item_background'))
          .backgroundBlurStyle(BlurStyle.Regular)
          .justifyContent(FlexAlign.Center)
          .bindMenu(this.generatePlaylistMenu())
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .stateStyles({
            pressed: this.pressedStyles,
            normal: this.normalStyles
          })
        }
        .padding({
          top: 8,
          bottom: 4,
          left: 12,
          right: 12
        })
      }
    }
    .onAreaChange((_: Area, newValue: Area) => {
      this.placeholderOffset = newValue.height as number
    })
  }

  private generatePlaylistMenu(): Array<MenuElement> {
    return [
      {
        value: $r('app.string.download_all_songs'),
        action: () => {
          if (this.songs && this.songs.length > 0) {
            ToastUtil.showToast("开始下载全部歌曲", { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/4 } })
            const songs = this.songs.filter(song => song.privilege.playable)
            SongDownloadManager.batchDownloadSongs(songs)
          }
        }
      },
      {
        value: $r('app.string.add_to_playlist'),
        action: () => {
          DialogHelper.showSelectDialog({
            title: $r('app.string.add_to_playlist'),
            confirm: $r('app.string.back'),
            selectedIndex: -1,
            radioContent: this.aggregationPlaylist.map(playlist => playlist.name),
            onCheckedChanged: (index) => {
              this.selectedIndex = index
              if (this.songs && this.songs.length > 0) {
                PreferencesCache.addSongsToAggregationPlaylist(this.aggregationPlaylist[this.selectedIndex], this.songs as Song[])
              }
            },
            onAction: (): void => {}
          })
        }
      }
    ]
  }

  countSubVp(): number {
    let sub: number = this.winHeight - 50 - this.groupHeight - (this.bottomRect+this.topRect)  - this.placeholderOffset - 10
    // if(this.songDataSource.totalCount() <= 15){
    //   // 填补高度=屏幕高度 - title高度50 - (播放组件高度40+上下padding高度2*4) - 状态栏高度 - 导航栏高度
    //   sub = px2vp(this.winHeight) - (50+40+12*2+(68+2*4)*this.songDataSource.totalCount()) - px2vp(this.topRect) - px2vp(this.bottomRect)
    // }
    return sub > 0 ? sub : 0
  }

  private filterSongs() {
    if (!this.songs) {
      return
    }

    if (!this.searchKeywords.trim()) {
      this.filteredSongs = this.songs
      this.isSearching = false
      return
    }

    const keywords = this.searchKeywords.toLowerCase().trim()
    this.filteredSongs = this.songs.filter(song =>
    song.name?.toLowerCase().includes(keywords) ||
    song.artists?.some(artist => artist?.name?.toLowerCase().includes(keywords)) ||
    song.album?.name?.toLowerCase().includes(keywords)
    )
    this.isSearching = true
  }

  @Styles pressedStyles(): void {
    .borderWidth(1)
    .borderColor($r('app.color.text_click'))
  }

  @Styles normalStyles(): void {
    .borderWidth(0)
  }
}