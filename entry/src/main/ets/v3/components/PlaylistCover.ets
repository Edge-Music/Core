/**
 * OMSP 3.0 · 歌单封面（统一封装）
 * - 有可解析封面：正常 Image（支持 cover://N 取第 N 首歌封面）。
 * - 无封面（key_ 特殊歌单 / cover://N 无 songs 上下文）：渲染颜色块卡片占位，
 *   颜色由歌单 id/name 哈希决定，保证同一歌单稳定同色。
 */
import { Playlist } from '../../type/Adapter'
import { playlistCover, hasResolvableCover } from '../../util/AdapterHelper'
import { V3Theme } from '../theme/Tokens'

// 卡片风格渐变配色（浅深两色兼容）
const GRADIENTS: string[][] = [
  ['#7C6FF0', '#5B8DEF'],
  ['#F0946F', '#F06F9C'],
  ['#6FD0C0', '#5BAEEF'],
  ['#F0C36F', '#F0906F'],
  ['#9C6FF0', '#EF5B9C'],
  ['#6F9CF0', '#6FE0C0'],
  ['#F06F6F', '#F0A66F'],
  ['#6FC0F0', '#8C6FF0']
]

@Component
export struct PlaylistCover {
  pl: Playlist | null = null
  coverSize: number = 200 // 传给 playlistCover 的分辨率
  sizeW: Length = '100%'
  aspect: number = 1
  radius: number = 16
  @StorageProp('v3_theme_mode') mode: string = 'dark'

  private hashKey(): number {
    const key: string = `${this.pl?.id ?? ''}${this.pl?.name ?? ''}`
    let h: number = 0
    for (let i = 0; i < key.length; i++) {
      h = (h * 31 + key.charCodeAt(i)) % 100000
    }
    return h
  }

  private gradient(): string[] {
    return GRADIENTS[this.hashKey() % GRADIENTS.length]
  }

  private initial(): string {
    const n: string = this.pl?.name ?? ''
    return n.length > 0 ? n.substring(0, 1) : '♪'
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.pl && hasResolvableCover(this.pl)) {
        Image(playlistCover(this.pl, this.coverSize))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        // 颜色块占位：渐变 + 首字 + 半透明音符
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .fontSize(this.aspect >= 1 ? 34 : 20)
            .fontColor(['rgba(255,255,255,0.28)'])
          Text(this.initial())
            .fontSize(this.aspect >= 1 ? 26 : 18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .maxLines(1)
        }
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [[this.gradient()[0], 0.0], [this.gradient()[1], 1.0]]
        })
      }
    }
    .width(this.sizeW)
    .aspectRatio(this.aspect)
    .borderRadius(this.radius)
    .clip(true)
    .backgroundColor(V3Theme.track(this.mode))
  }
}
