import { StyleConstants } from "../constants/StyleConstants"
import { AnimationConstants } from "../constants/AnimationConstants"
import { SourceConfig, ID } from "../type/Adapter"
import { PreferencesCache } from "../util/PreferenceCache"

/**
 * 数据源筛选选项
 */
export interface SourceFilterOption {
  id: ID;
  name: string;
  isAll: boolean;
}

/**
 * 数据源筛选器组件
 * 用于筛选搜索结果的数据源
 */
@Component
export struct SourceFilter {
  @Link selectedSourceIds: Set<ID>
  @State sources: SourceFilterOption[] = []

  aboutToAppear(): void {
    this.loadSources()
  }

  private loadSources(): void {
    const userSources = PreferencesCache.getUserDataSource()
    const options: SourceFilterOption[] = []

    // 添加"全部"选项
    options.push({
      id: 'all',
      name: '全部',
      isAll: true
    })

    // 添加各个数据源选项
    for (let i = 0; i < userSources.length; i++) {
      const source = userSources[i]
      options.push({
        id: source.id,
        name: source.name || this.getSourceDisplayName(source),
        isAll: false
      })
    }

    this.sources = options
  }

  /**
   * 获取数据源显示名称
   */
  private getSourceDisplayName(source: SourceConfig): string {
    // 根据 URL 推断数据源名称
    const url = source.url.toLowerCase()
    if (url.includes('netease') || url.includes('163')) {
      return '网易云音乐'
    } else if (url.includes('qq') || url.includes('tencent')) {
      return 'QQ音乐'
    } else if (url.includes('kugou')) {
      return '酷狗音乐'
    } else if (url.includes('kuwo')) {
      return '酷我音乐'
    } else if (url.includes('migu')) {
      return '咪咕音乐'
    } else if (url.includes('bilibili')) {
      return '哔哩哔哩'
    }
    return source.name || '未知数据源'
  }

  private isSelected(option: SourceFilterOption): boolean {
    if (option.isAll) {
      // "全部"选项：当没有选中任何特定数据源时，视为选中"全部"
      return this.selectedSourceIds.size === 0
    }
    return this.selectedSourceIds.has(option.id)
  }

  private toggleSelection(option: SourceFilterOption): void {
    if (option.isAll) {
      // 点击"全部"：清空所有选择
      this.selectedSourceIds.clear()
      // 触发更新
      const newSet = new Set<ID>()
      this.selectedSourceIds = newSet
    } else {
      // 点击特定数据源
      const newSet = new Set<ID>(this.selectedSourceIds)
      if (newSet.has(option.id)) {
        newSet.delete(option.id)
      } else {
        newSet.add(option.id)
      }
      this.selectedSourceIds = newSet
    }
  }

  build() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.sources, (option: SourceFilterOption) => {
          Text(option.name)
            .fontSize(13)
            .fontColor(this.isSelected(option) ?
              Color.White :
              $r('app.color.text_secondary'))
            .fontWeight(this.isSelected(option) ?
              FontWeight.Medium :
              FontWeight.Regular)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .borderRadius(14)
            .backgroundColor(this.isSelected(option) ?
              $r('app.color.accent_primary') :
              $r('app.color.interactive_normal'))
            .onClick(() => {
              this.toggleSelection(option)
            })
            .clickEffect({
              level: ClickEffectLevel.LIGHT,
              scale: 0.95
            })
            .animation({
              duration: AnimationConstants.DURATION_FAST,
              curve: AnimationConstants.CURVE_DECELERATE
            })
        })
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width(StyleConstants.FULL_WIDTH)
    .height(40)
  }
}

/**
 * 数据源标签组件
 * 用于在搜索结果项中显示数据源标识
 */
@Component
export struct SourceBadge {
  @Prop source: SourceConfig | undefined

  /**
   * 获取数据源显示名称（简短版本）
   */
  private getShortName(): string {
    if (!this.source) {
      return ''
    }

    // 优先使用配置的名称
    if (this.source.name) {
      // 截取前4个字符
      return this.source.name.length > 4 ? this.source.name.substring(0, 4) : this.source.name
    }

    // 根据 URL 推断
    const url = this.source.url.toLowerCase()
    if (url.includes('netease') || url.includes('163')) {
      return '网易'
    } else if (url.includes('qq') || url.includes('tencent')) {
      return 'QQ'
    } else if (url.includes('kugou')) {
      return '酷狗'
    } else if (url.includes('kuwo')) {
      return '酷我'
    } else if (url.includes('migu')) {
      return '咪咕'
    } else if (url.includes('bilibili')) {
      return 'B站'
    }
    return '未知'
  }

  /**
   * 获取数据源对应的颜色
   */
  private getBadgeColor(): ResourceColor {
    if (!this.source) {
      return $r('app.color.text_hint')
    }

    const url = this.source.url.toLowerCase()
    if (url.includes('netease') || url.includes('163')) {
      return '#E60026' // 网易云红色
    } else if (url.includes('qq') || url.includes('tencent')) {
      return '#31C27C' // QQ音乐绿色
    } else if (url.includes('kugou')) {
      return '#1E90FF' // 酷狗蓝色
    } else if (url.includes('kuwo')) {
      return '#FF6600' // 酷我橙色
    } else if (url.includes('migu')) {
      return '#FF1493' // 咪咕粉色
    } else if (url.includes('bilibili')) {
      return '#FB7299' // B站粉色
    }
    return $r('app.color.accent_primary')
  }

  build() {
    if (this.source) {
      Text(this.getShortName())
        .fontSize(10)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(4)
        .backgroundColor(this.getBadgeColor())
        .margin({ left: 6 })
    }
  }
}

