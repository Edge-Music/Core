import { StyleConstants } from '../constants/StyleConstants';
import { Song } from '../type/Adapter';
import { avPlayerManager } from '../util/AVPlayerManager';
import { PlaylistManager, PlayMode } from '../util/PlaylistManager';
import { cover } from '../util/AdapterHelper';
import { PlaylistView } from '../component/PlaylistView';
import { BreakpointConstants } from '../constants/BreakpointConstants';
import { PreferencesCache } from "../util/PreferenceCache";
import { LyricsLine } from '../util/LyricsManager';

@Component
export struct MiniPlaybackControl {
  @StorageLink('current_playing_song') currentSong: Song | null = null;
  @StorageLink('current_playing_playMode') playMode: PlayMode = PlayMode.LOOP;
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm'
  @State currentTimeMs: number = 0;
  @State durationMs: number = 0;
  @State isPlaying: boolean = false;
  @State showPlaylist: boolean = false;
  @State swipeOffset: number = 0; // 滑动偏移量
  @State isSwipingActive: boolean = false; // 是否正在滑动中
  @State swipeDirection: string = ''; // 滑动方向
  @StorageLink('winWidth') winWidth: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageLink('miniplaying_bottom_judge') bottom_judge: string = PreferencesCache.getUserPreference('miniplaying_bottom_judge','0')
  @StorageProp('current_line_lyrics') currentLineLyrics: LyricsLine | undefined = AppStorage.get<LyricsLine>('current_line_lyrics')
  @StorageProp('current_width_breakpoint') widthBreakpoint: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @State playBtnScale: number = 1
  @State nextBtnScale: number = 1
  @State playListBtnScale: number = 1
  private updateTimer: number = -1;
  private playerManager = avPlayerManager;
  private readonly SWIPE_THRESHOLD: number = 80; // 触发切换的阈值
  uiContext: UIContext | undefined = undefined;
  aboutToAppear() {
    // 获取初始状态
    this.playerManager.getAVPlayerInstance().then(player => {
      this.currentTimeMs = player.currentTime;
      this.durationMs = player.duration;
      this.uiContext = this.getUIContext();
      this.isPlaying = player.state === 'playing';
    });

    // 添加事件监听
    this.playerManager.addListener('onPlay', () => {
      this.isPlaying = true;
    });

    this.playerManager.addListener('onPause', () => {
      this.isPlaying = false;
    });

    // 定时更新进度
    this.updateTimer = setInterval(async () => {
      const player = await this.playerManager.getAVPlayerInstance();
      this.currentTimeMs = player.currentTime;
      this.durationMs = player.duration;
    }, 500);
  }

  aboutToDisappear() {
    // 清理定时器
    if (this.updateTimer !== -1) {
      clearInterval(this.updateTimer);
      this.updateTimer = -1;
    }
  }

  // 处理歌曲切换
  handleSongChange(direction: 'next' | 'prev') {
    this.uiContext?.animateTo({
      duration: 350,
      curve: Curve.EaseInOut,
      delay: 0,
      onFinish: () => {
        this.swipeOffset = 0;
        this.isSwipingActive = false;
        this.swipeDirection = '';
      }
    }, () => {
      if (direction === 'next') {
        const nextSong = PlaylistManager.playNext();
        if (nextSong) {
          PlaylistManager.playSong(nextSong);
        }
      } else {
        const prevSong = PlaylistManager.playPrevious();
        if (prevSong) {
          PlaylistManager.playSong(prevSong);
        }
      }
    });
  }

  // 进度条构建器
  @Builder
  ProgressBar() {
    Column() {
      Progress({
        value: this.currentTimeMs,
        total: this.durationMs || 100,
        type: ProgressType.Capsule
      })
        .height(2)
        .width((this.winWidth*StyleConstants.NINETY_HEIGHT) - StyleConstants.BORDER_RADIUS*2) //进度条调整长度为屏幕宽度的90%-圆角的2倍(12*2)
        .color($r('app.color.text_click'))
        .backgroundColor('rgba(255, 255, 255, 0.2)')
    }
    .width(StyleConstants.FULL_WIDTH)
    .position({ x: 0, y: 0 })
  }

  @Builder
  ProgressBarCircle() {
    Column() {
      Progress({
        value: this.currentTimeMs,
        total: this.durationMs || 100,
        type: ProgressType.Ring
      })
        .height(37)
        .width(37)
        .color($r('app.color.text_primary'))
        .style({
          strokeWidth: 2,
          shadow: false,
          status: ProgressStatus.PROGRESSING
        })
        .backgroundColor('transparent')
    }
  }

  // 播放列表弹层构建器
  @Builder
  PlayListBuilder() {
    Column() {
      PlaylistView()
    }
    .backgroundColor($r('app.color.page_background'))
    .layoutWeight(1)
    .transition({ type: TransitionType.Insert, scale: { y: 0.8, x: 1.0 }, opacity: 0.0 })
    .transition({ type: TransitionType.Delete, scale: { y: 0.8, x: 1.0 }, opacity: 0.0 })
  }

  build() {
    Stack() {
      // 背景
      Column()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .backgroundBlurStyle(BlurStyle.Thick)
        .borderRadius(10)
        .shadow({
          color: 'rgba(0, 0, 0, 0.12)',
          radius: 30,
          offsetX: 1,
          offsetY: 1,
        })
        .clip(true)

      Column() {
        // 进度条（覆盖在整个组件上方）
        // this.ProgressBar()

        // 主控制栏布局
        Row() {
          // 唱片封面
          Stack() {
            Image(cover(this.currentSong?.album.cover || '', 200))
              .width(42)
              .height(42)
              .borderRadius(8)
              // .geometryTransition('song-cover', { follow: true })
              // .transition(TransitionEffect.OPACITY)
          }
          .margin({ left: 16 })

          // 歌曲信息
          Column() {
            Text(this.currentSong?.name || $r('app.string.no_playback_available'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_title'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (this.currentSong) {
              Text(this.currentSong.artists?.map(artist => artist.name).join(' / ') || $r('app.string.unknown_artist'))
                .fontSize(12)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(2)

          Column() {
            Text(this.currentLineLyrics?.text)
              .fontSize(17)
              .fontWeight(700)
              .fontColor($r('app.color.text_title'))
              .maxLines(2)
              .textAlign(TextAlign.Center)
              .borderRadius(8)
          }
          .margin({ left: 12, right: 12 })
          .layoutWeight(5)
          .visibility(this.widthBreakpoint >= WidthBreakpoint.WIDTH_MD ? Visibility.Visible : Visibility.None)

          // 控制按钮组
          Row({ space: 8 }) {
            // 播放/暂停按钮
            Stack(){
              Button({ type: ButtonType.Circle }) {
                if(this.isPlaying){
                  Image($r('app.media.ic_pause'))
                    .width(20)
                    .height(20)
                    .fillColor($r('app.color.text_primary'))

                }else{
                  Image($r('app.media.ic_play'))
                    .width(16)
                    .height(16)
                    .fillColor($r('app.color.text_primary'))
                    .margin({ left: 2 })
                }
              }
              .width(36)
              .height(36)
              .alignSelf(ItemAlign.Center)
              .backgroundBlurStyle(BlurStyle.Thin)
              .backgroundColor('rgba(179, 179, 179, 0.10)')
              .shadow(ShadowStyle.OUTER_DEFAULT_XS)

              this.ProgressBarCircle()
            }
            .scale({ x: this.playBtnScale, y: this.playBtnScale})
            .onClick(() => {
              this.isPlaying = !this.isPlaying
              if (this.isPlaying) {
                this.playerManager.play();
              } else {
                this.playerManager.pause();
              }
            })
            .onTouch((event) => {
              if (event.type === TouchType.Down) {
                this.uiContext?.animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                  this.playBtnScale = 0.8
                })
              } else if (event.type === TouchType.Up) {
                this.uiContext?.animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                  this.playBtnScale = 1
                })
              }
            })


            // 下一首按钮
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.ic_next'))
                .width(20)
                .height(20)
                .fillColor($r('app.color.text_primary'))
            }
            .width(36)
            .height(36)
            .scale({ x: this.nextBtnScale, y: this.nextBtnScale})
            .backgroundBlurStyle(BlurStyle.Thin)
            .backgroundColor('rgba(200, 200, 200, 0.1)')
            .shadow(ShadowStyle.OUTER_DEFAULT_XS)
            .onClick(() => {
              const nextSong = PlaylistManager.playNext();
              if (nextSong) {
                PlaylistManager.playSong(nextSong);
              }
            })
            .onTouch((event) => {
              if (event.type === TouchType.Down) {
                this.uiContext?.animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                  this.nextBtnScale = 0.8
                })
              } else if (event.type === TouchType.Up) {
                this.uiContext?.animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                  this.nextBtnScale = 1
                })
              }
            })

            // 播放列表按钮
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.ic_list'))
                .width(20)
                .height(20)
                .fillColor($r('app.color.text_primary'))
            }
            .width(36)
            .height(36)
            .scale({ x: this.playListBtnScale, y: this.playListBtnScale})
            .backgroundBlurStyle(BlurStyle.Thin)
            .backgroundColor('rgba(200, 200, 200, 0.1)')
            .shadow(ShadowStyle.OUTER_DEFAULT_XS)
            .onClick(() => {
              this.showPlaylist = true;
            })
            .onTouch((event) => {
              if (event.type === TouchType.Down) {
                this.uiContext?.animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                  this.playListBtnScale = 0.8
                })
              } else if (event.type === TouchType.Up) {
                this.uiContext?.animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                  this.playListBtnScale = 1
                })
              }
            })

          }
          .margin({ right: 16 })
        }
        .height(64)
        .width(StyleConstants.FULL_WIDTH)
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .translate({ x: this.swipeOffset })
        // .geometryTransition('song-cover', { follow: false })
        .opacity(this.isSwipingActive ? (1 - Math.min(0.3, Math.abs(this.swipeOffset) / 300)) : 1)
        .animation({
          duration: 350,
          curve: Curve.EaseInOut,
          delay: 0,
          iterations: 1
        })

        if(this.bottom_judge !== '0'){
          Row()
            .height(this.bottomRect/2)
            .width(StyleConstants.FULL_WIDTH)
        }
      }
      .transition(TransitionEffect.OPACITY)
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .onVisibleAreaChange([0.0, 1.0], () => {
      this.bottom_judge = PreferencesCache.getUserPreference('miniplaying_bottom_judge','0')
    })
    .width(this.bottom_judge === '0' && this.bottomRect > 0 ? "90%" : "100%")
    .height(this.bottom_judge === '0' ? 64 : 64+this.bottomRect/2)
    .margin(this.bottom_judge === '0' ? this.bottomRect : 0)
    .borderRadius(12)
    .clip(true)
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.15)',
      offsetX: 0,
      offsetY: 2
    })
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal })
        .onActionStart(() => {
          this.isSwipingActive = true;
        })
        .onActionUpdate((event) => {
          // 更新滑动偏移量
          this.swipeOffset = event.offsetX;

          // 确定滑动方向
          if (event.offsetX > 10) {
            this.swipeDirection = 'right'; // 向右滑动，上一首
          } else if (event.offsetX < -10) {
            this.swipeDirection = 'left'; // 向左滑动，下一首
          } else {
            this.swipeDirection = '';
          }
        })
        .onActionEnd(() => {
          // 根据最终偏移量决定是切换歌曲还是回弹
          if (this.swipeOffset > this.SWIPE_THRESHOLD) {
            // 向右滑动超过阈值，切换到上一首
            this.handleSongChange('prev');
          } else if (this.swipeOffset < -this.SWIPE_THRESHOLD) {
            // 向左滑动超过阈值，切换到下一首
            this.handleSongChange('next');
          } else {
            // 未达到阈值，回弹
            this.uiContext?.animateTo({
              duration: 250,
              curve: Curve.EaseOut,
              delay: 0,
              onFinish: () => {
                this.isSwipingActive = false;
                this.swipeDirection = '';
              }
            }, () => {
              this.swipeOffset = 0;
            });
          }
        })
    )
    .onClick(() => {
      // 只有在没有滑动时才响应点击事件
      if (!this.isSwipingActive && this.currentSong) {
        // this.uiContext?.animateTo({
        //   duration: 100,
        //   // 构造插值器弹簧曲线对象，生成一条从0到1的动画曲线
        //   curve: curves.interpolatingSpring(0, 1, 324, 38),
        // }, () => {
        //   this.pageStack.pushPath({ name: 'Playing' },{launchMode:LaunchMode.MOVE_TO_TOP_SINGLETON,animated:true} )
        // })
        this.pageStack.pushPath({ name: 'Playing' },{launchMode:LaunchMode.MOVE_TO_TOP_SINGLETON,animated:true} )
      }
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .bindSheet($$this.showPlaylist, this.PlayListBuilder(), {
      showClose: false,
      height: SheetSize.MEDIUM,
      dragBar: false,
      preferType: this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM ? SheetType.POPUP : SheetType.POPUP,
      onWillDismiss: () => {
        this.showPlaylist = false;
      }
    })
    .animation({
      duration: 500,
      curve: Curve.FastOutSlowIn
    })
  }
}