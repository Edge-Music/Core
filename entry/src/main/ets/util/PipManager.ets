// model/PipManager.ets
// 画中画控制器单例
import { BuilderNode, NodeController, PiPWindow, typeNode } from '@kit.ArkUI'; // 引入PiPWindow模块
import { BusinessError } from '@kit.BasicServicesKit';
import { avPlayerManager} from './AVPlayerManager'
import { PlaylistManager } from '../util/PlaylistManager'
import { Song } from "../type/Adapter";
import { cover } from './AdapterHelper';

let mess:string=AppStorage.get('test_index')??''
let song: Song
let  intervalID:number
@Observed
class Params {
  text: string = '';
  constructor(text: string) {
    this.text = text;
  }
}
// 开发者可以通过@Builder装饰器实现布局构建
@Builder
function buildText(params: Params) {
  Column() {
    Stack(){

      Image(cover(song?.album?.cover ?? "", 512))
        .foregroundBlurStyle(BlurStyle.BACKGROUND_REGULAR)
        // .blur(60)

      Text(AppStorage.get('test_index'))
        .maxLines(2)
        .fontSize(28)
        .fontColor(Color.White)
        .textOverflow({overflow: TextOverflow.Ellipsis })
    }

  }.backgroundColor('#00000000')
  .onClick(()=>{
    mess =AppStorage.get('test_index') ??'a'
  })
  .width('100%') // 宽度方向充满画中画窗口
  .height('100%') // 高度方向充满画中画窗口
}

// 开发者可通过继承NodeController实现自定义UI控制器
class TextNodeController extends NodeController {
  // private message: string;
  private mess:string=AppStorage.get('test_index')??''

  private textNode: BuilderNode<[Params]> | null = null;
  // constructor(message: string) {
  //   super();
  //   this.mess = AppStorage.get('test_index')??'w';
  // }

  // 通过BuilderNode加载自定义布局
  makeNode(context: UIContext): FrameNode | null {
    this.textNode = new BuilderNode(context);
    this.textNode.build(wrapBuilder<[Params]>(buildText), new Params(this.mess));
    return this.textNode.getFrameNode();
  }

  // 开发者可自定义该方法实现布局更新
  update(message: string) {
    mess=AppStorage.get('test_index')??'w'
    song = AppStorage.get("current_playing_song")??song

    console.log(`update message: ${message}`);
    if (this.textNode !== null) {
      this.textNode.update(new Params(message));
    }
  }
}
export let nodeController: TextNodeController = new TextNodeController();

// 自定义XComponentController
class CustomXComponentController extends XComponentController {
  // 监听onSurfaceCreated，并将surfaceId设置给播放器
  onSurfaceCreated(surfaceId: string): void {
    console.log(TAG, `onSurfaceCreated surfaceId: ${surfaceId}`);
    if (PipManager.getInstance().player?.surfaceId === surfaceId) {
      return;
    }
    // PipManager.getInstance().player.surfaceId = surfaceId;
    // PipManager.getInstance().player.avPlayerFdSrc();
  }

  onSurfaceDestroyed(surfaceId: string): void {
    console.log(TAG, `onSurfaceDestroyed surfaceId: ${surfaceId}`);
  }
}

const TAG = 'PipManager';

export class PipManager {
  player=avPlayerManager.avPlayer;
  private static instance: PipManager = new PipManager();
  private pipController?: PiPWindow.PiPController = undefined;
  private mXComponentController: XComponentController;
  private xComponent: typeNode.XComponent| null = null; // typeNode节点
  private isPlaying: boolean = false;
  // private intervalID

  // private message_text:LyricsLine=AppStorage.get('current_line_lyrics')


  private mess:string=AppStorage.get('test_index')??'w'

  public static getInstance(): PipManager {
    return PipManager.instance;
  }

  constructor() {
    this.player = avPlayerManager.avPlayer;
    this.mXComponentController = new CustomXComponentController();
  }

  onActionEvent(control: PiPWindow.ControlEventParam) {
    switch (control.controlType) {
      case PiPWindow.PiPControlType.VIDEO_PLAY_PAUSE:
        if (control.status === PiPWindow.PiPControlStatus.PAUSE) {
          avPlayerManager.pause()
          mess='a'

          //停止视频
        } else if (control.status === PiPWindow.PiPControlStatus.PLAY) {
          //播放视频
          avPlayerManager.play()
        }
        break;
      case PiPWindow.PiPControlType.VIDEO_NEXT:

        const nextSong = PlaylistManager.playNext()
        if (nextSong) {
          PlaylistManager.playSong(nextSong)
        }
        // 切换到下一个视频
        break;
      case PiPWindow.PiPControlType.VIDEO_PREVIOUS:
        const prevSong = PlaylistManager.playPrevious()
        if (prevSong) {
          PlaylistManager.playSong(prevSong)
        }
        break;
      case PiPWindow.PiPControlType.FAST_FORWARD:
        // 视频进度快进
        break;
      case PiPWindow.PiPControlType.FAST_BACKWARD:
        // 视频进度后退
        break;
      default:
        break;
    }
    console.info('onActionEvent, controlType:' + control.controlType + ', status' + control.status);
  }

  // 监听画中画生命周期
  onStateChange(state: PiPWindow.PiPState, reason: string) {
    let curState: string = '';
    switch (state) {
      case PiPWindow.PiPState.ABOUT_TO_START:
        curState = "ABOUT_TO_START";
        break;
      case PiPWindow.PiPState.STARTED:
        curState = "STARTED";

        break;
      case PiPWindow.PiPState.ABOUT_TO_STOP:
        curState = "ABOUT_TO_STOP";
        break;
      case PiPWindow.PiPState.STOPPED:
        curState = "STOPPED";
        break;
      case PiPWindow.PiPState.ABOUT_TO_RESTORE:
        curState = "ABOUT_TO_RESTORE";
        break;
      case PiPWindow.PiPState.ERROR:
        curState = "ERROR";
        break;
      default:
        curState="testjizhishi"
        break;
    }
    console.info(`[${TAG}] onStateChange: ${curState}, reason: ${reason}`);
  }

  // 解注册监听
  unregisterPipStateChangeListener() {
    console.info(TAG, 'aboutToDisappear');
    this.pipController?.off('stateChange');
    this.pipController?.off('controlEvent');
  }

  getXComponentController(): CustomXComponentController {
    return this.mXComponentController;
  }

  // 步骤1：创建画中画控制器，注册生命周期事件以及控制事件回调
  init(ctx: Context) {
    if (this.pipController !== null && this.pipController != undefined) {
      return;
    }

    console.info(TAG, 'onPageShow');
    if (!PiPWindow.isPiPEnabled()) {
      console.error(TAG, `picture in picture disabled for current OS`);
      return;
    }
    let config: PiPWindow.PiPConfiguration = {
      context: ctx,
      componentController: this.getXComponentController(),
      templateType: PiPWindow.PiPTemplateType.VIDEO_PLAY,
      controlGroups:[PiPWindow.VideoPlayControlGroup.VIDEO_PREVIOUS_NEXT],
      customUIController: nodeController,
      contentWidth: 1920, // 使用typeNode启动画中画时，contentWidth需设置为大于0的值，否则将设置为16:9默认比例
      contentHeight: 400, // 使用typeNode启动画中画时，contentHeight需设置为大于0的值，否则将设置为16:9默认比例
    };
      intervalID =setInterval(() => {
      nodeController.update('he')
    }, 100);

    // 通过create接口创建画中画控制器实例
    let promise: Promise<PiPWindow.PiPController> = PiPWindow.create(config, this.xComponent);
    promise.then((controller: PiPWindow.PiPController) => {
      this.pipController = controller;
      // 通过画中画控制器实例的setAutoStartEnabled接口设置是否需要在应用返回桌面时自动启动画中画
      this.pipController.setAutoStartEnabled(true);
      // 通过画中画控制器实例的on('stateChange')接口注册生命周期事件回调
      this.pipController.on('stateChange', (state: PiPWindow.PiPState, reason: string) => {
        console.info(TAG, `Succeeded in starting pip.`+state);
        AppStorage.setOrCreate<boolean>('current_lyrics',true)

        mess=AppStorage.get('test_index')??'a'
        nodeController.update(AppStorage.get('test_index')??'a')
        this.onStateChange(state, reason);
      });
      // 通过画中画控制器实例的on('controlEvent')接口注册控制事件回调
      this.pipController.on('controlEvent', (control: PiPWindow.ControlEventParam) => {
        this.onActionEvent(control);
        nodeController.update(AppStorage.get('test_index')??'l')
      });
    }).catch((err: BusinessError) => {
      console.error(TAG, `Failed to create pip controller. Cause:${err.code}, message:${err.message}`);
    });
  }

  // 步骤2：创建画中画控制器实例后，通过startPiP接口启动画中画
  startPip() {
    avPlayerManager.getAVPlayerInstance().then(player => {
      this.isPlaying = player.state === 'playing';

    });
      this.pipController?.startPiP().then(() => {

        console.info(TAG, `Succeeded in starting pip.`);
      }).catch((err: BusinessError) => {
        console.error(TAG, `Failed to start pip. Cause:${err.code}, message:${err.message}`);
      });


  }

  // 步骤3：更新媒体源尺寸信息
  updateContentSize(width: number, height: number) {
    if (this.pipController) {
      this.pipController.updateContentSize(width, height);
    }
  }

  // 步骤4：关闭画中画
  stopPip() {

    if (this.pipController === null || this.pipController === undefined) {
      return;
    }
    clearInterval(intervalID);
    let promise: Promise<void> = this.pipController.stopPiP();
    promise.then(() => {
      console.info(TAG, `Succeeded in stopping pip.`);
    }).catch((err: BusinessError) => {
      console.error(TAG, `Failed to stop pip. Cause:${err.code}, message:${err.message}`);
    });
  }

  setAutoStart(autoStart: boolean): void {
    this.pipController?.setAutoStartEnabled(autoStart);
  }

  // 创建typeNode节点
  makeTypeNode(ctx: UIContext) {
    if (this.xComponent === null || this.xComponent === undefined) {
      // 创建typeNode
      // let xc_options: XComponentOptions = {
      //   type: XComponentType.TEXTURE, // 类型设置为TEXTURE
      //   controller: PipManager.getInstance().getXComponentController(), // 设置XComponentController
      // }
      // this.xComponent = typeNode.createNode(ctx, "XComponent", xc_options);

      // 创建XComponent类型的typeNode
      this.xComponent = typeNode.createNode(ctx, "XComponent", {
        type: XComponentType.SURFACE, // 类型设置为SURFACE
        controller: PipManager.getInstance().getXComponentController(), // 设置XComponentController
      });
    }
  }
}