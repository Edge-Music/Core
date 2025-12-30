import { Artist, Playlist, Song } from '../type/Adapter'
import { StyleConstants } from "../constants/StyleConstants"
import { AnimationConstants } from "../constants/AnimationConstants"
import { BreakpointConstants } from '../constants/BreakpointConstants'
import { cover } from '../util/AdapterHelper'
import { PlaylistManager } from '../util/PlaylistManager'
import { EventHelper } from '../util/EventHelper'
import { avPlayerManager } from '../util/AVPlayerManager'
import { AppUtil, ClickUtil, LogUtil, ToastUtil } from '@pura/harmony-utils'
import { LyricsView } from '../component/LyricsView'
import { PlaylistView } from '../component/PlaylistView'
import { PreferencesCache } from '../util/PreferenceCache'
import { SourceAdapter } from '../adapter'
import { TimerSelector } from '../component/TimerSelector'
import { isHorizontalMode } from '../util/HorizontalCheck'
import { screen_on } from '../util/On_screen_control'
import { SongDownloadManager } from '../util/SongDownloadManager'
import { hilog } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import ImageUtils from '../util/ImageUtils';
import { curves } from '@kit.ArkUI'
import { PipManager } from '../util/PipManager'
import WindowUtil from '../util/WindowUtil'
import SensorUtil from '../util/SensorUtil'
import { DialogHelper } from '@pura/harmony-dialog'
import { resourceManager } from '@kit.LocalizationKit'
import { LyricsLine } from '../util/LyricsManager'
import { PushPathHelper } from '../util/PushPathHelper'
import { image } from '@kit.ImageKit'
import { effectKit } from '@kit.ArkGraphics2D'
import { BusinessError, deviceInfo, emitter } from '@kit.BasicServicesKit'
import { Event } from '@kit.ArkTS'
import { Playing4Landscape } from '../component/Playing4Landscape'

type ShowLyricsStatus = -1 | 0 | 1 | 2

@Builder
export function PlayingBuilder() {
  Playing()
}
const TAG = 'Playing'
@Component
struct Playing {

  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('decorHeight') decorHeight: number = 0
  @StorageProp('leftCutoutRectWidth') leftCutoutRectWidth: number = 0
  @StorageProp('rightCutoutRectWidth') rightCutoutRectWidth: number = 0
  @StorageProp('windowStatus') windowStatus: string = 'FULL_SCREEN'
  @StorageProp('deviceType') deviceType: resourceManager.DeviceType = resourceManager.DeviceType.DEVICE_TYPE_PHONE
  @StorageProp('current_line_lyrics') currentLineLyrics: LyricsLine | undefined = AppStorage.get<LyricsLine>('current_line_lyrics')
  @Watch('song_change') @StorageLink("current_playing_song") song: Song | null = null
  @StorageLink('Lyic_desktop') Lyic_desktop: string = PreferencesCache.getUserPreference('Lyic_desktop','0')
  @StorageProp('flip_mute') isOnFlipMute: string = PreferencesCache.getUserPreference('flip_mute','0')
  @StorageLink('aggregation_playlist') aggregationPlaylist: Playlist[] = PreferencesCache.getPlaylistCache('aggregation_playlist')
  @StorageProp('test_index') currentLyric: string = ''
  @StorageProp('currentBreakpoint') @Watch('onBreakpointChange') currentBreakpoint: string = 'sm'
  @StorageProp('winWidth') @Watch('onWinWidthChange') winWidth: number = 0
  @StorageProp('winHeight') @Watch('onWinWidthChange') winHeight: number = 0
  @StorageProp('winWidthWithPx') @Watch('onWinWidthChange') winWidthWithPx: number = 0
  @StorageProp('winHeightWithPx') @Watch('onWinWidthChange') winHeightWithPx: number = 0
  @StorageProp('current_width_breakpoint') widthBreakpoint: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('current_height_breakpoint') heightBreakpoint: HeightBreakpoint = HeightBreakpoint.HEIGHT_SM
  @StorageLink('current_playing_playlist') playlist: Array<Song> = [];
  @StorageProp('malv')malv:number = 0
  @StorageProp('playing_title_show_lyrics') showTitleLyrics: string = PreferencesCache.getUserPreference('playing_title_show_lyrics','0')
  @Watch('sys_ColorMode_dark_change')@StorageLink('sys_ColorMode_dark')sys_ColorMode_dark:boolean =false
  @Consume('NavPathStack') pageStack: NavPathStack
  @State curColorIndex: number = 0
  @State currentTime: number = 0
  @State isProgressBarExpanded: boolean = false
  @State isVolumeBarExpanded: boolean = false
  @State selectedTabIndex: number = 0
  @State isPlaying: boolean = true
  @State isFavorite: boolean = false
  @State playMode: number = PlaylistManager.getPlayMode()
  @State showPlaylist: boolean = false
  @State isWideScreen: boolean = false // 是否为宽屏
  @State imageColorHex: string='ff4e061a'
  @State currentIndex: number = -1
  @State swipeOffset: number = 0; // 滑动偏移量
  @State isSwipingActive: boolean = false; // 是否正在滑动中
  @State swipeDirection: string = ''; // 滑动方向
  @State img_playing_ctrl:string=  PreferencesCache.getUserPreference('img_playing_ctrl','0')
  @State isPrevButtonPressed: boolean = false
  @State isPlayButtonPressed: boolean = false
  @State isNextButtonPressed: boolean = false
  @State isShuffleButtonPressed: boolean = false
  @State isListButtonPressed: boolean = false
  @State isHeartButtonPressed: boolean = false
  @State isMoreButtonPressed: boolean = false
  @State isBackButtonPressed: boolean = false
  @State Playing_Next: boolean = true
  @State Fold_judge: boolean = true
  @State is_backblur: boolean = true
  @State rotateAngle: number=0
  @State IMG_ctrl: boolean = true
  @State isSliderVisible: boolean = false
  @State isSliderVisible1: boolean = false
  @State selectedIndex: number = 0
  @State flipCoverLyric: boolean = PreferencesCache.flipCoverLyric()
  @State Pura_X: string = PreferencesCache.getUserPreference('is_Pura_X', '0')//pura_x尝试适配
  @State sheetType: "playlist" | "timer" | "artist" = "playlist" // 用于控制底部弹出表单的类型，默认为播放列表
  @State showLyricType: ShowLyricsStatus = parseInt(PreferencesCache.getUserPreference('playing_title_lyric_show_status', '0')) as ShowLyricsStatus
  @State Color_main: string = '#121234'
  @State Color_sum: string = '#114514'
  @State colum_20: AttributeModifier<ColumnAttribute> | undefined = undefined
  @State UV_background: boolean = false
  @State is_press_long: boolean = false
  // UV 背景颜色更新事件 ID
  private uvColorUpdateEventId: number = 0
  // Ctrl_vision 将在 API 20+ 设备上通过动态导入初始化
  private Ctrl_vision: ESObject = undefined
  private uiContext: UIContext | undefined = undefined;
  private readonly SWIPE_THRESHOLD: number = 80; // 触发切换的阈值
  private timerId: number = -1
  private updateTimer: number = -1
  @State P_X:number =0
  @State netok:boolean =false
  //TAB,swiper控制
  private controller: TabsController = new TabsController()
  private windowStage = AppUtil.getWindowStage()
  // private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Left | PanDirection.Right });
  private resetTimer() {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId)
    }
    this.timerId = setTimeout(() => {
      this.isSliderVisible = false
      this.isSliderVisible1 = false

    }, 3000) // 3秒后隐藏
  }

  /**
   * 动态加载 UV 背景效果 Modifier
   * 仅在 API 20+ 设备上加载，避免在低版本设备上导入 hdsEffect 导致崩溃
   */
  private loadUVBackgroundModifier(): void {
    try {
      this.UV_background = PreferencesCache.getUserPreference('UV_background') === '1'

      LogUtil.info(TAG, `loadUVBackgroundModifier: UV_background=${this.UV_background}, sdkApiVersion=${deviceInfo.sdkApiVersion}`)

      // 仅在 API 20+ 且启用了 UV 背景时才动态加载
      if (deviceInfo.sdkApiVersion > 19 && this.UV_background) {
        LogUtil.info(TAG, `Loading MyButtonModifier module...`)

        import('../modifier/MyButtonModifier').then((module) => {
          LogUtil.info(TAG, `MyButtonModifier module loaded successfully`)

          // 获取颜色更新事件 ID
          this.uvColorUpdateEventId = module.getColorUpdateEventId()
          LogUtil.info(TAG, `Color update event ID: ${this.uvColorUpdateEventId}`)

          // 创建 ShaderEffectController
          this.Ctrl_vision = module.createShaderEffectController()
          LogUtil.info(TAG, `ShaderEffectController created`)

          // 创建 Modifier（只创建一次，后续通过 emitter 更新颜色）
          this.colum_20 = new module.MyButtonModifier(true, this.Ctrl_vision, this.UV_background)
          LogUtil.info(TAG, `MyButtonModifier instance created`)

          // 加载封面图片用于提取颜色
          const coverUrl = cover(this.song?.album?.cover ?? "", 100) as string
          LogUtil.info(TAG, `Loading cover image for color extraction: ${coverUrl}`)
          this.getPicture(coverUrl)
        }).catch((error: Error) => {
          LogUtil.error(TAG, `Failed to load MyButtonModifier: ${error.message}`)
          this.colum_20 = undefined
        })
      } else {
        // API 19 及以下或未启用 UV 背景，不使用 Modifier
        LogUtil.info(TAG, `UV background disabled or API < 20, skipping Modifier`)
        this.colum_20 = undefined
      }
    } catch (e) {
      LogUtil.error(TAG, `loadUVBackgroundModifier error: ${JSON.stringify(e)}`)
      this.colum_20 = undefined
    }
  }

  // 监听屏幕断点变化
  onBreakpointChange() {
    this.isWideScreen = this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM;
    this.Playing_Next = isHorizontalMode()
    console.info('Succeeded in obtaining fold status.judge: ' + this.Playing_Next);
  }

  /**
   * 使用提取的颜色更新 UV 背景效果
   * 通过 emitter 发送颜色更新事件，MyButtonModifier 内部监听并更新
   */
  private updateUVBackgroundColors(): void {
    // 仅在 API 20+ 且启用了 UV 背景且事件 ID 已初始化时更新
    if (deviceInfo.sdkApiVersion > 19 && this.UV_background && this.uvColorUpdateEventId > 0) {
      LogUtil.info(TAG, `Emitting UV background color update: ${this.Color_main}, ${this.Color_sum}`)

      // 构建颜色数组
      const colorArray: Array<ResourceColor> = [this.Color_main, this.Color_sum, $r('app.color.card_background')]

      // 构建事件数据
      const eventData: emitter.EventData = {
        data: {
          colors: colorArray
        }
      }

      // 构建内部事件
      const innerEvent: emitter.InnerEvent = {
        eventId: this.uvColorUpdateEventId,
        priority: emitter.EventPriority.HIGH
      }

      // 发送颜色更新事件
      emitter.emit(innerEvent, eventData)
      LogUtil.info(TAG, `Color update event emitted with eventId: ${this.uvColorUpdateEventId}`)
    } else {
      LogUtil.info(TAG, `Skipping color update: sdkApiVersion=${deviceInfo.sdkApiVersion}, UV_background=${this.UV_background}, eventId=${this.uvColorUpdateEventId}`)
    }
  }

  song_change(){
    if (this.UV_background) {
      this.getPicture(cover(this.song?.album?.cover ?? "", 100) as string )

    }
}
  sys_ColorMode_dark_change(){
    this.getPicture(cover(this.song?.album?.cover ?? "", 100) as string )

  }
  async getPicture(uri:string) {

      http.createHttp()
        .request(uri, (error: BusinessError, data: http.HttpResponse) => {
          if (error) {
            // 下载失败时弹窗提示检查网络，不执行后续逻辑
            console.error(`request failed, ${JSON.stringify(error.message)}`);
            return;
          }
          this.transcodePixelMap(data);
        },
        );


  }
  /**
   * 使用createPixelMap将ArrayBuffer类型的图片装换为PixelMap类型
   * @param data：网络获取到的资源
   */
  transcodePixelMap(data: http.HttpResponse) {
    if (http.ResponseCode.OK === data.responseCode) {
      const imageData: ArrayBuffer = data.result as ArrayBuffer;
      // 通过ArrayBuffer创建图片源实例
      const imageSource: image.ImageSource = image.createImageSource(imageData);
      const options: image.InitializationOptions = {
        'alphaType': 0,
        'editable': false,
        'pixelFormat': 3,
        'scaleMode': 1,
        'size': { height: 100, width: 100 },
      };

      // 通过属性创建PixelMap
      imageSource.createPixelMap(options).then((pixelMap: PixelMap) => {
        effectKit.createColorPicker(pixelMap, (err, colorPicker) => {
          const color = colorPicker.getMainColorSync();
          console.info('get main color =', '{red:', color.red, 'green:', color.green, 'blue:', color.blue, 'alpha:',
            color.alpha, '}'); // 立即输出主色值
          // 获取视觉占比最大值的颜色
          const b = color.blue
          const g = color.green
          const r = color.red
          const a = color.alpha
          let rightColor =
            `#${a.toString(16)}${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16)
              .padStart(2, '0')}`
          this.Color_main = rightColor
          console.info('十六进制数', rightColor)
          const LargestColor = colorPicker.getLargestProportionColor();
          console.info('get largest proportion color =' + '{red:', LargestColor.red, 'green:', LargestColor.green,
            'blue:', LargestColor.blue, 'alpha:', LargestColor.alpha, '}');
          // 获取像素占比最大值的颜色
          const topColors = colorPicker.getTopProportionColors(2);
          for (let index = 0; index < topColors.length; index++) {
            if (topColors[index]) {
              console.info('get top proportion colors: index ' + index + ', color ' + '{red:', topColors[index]?.red,
                'green:', topColors[index]?.green, 'blue:', topColors[index]?.blue, 'alpha:',
                topColors[index]?.alpha, '}');
            }
          }
          // 获取平均色
          const averageColor = colorPicker.getAverageColor();
          console.info('get average color =' + '{red:', averageColor.red, 'green:', averageColor.green, 'blue:',
            averageColor.blue, 'alpha:', averageColor.alpha, '}');
          const b1 = averageColor.blue
          const g1 = averageColor.green
          const r1 = averageColor.red
          const a1 = averageColor.alpha
          let rightColor1 =
            `#${a1.toString(16)}${r1.toString(16).padStart(2, '0')}${g1.toString(16).padStart(2, '0')}${b1.toString(16)
              .padStart(2, '0')}`
          this.Color_sum =rightColor1
          // 获取饱和度最高的颜色
          const highestSatColor = colorPicker.getHighestSaturationColor();
          console.info('get highest SatColor color =', '{red:', highestSatColor.red, 'green:', highestSatColor.green,
            'blue:', highestSatColor.blue, 'alpha:', highestSatColor.alpha, '}');
          const b2 = highestSatColor.blue
          const g2 = highestSatColor.green
          const r2 = highestSatColor.red
          const a2 = highestSatColor.alpha
          let rightColor2 =
            `#${a2.toString(16)}${r2.toString(16).padStart(2, '0')}${g2.toString(16).padStart(2, '0')}${b2.toString(16)
              .padStart(2, '0')}`
          const isNeutral = colorPicker.isBlackOrWhiteOrGrayColor(0xFFFF00FF);
          console.info('isBlackOrWhiteOrGrayColor', isNeutral)

          LogUtil.info(TAG, `Extracted colors: Color_main=${this.Color_main}, Color_sum=${this.Color_sum}`)

          // 使用提取的颜色更新 UV 背景效果
          this.updateUVBackgroundColors()
          this.netok = true

        })
        // this.image = pixelMap;
      });
    }
  }
  @Builder
  progress_Volume(){
    Column(){
      Slider({
        value:  Number(PreferencesCache.getUserPreference('Volume','100')),
        style: SliderStyle.InSet,
        direction: Axis.Vertical,
        reverse: true // 竖向的Slider默认是上端是min值，下端是max值，因此想要从下往上滑动，需要设置reverse为true
      })
        .onTouch((event) => {
          if (event.type === TouchType.Down) {
            this.isVolumeBarExpanded = true
          } else if (event.type === TouchType.Up) {
            this.isVolumeBarExpanded = false
          }
        })
        .onAppear(()=>{
          this.rotateAngle = Number(PreferencesCache.getUserPreference('Volume','100'))
        })
        .trackThickness(this.isVolumeBarExpanded ? 36 : 46)
        .selectedColor(Color.Orange)
        .trackColor('rgba(255, 255, 255, 0.3)')
        .blockColor(Color.Orange)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.resetTimer()
          avPlayerManager.avPlayer?.setVolume(value/100)
          PreferencesCache.setUserPreference('Volume', value.toString())
          console.info('value:' + value + 'mode:' + mode.toString())
          this.uiContext?.animateTo({
            duration: AnimationConstants.DURATION_FAST,
            curve: AnimationConstants.CURVE_DECELERATE
          }, () => {
            this.rotateAngle = value
          })
        })
        .animation({
          duration: AnimationConstants.DURATION_FAST,
          curve: AnimationConstants.CURVE_DECELERATE,
          iterations: 1,
          playMode: PlayMode.Normal
        })

      if(this.rotateAngle === 0){
        SymbolGlyph($r('sys.symbol.speaker_slash'))
          .fontSize(20)
      } else if(this.rotateAngle > 0 && this.rotateAngle <= 33) {
        SymbolGlyph($r('sys.symbol.speaker_wave_1'))
          .fontSize(20)
      } else if(this.rotateAngle > 33 && this.rotateAngle <= 66) {
        SymbolGlyph($r('sys.symbol.speaker_wave_2'))
          .fontSize(20)
      } else if(this.rotateAngle > 66 && this.rotateAngle <= 100) {
        SymbolGlyph($r('sys.symbol.speaker_wave_3'))
          .fontSize(20)
      }
    }
    .width(36)
    .justifyContent(FlexAlign.Center)
    .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: curves.interpolatingSpring(0, 1, 324, 38) }).combine(
      // TransitionEffect.rotate({x:20, z: 1, angle: 0 })
      TransitionEffect.translate({ x: 20, y: 0, z: 0 })
    ))
  }
  @Builder
  playing_50(){
    Stack(){
      Stack(){
        Image(cover(this.song?.album?.cover ?? "", this.winWidth))
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)

        Column(){
          this.Title(true)

          Tabs({ barPosition: BarPosition.End, index: this.selectedTabIndex, controller: this.controller }){
            TabContent(){
              Column(){
                Column({ space: 4 }){
                  Text(this.currentLineLyrics?.text)
                    .fontSize(20)
                    .fontWeight(700)
                    .fontColor(Color.White)
                    .textAlign(TextAlign.Center)
                    .borderRadius(8)

                  Text(this.currentLineLyrics?.translation)
                    .fontSize(16)
                    .opacity(0.9)
                    .borderRadius(8)
                    .fontColor(Color.White)
                    .textAlign(TextAlign.Center)
                    .fontWeight(FontWeight.Normal)
                    .visibility(this.currentLineLyrics?.translation && this.winWidthWithPx/this.winHeightWithPx <= 1.01 ? Visibility.Visible : Visibility.None)

                  Text(this.currentLineLyrics?.transliteration)
                    .fontSize(16)
                    .opacity(0.9)
                    .borderRadius(8)
                    .fontColor(Color.White)
                    .textAlign(TextAlign.Center)
                    .fontWeight(FontWeight.Normal)
                    .visibility(this.currentLineLyrics?.transliteration && this.winWidthWithPx/this.winHeightWithPx <= 1.01 ? Visibility.Visible : Visibility.None)
                }
                .padding(16)
                .height('40%')
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .width(StyleConstants.FULL_WIDTH)

                Column(){
                  this.ProgressBar(true)
                }
                Column(){
                  this.PlayerControls(true)
                }

                Blank()
                  .height(this.bottomRect/2)
              }
              .width(StyleConstants.FULL_WIDTH)
              .height(StyleConstants.FULL_HEIGHT)
              .justifyContent(FlexAlign.SpaceBetween)
              .visibility(this.IMG_ctrl ? Visibility.Visible : Visibility.None)
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)

            TabContent(){
              Column(){
                LyricsView({ mode_judge: false })
                  .width('100%')
                  .layoutWeight(1)
              }
            }
          }
          .width('100%')
          .scrollable(true)
          .barMode(BarMode.Fixed)
          .layoutWeight(1)
          .clip(false)
          .barHeight(0)
          .onChange((index: number) => {
            this.uiContext?.animateTo({
              duration: AnimationConstants.DURATION_SLOW,
              curve: AnimationConstants.CURVE_DECELERATE
            }, () => {
              this.selectedTabIndex = index
            })
          })

        }
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .linearGradient({
          angle: 180,
          colors: [['rgba(0, 0, 0, 0.50)', 0.0], ['rgba(0, 0, 0, 0.20)', 0.5], ['rgba(0, 0, 0, 0.50)', 1.0]]
        })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignContent(Alignment.Center)
    .alignSelf(ItemAlign.Center)

  }
  @Builder
  playing_30(){
    Stack(){
      Stack(){
        Image(cover(this.song?.album?.cover ?? "", this.winWidth))
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)

        Column()
          .width(StyleConstants.FULL_WIDTH)
          .height(StyleConstants.FULL_HEIGHT)
          .linearGradient({
            angle: 180,
            colors: [['rgba(0, 0, 0, 0.50)', 0.0], ['rgba(0, 0, 0, 0.20)', 0.5], ['rgba(0, 0, 0, 0.50)', 1.0]]
          })
      }
      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)

      Column(){
        this.Title(true)

        Tabs({ barPosition: BarPosition.End, index: this.selectedTabIndex, controller: this.controller }){
          TabContent(){
            Column(){
              Column(){
                Text(this.currentLyric)
                  .fontSize(20)
                  .fontWeight(700)
                  .fontColor(Color.White)
                  .textAlign(TextAlign.Center)
                  .borderRadius(8)
                  .animation({
                    duration: 500,
                    curve: Curve.FastOutSlowIn
                  })
              }
              .padding(16)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .width(StyleConstants.FULL_WIDTH)
              .layoutWeight(1)

              this.ProgressBar(true)
              this.PlayerControls(true)

              Blank()
                .height(this.bottomRect/2)
            }
            .width('100%')
          }
          TabContent(){
            Column(){
              LyricsView({
                mode_judge: false,
              }).width('100%').layoutWeight(1)
            }}
        }
        .layoutWeight(1)
        .width('100%')
        .scrollable(true)
        .barMode(BarMode.Fixed)
        .clip(false)
        .barHeight(0)
        .onChange((index: number) => {
          this.uiContext?.animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
            this.selectedTabIndex = index
          })
        })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignContent(Alignment.Center)
    .alignSelf(ItemAlign.Center)
  }
  @Builder
  PlayListBuilder() {
    Column() {
      PlaylistView()
    }
    .height(StyleConstants.FULL_HEIGHT)
    .layoutWeight(1)
    .transition({ type: TransitionType.Insert, scale: { y: 0.8, x: 1.0 }, opacity: 0.0 })
    .transition({ type: TransitionType.Delete, scale: { y: 0.8, x: 1.0 }, opacity: 0.0 })
  }

  @Builder
  Timer() {
    Column() {
      Text($r('app.string.scheduled_shutdown'))
        .fontSize(18)
        .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
        .fontColor($r('app.color.text_title'))
        .margin({ left: 36, top: 16, bottom: 16 })
        .width(StyleConstants.FULL_WIDTH)
        .textAlign(TextAlign.Start)
        TimerSelector()
    }
    .height(StyleConstants.FULL_HEIGHT)
    .layoutWeight(1)
    .transition({ type: TransitionType.Insert, scale: { y: 0.8, x: 1.0 }, opacity: 0.0 })
    .transition({ type: TransitionType.Delete, scale: { y: 0.8, x: 1.0 }, opacity: 0.0 })
  }
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
  @Builder
  //————————————————————————
  // 函数名：Playing_HorizontalMode()
  // 参数：null
  // 功能：手机横屏播放器
  //——————————————————————————
  Playing_HorizontalMode() {
    Column(){
      Playing4Landscape({
        song:this.song,
        isPlaying:this.isPlaying,
        bottomRect:this.bottomRect,
        paramCurrentTime:this.currentTime,
        OneSentence:this.currentLyric,
        playControl: () => {
          this.PlayerControls()
        },
        playControlWithHeart: () => {
          this.PlayerControlsWithHeart()
        },
        songPlay:()=>{
          avPlayerManager.play()
        },
        songPause:()=>{
          avPlayerManager.pause()
        },
        songNext:()=>{
          this.handleSongChange('next')
        },
        songPrev:()=>{
          this.handleSongChange('prev')
        }
      })

    }
    .onAppear(() => {
      screen_on(this.getUIContext().getHostContext() as Context, true)
    })
    .onDisAppear(() => {
      screen_on(this.getUIContext().getHostContext() as Context, false)
    })

  }

  async aboutToAppear() {
    const player = await avPlayerManager.getAVPlayerInstance()
    this.Playing_Next = isHorizontalMode()
    // 初始化当前时间和持续时间
    this.currentTime = player.currentTime
    this.isPlaying = player.state === 'playing'

    this.isFavorite = this.song?.meta?.isFavorite || false
    this.uiContext = this.getUIContext();

    // 初始化宽屏检测
    this.isWideScreen = this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM;

    // 播放位置更新计时器
    this.updateTimer = setInterval(() => {
      if (this.isPlaying && this.currentTime <= (this.song?.duration || 0)) {
        this.currentTime = player.currentTime;
      }
    }, 300)
    // 初始化监听
    EventHelper.subscribeLoopMode((mode: number) => {
      this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
        this.playMode = mode;
        this.isShuffleButtonPressed = true;
        setTimeout(() => {
          this.isShuffleButtonPressed = false;
        }, 300);
      })
    })

    EventHelper.subscribeSongState((state: "PLAY" | "PAUSE") => {
      this.uiContext?.animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
        this.isPlaying = state === "PLAY";
      })
    })

    EventHelper.subscribeFavoriteToggle(() => {
      this.uiContext?.animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
        this.isFavorite = !this.isFavorite;
      })
    })

    EventHelper.subscribePlaySong(() => {
      // 当歌曲改变时，更新当前时间和歌词
      this.isFavorite = this.song?.meta?.isFavorite || false
      this.currentTime = 0
    })

    // 添加事件监听
    avPlayerManager.addListener('onPlay', () => {
      this.isPlaying = true;
    });

    avPlayerManager.addListener('onPause', () => {
      this.isPlaying = false;
    });
    if(this.winWidth > this.winHeight){
      WindowUtil.setSystemBarEnabled(this.windowStage, false)
    }else{
      WindowUtil.setSystemBarEnabled(this.windowStage, true)
    }
    WindowUtil.setWindowScreenOn(this.windowStage, true)

    LogUtil.info(`${TAG}`, `this.isOnFlipMute: ${this.isOnFlipMute}`)
    if(this.isOnFlipMute === '1'){
      SensorUtil.onAccelerometer()
    }
  }

  aboutToDisappear() {
    WindowUtil.setSystemBarEnabled(this.windowStage, true)
    WindowUtil.setWindowScreenOn(this.windowStage, false)
    if(this.isOnFlipMute === '1'){
      SensorUtil.offAccelerometer()
    }
    if (this.updateTimer !== -1) {
      clearInterval(this.updateTimer)
      this.updateTimer = -1
    }
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

  getFontSize(text: string, baseSize = 18, maxLength = 36): number {
    if (!text) {
      return baseSize
    }
    if (text.length <= maxLength) {
      return baseSize
    }
    return Math.max(12, baseSize * maxLength / text.length)
  }

  calculateCurrentIndex(offset: number) {
    offset = Math.abs(offset)
    if (offset < 32) {
      return -1
    }
    return 0
  }

  onMenuIconClick(index: number) {
    if (index === 0 && this.pageStack.size() > 1) {
      this.pageStack.pop()
    }
  }

  @Builder
  BlurBackground(judge:boolean = true) {
    Stack() {
      // 背景图片 - 第一层（使用超强模糊）
      Image(cover(this.song?.album?.cover ?? "", 512))
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .objectFit(ImageFit.Cover)
        .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK)
        .opacity(0.4)

      // 毛玻璃效果层 - 使用 backgroundEffect 增强质感
      Column()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .backgroundEffect({
          radius: 60,
          saturation: 1.3,
          brightness: 0.9
        })
        .backgroundColor('rgba(0, 0, 0, 0.2)')

      // 渐变遮罩层 - 增强视觉层次和对比度
      Column()
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
        .linearGradient({
          angle: 180,
          colors: [['rgba(0, 0, 0, 0.60)', 0.0], ['rgba(0, 0, 0, 0.30)', 0.5], ['rgba(0, 0, 0, 0.60)', 1.0]]
        })
    }
    .width(judge?StyleConstants.FULL_WIDTH:0)
    .height(judge?StyleConstants.FULL_HEIGHT:0)
    .position({ x: 0, y: 0 })
  }

  @Builder
  ProgressBar(judge: boolean = true, weight: number = 0, judge_time_area: boolean = true) {
    Column() {
      if (judge && judge_time_area){
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
        .trackThickness(this.isProgressBarExpanded ? 12+weight : 8+weight)
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
          this.uiContext?.animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
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
      if (judge && judge_time_area === false){
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

  private buttonSize = 48
  private smallButtonSize = 36

  @Builder
  PlayerControls(judge: boolean = true) {
    Row() {
      // Shuffle/repeat button (Left)
      if(judge){ Button({ type: ButtonType.Circle }) {
        Image(this.getPlayModeResource(this.playMode))
          .width(22)
          .height(22)
          .fillColor(Color.White)
          .animation({
            duration: 300,
            curve: Curve.EaseOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
      }
      .width(this.smallButtonSize)
      .height(this.smallButtonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isShuffleButtonPressed ? 1.3 : 1.0, y: this.isShuffleButtonPressed ? 1.3 : 1.0 })
      .animation({
        duration: 300,
        curve: Curve.EaseOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onClick(() => {
        this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
          this.isShuffleButtonPressed = true
          PlaylistManager.switchPlayMode();
          setTimeout(() => {
            this.isShuffleButtonPressed = false
          }, 300)
        })
      })}



      // Previous button
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_prev'))
          .width(28)
          .height(28)
          .fillColor(Color.White)
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isPrevButtonPressed ? 0.85 : 1.0, y: this.isPrevButtonPressed ? 0.85 : 1.0 })
      .opacity(this.isPrevButtonPressed ? 0.8 : 1.0)
      .animation({
        duration: 150,
        curve: Curve.EaseIn,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          this.isPrevButtonPressed = true
        } else if (event.type === TouchType.Up) {
          this.isPrevButtonPressed = false
        }
      })
      .onClick(() => {
        ClickUtil.debounce(async () => {
          this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            const prevSong = PlaylistManager.playPrevious()
            if (prevSong) {
              PlaylistManager.playSong(prevSong)
            }
          })
        }, 500, "playPrev")
      })

      // Play/pause button (center)
      Button({ type: ButtonType.Circle }) {
        Image(this.isPlaying ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
          .width(this.isPlaying ? 36 : 32)
          .height(this.isPlaying ? 36 : 32)
          .fillColor(Color.White)
          .margin({
            left: this.isPlaying ? 0 : 4
          })
      }
      .backgroundColor(this.isPlayButtonPressed ? 'rgba(255, 255, 255, 0.2)' : Color.Transparent)
      .width(this.buttonSize + 6)
      .height(this.buttonSize + 6)
      .scale({ x: this.isPlayButtonPressed ? 0.9 : 1.0, y: this.isPlayButtonPressed ? 0.9 : 1.0 })
      .shadow({
        radius: this.isPlaying ? 24 : 0,
        color: this.isPlaying ? 'rgba(255, 255, 255, 0.30)' : 'transparent',
        offsetX: 0,
        offsetY: 0
      })
      .animation({
        duration: 200,
        tempo: 1.0,
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal,
      })
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          this.isPlayButtonPressed = true
        } else if (event.type === TouchType.Up) {
          this.isPlayButtonPressed = false
        }
      })
      .onClick(() => {
        this.isPlaying = !this.isPlaying
        if (this.isPlaying) {
          avPlayerManager.play()
        } else {
          avPlayerManager.pause()
        }
      })

      // Next button
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_next'))
          .width(28)
          .height(28)
          .fillColor(Color.White)
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isNextButtonPressed ? 0.85 : 1.0, y: this.isNextButtonPressed ? 0.85 : 1.0 })
      .opacity(this.isNextButtonPressed ? 0.8 : 1.0)
      .animation({
        duration: 150,
        curve: Curve.EaseIn,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          this.isNextButtonPressed = true
        } else if (event.type === TouchType.Up) {
          this.isNextButtonPressed = false
        }
      })
      .onClick(() => {
        ClickUtil.debounce(async () => {
          this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {

            const nextSong = PlaylistManager.playNext()
            if (nextSong) {
              PlaylistManager.playSong(nextSong)
            }
          })
        }, 500, "playNext")
      })
      // Playlist button (Right)
      if (judge){
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_list'))
            .width(22)
            .height(22)
            .fillColor(Color.White)
      }
      .width(this.smallButtonSize)
      .height(this.smallButtonSize)
      .backgroundColor(Color.Transparent)
      .translate({ x: this.isListButtonPressed ? 5 : 0, y: this.isListButtonPressed ? -5 : 0 })
      .scale({ x: this.isListButtonPressed ? 1.3 : 1.0, y: this.isListButtonPressed ? 1.3 : 1.0 })
      .animation({
        duration: 200,
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onClick(() => {
        this.isListButtonPressed = true
        this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
          this.sheetType = "playlist"; // 设置当前类型为播放列表
          this.showPlaylist = true;
          setTimeout(() => {
            this.isListButtonPressed = false
          }, 300)
        })
      })
      }
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.SpaceBetween) // Space between all buttons
    .alignItems(VerticalAlign.Center)
    .height(70) // Fixed height
  }

  @Builder
  PlayerControlsWithHeart(judge: boolean = true) {
    Row() {
      // Shuffle/repeat button (Left)
      if(judge){ Button({ type: ButtonType.Circle }) {
        Image(this.getPlayModeResource(this.playMode))
          .width(22)
          .height(22)
          .fillColor(Color.White)
          .animation({
            duration: 300,
            curve: Curve.EaseOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
      }
      .width(this.smallButtonSize)
      .height(this.smallButtonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isShuffleButtonPressed ? 1.3 : 1.0, y: this.isShuffleButtonPressed ? 1.3 : 1.0 })
      .animation({
        duration: 300,
        curve: Curve.EaseOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onClick(() => {
        this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
          this.isShuffleButtonPressed = true
          PlaylistManager.switchPlayMode();
          setTimeout(() => {
            this.isShuffleButtonPressed = false
          }, 300)
        })
      })}



      // Previous button
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_prev'))
          .width(22)
          .height(22)
          .fillColor(Color.White)
      }
      .width(this.smallButtonSize)
      .height(this.smallButtonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isPrevButtonPressed ? 0.85 : 1.0, y: this.isPrevButtonPressed ? 0.85 : 1.0 })
      .opacity(this.isPrevButtonPressed ? 0.8 : 1.0)
      .animation({
        duration: 150,
        curve: Curve.EaseIn,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          this.isPrevButtonPressed = true
        } else if (event.type === TouchType.Up) {
          this.isPrevButtonPressed = false
        }
      })
      .onClick(() => {
        ClickUtil.debounce(async () => {
          this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            const prevSong = PlaylistManager.playPrevious()
            if (prevSong) {
              PlaylistManager.playSong(prevSong)
            }
          })
        }, 500, "playPrev")
      })

      // Play/pause button (center)
      Button({ type: ButtonType.Circle }) {
        Image(this.isPlaying ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
          .width(22)
          .height(22)
          .fillColor(Color.White)
          .margin({
            left: this.isPlaying ? 0 : 4
          })
      }
      .backgroundColor(Color.Transparent)
      .width(this.smallButtonSize)
      .height(this.smallButtonSize)
      .scale({ x: this.isPlayButtonPressed ? 0.9 : 1.0, y: this.isPlayButtonPressed ? 0.9 : 1.0 })
      .animation({
        duration: 200,
        tempo: 1.0,
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal,
      })
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          this.isPlayButtonPressed = true
        } else if (event.type === TouchType.Up) {
          this.isPlayButtonPressed = false
        }
      })
      .onClick(() => {
        this.isPlaying = !this.isPlaying
        if (this.isPlaying) {
          avPlayerManager.play()
        } else {
          avPlayerManager.pause()
        }
      })

      // Next button
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_next'))
          .width(22)
          .height(22)
          .fillColor(Color.White)
      }
      .width(this.smallButtonSize)
      .height(this.smallButtonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isNextButtonPressed ? 0.85 : 1.0, y: this.isNextButtonPressed ? 0.85 : 1.0 })
      .opacity(this.isNextButtonPressed ? 0.8 : 1.0)
      .animation({
        duration: 150,
        curve: Curve.EaseIn,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          this.isNextButtonPressed = true
        } else if (event.type === TouchType.Up) {
          this.isNextButtonPressed = false
        }
      })
      .onClick(() => {
        ClickUtil.debounce(async () => {
          this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {

            const nextSong = PlaylistManager.playNext()
            if (nextSong) {
              PlaylistManager.playSong(nextSong)
            }
          })
        }, 500, "playNext")
      })
      // Playlist button (Right)
      Button({ type: ButtonType.Circle }) {
        Image(this.isFavorite ? $r('app.media.ic_heart_fill') : $r('app.media.ic_heart'))
          .width(22)
          .height(22)
          .fillColor(this.isFavorite ? '#FF4081' : Color.White)
          .animation({
            duration: 300,
            curve: Curve.EaseOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
      }
      .width(this.smallButtonSize)
      .height(this.smallButtonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isHeartButtonPressed ? 1.3 : 1.0, y: this.isHeartButtonPressed ? 1.3 : 1.0 })
      .animation({
        duration: 300,
        curve: Curve.EaseOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onClick(() => {
        this.isHeartButtonPressed = true
        this.uiContext?.animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
          if (this.song) {
            SourceAdapter.likeSong(this.song, !this.isFavorite)
          }
          EventHelper.postFavoriteToggle("")

          // 重置按钮状态
          setTimeout(() => {
            this.isHeartButtonPressed = false
          }, 400)
        })
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .padding({ top: 16 })
    .justifyContent(FlexAlign.SpaceBetween) // Space between all buttons
    .alignItems(VerticalAlign.Center)
  }

  // 下载歌曲
  async downloadSong() {
    if (this.song) {
      const success = SongDownloadManager.downloadSong(
        this.song.id.toString(),
        this.song
      );
      if (success) {
        ToastUtil.showShort($r('app.string.added_to_the_download_queue'));
      }
    }
  }

  getWideScreenMenu(): MenuElement[] {
    return [
      {
        value: '布局翻转',
        action: () => {
          this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.flipCoverLyric = !this.flipCoverLyric
            PreferencesCache.flipCoverLyric(this.flipCoverLyric)
          })
        }
      },
      {
        value: $r('app.string.download_this_song'),
        action: () => {
          this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.downloadSong()
          })
        }
      },
      {
        value: $r('app.string.scheduled_shutdown'),
        action: () => {
          this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.sheetType = "timer";
            this.showPlaylist = true;
          })
        }
      },
      {
        value: $r('app.string.add_to_playlist'),
        action: () => {
          DialogHelper.showSelectDialog({
            title: $r('app.string.add_to_playlist'),
            confirm: $r('app.string.back'),
            selectedIndex: -1,
            radioContent: this.aggregationPlaylist.map(playlist => playlist?.name),
            onCheckedChanged: (index) => {
              this.selectedIndex = index
              PreferencesCache.addSongToAggregationPlaylist(this.aggregationPlaylist[this.selectedIndex], this.song!).then((result: boolean) => {
                if(result){
                  ToastUtil.showShort(`[${this.song?.name}]存在于[${this.aggregationPlaylist[index].name}]`)
                }else{
                  ToastUtil.showShort(`[${this.song?.name}]添加到[${this.aggregationPlaylist[index].name}]`)
                }
              })
            },
            onAction: (): void => {}
          })
        }
      }
    ]
  }

  getNarrowScreenMenu(): MenuElement[] {
    return [
      {
        value: $r('app.string.download_this_song'),
        action: () => {
          this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.downloadSong()
          })
        }
      },
      {
        value: $r('app.string.scheduled_shutdown'),
        action: () => {
          this.uiContext?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.sheetType = "timer";
            this.showPlaylist = true;
          })
        }
      },
      {
        value: $r('app.string.add_to_playlist'),
        action: () => {
          DialogHelper.showSelectDialog({
            title: $r('app.string.add_to_playlist'),
            confirm: $r('app.string.back'),
            selectedIndex: -1,
            radioContent: this.aggregationPlaylist.map(playlist => playlist?.name),
            onCheckedChanged: (index) => {
              this.selectedIndex = index
              PreferencesCache.addSongToAggregationPlaylist(this.aggregationPlaylist[this.selectedIndex], this.song!).then((result: boolean) => {
                if(result){
                  ToastUtil.showShort(`[${this.song?.name}]存在于[${this.aggregationPlaylist[index].name}]`)
                }else{
                  ToastUtil.showShort(`[${this.song?.name}]添加到[${this.aggregationPlaylist[index].name}]`)
                }
              })
            },
            onAction: (): void => {}
          })
        }
      }
    ]
  }

  @Builder
  BottomControls() {
    Row() {
      // 红心点赞按钮
      Button({ type: ButtonType.Circle }) {
        Image(this.isFavorite ? $r('app.media.ic_heart_fill') : $r('app.media.ic_heart'))
          .width(24)
          .height(24)
          .fillColor(this.isFavorite ? '#FF4081' : Color.White)
          .animation({
            duration: 300,
            curve: Curve.EaseOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .backgroundColor(Color.Transparent)
      .scale({ x: this.isHeartButtonPressed ? 1.3 : 1.0, y: this.isHeartButtonPressed ? 1.3 : 1.0 })
      .animation({
        duration: 300,
        curve: Curve.EaseOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onClick(() => {
        this.isHeartButtonPressed = true
        this.uiContext?.animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
          if (this.song) {
            SourceAdapter.likeSong(this.song, !this.isFavorite)
          }
          EventHelper.postFavoriteToggle("")

          // 重置按钮状态
          setTimeout(() => {
            this.isHeartButtonPressed = false
          }, 400)
        })
      })

      // 更多菜单按钮
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_more'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .backgroundColor(Color.Transparent)
      .rotate({ angle: this.isMoreButtonPressed ? 90 : 0 })
      .animation({
        duration: 300,
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
      .onClick(() => {
        this.isMoreButtonPressed = true

        // 重置按钮状态
        setTimeout(() => {
          this.isMoreButtonPressed = false
        }, 300)
      })
      .bindMenu(this.isWideScreen ? this.getWideScreenMenu() : this.getNarrowScreenMenu())
    }
    .width(StyleConstants.FULL_WIDTH)
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 8, right: 8, top: 16 })
    .height(64) // 固定高度保持布局稳定
  }

  getPlayModeResource(playMode: number) {
    switch (playMode) {
      case 0:
        return $r('app.media.ic_order_play')
      case 3:
        return $r('app.media.ic_shuffle')
      case 2:
        return $r('app.media.ic_repeat')
      case 1:
        return $r('app.media.ic_repeat_1')
      default:
        return $r('app.media.ic_order_play')
    }
  }

  @Builder
  LyricsPlaceholder() {
    Column() {
      LyricsView({
        mode_judge: true
      })
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .transition({ type: TransitionType.All, opacity: 0.0, translate: { y: 20 } })
  }

  @Builder
  PlayingContent() {
    Column() {
      // 封面图
      Row(){
        Column(){
          Column(){
            if (this.isSliderVisible){
              this.progress_Volume()
            }
          }
          .height(150)
          .width(46)
        }
        .height('100%')
        .width(46)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .gesture(
          // 绑定count为2的TapGesture
          TapGesture({ count: 2 })
            .onAction((event: GestureEvent|undefined) => {
              if(event){
                this.isSliderVisible1 = false
                this.isSliderVisible = true
                this.resetTimer() // 显示时启动定时器
              }
            }))

        Column(){
          Image(cover(this.song?.album?.cover ?? "", 512))
            // .width(this.coverWidth.getValue(this.currentBreakpoint))
            .aspectRatio(1)
            .borderRadius(24)
              // .geometryTransition("picture", { follow: false })
            .transition(TransitionEffect.OPACITY)
              // .geometryTransition('song-cover', { follow: true })
            .transition(TransitionEffect.OPACITY)
            .onClick(() => {
              if (!this.isWideScreen) {
                this.controller.changeIndex(1)
              }
            }) //点击图片切换到歌词页面

            .borderRadius(this.img_playing_ctrl==='1'?0:24)
            .gesture(
              PanGesture({ direction: PanDirection.Horizontal })
                .onActionStart(() => {
                  this.isSwipingActive = true;
                })
                .onActionUpdate((event) => {
                  // 更新滑动偏移量
                  this.swipeOffset = event.offsetX;

                  // 确定滑动方向
                  if (event.offsetX > 10 &&this.img_playing_ctrl==='1') {
                    this.swipeDirection = 'right'; // 向右滑动，上一首
                  } else if (event.offsetX < -10) {
                    this.swipeDirection = 'left'; // 向左滑动，下一首
                  } else {
                    this.swipeDirection = '';
                  }
                })
                .onActionEnd(() => {
                  // 根据最终偏移量决定是切换歌曲还是回弹
                  if (this.swipeOffset > this.SWIPE_THRESHOLD &&this.img_playing_ctrl==='1') {
                    // 向右滑动超过阈值，切换到上一首
                    this.handleSongChange('prev');
                  } else if (this.swipeOffset < -this.SWIPE_THRESHOLD&&this.img_playing_ctrl==='1') {
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
            .borderImage({
              source: {
                angle: 90,
                direction: GradientDirection.Left,
                colors: [[0xAEE1E1, 0.0], [0xD3E0DC, 0.3], [0xFCD1D1, 1.0]]
              },
              slice: { top: this.img_playing_ctrl==='1'?10:0, bottom: this.img_playing_ctrl==='1'?10:0, left: this.img_playing_ctrl==='1'?10:0, right: this.img_playing_ctrl==='1'?10:0 },
              width: { top:this.img_playing_ctrl==='1'? "10px":"0px", bottom: this.img_playing_ctrl==='1'? "10px":"0px", left: this.img_playing_ctrl==='1'? "10px":"0px", right: this.img_playing_ctrl==='1'? "10px":"0px" },
              repeat: RepeatMode.Stretch,
              fill: false
            })
        }
        .layoutWeight(1)
        .clickEffect({ level: ClickEffectLevel.LIGHT })

        Column(){
          Column(){
            if (this.isSliderVisible1){
              this.progress_Volume()
            }
          }
          .height(150)
          .width(46)
        }
        .width(46)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .gesture(
          // 绑定count为2的TapGesture
          TapGesture({ count: 2 })
            .onAction((event: GestureEvent|undefined) => {
              if(event){
                // animateTo()
                this.isSliderVisible = false
                this.isSliderVisible1 = true
                this.resetTimer() // 显示时启动定时器
              }
            }))
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .layoutWeight(4)

      Blank()

      // 歌曲信息
      Column({ space: 4 }) {
        Text(this.song?.name || "未知歌曲")
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .fontColor(Color.White)
          .height(32) // 固定高度确保布局稳定

        Text(this.song?.artists ? this.song.artists.map(artist => artist.name).join(" / ") : "未知艺术家")
          .fontSize(16)
          .fontColor('rgba(255, 255, 255, 0.6)')
          .maxLines(1)
          .width(250)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .height(24) // 固定高度确保布局稳定
          .onClick(() => {
            if (this.song?.artists && this.song.artists.length > 0) {
              this.sheetType = "artist";
              this.showPlaylist = true;
            }
          })
      }
      .width(StyleConstants.FULL_WIDTH)
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 16, bottom: 4 })
      .padding({ left: 12, right: 12 })
      .layoutWeight(1)
      .height(60) // 固定整个信息区的高度

      Blank()

      // 进度条
      Column(){
        this.ProgressBar(true)
      }
      .layoutWeight(1)

      // 底部控件 - 使用Blank占据空间，将控件推到底部
      Blank()

      // 播放控制区
      Column(){
        this.PlayerControls()
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)

      // 底部控件 - 使用Blank占据空间，将控件推到底部
      Blank()

      // 底部控件
      Column() {
        this.BottomControls()
      }

      Blank()
      // 底部避让
      Blank().height(this.bottomRect/2)
    }
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  sheet() {
    // 根据当前的sheetType渲染不同的内容
    if (this.sheetType === "playlist") {
      this.PlayListBuilder()
    } else if (this.sheetType === "timer") {
      this.Timer()
    } else if (this.sheetType === "artist") {
      this.ArtistSheet()
    }
  }

  @Builder
  ArtistSheet() {
    Column({ space: 16 }) {
      // 弹窗标题
      Row() {
        Text($r("app.string.artist"))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_title'))

        Blank()

        Button() {
          Image($r('app.media.ic_close'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.text_secondary'))
        }
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showPlaylist = false;
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 })

      // 艺术家列表
      if (this.song?.artists && this.song.artists.length > 0) {
        List({ space: 8 }) {
          ForEach(this.song.artists, (artist: Artist) => {
            ListItem() {
              Row({ space: 16 }) {
                // 艺术家信息
                Column({ space: 6 }) {
                  Text(artist.name || '未知艺术家')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_title'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                // 箭头图标
                Image($r('app.media.ic_chevron_right'))
                  .width(16)
                  .height(16)
                  .fillColor($r('app.color.text_hint'))
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 16, bottom: 16 })
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
              .border({
                width: 0.5,
                color: $r('app.color.border_line'),
                style: BorderStyle.Solid
              })
              .onClick(() => {
                this.showPlaylist = false;
                this.navigateToArtist(artist);
              })
              .clickEffect({ level: ClickEffectLevel.LIGHT })
              .stateStyles({
                pressed: {
                  .backgroundColor($r('app.color.setting_item_background'))
                  .scale({ x: 0.98, y: 0.98 })
                },
                normal: {
                  .backgroundColor($r('app.color.card_background'))
                  .scale({ x: 1, y: 1 })
                }
              })
              .animation({
                duration: 150,
                curve: Curve.EaseInOut
              })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      } else {
        // 无艺术家信息的提示
        Column({ space: 8 }) {

          Text('暂无艺术家信息')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
      }

      // 底部安全区域
      Row()
        .height(this.bottomRect)
        .width('100%')
    }
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  @Builder
  Title(judge: boolean = false) {
    Column(){
      // PC工具栏适配
      Row()
        .height(this.topRect > this.decorHeight ? this.topRect : this.decorHeight)
        .backgroundColor('transparent')
        .width('100%')

      Row() {
        if (judge || this.selectedTabIndex === 1){
          Row({ space: 4 }) {
            Image(cover(this.song?.album?.cover ?? "", 512))
              .height(34)
              .aspectRatio(1)
              .borderRadius(4)
              .shadow(ShadowStyle.OUTER_DEFAULT_SM)

            Column({ space: 4 }) {
              Text(this.song?.name || "未知歌曲")
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .fontColor(Color.White)
                .height(16) // 固定高度确保布局稳定

              Text(this.song?.artists ? this.song.artists.map(artist => artist.name).join(" / ") : "未知艺术家")
                .fontSize(12)
                .fontColor('rgba(255, 255, 255, 0.6)')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .height(12) // 固定高度确保布局稳定
                .onClick(() => {
                  if (this.song?.artists && this.song.artists.length > 0) {
                    this.sheetType = "artist";
                    this.showPlaylist = true;
                  }
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
        } else {
          if(this.showTitleLyrics === '0') {
            Row() {
              Button({ type: ButtonType.Circle }) {
                Image($r('app.media.ic_arrow_down_3'))
                  .width(36)
                  .height(36)
                  .fillColor(Color.White)
              }
              .width(this.buttonSize)
              .height(this.buttonSize)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.pageStack.pop()
              })

            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Start)

          } else {
            Column(){
              Text(this.getTitleLyrics(this.currentLineLyrics as LyricsLine))
                .fontSize(20)
                .fontWeight(700)
                .fontColor(Color.White)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .textAlign(TextAlign.Center)
                .borderRadius(8)
            }
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .width(StyleConstants.FULL_WIDTH)
            .opacity(this.showLyricType === -1 ? 0 : 1)
            .layoutWeight(1)
            .onClick(() => {
              switch(this.showLyricType) {
                case -1:
                  this.showLyricType += 1
                  break
                case 0:
                  if(this.currentLineLyrics?.translation) {
                    this.showLyricType += 1
                  } else {
                    this.showLyricType = -1
                  }
                  break
                case 1:
                  if(this.currentLineLyrics?.transliteration) {
                    this.showLyricType += 1
                  } else {
                    this.showLyricType = -1
                  }
                  break
                case 2:
                  this.showLyricType = -1
              }
              AppStorage.setOrCreate<number>('playing_title_lyric_show_status', this.showLyricType)
              PreferencesCache.setUserPreference('playing_title_lyric_show_status', this.showLyricType.toString())
            })
          }
        }

        if (judge || this.selectedTabIndex === 1){
          Blank()
          Button({ type: ButtonType.Circle }) {
            Image(this.isFavorite ? $r('app.media.ic_heart_fill') : $r('app.media.ic_heart'))
              .width(24)
              .height(24)
              .fillColor(this.isFavorite ? '#FF4081' : Color.White)
              .animation({
                duration: 300,
                curve: Curve.EaseOut,
                iterations: 1,
                playMode: PlayMode.Normal
              })
          }
          .width(this.buttonSize)
          .height(this.buttonSize)
          .backgroundColor(Color.Transparent)
          .scale({ x: this.isHeartButtonPressed ? 1.3 : 1.0, y: this.isHeartButtonPressed ? 1.3 : 1.0 })
          .animation({
            duration: 300,
            curve: Curve.EaseOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
          .onClick(() => {
            this.isHeartButtonPressed = true
            this.uiContext?.animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
              if (this.song) {
                SourceAdapter.likeSong(this.song, !this.isFavorite)
              }
              EventHelper.postFavoriteToggle("")

              // 重置按钮状态
              setTimeout(() => {
                this.isHeartButtonPressed = false
              }, 400)
            })
          })

          // 更多菜单按钮
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_more'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
          }
          .width(this.buttonSize)
          .height(this.buttonSize)
          .backgroundColor(Color.Transparent)
          .rotate({ angle: this.isMoreButtonPressed ? 90 : 0 })
          .animation({
            duration: 300,
            curve: Curve.EaseInOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
          .onClick(() => {
            this.isMoreButtonPressed = true

            // 重置按钮状态
            setTimeout(() => {
              this.isMoreButtonPressed = false
            }, 300)
          })
          .bindMenu(this.isWideScreen ? this.getWideScreenMenu() : this.getNarrowScreenMenu())
        }

        if(this.selectedTabIndex === 1 ||this.isWideScreen && this.Playing_Next == false){
          Blank()
          Button({ type: ButtonType.Circle }){
            Image($r('app.media.lysic'))
              .width(24)
              .height(24)
              .fillColor(this.Lyic_desktop==='1' ? Color.Orange : Color.White)
          }.width(this.buttonSize)
          .height(this.buttonSize)
          .backgroundColor(Color.Transparent)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .animation({
            duration: 300,
            curve: Curve.EaseInOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
          .onClick(() => {
            if (PreferencesCache.getUserPreference('Lyic_desktop','0')==='0') {
              PipManager.getInstance().startPip()
            }else {
              PipManager.getInstance().stopPip()
            }
            // 重置按钮状态
          })
        }
      }
      .width(StyleConstants.FULL_WIDTH)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      .height(50) // 固定标题栏高度
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width(StyleConstants.FULL_WIDTH)
  }

  build() {
    NavDestination() {
      FolderStack() {
        // 背景
        this.BlurBackground(this.is_backblur)

        Column() {

          // 根据屏幕尺寸显示不同布局
          if (this.isWideScreen && this.Playing_Next == false) {
            // 标题栏
            this.Title()
            // 宽屏布局 - 左右分栏
            if (this.winWidth >WidthBreakpoint.WIDTH_LG) {
              
            }
            Row() {
              if (this.flipCoverLyric) {
                Column() {
                  // 右侧歌词
                  this.LyricsPlaceholder()
                }
                .width('50%')
                .transition({ type: TransitionType.All, translate: { x: 20 }, opacity: 0.0 })

                Column() {
                  // 左侧播放内容
                  this.PlayingContent()
                }
                .width('50%')
                .transition({ type: TransitionType.All, translate: { x: -20 }, opacity: 0.0 })
              } else {
                Column() {
                  // 左侧播放内容
                  this.PlayingContent()
                }
                .width('50%')
                .transition({ type: TransitionType.All, translate: { x: -20 }, opacity: 0.0 })

                Column() {
                  // 右侧歌词
                  this.LyricsPlaceholder()
                }
                .width('50%')
                .transition({ type: TransitionType.All, translate: { x: 20 }, opacity: 0.0 })
              }
            }
            .width(StyleConstants.FULL_WIDTH)
            .height(StyleConstants.FULL_HEIGHT)
            .layoutWeight(1)
          } else if (this.isWideScreen && this.Playing_Next) {
            this.Playing_HorizontalMode()
          } else if (this.widthBreakpoint <= WidthBreakpoint.WIDTH_SM && (this.heightBreakpoint <= HeightBreakpoint.HEIGHT_SM || this.winWidth/this.winHeight > 0.80)){
            this.playing_50()
          } else {

            this.Title()
            // 窄屏布局 - Tabs切换
            Tabs({ barPosition: BarPosition.End, index: this.selectedTabIndex, controller: this.controller }) {
              TabContent() {
                // 播放内容
                Column() {
                  this.PlayingContent()
                }
              }
              .transition({ type: TransitionType.All, opacity: 0.0, translate: { x: -20 } })

              TabContent() {
                // 歌词
                this.LyricsPlaceholder()
              }
              .transition({ type: TransitionType.All, opacity: 0.0, translate: { x: 20 } })
            }
            .scrollable(true)
            .barMode(BarMode.Fixed)
            .layoutWeight(1)
            .barHeight(0)
            .onChange((index: number) => {
              this.uiContext?.animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
                this.selectedTabIndex = index
              })
            })
          }
        }
        .attributeModifier(this.colum_20)
        .width(StyleConstants.FULL_WIDTH)
        .height(StyleConstants.FULL_HEIGHT)
      }
      .onHoverStatusChange((msg) => {
        console.log('this foldStatus:' + msg.foldStatus);
        console.log('this isHoverMode:' + msg.isHoverMode);
        console.log('this appRotation:' + msg.appRotation);
        console.log('this windowStatusType:' + msg.windowStatusType);
      })

      .width(StyleConstants.FULL_WIDTH)
      .height(StyleConstants.FULL_HEIGHT)
    }
    .systemTransition(NavigationSystemTransitionType.FADE)
    .hideToolBar(true)
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_background'))
    .mode(NavDestinationMode.STANDARD)
      .onAxisEvent(async (event)=>{
        let max:number = this.song?.duration || 0
        if (event.action ===AxisAction.BEGIN) {
          // avPlayerManager.seek(this.currentTime)
          clearInterval(this.updateTimer);
        }
        if (event.axisHorizontal) {
        // let judge:boolean =  event.axisHorizontal>30
        //   this.P_X = this.P_X+event.axisHorizontal
        //   console.log('jizhishipx'+this.P_X)
          if (event.axisHorizontal <0) {
                this.currentTime = this.currentTime+1000
                console.log(this.currentTime+'onAxisEvent_jizhishi'+max)
            this.P_X++
          }else  {
            this.currentTime = this.currentTime-1000
            console.log(this.currentTime+'onAxisEvent_jizhishi'+max)
            this.P_X--
          }



        }
        if (event.action ===AxisAction.END) {
          if (this.P_X!=0) {
            avPlayerManager.seek(this.currentTime)
            this.P_X =0

          }

          const player = await avPlayerManager.getAVPlayerInstance()

          this.updateTimer = setInterval(() => {
            if (this.isPlaying && this.currentTime <= (this.song?.duration || 0)) {
              this.currentTime = player.currentTime;
            }
          }, 300)
        }

      })
    .onWillShow(() => {
      this.loadUVBackgroundModifier()
    })
    .onWillAppear(() => {
      this.loadUVBackgroundModifier()
    })

    .onAppear(()=>{
      this.img_playing_ctrl=  PreferencesCache.getUserPreference('img_playing_ctrl','0')
      PipManager.getInstance().init(this.getUIContext().getHostContext() as Context); // 创建画中画控制器


    })
    .width(StyleConstants.FULL_WIDTH)
    .height(StyleConstants.FULL_HEIGHT)
    // .onBackPressed(()=> {
    //   this.uiContext?.animateTo({
    //     duration: 100,
    //     // 构造插值器弹簧曲线对象，生成一条从0到1的动画曲线
    //     curve: curves.interpolatingSpring(0, 1, 324, 38),
    //     // curve:Curve.Linear
    //   }, () => {
    //     this.pageStack.pop()
    //   })
    //   return true
    // })
    .gesture(
      SwipeGesture({
        // 竖直方向滑动
        direction: SwipeDirection.Vertical,
      }).onAction((event) => {
        if (event.angle < -45 && event.angle > -135) {
          // 向上滑，显示播放列表
          this.uiContext?.animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
            this.sheetType = "playlist";
            this.showPlaylist = true;
          })
        } else if (event.angle > 45 && event.angle < 135) {
          this.pageStack.pop()
        }
      })

    )
    // .gesture(
    //   PanGesture(this.panOption)
    //     .onActionStart((event: GestureEvent) => {
    //       console.info('Pan start');
    //       console.info('Pan start timeStamp is: ' + event.timestamp);
    //     })
    //     .onActionUpdate((event: GestureEvent) => {
    //       if (event) {
    //         // this.offsetX = this.positionX + event.offsetX;
    //         // this.offsetY = this.positionY + event.offsetY;
    //       }
    //     })
    //     .onActionEnd((event: GestureEvent) => {
    //       event.offsetX
    //       // this.positionX = this.offsetX;
    //       // this.positionY = this.offsetY;
    //       console.info('Pan end');
    //       console.info('Pan end timeStamp is: ' + event.timestamp);
    //     })
    // )
    .onSizeChange(() => {
      this.Playing_Next = isHorizontalMode()
    })
    .bindSheet($$this.showPlaylist, this.sheet, {
      showClose: false,
      height: SheetSize.MEDIUM,
      dragBar: false,
      preferType: this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM ? SheetType.BOTTOM : SheetType.CENTER,
      onWillDismiss: () => {
        this.showPlaylist = false;
        this.sheetType = "playlist";
      }
    })
  }

  onWinWidthChange() {
    if(this.winWidth > this.winHeight) {
      WindowUtil.setSystemBarEnabled(this.windowStage, false)
    }else{
      WindowUtil.setSystemBarEnabled(this.windowStage, true)
    }
  }

  getTitleLyrics(lyricsLine: LyricsLine): string {
    switch(this.showLyricType){
      case 0:
        return lyricsLine?.text ?? ''
      case 1:
        return lyricsLine?.translation ?? (lyricsLine?.text ?? '')
      case 2:
        return lyricsLine?.transliteration ?? (lyricsLine?.translation ?? (lyricsLine?.text ?? ''))
      default:
        return ''
    }
  }

  // 导航到艺术家页面
  private navigateToArtist(artist: Artist) {
    PushPathHelper.pushPath(this.pageStack, "Playlist", async () => {
      try {
        // 歌手复用歌单UI
        artist.source = this.song?.source
        const playlist = await SourceAdapter.getArtistDetail(artist);
        AppStorage.setOrCreate('current_playlist_data', playlist);
        AppStorage.setOrCreate('current_playlist_songs', playlist.songs);
        LogUtil.info('Playing', `成功获取艺术家详情: ${artist.id}`);
      } catch (error) {
        LogUtil.error('Playing', `获取艺术家详情失败: ${artist.name}`, error);
        ToastUtil.showShort('获取艺术家信息失败');
      }
    });
  }
}
