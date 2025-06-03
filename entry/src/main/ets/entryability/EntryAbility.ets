import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppUtil, CrashUtil, LogUtil } from '@pura/harmony-utils';
import { ImageKnife } from '@ohos/imageknife';
import { DialogHelper } from '@pura/harmony-dialog';
import { SongCacheManager } from '../util/SongCacheManager';
import { EventHelper } from '../util/EventHelper';
import { ContextHelper } from '../util/ContextHelper';
import { DownloadManager } from '../util/DownloadUtils';
import { avPlayerManager } from '../util/AVPlayerManager';
import { backgroundRunningManager } from '../util/BackgroundRunningManager';
import app from '@system.app';
import FormUtils from '../util/FormUtils';
import { CallMethod } from '../widget/model/FormCardConstant';
import { SongDownloadManager } from '../util/SongDownloadManager';
import WindowUtil from '../util/WindowUtil';

const TAG = 'EntryAbility'
export default class EntryAbility extends UIAbility {

  private _pause_timer: number = -1; // 用于存储暂停计时器的ID
  private page?: string | null = null;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    LogUtil.init(0x2003, 'Edge Music', true); // 初始化日志工具类
    AppUtil.init(this.context); // 初始化应用工具类
    LogUtil.info(`[${TAG}]`, 'Ability onCreate');
    if (want?.parameters?.params) {
      let params: Record<string, Object> = JSON.parse(want.parameters.params as string);
      this.page = params.type as string;
    }

    DialogHelper.setDefaultConfig((config) => {
      config.uiAbilityContext = this.context;
      config.autoCancel = false; //点击遮障层时，是否关闭弹窗
      config.backCancel = true; // 点击返回键时，是否关闭弹窗
    }) // 初始化对话框工具类

    SongCacheManager.initialize() // 初始化歌曲缓存管理器
    SongDownloadManager.init(this.context) // 初始化歌曲下载管理器
    CrashUtil.onError(); // 注册错误处理
    ContextHelper.init(this.context) // 初始化上下文工具类
    DownloadManager.init(this.context) // 初始化下载工具类
    await avPlayerManager.init(this.context); // 初始化播放器
    FormUtils.init(this.context) //初始化服务卡片工具
    // 事件监听注册
    EventHelper.subscribePlaySong()
    EventHelper.subscribeInitData()
    EventHelper.subscribeFavoriteToggle()
    EventHelper.subscribePauseTimer(async (endAt) => {
      // 监听暂停计时器事件
      if (this._pause_timer !== -1) {
        clearTimeout(this._pause_timer); // 清除旧的计时器
      }
      if (endAt > 0) {
        this._pause_timer = setTimeout(async () => {
          // 当计时器到达指定时间后触发
          LogUtil.info(`[${TAG}]`, "Pause Timer Ended", `Pausing playback`);
          await avPlayerManager.pause(); // 暂停播放器
          this._pause_timer = -1; // 重置计时器ID
        }, endAt - Date.now());
      } else {
        this._pause_timer = -1; // 重置计时器ID
      }
    })
    EventHelper.subscribeSongState(async (data) => {
      LogUtil.info(`[${TAG}]`, 'context '+ this.context);
      if (data === 'PLAY') {
        await backgroundRunningManager.startBackgroundRunning(this.context);
        FormUtils.updateCardPlayStatus(true);
      } else if (data === 'PAUSE') {
        await backgroundRunningManager.stopBackgroundRunning(this.context);
        FormUtils.updateCardPlayStatus(false);
      }
    })
    EventHelper.subscribeLoopMode((mode) => {
      const session = avPlayerManager.getSession();
      if (session) {
        session.setAVPlaybackState({
          loopMode: mode
        })
      }
    })
    EventHelper.subscribeFormJumpPage()
    await ImageKnife.getInstance().initFileCache(this.context, 256, 256 * 1024 * 1024)
    app.setImageRawDataCacheSize(100 * 1024 * 1024) // 设置解码前图片数据内存缓存上限为100MB
    this.callee.on(CallMethod.REQUEST_UPDATE_CARD, FormUtils.requestUpdatePlayCard);
    this.callee.on(CallMethod.PLAY_BY_ACTION, FormUtils.playByActionCall);
    this.callee.on(CallMethod.COLLECT_ACTION, FormUtils.collectActionCall);
  }

  onDestroy(): void {
    LogUtil.info(`[${TAG}]`, 'Ability onDestroy');
    FormUtils.updateCardPlayStatus(false);
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    LogUtil.info(`[${TAG}]`, 'Ability onWindowStageCreate');
    WindowUtil.loadContent(windowStage);
    WindowUtil.setupWindowProperties(windowStage)
    WindowUtil.setupWindowListeners(windowStage)
    WindowUtil.setupPipManager(windowStage)

    if (this.page){
      WindowUtil.setupPageJump(this.page)
    }

  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    LogUtil.info(`[${TAG}]`, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    LogUtil.info(`[${TAG}]`, 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    LogUtil.info(`[${TAG}]`, 'Ability onBackground');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    if (want?.parameters?.params) {
      let params: Record<string, Object> = JSON.parse(want.parameters.params as string);
      let type = params.type as string;
      EventHelper.postFormJumpPage(type)
      LogUtil.info(`[${TAG}]`, 'targetPage: '+ type);
    }
  }
}
