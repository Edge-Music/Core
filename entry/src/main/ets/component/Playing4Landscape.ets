import { StyleConstants } from "../constants/StyleConstants"
import { Song, SongV2 } from "../type/Adapter"
import { cover } from "../util/AdapterHelper"
import { AppStorageV2, curves, font, window } from "@kit.ArkUI"
import { avPlayerManager } from "../util/AVPlayerManager"
import { LyricsView } from "./LyricsView"
import { PreferencesCache } from "../util/PreferenceCache"
import { text } from "@kit.ArkGraphics2D"

const TAG = 'Playing4Landscape'

@ComponentV2
export struct Playing4Landscape {
  //歌曲信息获取
  @Require @Param song: Song | null
  //播放状态获取
  @Require @Param isPlaying: boolean
  //一句播放歌词
  @Require @Param OneSentence: string

  //底部避让高度获取
  @Require @Param bottomRect: number
  @Require @Param paramCurrentTime: number
  @Local currentTime: number = 0

  @Require @BuilderParam playControl: () => void
  @Require @BuilderParam playControlWithHeart: () => void

  @Monitor('paramCurrentTime')
  onStrChange(monitor: IMonitor) {
    this.currentTime = this.paramCurrentTime
    // monitor.dirty.forEach((path: string) => {
    //   console.info(`${path} changed from ${monitor.value(path)?.before} to ${monitor.value(path)?.now}`);
    // });
  }

  // @Builder LyricsView_1() {};
  // @BuilderParam LyricsView: () => void = this.LyricsView_1
  // @Local SongItem: SongV2 =
  //   AppStorageV2.connect(SongV2,'SongV2', () => new SongV2())! //避让相关参数获取
  //音频控制相关需执行函数
  @Event songPlay: () => void = () => {
  }
  @Event songPause: () => void = () => {
  }
  @Event songNext: () => void = () => {
  }
  @Event songPrev: () => void = () => {
  }
  @Local screenWidth: number = 0
  @Local screenHeight: number = 0
  //播放主题控制及动画相关
  @Local ThemeChoose: number = 0
  @Local themeCount: number = 5
  // @Local ThemeSetting:boolean = false
  @Local themeSetting: boolean = false
  @Local isSwipingActive: boolean = false
  @Local swipeOffset: number = 0
  private swiperController: SwiperController = new SwiperController()
  //titlebar
  @Local Timer4showTitleBar: number = 0
  @Local showTitleBar: boolean = false
  @Local isProgressBarExpanded: boolean = false
  //主题3配置
  @Local setting4Theme3: boolean = false
  @Local Font4Theme3: string = '0'
  @Local FontSize4Theme3: number = 100
  // @Local Timer4Theme3ctrl: number = 0
  @Local showSongCtrl4Theme3: boolean = false
  //主题4配置
  private  textTimerController: TextTimerController = new TextTimerController();
  //音频播放相关状态及控制
  // private playerManager = avPlayerManager;

  aboutToAppear() {
    let context = this.getUIContext();


    let fontCollection = text.FontCollection.getGlobalInstance()
    fontCollection.loadFontSync('yxs0', $rawfile('hwbsj.ttf'))
    fontCollection.loadFontSync('yxs1', $rawfile('HarmonyClock_01.ttf'))
    fontCollection.loadFontSync('yxs2', $rawfile('HarmonyClock_02.ttf'))
    fontCollection.loadFontSync('yxs3', $rawfile('HarmonyClock_03.ttf'))
    fontCollection.loadFontSync('yxs4', $rawfile('HarmonyClock_04.ttf'))
    fontCollection.loadFontSync('yxs5', $rawfile('HarmonyClock_05.ttf'))
    fontCollection.loadFontSync('yxs6', $rawfile('HarmonyClock_06.ttf'))
    fontCollection.loadFontSync('yxs7', $rawfile('HarmonyClock_07.ttf'))
    fontCollection.loadFontSync('yxs8', $rawfile('HarmonyClock_08.ttf'))
    // 获取屏幕的宽高
    window.getLastWindow(context.getHostContext())
      .then((windowClass: window.Window) => {
        let windowProperties = windowClass.getWindowProperties();
        this.screenWidth = context.px2vp(windowProperties.windowRect.width);
        this.screenHeight = context.px2vp(windowProperties.windowRect.height);
      })
      .catch((error: Error) => {
        console.error('Failed to obtain the window size. Cause: ' + JSON.stringify(error));
      })
    let ChooseTheme: number = Number(PreferencesCache.getUserPreference('Playing_HorizontalMode_index', '0'))

    //首次进入展示设置按键
    clearInterval(this.Timer4showTitleBar)
      if (this.showTitleBar === false&&ChooseTheme!=2) {
        this.getUIContext().animateTo({
          duration: 300,
          curve: curves.springMotion(0, 0.65),
          // delay: 500,
          // iterations: -1, // 设置-1表示动画无限循环
          playMode: PlayMode.Alternate,
          expectedFrameRateRange: {
            min: 10,
            max: 120,
            expected: 60,
          }
        }, () => {
          // this.themeSetting =!this.themeSetting
          this.showTitleBar = true
        })
        this.Timer4showTitleBar = setInterval(() => {
          this.getUIContext().animateTo({
            duration: 300,
            curve: curves.springMotion(0, 0.65),
            // delay: 500,
            // iterations: -1, // 设置-1表示动画无限循环
            playMode: PlayMode.Alternate,
            expectedFrameRateRange: {
              min: 10,
              max: 120,
              expected: 60,
            }
          }, () => {
            // this.themeSetting =!this.themeSetting
            this.showTitleBar = false
            // this.showSetting = true
          })
        }, 3000)
      }


    this.Font4Theme3 = PreferencesCache.getUserPreference('Font4Theme3', '-1')
    this.FontSize4Theme3 = Number(PreferencesCache.getUserPreference('FontSize4Theme3', '100'))

  }

  handleSongChange(direction: 'next' | 'prev') {
    this.getUIContext()?.animateTo({
      duration: 350,
      curve: Curve.EaseInOut,
      delay: 0,
      onFinish: () => {
        this.swipeOffset = 0;
        this.isSwipingActive = false;
        // this.swipeDirection = '';
      }
    }, () => {
      if (direction === 'next') {
        this.songNext()
        // const nextSong = PlaylistManager.playNext();
        // if (nextSong) {
        //   PlaylistManager.playSong(nextSong);
        // }
      } else {
        this.songPrev()
      }
    });
  }

  getFontSize(text: string, baseSize = 18, maxLength = 36): number {
    if (!text) {
      return baseSize
    }
    if (text.length <= maxLength) {
      return baseSize
    }
    return Math.max(12, baseSize * maxLength / text.length)
  }

  formatTime(milliseconds: number): string {
    if (isNaN(milliseconds) || milliseconds < 0) {
      return '0:00'
    }
    const seconds = Math.floor(milliseconds / 1000)
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  @Builder
  //通用封面图样式
  song2Image() {
    Stack() {
      Stack() {
        Image(cover(this.song?.album?.cover ?? "", 512))
        // .geometryTransition("picture", { follow: false })
        // .transition(TransitionEffect.OPACITY)
          .layoutWeight(1)
        // Image(cover(this.song?.album?.cover ?? "", 512))

          .aspectRatio(1)
          .clip(true)
          .shadow({
            radius: 0,
            color: 'rgba(0, 0, 0, 0.15)',
            offsetX: 0,
            offsetY: 2
          })
          .borderRadius(24)
          .translate({ x: this.swipeOffset })
          .opacity(this.isSwipingActive ? (1 - Math.min(0.3, Math.abs(this.swipeOffset) / 300)) : 1)
          .animation({
            duration: 350,
            curve: Curve.EaseInOut,
            delay: 0,
            iterations: 1
          })
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal })
              .onActionStart(() => {
                this.isSwipingActive = true;
              })
              .onActionUpdate((event) => {
                // 更新滑动偏移量
                this.swipeOffset = event.offsetX;

                // // 确定滑动方向
                // if (event.offsetX > 10) {
                //   this.swipeDirection = 'right'; // 向右滑动，上一首
                // } else if (event.offsetX < -10) {
                //   this.swipeDirection = 'left'; // 向左滑动，下一首
                // } else {
                //   this.swipeDirection = '';
                // }
              })
              .onActionEnd(() => {
                // 根据最终偏移量决定是切换歌曲还是回弹
                if (this.swipeOffset > 80) {
                  // 向右滑动超过阈值，切换到上一首

                  this.handleSongChange('prev');
                } else if (this.swipeOffset < -80) {
                  // 向左滑动超过阈值，切换到下一首
                  this.handleSongChange('next');
                } else {
                  // 未达到阈值，回弹
                  this.getUIContext().animateTo({
                    duration: 250,
                    curve: Curve.EaseOut,
                    delay: 0,
                    onFinish: () => {
                      this.isSwipingActive = false;
                      // this.swipeDirection = '';
                    }
                  }, () => {
                    this.swipeOffset = 0;
                  });
                }
              })
          )
        // if (!this.isPlaying){
        //
        // }
      }

      // .clickEffect({ level: ClickEffectLevel.LIGHT })

      Row() {
        Text(this.song?.artists ? this.song.artists.map(artist => artist.name).join(" / ") : "未知艺术家")
          .maxLines(1)
          .fontSize(14)
          .width('60%')
          .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
          //TODO:: 需要实现字体颜色控制
          // .fontColor(`#ff${this.imageColorHex}`)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .blendMode(BlendMode.DIFFERENCE, BlendApplyType.OFFSCREEN)
        //TODO:: 需要实现拉起歌手页面
        // .onClick(() => {
        //   if (this.song?.artists && this.song.artists.length > 0) {
        //     this.sheetType = "artist";
        //     this.showPlaylist = true;
        //   }
        // })

        Row() {
          if (!this.themeSetting) {
            TextClock()
              .format('HH:mm:ss')
              .blendMode(BlendMode.DIFFERENCE, BlendApplyType.OFFSCREEN)
          }


        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding(12)
    }.layoutWeight(1)
    .alignContent(Alignment.BottomEnd)
    .aspectRatio(1)
    .scale({ x: this.isPlaying ? 1 : 0.8, y: this.isPlaying ? 1 : 0.8 })
    .animation({
      duration: 300,
      curve: curves.springMotion(0, 0.65),
      // iterations: 3,
      playMode: PlayMode.Normal
    })

    // .layoutWeight(1)
  }

  @Builder
  ProgressBar(judge: boolean = true, weight: number = 0, judge_time_area: boolean = true) {
    Column() {
      if (judge && judge_time_area) {
        Row() {
          Text(this.formatTime(this.currentTime))
            .fontSize(12)
            .fontColor('rgba(255, 255, 255, 0.6)')
            .height(16)// 固定高度以保持布局稳定
            .animation({
              duration: 500,
              curve: Curve.Linear,
              iterations: 1,
              playMode: PlayMode.Normal
            })

          Blank()

          Text(this.formatTime(this.song?.duration || 0))
            .fontSize(12)
            .fontColor('rgba(255, 255, 255, 0.6)')
            .height(16) // 固定高度以保持布局稳定
        }
        .width(StyleConstants.FULL_WIDTH)
        .padding({ left: 8, right: 8 })
        .height(16) // 固定高度以保持布局稳定
      }
      // bnm
      Slider({
        value: this.currentTime,
        max: this.song?.duration || 0,
        step: 1,
        style: SliderStyle.InSet
      })
        .trackThickness(this.isProgressBarExpanded ? 12 + weight : 8 + weight)
        .selectedColor('rgba(255, 255, 255, 1.00)')
        .trackColor('rgba(177, 177, 177, 0.30)')// 半透明背景
        .blockColor('rgba(164, 164, 164, 1.00)')
        .width(StyleConstants.FULL_WIDTH)
        .height(25)// 固定高度以保持布局稳定
        .animation({
          duration: 250,
          curve: Curve.EaseOut,
          iterations: 1,
          playMode: PlayMode.Normal
        })
        .onChange((value: number) => {
          this.getUIContext()?.animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
            this.currentTime = value;
          })
        })
        .onTouch((event) => {
          if (event.type === TouchType.Down) {
            this.isProgressBarExpanded = true
          } else if (event.type === TouchType.Up) {
            this.isProgressBarExpanded = false
            avPlayerManager.seek(this.currentTime)
          }
        })
      if (judge && judge_time_area === false) {
        Row() {
          Text(this.formatTime(this.currentTime))
            .fontSize(12)
            .fontColor('rgba(255, 255, 255, 0.6)')
            .height(16)// 固定高度以保持布局稳定
            .animation({
              duration: 500,
              curve: Curve.Linear,
              iterations: 1,
              playMode: PlayMode.Normal
            })

          Blank()

          Text(this.formatTime(this.song?.duration || 0))
            .fontSize(12)
            .fontColor('rgba(255, 255, 255, 0.6)')
            .height(16) // 固定高度以保持布局稳定
        }
        .width(StyleConstants.FULL_WIDTH)
        .padding({ left: 8, right: 8 })
        .height(20) // 固定高度以保持布局稳定
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({
      left: 16,
      right: 16,
      top: judge_time_area ? 8 : 0,
      bottom: 4
    })
    .height(judge ? 40 : 30) // 固定整个进度条区域的高度
  }

  @Builder
  PlayerControls() {
    Row({ space: 16 }) {

      // 上一首按钮
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_prev'))
          .width(30)
          .height(30)
          .fillColor($r('app.color.text_primary'))
        // .fillColor(Color.White)

      }
      .backgroundColor(Color.Transparent)
      .width(36)
      .height(36)

      // .backgroundBlurStyle(BlurStyle.Thin)
      // .backgroundColor('rgba(200, 200, 200, 0.1)')
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .onClick(() => {
        this.songPrev()
      })

      // 播放/暂停按钮
      Button({ type: ButtonType.Circle }) {
        if (this.isPlaying) {
          Image($r('app.media.ic_pause'))
            .width(30)
            .height(30)
            .fillColor($r('app.color.text_primary'))

        } else {
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
      // .backgroundBlurStyle(BlurStyle.Thin)
      // .backgroundColor('rgba(179, 179, 179, 0.10)')
      .backgroundColor(Color.Transparent)
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .onClick(() => {
        // this.isPlaying = !this.isPlaying
        if (!this.isPlaying) {
          this.songPlay()
        } else {
          this.songPause();
        }

      })

      // 下一首按钮
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_next'))
          .width(30)
          .height(30)
          .fillColor($r('app.color.text_primary'))
      }
      .width(36)
      .height(36)
      // .backgroundBlurStyle(BlurStyle.Thin)
      // .backgroundColor('rgba(200, 200, 200, 0.1)')
      .backgroundColor(Color.Transparent)
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .onClick(() => {
        this.songNext()

      })
    }.alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .margin(16).width('100%')

  }

  @Builder
  LyricsView_1() {
    LyricsView({
      mode_judge: false
    })
  }

  @Builder
  theme1(song?: Song) {
    Column() {
      if (this.themeSetting || this.ThemeChoose === 0) {
        Column() {
          Stack() {

            Row() {
              Column() {
                Column() {
                  this.song2Image()
                }.onClick(() => {
                  // this.isPlaying = !this.isPlaying
                  if (!this.isPlaying) {
                    this.songPlay();
                  } else {
                    this.songPause();
                  }
                })
              }.width('50%').padding(20)

              Column() {
                //TODO::迁移V2 这里放歌词
                this.LyricsView_1()
              }.width('50%').height('100%')
            }.width('100%').height('100%')

            if (this.themeSetting) {
              Column() {

              }.width('100%').height('100%').backgroundColor(Color.Transparent).onClick(() => {
                this.getUIContext().animateTo({
                  duration: 300,
                  curve: curves.springMotion(0, 0.65),
                  // delay: 500,
                  // iterations: -1, // 设置-1表示动画无限循环
                  playMode: PlayMode.Alternate,
                  expectedFrameRateRange: {
                    min: 10,
                    max: 120,
                    expected: 60,
                  }
                }, () => {
                  this.themeSetting = !this.themeSetting
                  PreferencesCache.setUserPreference('Playing_HorizontalMode_index', '0')
                  // PreferencesUtil.put('ChooseTheme', 0)
                })
              })
            }
          }

        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .aspectRatio(this.screenWidth / this.screenHeight)
        .transition(TransitionEffect.OPACITY.animation({
          duration: this.ThemeChoose - 1 === 1 || this.ThemeChoose + 1 === this.themeCount ? 300 : 0,
          curve: curves.springMotion(0, 0.65)
        }).combine(
          TransitionEffect.translate({
            x: this.ThemeChoose - 1 === 0 ? -200 : this.ThemeChoose + 1 === this.themeCount ? 200 : 0,
            y: 0,
            z: 0
          })
        ))
      }


    }.width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor(Color.Transparent)

  }

  @Builder
  theme2() {
    Column() {

      if (this.themeSetting || this.ThemeChoose === 1) {
        Stack() {
          Row() {
            Column() {
              Column() {
                this.song2Image()
              }.onClick(() => {
                // this.isPlaying = !this.isPlaying
                if (!this.isPlaying) {
                  this.songPlay();
                } else {
                  this.songPause();
                }
              }).layoutWeight(1).margin({ top: 16 })

              Text((this.song?.name || "未知歌曲"))
                .fontSize(this.getFontSize(this.song?.name ?? "", 16, 16))// .fontWeight(FontWeight.Bold)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .fontColor(Color.White)
                .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
                .height(24) // 固定高度确保布局稳定
                .margin({ top: 5 })

              Column() {
                this.ProgressBar(true, 0, true)
              }
              .padding({ left: 20, right: 20 })
              .width('100%')

              Column() {
                this.playControl()
              }
              .padding({ left: 20, right: 20 })
              .width('100%')
            }.width('50%').height('100%')

            Column() {
              this.LyricsView_1()
            }.width('50%').height('100%')
          }
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .aspectRatio(this.screenWidth / this.screenHeight)

          .transition(TransitionEffect.OPACITY.animation({
            duration: this.ThemeChoose - 1 === 1 || this.ThemeChoose + 1 === 1 ? 1300 : 0,
            curve: curves.springMotion(0, 0.65)
          }).combine(
            TransitionEffect.translate({
              x: this.ThemeChoose - 1 === 1 ? -200 : this.ThemeChoose + 1 === 1 ? 200 : 0,
              y: 0,
              z: 0
            })
          ))

          if (this.themeSetting) {
            Column() {
              // Blank()
            }.width('100%').height('100%').backgroundColor(Color.Transparent).onClick(() => {
              this.getUIContext().animateTo({
                duration: 300,
                curve: curves.springMotion(0, 0.65),
                // delay: 500,
                // iterations: -1, // 设置-1表示动画无限循环
                playMode: PlayMode.Alternate,
                expectedFrameRateRange: {
                  min: 10,
                  max: 120,
                  expected: 60,
                }
              }, () => {
                this.themeSetting = !this.themeSetting
                PreferencesCache.setUserPreference('Playing_HorizontalMode_index', '1')
              })
            })
          }
        }
      }

    }.width('100%').height('100%').justifyContent(FlexAlign.Center)

  }

  @Builder
  theme3() {
    Column() {
      if (this.themeSetting || this.ThemeChoose === 2) {
        Stack() {
          Column() {
            Stack() {
              Column() {
                if (this.Font4Theme3==='-1') {
                  TextClock()
                    .format('HH:mm:ss')
                    .fontFeature("\"ss01\" off")
                    .fontSize(this.FontSize4Theme3)
                    // .fontFamily('yxs' + this.Font4Theme3)
                    .width('100%')
                    .layoutWeight(1)
                }else {
                  TextClock()
                    .format('HH:mm:ss')
                    .fontFeature("\"ss01\" off")
                    .fontSize(this.FontSize4Theme3)
                    .fontFamily('yxs' + this.Font4Theme3)
                    .width('100%')
                    .layoutWeight(1)
                }


                if (this.setting4Theme3) {
                  List({ space: 16 }) {
                    ListItem() {
                      Column() {
                        Text('10:08')
                      }.borderWidth('yxs-1' === ('yxs' + this.Font4Theme3) ? 2 : 0)
                      .height('100%')
                      .aspectRatio(1)
                      .borderRadius(20)
                      .justifyContent(FlexAlign.Center)
                      .onClick(() => {
                        this.Font4Theme3 = '-1'
                        PreferencesCache.setUserPreference('Font4Theme3', this.Font4Theme3)
                      })
                    }
                    ListItem() {
                      Column() {
                        Text('10:08')
                          .fontFamily('yxs0')
                      }.borderWidth('yxs0' === ('yxs' + this.Font4Theme3) ? 2 : 0)
                      .height('100%')
                      .aspectRatio(1)
                      .borderRadius(20)
                      .justifyContent(FlexAlign.Center)
                      .onClick(() => {
                        this.Font4Theme3 = '0'
                        PreferencesCache.setUserPreference('Font4Theme3', this.Font4Theme3)
                      })
                    }


                    ListItem() {
                      Column() {
                        Text('10:08')
                          .fontFamily('yxs1')
                      }.borderWidth('yxs1' === ('yxs' + this.Font4Theme3) ? 2 : 0)
                      .height('100%')
                      .aspectRatio(1)
                      .borderRadius(20)
                      .justifyContent(FlexAlign.Center)
                      .onClick(() => {
                        this.Font4Theme3 = '1'
                        PreferencesCache.setUserPreference('Font4Theme3', this.Font4Theme3)
                      })
                    }

                    ListItem() {
                      Column() {
                        Text('10:08')
                          .fontFamily('yxs2')
                      }.borderWidth('yxs2' === ('yxs' + this.Font4Theme3) ? 2 : 0)
                      .height('100%')
                      .aspectRatio(1)
                      .borderRadius(20)
                      .justifyContent(FlexAlign.Center)
                      .onClick(() => {
                        this.Font4Theme3 = '2'
                        PreferencesCache.setUserPreference('Font4Theme3', this.Font4Theme3)
                      })
                    }

                    ListItem() {
                      Column() {
                        Text('10:08')
                          .fontFamily('yxs3')
                      }.borderWidth('yxs3' === ('yxs' + this.Font4Theme3) ? 2 : 0)
                      .height('100%')
                      .aspectRatio(1)
                      .borderRadius(20)
                      .justifyContent(FlexAlign.Center)
                      .onClick(() => {
                        this.Font4Theme3 = '3'
                        PreferencesCache.setUserPreference('Font4Theme3', this.Font4Theme3)
                      })
                    }

                    ListItem() {
                      Column() {
                        Text('10:08')
                          .fontFamily('yxs4')
                      }.borderWidth('yxs4' === ('yxs' + this.Font4Theme3) ? 2 : 0)
                      .height('100%')
                      .aspectRatio(1)
                      .borderRadius(20)
                      .justifyContent(FlexAlign.Center)
                      .onClick(() => {
                        this.Font4Theme3 = '4'
                        PreferencesCache.setUserPreference('Font4Theme3', this.Font4Theme3)
                      })
                    }

                    ListItem() {
                      Column() {
                        Text('10:08')
                          .fontFamily('yxs5')
                      }.borderWidth('yxs5' === ('yxs' + this.Font4Theme3) ? 2 : 0)
                      .height('100%')
                      .aspectRatio(1)
                      .borderRadius(20)
                      .justifyContent(FlexAlign.Center)
                      .onClick(() => {
                        this.Font4Theme3 = '5'
                        PreferencesCache.setUserPreference('Font4Theme3', this.Font4Theme3)
                      })
                    }

                    ListItem() {
                      Column() {
                        Text('10:08')
                          .fontFamily('yxs6')
                      }.borderWidth('yxs6' === ('yxs' + this.Font4Theme3) ? 2 : 0)
                      .height('100%')
                      .aspectRatio(1)
                      .borderRadius(20)
                      .justifyContent(FlexAlign.Center)
                      .onClick(() => {
                        this.Font4Theme3 = '6'
                        PreferencesCache.setUserPreference('Font4Theme3', this.Font4Theme3)
                      })
                    }

                    ListItem() {
                      Column() {
                        Text('10:08')
                          .fontFamily('yxs7')
                      }.borderWidth('yxs7' === ('yxs' + this.Font4Theme3) ? 2 : 0)
                      .height('100%')
                      .aspectRatio(1)
                      .borderRadius(20)
                      .justifyContent(FlexAlign.Center)
                      .onClick(() => {
                        this.Font4Theme3 = '7'
                        PreferencesCache.setUserPreference('Font4Theme3', this.Font4Theme3)
                      })
                    }

                    ListItem() {
                      Column() {
                        Text('10:08')
                          .fontFamily('yxs8')
                      }.borderWidth('yxs8' === ('yxs' + this.Font4Theme3) ? 2 : 0)
                      .height('100%')
                      .aspectRatio(1)
                      .borderRadius(20)
                      .justifyContent(FlexAlign.Center)
                      .onClick(() => {
                        this.Font4Theme3 = '8'
                        PreferencesCache.setUserPreference('Font4Theme3', this.Font4Theme3)
                      })
                    }
                  }
                  .width('100%')
                  .height('20%')
                  .listDirection(Axis.Horizontal)
                  .padding({ left: 16, right: 16 })
                  .scrollBar(BarState.Off)
                  Row(){
                    Text('字体大小')
                      .fontFamily('yxs0')
                    Slider({
                      value: $$this.FontSize4Theme3,
                      max: 150,
                      min: 50,
                      step: 1,
                      style: SliderStyle.InSet
                    })
                      .selectedColor('rgba(255, 255, 255, 1.00)')
                      .trackColor('rgba(177, 177, 177, 0.30)')// 半透明背景
                      .blockColor('rgba(164, 164, 164, 1.00)')
                      .width('60%')
                      .onChange((value)=>{
                        this.FontSize4Theme3 = value
                        PreferencesCache.setUserPreference('FontSize4Theme3',String(this.FontSize4Theme3))
                      })
                    Button('确定')
                      .fontColor($r('sys.color.font'))
                      .backgroundColor('rgba(177, 177, 177, 0.30)')
                      .onClick(()=>{

                        this.getUIContext().animateTo({
                          duration: 300,
                          curve: curves.springMotion(0, 0.65),
                          // delay: 500,
                          // iterations: -1, // 设置-1表示动画无限循环
                          playMode: PlayMode.Alternate,
                          expectedFrameRateRange: {
                            min: 10,
                            max: 120,
                            expected: 60,
                          }
                        }, () => {
                          this.setting4Theme3 = false
                        })
                      })
                  }.width('100%').justifyContent(FlexAlign.Center)
                  .margin({bottom:16})



                }

              }
              .scale({ x: !this.themeSetting ? 1 : 0.7, y: !this.themeSetting ? 1 : 0.7 })
              .width('100%')
              .height('100%')
              .backgroundColor(Color.Transparent)
              .justifyContent(FlexAlign.SpaceBetween)
              // 歌曲控制，灵动岛（仿制）
              Column(){
                Row({ space: this.showSongCtrl4Theme3 ? 8:4 }) {
                  Image(cover(this.song?.album?.cover ?? "", 512))
                    .aspectRatio(1)
                    .width(this.showSongCtrl4Theme3 ? 48+26:26)
                    .clip(true)
                    .shadow({
                      radius: 0,
                      color: 'rgba(0, 0, 0, 0.15)',
                      offsetX: 0,
                      offsetY: 2
                    })
                    .borderRadius(this.showSongCtrl4Theme3 ? 8:4)
                  //歌手，歌名，歌词，进度
                  Column(){
                    Text(this.song?.name+ (this.showSongCtrl4Theme3?`-${this.song?.artists ? this.song.artists.map(artist => artist.name).join(" / ") : "未知艺术家"}`:''))
                      .height(26)
                      .textOverflow({overflow:TextOverflow.MARQUEE})

                    if (this.showSongCtrl4Theme3){
                      Text(this.OneSentence)
                        .fontSize(14)
                        .height(22)
                        .textOverflow({overflow:TextOverflow.MARQUEE})
                        .fontColor($r('sys.color.font_secondary'))
                      Row(){
                        Text(this.formatTime(this.currentTime))
                          .maxFontSize(12)
                          .minFontSize(4)
                          .maxLines(1)
                          .fontColor($r('sys.color.font'))

                          .height(16)// 固定高度以保持布局稳定
                          .animation({
                            duration: 500,
                            curve: Curve.Linear,
                            iterations: 1,
                            playMode: PlayMode.Normal
                          })
                          .width('10%')

                        // Blank()

                        Slider({
                          value: this.currentTime,
                          max: this.song?.duration || 0,
                          step: 1,
                          style: SliderStyle.InSet
                        })
                        .trackThickness(8)
                          // .selectedColor('rgba(255, 255, 255, 1.00)')
                          .selectedColor($r('sys.color.font_secondary'))
                          .trackColor('rgba(177, 177, 177, 0.30)')// 半透明背景
                          // .blockColor('rgba(164, 164, 164, 1.00)')
                          .width('80%')
                          // .width(StyleConstants.FULL_WIDTH)
                          // .height(5)// 固定高度以保持布局稳定
                          .animation({
                            duration: 250,
                            curve: Curve.EaseOut,
                            iterations: 1,
                            playMode: PlayMode.Normal
                          })
                          .onChange((value: number) => {
                            // clearInterval(this.Timer4Theme3ctrl)
                            // this.Timer4Theme3ctrl = setInterval(()=>{
                            //   this.getUIContext().animateTo({
                            //     duration: 300,
                            //     curve: curves.springMotion(0, 0.65),
                            //     // delay: 500,
                            //     // iterations: -1, // 设置-1表示动画无限循环
                            //     playMode: PlayMode.Alternate,
                            //     expectedFrameRateRange: {
                            //       min: 10,
                            //       max: 120,
                            //       expected: 60,
                            //     }
                            //   }, () => {
                            //     this.showSongCtrl4Theme3 = false
                            //
                            //   })
                            // },5000)
                            this.getUIContext()?.animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
                              this.currentTime = value;
                            })
                          })
                          .onTouch((event) => {
                            if (event.type === TouchType.Down) {
                              this.isProgressBarExpanded = true
                            } else if (event.type === TouchType.Up) {
                              this.isProgressBarExpanded = false
                              avPlayerManager.seek(this.currentTime)
                            }
                          })
                        Text(this.formatTime(this.song?.duration || 0))
                          .maxFontSize(12)

                          .minFontSize(4)
                          .maxLines(1)

                          .fontColor($r('sys.color.font'))

                          .height(16) // 固定高度以保持布局稳定
                          .width('10%')
                      }.height(24)
                    }

                  }.layoutWeight(1)
                  .alignItems(this.showSongCtrl4Theme3?HorizontalAlign.Start:HorizontalAlign.Center)

                }
                //控制按钮
                if (this.showSongCtrl4Theme3) {
                  this.playControlWithHeart()
                }
              }
              // .height(this.showSongCtrl4Theme3? 48:24)
              .width(this.showSongCtrl4Theme3? 300:150)
              .margin(16)
              // .backgroundColor('rgba(177, 177, 177, 0.30)')
              // .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
              .backgroundColor('rgba(200, 200, 200, 0.1)')
              .backdropBlur(20)
              .padding(this.showSongCtrl4Theme3 ? 8:4)
              .borderRadius(this.showSongCtrl4Theme3 ? 16:8)
              .onClick(()=>{
                this.getUIContext().animateTo({
                  duration: 300,
                  curve: curves.springMotion(0, 0.65),
                  // delay: 500,
                  // iterations: -1, // 设置-1表示动画无限循环
                  playMode: PlayMode.Alternate,
                  expectedFrameRateRange: {
                    min: 10,
                    max: 120,
                    expected: 60,
                  }
                }, () => {
                  this.showSongCtrl4Theme3 = true
                })
              })
            }.alignContent(Alignment.Top)

          }
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .aspectRatio(this.screenWidth / this.screenHeight)
          .transition(TransitionEffect.OPACITY.animation({
            duration: this.ThemeChoose - 1 === 2 || this.ThemeChoose + 1 === 2 ? 300 : 0,
            curve: curves.springMotion(0, 0.65)
          }).combine(
            TransitionEffect.translate({
              x: this.ThemeChoose - 1 === 2 ? -200 : this.ThemeChoose + 1 === 2 ? 200 : 0,
              y: 0,
              z: 0
            })
          ))

          if (this.themeSetting) {
            Column() {
              // Blank()
            }.width('100%').height('100%').backgroundColor(Color.Transparent).onClick(() => {
              this.getUIContext().animateTo({
                duration: 300,
                curve: curves.springMotion(0, 0.65),
                // delay: 500,
                // iterations: -1, // 设置-1表示动画无限循环
                playMode: PlayMode.Alternate,
                expectedFrameRateRange: {
                  min: 10,
                  max: 120,
                  expected: 60,
                }
              }, () => {
                this.themeSetting = !this.themeSetting
                PreferencesCache.setUserPreference('Playing_HorizontalMode_index', '2')
              })
            })
          }
        }

      }


    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder
  theme4() {
    Column() {
      if (this.themeSetting || this.ThemeChoose === 3) {
        Stack(){
          Column(){
            TextTimer()
              .format('HH:mm:ss')
              // .fontFeature("\"ss01\" off")
              .fontSize(this.FontSize4Theme3)
              .fontFamily('yxs' + this.Font4Theme3)
              .width('100%')
              .layoutWeight(1)
          }
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .aspectRatio(this.screenWidth / this.screenHeight)
          .transition(TransitionEffect.OPACITY.animation({
            duration: this.ThemeChoose - 1 === 3 || this.ThemeChoose + 1 === 3 ? 300 : 0,
            curve: curves.springMotion(0, 0.65)
          }).combine(
            TransitionEffect.translate({
              x: this.ThemeChoose - 1 === 3 ? -200 : this.ThemeChoose + 1 === 3 ? 200 : 0,
              y: 0,
              z: 0
            })
          ))

          if (this.themeSetting) {
            Column() {
              // Blank()
            }.width('100%').height('100%').backgroundColor(Color.Transparent).onClick(() => {
              this.getUIContext().animateTo({
                duration: 300,
                curve: curves.springMotion(0, 0.65),
                // delay: 500,
                // iterations: -1, // 设置-1表示动画无限循环
                playMode: PlayMode.Alternate,
                expectedFrameRateRange: {
                  min: 10,
                  max: 120,
                  expected: 60,
                }
              }, () => {
                this.themeSetting = !this.themeSetting
                PreferencesCache.setUserPreference('Playing_HorizontalMode_index', '3')
              })
            })
          }

        }


      }

    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder
  theme5() {
    Column() {
      if (this.themeSetting || this.ThemeChoose === 4) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Red)
          .aspectRatio(this.screenWidth / this.screenHeight)
          .transition(TransitionEffect.OPACITY.animation({
            duration: this.ThemeChoose - 1 === -1 || this.ThemeChoose + 1 === 4 ? 300 : 0,
            curve: curves.springMotion(0, 0.65)
          }).combine(
            TransitionEffect.translate({
              x: this.ThemeChoose - 1 === -1 ? -200 : this.ThemeChoose + 1 === 4 ? 200 : 0,
              y: 0,
              z: 0
            })
          ))

      }

    }.width('100%').height('100%').justifyContent(FlexAlign.Center)

  }

  @Builder
  titleBar() {
    Stack() {
      Column().height(60).width('100%').backgroundColor('#33000000')
      // .linearGradientBlur(60,
      // { fractionStops: [[0, 0], [0, 0.33], [1, 0.66], [1, 1]], direction: GradientDirection.Top })
      Row() {
        Text(' ')
          .fontSize(24)
        Blank()
        Row({ space: 16 }) {


          Button('󰀍', { type: ButtonType.Circle })
            .backgroundColor(Color.Transparent)
            .fontSize(24)
            .onClick(() => {
              // this.themeSetting =!this.themeSetting
              //
              this.getUIContext().animateTo({
                duration: 300,
                curve: curves.springMotion(0, 0.65),
                // delay: 500,
                // iterations: -1, // 设置-1表示动画无限循环
                playMode: PlayMode.Alternate,
                expectedFrameRateRange: {
                  min: 10,
                  max: 120,
                  expected: 60,
                }
              }, () => {
                this.setting4Theme3 = false
                this.themeSetting = !this.themeSetting

              })

            })

          if (this.ThemeChoose === 2) {
            Button('󰀠', { type: ButtonType.Circle })
              .backgroundColor(Color.Transparent)
              .fontSize(24)
              .onClick(() => {
                this.getUIContext().animateTo({
                  duration: 300,
                  curve: curves.springMotion(0, 0.65),
                  // delay: 500,
                  // iterations: -1, // 设置-1表示动画无限循环
                  playMode: PlayMode.Alternate,
                  expectedFrameRateRange: {
                    min: 10,
                    max: 120,
                    expected: 60,
                  }
                }, () => {
                  this.setting4Theme3 = true
                })
              })
          }

        }

      }.height(60).width('100%').justifyContent(FlexAlign.SpaceBetween).padding(16)
    }

  }

  build() {

    Stack() {
      // Image(cover(this.song?.album?.cover ?? "", 512))
      Swiper(this.swiperController) {

        this.theme1()
        this.theme2()
        this.theme3()
        // this.theme4()
        // this.theme5()

      }
      .onAppear(() => {
        // let ChooseTheme: number = PreferencesUtil.get('ChooseTheme') ?? 0
        let ChooseTheme: number = Number(PreferencesCache.getUserPreference('Playing_HorizontalMode_index', '0'))

        this.swiperController.changeIndex(ChooseTheme)
        this.ThemeChoose = ChooseTheme

      })
      .width('100%')
      .height('100%')
      .itemSpace(this.themeSetting ? 16 : 0)
      .loop(false)
      .nextMargin(this.themeSetting ? 80 : 0)
      .prevMargin(this.themeSetting ? 80 : 0)
      .indicator(this.themeSetting? new DotIndicator().selectedColor('#ffffff') :false)

      .onChange((index: number) => {
        this.ThemeChoose = index
      })
      .gesture(
        PinchGesture({ fingers: 2 }) // 双指捏合手势，用于缩放操作
          .onActionStart((event: GestureEvent) => {
            if (event.scale < 1) {
              this.getUIContext().animateTo({
                duration: 300,
                curve: curves.springMotion(0, 0.65),
                // delay: 500,
                // iterations: -1, // 设置-1表示动画无限循环
                playMode: PlayMode.Alternate,
                expectedFrameRateRange: {
                  min: 10,
                  max: 120,
                  expected: 60,
                }
              }, () => {

                this.themeSetting = !this.themeSetting

              })
            }
          })
      )
      .onClick(() => {
        if (this.showSongCtrl4Theme3) {
          //如果是主题三，则清除定时器，关闭弹窗
          // clearInterval(this.Timer4Theme3ctrl)
          this.getUIContext().animateTo({
            duration: 300,
            curve: curves.springMotion(0, 0.65),
            // delay: 500,
            // iterations: -1, // 设置-1表示动画无限循环
            playMode: PlayMode.Alternate,
            expectedFrameRateRange: {
              min: 10,
              max: 120,
              expected: 60,
            }
          }, () => {
            // this.themeSetting =!this.themeSetting
            this.showSongCtrl4Theme3 = false
          })
        }else {
          clearInterval(this.Timer4showTitleBar)
          if (this.showTitleBar === false) {
            this.getUIContext().animateTo({
              duration: 300,
              curve: curves.springMotion(0, 0.65),
              // delay: 500,
              // iterations: -1, // 设置-1表示动画无限循环
              playMode: PlayMode.Alternate,
              expectedFrameRateRange: {
                min: 10,
                max: 120,
                expected: 60,
              }
            }, () => {
              // this.themeSetting =!this.themeSetting
              this.showTitleBar = true
            })
            this.Timer4showTitleBar = setInterval(() => {
              this.getUIContext().animateTo({
                duration: 300,
                curve: curves.springMotion(0, 0.65),
                // delay: 500,
                // iterations: -1, // 设置-1表示动画无限循环
                playMode: PlayMode.Alternate,
                expectedFrameRateRange: {
                  min: 10,
                  max: 120,
                  expected: 60,
                }
              }, () => {
                // this.themeSetting =!this.themeSetting
                this.showTitleBar = false
                // this.showSetting = true
              })
            }, 3000)

          }else{
            this.getUIContext().animateTo({
              duration: 300,
              curve: curves.springMotion(0, 0.65),
              // delay: 500,
              // iterations: -1, // 设置-1表示动画无限循环
              playMode: PlayMode.Alternate,
              expectedFrameRateRange: {
                min: 10,
                max: 120,
                expected: 60,
              }
            }, () => {
              // this.themeSetting =!this.themeSetting
              this.showTitleBar = false
              // this.showSetting = true
            })
          }
        }


      })
      .backgroundColor(Color.Transparent)
      .effectMode(this.themeSetting ? EdgeEffect.Spring : EdgeEffect.None)
      .onContentWillScroll((result: SwiperContentWillScrollResult) => {
        if (!this.themeSetting) {
          return false;
        }
        return true;
      })

      if (this.showTitleBar && !this.themeSetting &&!this.setting4Theme3) {
        this.titleBar()
      }
    }.alignContent(Alignment.Top).expandSafeArea()

  }
}