import { StyleConstants } from "../constants/StyleConstants"
import { AnimationConstants } from "../constants/AnimationConstants"

export enum SearchFilterType {
  ALL = 'all',
  SONGS = 'songs',
  PLAYLISTS = 'playlists',
  ARTISTS = 'artists',
  ALBUMS = 'albums'
}

/**
 * 搜索筛选器组件
 * 用于筛选搜索结果类型
 */
interface Filter {
  type: SearchFilterType;
  label: ResourceStr;
}

@Component
export struct SearchFilter {
  @Link selectedFilter: SearchFilterType
  
  private filters: Array<Filter> = [
    { type: SearchFilterType.ALL, label: $r('app.string.filter_all') },
    { type: SearchFilterType.SONGS, label: $r('app.string.filter_songs') },
    { type: SearchFilterType.PLAYLISTS, label: $r('app.string.filter_playlists') },
    { type: SearchFilterType.ARTISTS, label: $r('app.string.filter_artists') },
    { type: SearchFilterType.ALBUMS, label: $r('app.string.filter_albums') }
  ]

  build() {
    Row({ space: 8 }) {
      ForEach(this.filters, (filter: Filter) => {
        Text(filter.label)
          .fontSize(14)
          .fontColor(this.selectedFilter === filter.type ? 
            Color.White : 
            $r('app.color.text_secondary'))
          .fontWeight(this.selectedFilter === filter.type ? 
            FontWeight.Medium : 
            FontWeight.Regular)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(16)
          .backgroundColor(this.selectedFilter === filter.type ? 
            $r('app.color.accent_primary') : 
            $r('app.color.interactive_normal'))
          .onClick(() => {
            this.selectedFilter = filter.type
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
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }
}

