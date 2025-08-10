// 导入ArkUI框架中的相关模块，用于构建UI界面和处理用户交互。
import { DialogHelper } from "@pura/harmony-dialog" // 对话框辅助工具
import { ToastUtil } from "@pura/harmony-utils" // 轻提示（Toast）工具
// 导入项目内部定义的模块。
import { SourceAdapter } from "../adapter" // 数据源适配器，用于获取音乐数据。
import { Album, Artist, Playlist, Song } from "../type/Adapter" // 定义了音乐实体类型，如专辑、艺术家、歌单和歌曲。
import { cover } from "../util/AdapterHelper" // 封面图片处理辅助工具。
import { PlaylistManager } from "../util/PlaylistManager" // 播放列表管理器。
import { PreferencesCache } from "../util/PreferenceCache" // 应用偏好设置缓存。
import { PushPathHelper } from "../util/PushPathHelper" // 页面导航路径辅助工具。
import { Cover } from "./Cover" // 封面组件。

// 定义常量
const DEFAULT_COVER_SIZE = 256 // 默认封面尺寸
const MIN_SCALE = 0.85 // 最小缩放比例，用于远处的项目

/**
 * 横向滚动组件
 *
 * 该组件实现了一个横向列表，具有独特的3D视觉效果，
 * 包括缩放、模糊、透明度和层叠偏移。
 * 它被设计为可重用的，可以显示不同类型的内容，如歌曲、专辑、歌单等。
 */
@Component
export struct HorizontalScroll {
  // 从父组件消费的导航路径栈，用于页面跳转。
  @Consume('NavPathStack') pageStack: NavPathStack
  // 需要在列表中显示的数据数组。
  @Prop lists: Object[]
  // 当前选中的项目索引。
  @State selectedIndex: number = 0
  // 列表内容的类型（如 'Song', 'Playlist'），用于决定渲染哪个视图。
  type: string = ''
  // 封面的宽度，单位vp。
  private coverWidth: number = 120
  // 项目之间的间距，单位vp。
  private segmentPadding: number = 8
  // 封面的圆角半径。
  private radius: string | number = 15
  // 应用全局状态，用于双指捏合放大后的标题。
  @StorageLink('2in1title') title:string='首页'
  // 应用全局状态，用于判断当前页面是否为首页。
  @StorageLink('2in1page_judge') page_judge:string = 'index'
  // 应用全局状态，聚合的播放列表缓存。
  @StorageLink('aggregation_playlist') aggregationPlaylist: Playlist[] = PreferencesCache.getPlaylistCache('aggregation_playlist')

  // ArkUI的Scroller控制器，用于控制列表的滚动。
  private scroller: Scroller = new Scroller()
  // 真正用于UI渲染的列表。
  @State private displayLists: (Album | Artist | Playlist | Song | number)[] = []
  // 存储每个列表项的缩放值。
  @State private scaleList: number[] = []
  // 存储每个列表项的透明度值。
  @State private opacityList: number[] = []
  // 存储每个列表项的模糊效果值。
  @State private blurList: number[] = []
  // 存储每个列表项的Z轴层级，用于控制堆叠顺序。
  @State private zIndexList: number[] = []
  // 存储每个列表项的横向偏移量，用于创建堆叠效果。
  @State private offsetList: number[] = []
  // 列表容器的宽度。
  private listWidth: number = 0
  // 标记是否正在进行滚动停止后的对齐动画。
  @State private isSnapping: boolean = false;

  /**
   * 组件即将出现时的生命周期回调。
   * 初始化`displayLists`，并更新初始视觉效果。
   */
  aboutToAppear() {
    if (this.lists && this.lists.length > 0) {
      // 列表数据直接从props传入，不再进行填充。
      this.displayLists = [...this.lists] as (Album | Artist | Playlist | Song | number)[]
    } else if (this.type === 'Template') {
      // 如果是模板类型（用于加载时的占位显示），则创建一个包含10个占位符的数组。
      this.displayLists = new Array(10).fill(0)
    } else {
      this.displayLists = []
    }
    // 初始化所有项目的视觉效果。
    this.updateScale(0)
  }

  /**
   * 根据当前的滚动偏移量，计算并更新每个列表项的视觉效果（缩放、透明度等）。
   * @param scrollOffset - 当前Scroller的横向滚动偏移量。
   */
  updateScale(scrollOffset: number) {
    const itemCount = this.displayLists.length;
    if (itemCount === 0) return;

    // 创建临时数组来存储新的视觉状态值。
    const newScaleList: number[] = [];
    const newOpacityList: number[] = [];
    const newBlurList: number[] = [];
    const newZIndexList: number[] = [];
    const newOffsetList: number[] = [];
    // 单个项目（封面+间距）的总宽度。
    const itemWidthWithPadding = this.coverWidth + this.segmentPadding;

    // 定义“焦点线”为列表容器的左边缘。这是计算所有效果的基准。
    const focusLineX = scrollOffset;

    // 定义不同视觉效果区域的边界。
    // 焦点区域：从焦点线开始，延伸半个项目宽度。此区域内的项目是“焦点项目”。
    const focusZoneEnd = itemWidthWithPadding * 0.5;
    // 常规区域：从焦点区域结束处开始，延伸一个项目宽度。此区域是“下一个”项目。
    const normalZoneEnd = itemWidthWithPadding * 1.5;

    for (let i = 0; i < itemCount; i++) {
      // Z-index始终基于自然顺序，以确保左侧的项目（逻辑上先渲染）显示在右侧项目之上。
      newZIndexList.push(itemCount - i);

      // 计算当前项目的左边缘相对于整个可滚动区域起点的位置。
      const itemLeftEdge = i * itemWidthWithPadding;
      // 计算当前项目的左边缘与焦点线之间的距离。
      const distanceToFocus = itemLeftEdge - focusLineX;

      if (distanceToFocus < focusZoneEnd) {
        // 区域1：焦点项目。这是离左边缘最近的项目。
        // 效果：最大化（1.1倍），完全不透明，无模糊。
        // 缩放比例从焦点线的1.1平滑过渡到焦点区域边缘的1.0。
        const proximity = Math.abs(distanceToFocus) / focusZoneEnd;
        const scale = 1.1 - (0.1 * Math.min(1.0, proximity));
        newScaleList.push(scale);
        newOpacityList.push(1.0);
        newBlurList.push(0);
        newOffsetList.push(0); // 焦点项目没有额外的偏移。
      } else if (distanceToFocus < normalZoneEnd) {
        // 区域2：常规项目。紧邻焦点项目的下一个项目。
        // 效果：正常大小（1.0倍），完全不透明，无模糊。
        newScaleList.push(1.0);
        newOpacityList.push(1.0);
        newBlurList.push(0);
        newOffsetList.push(0); // 常规项目也没有额外的偏移。
      } else {
        // 区域3：堆叠区域。所有更远的项目。
        // 效果：逐渐缩小、变模糊、变透明，并向左偏移，形成堆叠感。

        // 计算项目进入堆叠区域的距离。
        const distanceIntoStack = distanceToFocus - normalZoneEnd;
        // 定义一个“渐变距离”，在这个距离内完成所有视觉效果的变化。
        const fadeDistance = this.coverWidth * 2.5;
        // 将进入堆叠区的距离归一化到 [0, 1] 区间。
        const normalizedDistance = Math.min(1.0, Math.max(0, distanceIntoStack / fadeDistance));
        // 使用三次缓出曲线（easeOutCubic）使效果变化更自然。
        const curvedDistance = 1 - Math.pow(1 - normalizedDistance, 3);

        // 根据曲线距离计算缩放值，从1.0过渡到MIN_SCALE。
        const scale = 1.0 - curvedDistance * (1.0 - MIN_SCALE);
        newScaleList.push(scale);

        // 定义最小透明度和最大模糊值。
        const MIN_OPACITY = 0.1;
        const MAX_BLUR = 8;
        // 根据曲线距离计算透明度和模糊值。
        newOpacityList.push(1.0 - curvedDistance * (1.0 - MIN_OPACITY));
        newBlurList.push(curvedDistance * MAX_BLUR);

        // 根据进入堆叠区的距离计算向左的偏移量，以产生堆叠效果。
        const stackOffsetFactor = 0.65; // 偏移因子，控制堆叠的紧密程度。
        newOffsetList.push(-distanceIntoStack * stackOffsetFactor);
      }
    }

    // 将计算出的新视觉状态批量更新到组件的@State变量，触发UI刷新。
    this.scaleList = newScaleList;
    this.opacityList = newOpacityList;
    this.blurList = newBlurList;
    this.zIndexList = newZIndexList;
    this.offsetList = newOffsetList;
  }

  /**
   * 处理滚动停止事件。
   * 此函数将列表平滑地滚动（对齐）到离当前停止位置最近的那个项目的中心。
   * 注意：此版本已移除了无限循环逻辑，列表现在有明确的起点和终点。
   */
  private handleScrollStop() {
    // 如果一个对齐动画正在进行中，则忽略此次事件，防止冲突。
    if (this.isSnapping) {
      return;
    }

    const itemWidthWithPadding = this.coverWidth + this.segmentPadding;
    if (itemWidthWithPadding <= 0) {
      return;
    }

    const currentOffset = this.scroller.currentOffset().xOffset;

    // 计算出最接近的目标项目的索引。
    const targetIndex = Math.round(currentOffset / itemWidthWithPadding);
    // 计算该目标项目的精确中心偏移量。
    const snapToOffset = targetIndex * itemWidthWithPadding;

    // 如果当前位置与目标对齐位置有偏差，则执行一个平滑的对齐动画。
    if (Math.abs(snapToOffset - currentOffset) > 0.5) {
      this.isSnapping = true;
      this.scroller.scrollTo({
        xOffset: snapToOffset,
        yOffset: 0,
        animation: {
          duration: 300,
          curve: Curve.EaseOut
        }
      });

      // 动画结束后，重置标志位，并再次更新视觉效果以确保最终状态精确。
      setTimeout(() => {
        this.updateScale(this.scroller.currentOffset().xOffset);
        this.isSnapping = false;
      }, 300);
    }
  }


  build() {
    Column() {
      // 根据传入的`type`属性，选择性地构建不同类型的封面列表。
      // 这种模式使得组件高度可复用。
      if (this.type === 'Song') {
        this.SongCover()
      } else if (this.type === 'Playlist') {
        this.PlaylistCover()
      } else if (this.type === 'Artist') {
        this.ArtistCover()
      } else if (this.type === 'TopPlaylist') {
        this.TopPlaylistCover()
      } else if (this.type === 'Template') {
        this.TemplateCover()
      } else if (this.type === 'Album') {
        this.AlbumCover()
      }
    }
    .width('100%')
    // 提供一个固定的高度以防止项目缩放时引起布局抖动。
    // 高度计算考虑了最大缩放（1.1倍）、垂直边距和文字高度。
    .height(this.coverWidth * 1.1 + 60)
  }

  /**
   * 构建专辑封面的列表。
   * 每个@Builder函数都遵循相似的结构，但处理的数据类型和点击事件不同。
   */
  @Builder
  AlbumCover(){
    List({ scroller: this.scroller, space: this.segmentPadding }) {
      ForEach(this.displayLists, (item: Album, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.cover, 256),
            title: item.name,
            subTitle: item.artists?.map(artist => artist.name).join(' / '),
            radius: this.radius,
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 }) // 属性变化时的动画
            .onClick(() => {
              // 点击后，导航到播放列表详情页。
              PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                const album = await SourceAdapter.getAlbumDetail(item)
                AppStorage.setOrCreate('current_playlist_data', album)
              })
            })
        }
        // 将计算出的视觉效果应用到ListItem上。
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .opacity(this.opacityList[index] ?? 1.0)
        .blur(this.blurList[index] ?? 0)
        .zIndex(this.zIndexList[index] ?? 0)
        .offset({ x: this.offsetList[index] ?? 0, y: 0 })
        .key(`${item.id}-${item.name}-${index}`) // 提供唯一的key以优化渲染性能
      })
    }
    .margin({ top: 10 })
    .clip(false) // 允许子组件超出父组件边界，这对于偏移和缩放效果至关重要。
    .width('100%')
    .listDirection(Axis.Horizontal) // 设置为水平列表
    .scrollBar(BarState.Off) // 关闭滚动条
    .edgeEffect(EdgeEffect.None) // 关闭滚动到边缘时的效果
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      // 列表区域尺寸变化时，根据当前滚动位置更新所有项目的视觉效果。
      this.updateScale(this.scroller.currentOffset().xOffset)
    })
    // 滚动过程中持续调用updateScale来更新视觉效果。
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    // 滚动停止时调用handleScrollStop来处理对齐和循环逻辑。
    .onScrollStop(() => this.handleScrollStop())
  }

  /**
   * 构建加载占位符的列表。
   */
  @Builder
  TemplateCover(){
    List({ scroller: this.scroller, space: this.segmentPadding }) {
      ForEach(this.displayLists, (item: number, index: number) => {
        ListItem() {
          Cover({
            loading: true,
            src: $r('app.media.ic_placeholder'),
            title: '',
            radius: this.radius
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 })
        }
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .opacity(this.opacityList[index] ?? 1.0)
        .blur(this.blurList[index] ?? 0)
        .zIndex(this.zIndexList[index] ?? 0)
        .offset({ x: this.offsetList[index] ?? 0, y: 0 })
        .key(`template-${index}`)
      })
    }
    .margin({ top: 10 })
    .clip(false)
    .width('100%')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      // 列表区域尺寸变化时，根据当前滚动位置更新所有项目的视觉效果。
      this.updateScale(this.scroller.currentOffset().xOffset)
    })
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    .onScrollStop(() => this.handleScrollStop())
  }

  /**
   * 构建排行榜歌单封面的列表。
   */
  @Builder
  TopPlaylistCover(){
    List({ scroller: this.scroller, space: this.segmentPadding }) {
      ForEach(this.displayLists, (item: Playlist, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.cover, DEFAULT_COVER_SIZE),
            title: item.name,
            subTitle: item.description,
            menuItems: this.generatePlaylistMenu(item),
            radius: this.radius
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 })
            .onClick(async () => {
              PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                const playlist = await SourceAdapter.getPlaylistDetail(item)
                AppStorage.setOrCreate('current_playlist_data', playlist)
              })
            })
        }
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .opacity(this.opacityList[index] ?? 1.0)
        .blur(this.blurList[index] ?? 0)
        .zIndex(this.zIndexList[index] ?? 0)
        .offset({ x: this.offsetList[index] ?? 0, y: 0 })
        .key(`${item.id}-${item.name}-${index}`)
      })
    }
    .margin({ top: 10 })
    .clip(false)
    .width('100%')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      // 列表区域尺寸变化时，根据当前滚动位置更新所有项目的视觉效果。
      this.updateScale(this.scroller.currentOffset().xOffset)
    })
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    .onScrollStop(() => this.handleScrollStop())
  }

  /**
   * 构建艺术家封面的列表。
   */
  @Builder
  ArtistCover() {
    List({ scroller: this.scroller, space: this.segmentPadding }) {
      ForEach(this.displayLists, (item: Artist, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.avatar, DEFAULT_COVER_SIZE),
            title: item.name,
            radius: "100%", // 艺术家封面通常是圆形的
            titleAlign: HorizontalAlign.Center
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 })
            .onClick(() => {
              PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                const playlist = await SourceAdapter.getArtistDetail(item)
                AppStorage.setOrCreate('current_playlist_data', playlist)
              })
            })
        }
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .opacity(this.opacityList[index] ?? 1.0)
        .blur(this.blurList[index] ?? 0)
        .zIndex(this.zIndexList[index] ?? 0)
        .offset({ x: this.offsetList[index] ?? 0, y: 0 })
        .key(`${item.id}-${item.name}-${index}`)
      })
    }
    .margin({ top: 10 })
    .clip(false)
    .width('100%')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      // 列表区域尺寸变化时，根据当前滚动位置更新所有项目的视觉效果。
      this.updateScale(this.scroller.currentOffset().xOffset)
    })
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    .onScrollStop(() => this.handleScrollStop())
  }

  /**
   * 构建歌单封面的列表。
   */
  @Builder
  PlaylistCover() {
    List({ scroller: this.scroller, space: this.segmentPadding }) {
      ForEach(this.displayLists, (item: Playlist, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.cover, DEFAULT_COVER_SIZE),
            title: item.name,
            menuItems: this.generatePlaylistMenu(item),
            radius: this.radius
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 })
            .onClick(async () => {
                PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
                  const playlist = await SourceAdapter.getPlaylistDetail(item)
                  AppStorage.setOrCreate('current_playlist_data', playlist)
                })
            })
        }
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .opacity(this.opacityList[index] ?? 1.0)
        .blur(this.blurList[index] ?? 0)
        .zIndex(this.zIndexList[index] ?? 0)
        .offset({ x: this.offsetList[index] ?? 0, y: 0 })
        .key(`${item.id}-${item.name}-${index}`)
      })
    }
    .margin({ top: 10 })
    .clip(false)
    .width('100%')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      // 列表区域尺寸变化时，根据当前滚动位置更新所有项目的视觉效果。
      this.updateScale(this.scroller.currentOffset().xOffset)
    })
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    .onScrollStop(() => this.handleScrollStop())
  }

  /**
   * 构建歌曲封面的列表。
   */
  @Builder
  SongCover(){
    List({ scroller: this.scroller, space: this.segmentPadding }) {
      ForEach(this.displayLists, (item: Song, index: number) => {
        ListItem() {
          Cover({
            src: cover(item.album.cover, DEFAULT_COVER_SIZE),
            title: item.name,
            subTitle: item.artists.map(artist => artist.name).join(' / '),
            menuItems: this.generateSongMenu(item),
            radius: this.radius
          })
            .width('100%')
            .animation({ curve: Curve.EaseOut, duration: 50 })
            .onClick(() => {
              // 点击歌曲时，将其插入到播放队列并开始播放。
              PushPathHelper.loading("Playing", async () => {
                PlaylistManager.insertSongs([item], -1, item)
              })
            })
        }
        .width(this.coverWidth * (this.scaleList[index] ?? 1.0))
        .opacity(this.opacityList[index] ?? 1.0)
        .blur(this.blurList[index] ?? 0)
        .zIndex(this.zIndexList[index] ?? 0)
        .offset({ x: this.offsetList[index] ?? 0, y: 0 })
        .key(`${item.id}-${item.name}-${index}`)
      })
    }
    .margin({ top: 10 })
    .clip(false)
    .width('100%')
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .padding({ left: 20, right: 20 })
    .onAreaChange((oldValue, newValue) => {
      this.listWidth = Number(newValue.width)
      // 列表区域尺寸变化时，根据当前滚动位置更新所有项目的视觉效果。
      this.updateScale(this.scroller.currentOffset().xOffset)
    })
    .onScroll(() => this.updateScale(this.scroller.currentOffset().xOffset))
    .onScrollStop(() => this.handleScrollStop())
  }

  /**
   * 为单曲生成上下文菜单项。
   * @param song - 目标歌曲
   * @returns 菜单项数组
   */
  private generateSongMenu(song: Song): Array<MenuElement> {
    return [
      {
        value: $r('app.string.add_to_play_next'), // "下一首播放"
        action: () => {
          PlaylistManager.insertSongs([song])
        }
      },
      {
        value: $r('app.string.add_to_playlist'), // "添加到歌单"
        action: () => {
          // 显示一个对话框，让用户选择要将歌曲添加到哪个歌单。
          DialogHelper.showSelectDialog({
            title: $r('app.string.add_to_playlist'),
            confirm: $r('app.string.back'),
            selectedIndex: -1,
            radioContent: this.aggregationPlaylist.map(playlist => playlist.name),
            onCheckedChanged: (index) => {
              this.selectedIndex = index
              if(PreferencesCache.addSongToAggregationPlaylist(this.aggregationPlaylist[this.selectedIndex], song)){
                ToastUtil.showShort(`[${song.name}]存在于[${this.aggregationPlaylist[index].name}]`)
              }else{
                ToastUtil.showShort(`[${song.name}]添加到[${this.aggregationPlaylist[index].name}]`)
              }
            },
            onAction: (): void => {}
          })
        }
      }
    ]
  }

  /**
   * 为歌单生成上下文菜单项。
   * @param playlist - 目标歌单
   * @returns 菜单项数组
   */
  private generatePlaylistMenu(playlist: Playlist): Array<MenuElement> {
    return [
      {
        value: $r('app.string.play_this_playlist'), // "播放此歌单"
        action: () => {
          PushPathHelper.loading("Playing", async () => {
            const playlistDetail = await SourceAdapter.getPlaylistDetail(playlist)
            const songs = playlistDetail?.songs?.filter(song => song.privilege.playable)
            if (!songs || songs.length === 0) {
              ToastUtil.showShort($r('app.string.no_playable_songs'))
              return
            }
            PlaylistManager.loadPlaylist(songs, songs[0])
          })
        }
      }
    ]
  }
}
