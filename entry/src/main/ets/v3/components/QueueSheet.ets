/**
 * OMSP 3.0 · 播放队列 Sheet（玻璃风重做，替代旧 PlaylistView）
 * UI 全新 3.0 玻璃行，但完整复用底层：SongsDataSource / PlaylistManager /
 * Scroller.scrollToIndex 定位当前 / current_playing_* 状态。
 */
import { Song } from '../../type/Adapter'
import { PlaylistManager } from '../../util/PlaylistManager'
import { SongsDataSource } from '../../util/SongsDataSource'
import { cover } from '../../util/AdapterHelper'
import { ToastUtil } from '@pura/harmony-utils'
import { V3Theme } from '../theme/Tokens'

@Component
export struct QueueSheet {
  @StorageLink('current_playing_song') currentSong: Song | null = null
  @StorageLink('current_playing_playlist') playlist: Song[] = []
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @State private ds: SongsDataSource = new SongsDataSource()
  private scroller: Scroller = new Scroller()
  private curIndex: number = -1

  aboutToAppear(): void {
    this.ds.pushMultiData(this.playlist)
    this.curIndex = this.playlist.findIndex((s) => s.id === this.currentSong?.id)
  }

  private locate(): void {
    const i: number = this.playlist.findIndex((s) => s.id === this.currentSong?.id)
    if (i >= 0) {
      this.scroller.scrollToIndex(i, true, ScrollAlign.CENTER)
    }
  }

  private artist(song: Song): string {
    return song.artists?.map((a) => a.name).join(' / ') ?? ''
  }

  @Builder
  Header() {
    Row() {
      Row() {
        Text('播放列表')
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
        Text(`${this.playlist.length}`)
          .fontSize(14)
          .fontColor(V3Theme.tx3(this.mode))
          .margin({ left: 8 })
      }
      Blank()
      Row({ space: 10 }) {
        this.RoundBtn($r('sys.symbol.scope'), () => {
          this.locate()
        })
        this.RoundBtn($r('sys.symbol.ohos_trash'), () => {
          this.ds.clearData()
          PlaylistManager.clearPlaylist()
          ToastUtil.showShort('已清空播放列表')
        })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 12 })
  }

  @Builder
  RoundBtn(icon: Resource, onTap: () => void) {
    Stack() {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([V3Theme.tx2(this.mode)])
    }
    .width(40)
    .height(40)
    .borderRadius(20)
    .backgroundColor(V3Theme.glass2(this.mode))
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .onClick(onTap)
  }

  @Builder
  Row3(song: Song, index: number) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Image(cover(song?.album?.cover ?? '', 200))
          .width(46)
          .height(46)
          .borderRadius(10)
          .objectFit(ImageFit.Cover)
          .opacity(this.currentSong?.id === song.id ? 0.7 : 1)
        if (this.currentSong?.id === song.id) {
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .fontSize(18)
            .fontColor([V3Theme.accentFallback(this.mode)])
        }
      }
      Column() {
        Text(song.name ?? '')
          .fontSize(15)
          .fontWeight(this.currentSong?.id === song.id ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.currentSong?.id === song.id ? V3Theme.accentFallback(this.mode) : V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.artist(song))
          .fontSize(12)
          .fontColor(V3Theme.tx3(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.xmark'))
        .fontSize(16)
        .fontColor([V3Theme.tx3(this.mode)])
        .padding(6)
        .onClick(() => {
          PlaylistManager.removeSong(song)
          this.ds.deleteData(index)
          this.ds.reloadData()
        })
    }
    .width('100%')
    .padding({ left: 20, right: 16, top: 8, bottom: 8 })
    .onClick(() => {
      PlaylistManager.playSong(song)
    })
  }

  build() {
    Column() {
      this.Header()
      if (this.playlist && this.playlist.length > 0) {
        List({ scroller: this.scroller }) {
          LazyForEach(this.ds, (song: Song, index: number) => {
            ListItem() {
              this.Row3(song, index)
            }
          }, (song: Song, index: number) => `${song.id}-${index}`)
          ListItem() {
            Row().height(this.bottomRect + 16)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .cachedCount(8)
        .onAppear(() => {
          this.locate()
        })
      } else {
        Column() {
          Text('播放列表为空')
            .fontSize(15)
            .fontColor(V3Theme.tx3(this.mode))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(V3Theme.canvas(this.mode))
    .borderRadius({
      topLeft: this.widthBp >= WidthBreakpoint.WIDTH_LG ? 30 : 40,
      topRight: this.widthBp >= WidthBreakpoint.WIDTH_LG ? 30 : 40,
      bottomLeft: this.widthBp >= WidthBreakpoint.WIDTH_LG ? 30 : 0,
      bottomRight: this.widthBp >= WidthBreakpoint.WIDTH_LG ? 30 : 0
    })
    .clip(true)
  }
}
