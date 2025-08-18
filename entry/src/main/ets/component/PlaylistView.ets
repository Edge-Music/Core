import { SongInfo } from '../component/SongInfo';
import { StyleConstants } from '../constants/StyleConstants';
import { Playlist, Song } from '../type/Adapter';
import { PlaylistManager } from '../util/PlaylistManager';
import { ToastUtil } from '@pura/harmony-utils';
import { LogUtil } from '@pura/harmony-utils';
import { SongsDataSource } from '../util/SongsDataSource';

@Component
export struct PlaylistView {
  @StorageLink('current_playing_song') currentSong: Song | null = null;
  @StorageLink('current_playing_playlist') playlist: Array<Song> = [];
  @StorageLink("current_playlist_data") curPlaylist: Playlist | null = null
  @StorageProp('current_width_breakpoint') widthBreakpoint: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('bottomRect') bottomRect: number = 0
  @State isLoading: boolean = false;
  @State highlightIndex: number = -1;
  @State currentIndex: number = -1
  @State private songsDataSource: SongsDataSource = new SongsDataSource()

  private scrollController: Scroller = new Scroller();

  // 可选的事件回调
  onSongSelected?: (song: Song) => void;
  onPlaylistEmpty?: () => void;

  aboutToAppear(): void {
    this.initSongsData_();
  }

  initSongsData_() {
    this.songsDataSource.pushMultiData(this.playlist)
    // 滚动到当前播放的歌曲
    this.scrollToCurrentSong();
  }

  // 处理歌曲点击
  private handleSongTap(song: Song, index: number): void {
    LogUtil.info('PlaylistView', 'Song tapped:', song.name || 'unknown');

    // 播放选中的歌曲
    if (this.playlist && this.playlist.length > 0) {
      PlaylistManager.playSong(song);
    }

    // 触发选中事件
    if (this.onSongSelected) {
      this.onSongSelected(song);
    }

    this.currentIndex = index
  }

  // 处理歌曲删除
  private handleSongDelete(dsong: Song, index: number): void {

    // 直接从数据源删除
    this.songsDataSource.deleteData(index)
    this.songsDataSource.reloadData()

    // 从播放列表中移除歌曲
    PlaylistManager.removeSong(dsong);

    // 显示删除成功提示
    ToastUtil.showShort($r('app.string.removed_from_the_playlist'));
  }

  // 滚动到当前播放的歌曲
  scrollToCurrentSong(): void {
    if (!this.currentSong || !this.playlist || this.playlist.length === 0) {
      return;
    }

    // 查找当前歌曲的索引
    this.currentIndex = this.playlist.findIndex(song =>
    song.id === this.currentSong?.id
    );


    if (this.currentIndex !== -1) {

      // 设置高亮效果
      this.highlightIndex = this.currentIndex;
      setTimeout(() => {
        this.highlightIndex = -1;
      }, 300)

    }
  }

  // 删除按钮构建器
  @Builder
  DeleteButton(song: Song, index: number) {
    Button({ type: ButtonType.Circle }) {
      Image($r('app.media.ic_close'))
        .width(20)
        .height(20)
        .fillColor($r('app.color.text_secondary'))
    }
    .width(36)
    .height(36)
    .backgroundColor('rgba(200, 200, 200, 0.1)')
    .margin({ left: 8 })
    .onClick(() => {
      this.handleSongDelete(song, index);
    })
  }

  // 空状态构建器
  @Builder
  EmptyState() {
    Column() {
      Text($r('app.string.no_songs_available'))
        .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
        .fontColor($r('app.color.text_hint'))
        .fontSize(16)
        .margin({ bottom: 8 })

      Text('点击添加按钮添加歌曲')
        .fontSize(14)
        .fontColor($r('app.color.text_hint'))
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(300)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Row() {
          Text($r('app.string.playing_list'))
            .fontSize(20)
            .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
            .fontColor($r('app.color.text_title'))
          Text(`(${this.playlist.length})`)
            .fontSize(14)
            .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
            .fontColor($r('app.color.text_title'))
            .margin({ left: 2 })
        }

        Row() {
          SymbolGlyph($r('sys.symbol.scope'))
            .fontSize(20)
            .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
            .fontColor([$r('app.color.text_title')])
            .clickEffect({ level: ClickEffectLevel.LIGHT })
            .onClick(() => {
              this.scrollController.scrollToIndex(this.currentIndex, true)
            })

          SymbolGlyph($r('sys.symbol.ohos_trash'))
            .fontSize(20)
            .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
            .fontColor([$r('app.color.text_title')])
            .margin({ left: 10 })
            .clickEffect({ level: ClickEffectLevel.LIGHT })
            .onClick(() => {
              this.songsDataSource.clearData()
              PlaylistManager.clearPlaylist();
            })
        }

      }
      .padding(16)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .width(StyleConstants.FULL_WIDTH)
      if (!this.playlist || this.playlist.length === 0) {
        this.EmptyState()
      } else {
        List({ initialIndex: this.currentIndex, scroller: this.scrollController }) {
          // 使用LazyForEach实现懒加载歌曲列表
          LazyForEach(this.songsDataSource, (song: Song, index: number) => {
            ListItem() {
              SongInfo({
                playlistId: this.curPlaylist?.id,
                song: song,
                showIndex: false,
                active: this.currentSong?.id === song.id,
                highlight: this.highlightIndex === index,
                disabled: song.privilege && !song.privilege.playable,
                onTap: (song: Song) => this.handleSongTap(song, index),
                isShowMenu: false
              }) {
                // 使用rightSlot插槽添加删除按钮
                this.DeleteButton(song, index)
              }
            }
            .margin({ bottom: 4 })
          }, (song: Song, index: number) => `${song.id}-${index}`) // 使用歌曲ID作为唯一标识符

          // 加载中状态显示
          if (this.isLoading) {
            ListItem() {
              Row() {
                LoadingProgress()
                  .width(24)
                  .height(24)
                  .color($r('app.color.text_secondary'))

                Text('加载中...')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ left: 8 })
              }
              .width(StyleConstants.FULL_WIDTH)
              .justifyContent(FlexAlign.Center)
              .padding({ top: 16, bottom: 16 })
            }
          }

          ListItem(){
            Column(){
              Blank().height(this.bottomRect)
            }
          }
        }
        .width(StyleConstants.FULL_WIDTH)
        .layoutWeight(1)
        .listDirection(Axis.Vertical)
        .divider({ strokeWidth: 0 })
        .scrollBar(BarState.Off)
        .cachedCount(8)
        .onAppear(() => {
          this.scrollController.scrollToIndex(this.currentIndex, true)
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .layoutWeight(1)
  }
}