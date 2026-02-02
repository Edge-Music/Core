import { curves, window } from "@kit.ArkUI"
import { LogUtil, ToastUtil } from "@pura/harmony-utils"
import { SourceAdapter } from "../adapter"
import { Song } from "../type/Adapter"
import { avPlayerManager } from "../util/AVPlayerManager"
import { VibrationControl } from "../util/DeviceController"
import { EventHelper } from "../util/EventHelper"
import { PlaylistManager } from "../util/PlaylistManager"
import { PreferencesCache } from "../util/PreferenceCache"
import WindowUtil from "../util/WindowUtil"


const TAG = 'MultiFuncSubWindow'

@Entry
@Component
export struct MultiFuncSubWindow {

  @State startY: number = 0
  @State totalDeltaY: number = 0
  @State offsetX: number = 0
  @State offsetY: number = 0
  @State btnOpacity: number = 0.5
  @State @Watch('playModeChange') playMode: number = PlaylistManager.getPlayMode()

  @State windowStage: window.WindowStage = AppStorage.get('windowStage') as window.WindowStage
  @State subWindow: window.Window = window.findWindow('MultiFuncSubWindow')

  @StorageProp('winWidthWithPx') @Watch('onWinWidthChange') winWidthWithPx: number = 0
  @StorageProp('winHeightWithPx') @Watch('onWinWidthChange') winHeightWithPx: number = 0
  @StorageProp('sub_window_show_type') @Watch('onWinWidthChange') subShowType: number = 0
  @StorageProp("current_playing_song") song: Song | null = null
  @StorageProp('winHeight') winHeight: number = 0
  @StorageProp('hand') @Watch('onHandChange')  hand: number = 0

  private uiContext: UIContext | undefined = undefined
  private playerManager = avPlayerManager;
  private isPlaying: boolean = false
  private isFavorite: boolean = false
  private timerId: number = -1


  aboutToAppear(): void {
    this.uiContext = this.getUIContext()

    this.isFavorite = this.song?.meta?.isFavorite || false

    EventHelper.subscribeFavoriteToggle(() => {
      this.isFavorite = !this.isFavorite;
    })

    // 初始化监听
    EventHelper.subscribeLoopMode((mode: number) => {
      this.playMode = mode;
    })

    // 获取初始状态
    this.playerManager.getAVPlayerInstance().then(player => {
      this.isPlaying = player.state === 'playing';
    });

    // 添加事件监听
    this.playerManager.addListener('onPlay', () => {
      this.isPlaying = true;
    });

    this.playerManager.addListener('onPause', () => {
      this.isPlaying = false;
    });
    WindowUtil.changeFocus(this.windowStage, 'MultiFuncSubWindow')

  }

  aboutToDisappear(): void {

  }

  build() {
    Stack({ alignContent: Alignment.Center}) {
      Row()
        .width(45)
        .height(45)
        .backgroundColor('#66666666')
        .border({ width: 2, color: '#66aaaaaa', radius: 22.5 })

      Image($r('app.media.circle'))
        .width(30)
        .height(30)
        .fillColor(Color.White)
        .translate({ x: this.offsetX, y: this.offsetY })
        .draggable(false)
    }
    .height(70)
    .width(70)
    .opacity(this.btnOpacity)
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        // 拖动手势
        PanGesture()
          .onActionStart(() => {
            this.startY = this.offsetY // 记录拖动开始位置
            this.totalDeltaY = 0       // 初始化总拖动距离
          })
          .onActionUpdate((event: GestureEvent) => {

            const speedFactor = 0.05
            let newX = this.offsetX + event.offsetX * speedFactor
            let newY = this.offsetY + event.offsetY * speedFactor
            // 计算当前拖动距离（基于缩放后的坐标）
            const distance = Math.sqrt(newX * newX + newY * newY)
            // 当距离超过10时进行比例缩放
            if (distance > 20) {
              const scale = 20 / distance
              newX *= scale
              newY *= scale
            }
            this.offsetX = newX
            this.offsetY = newY

            // 累计垂直方向拖动距离
            this.totalDeltaY += event.offsetY * speedFactor
          })
          .onActionEnd(() => {
            this.uiContext?.animateTo({ duration: 600, curve: curves.springCurve(1, 1, 100, 18) }, () => {
              this.offsetX = 0
              this.offsetY = 0
            })

            // 检测垂直拖动方向
            if (Math.abs(this.totalDeltaY) > 50) {
              if (this.totalDeltaY > 0) {
                this.handleSwipeDown()
              } else {
                this.handleSwipeUp()
              }
            }

            WindowUtil.changeFocus(this.windowStage, 'MultiFuncSubWindow')
            this.btnOpacity = 1
          }),

        // 长按手势
        LongPressGesture({ duration: 1000 })
          .onAction((event: GestureEvent) => {
            LogUtil.info(`[${TAG}]`, '长按了1秒');
            this.handleLongTap()
          })
          .onActionEnd(() => {
            WindowUtil.changeFocus(this.windowStage, 'MultiFuncSubWindow')
            this.btnOpacity = 1
          }),

        // 三击手势
        TapGesture({ count: 3 })
          .onAction(() => {
            this.handleTripleTap()
            LogUtil.info(`[${TAG}]`, '敲击了3下');
            WindowUtil.changeFocus(this.windowStage, 'MultiFuncSubWindow')
            this.btnOpacity = 1
          }),

          // 双击手势
        TapGesture({ count: 2 })
          .onAction(() => {
            this.handleDoubleTap()
            LogUtil.info(`[${TAG}]`, '敲击了2下');
            WindowUtil.changeFocus(this.windowStage, 'MultiFuncSubWindow')
            this.btnOpacity = 1
          }),
          // 单击手势
        TapGesture({ count: 1 })
          .onAction(() => {
            this.handleSingleTap()
            WindowUtil.changeFocus(this.windowStage, 'MultiFuncSubWindow')
            this.btnOpacity = 1
          })
      )
    )

  }

  handleSingleTap() {
    VibrationControl.handlePresetVibration()
    let pageStack = AppStorage.get("pageStack") as NavPathStack
    LogUtil.info(`[${TAG}]`, `敲击了1下: ${pageStack.size()}`);
    if (pageStack.size() > 1) {
      pageStack.pop();
      ToastUtil.showToast(`返回`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
      this.commonAction()
    }
  }

  handleDoubleTap() {
    VibrationControl.handlePresetVibration(2)
    this.isPlaying = !this.isPlaying
    if (this.isPlaying) {
      this.playerManager.play();
      ToastUtil.showToast(`播放`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
    } else {
      this.playerManager.pause();
      ToastUtil.showToast(`暂停`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
    }
    this.commonAction()
  }

  handleTripleTap() {
    PlaylistManager.switchPlayMode();
    VibrationControl.handlePresetVibration(3)
  }

  handleLongTap() {
    VibrationControl.handlePresetVibration(4)
    if (this.song) {
      SourceAdapter.likeSong(this.song, !this.isFavorite)
    }
    EventHelper.postFavoriteToggle("")
    if(this.isFavorite) {
      ToastUtil.showToast(`取消收藏当前歌曲`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
    } else {
      ToastUtil.showToast(`收藏当前歌曲`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
    }
    this.commonAction()
  }

  handleSwipeUp() {
    VibrationControl.handlePresetVibration(1)
    const prevSong = PlaylistManager.playPrevious();
    if (prevSong) {
      PlaylistManager.playSong(prevSong);
      ToastUtil.showToast(`上一首`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
      this.commonAction()
    }
    LogUtil.info(`[${TAG}]`, '向上运动了');
  }

  handleSwipeDown() {
    VibrationControl.handlePresetVibration(1)
    const nextSong = PlaylistManager.playNext();
    if (nextSong) {
      PlaylistManager.playSong(nextSong);
      ToastUtil.showToast(`下一首`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
      this.commonAction()
    }
    LogUtil.info(`[${TAG}]`, '向下运动了');
  }

  onWinWidthChange() {
    let settingData = PreferencesCache.multiFuncSubWindow(this.windowStage, this.hand)
    this.subWindow.moveWindowTo(settingData.x, settingData.y);
    this.commonAction()
  }

  onHandChange() {
    let settingData = PreferencesCache.multiFuncSubWindow(this.windowStage, this.hand)
    this.subWindow.moveWindowTo(settingData.x, settingData.y);
    this.commonAction()
  }

  commonAction() {
    if(this.timerId != -1) {
      clearTimeout(this.timerId)
    }
    this.timerId = setTimeout(() => {
      this.btnOpacity = 0.5
      this.timerId = -1
    }, 3000)

  }

  playModeChange() {
    switch (this.playMode) {
      case 0:
        ToastUtil.showToast(`顺序播放`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
        break
      case 1:
        ToastUtil.showToast(`单曲循环`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
        break
      case 2:
        ToastUtil.showToast(`列表循环`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
        break
      case 3:
        ToastUtil.showToast(`随机播放`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
        break
      default :
        ToastUtil.showToast(`顺序播放`, { alignment: Alignment.Bottom, offset: { dx: 0, dy: -this.winHeight/3 } })
    }
  }
}