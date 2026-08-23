import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppUtil } from '@pura/harmony-utils';
import { Log, LogUtil } from '../logger/Logger';
import { ImageKnife } from '@ohos/imageknife';
import { SongCacheManager } from '../util/SongCacheManager';
import { EventHelper } from '../util/EventHelper';
import { ContextHelper } from '../util/ContextHelper';
import { DownloadManager } from '../util/DownloadUtils';
import { avPlayerManager } from '../util/AVPlayerManager';
import { backgroundRunningManager } from '../util/BackgroundRunningManager';
import { Song } from '../type/Adapter';
import app from '@system.app';
import FormUtils from '../util/FormUtils';
import { CallMethod } from '../widget/model/FormCardConstant';
import { SongDownloadManager } from '../util/SongDownloadManager';
import WindowUtil from '../util/WindowUtil';
import { DialogHelper } from '@pura/harmony-dialog';
import { PipManager } from '../util/PipManager';
import { PreferencesCache } from '../util/PreferenceCache';
import ResourceManager from '../util/ResourceManager';
import { SourceAdapter } from '../adapter';
import { sensor } from '@kit.SensorServiceKit';
import json from '@ohos.util.json';

const TAG = 'EntryAbility'
export default class EntryAbility extends UIAbility {

  private _pause_timer: number = -1; // 用于存储暂停计时器的ID
  private page?: string | null = null;
  onConfigurationUpdate(newConfig: Configuration): void {
    let  isDark = newConfig.colorMode ===0   ?true:false
    AppStorage.setOrCreate('sys_ColorMode_dark',isDark)
  }
  // onConfigurationUpdate(newConfig: Configuration): void {
  //   //颜色深浅变化监听，也可以监听系统语言变化
  //   PersonalizedSettingData.isDark = newConfig.colorMode ===0   ?true:false
  //   console.log(`onConfigurationUpdate, config: ${JSON.stringify(PersonalizedSettingData.isDark)}`);
  //   console.log(`onConfigurationUpdate, config: ${JSON.stringify(newConfig)}`);
  // }
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    Log.init(this.context); // 初始化日志模块（落盘+崩溃订阅），须最先
    this.callee.on(CallMethod.REQUEST_UPDATE_CARD, FormUtils.requestUpdatePlayCard);
    this.callee.on(CallMethod.PLAY_BY_ACTION, FormUtils.playByActionCall);
    this.callee.on(CallMethod.COLLECT_ACTION, FormUtils.collectActionCall);
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

    // 事件监听注册
    EventHelper.subscribePlaySong()
    EventHelper.subscribeInitData()
    EventHelper.subscribeFavoriteToggle()
    AppStorage.setOrCreate('cacheDir_jzs',this.context.cacheDir)
    SongCacheManager.initialize() // 初始化歌曲缓存管理器
    SongDownloadManager.init(this.context) // 初始化歌曲下载管理器
    ContextHelper.init(this.context) // 初始化上下文工具类
    DownloadManager.init(this.context) // 初始化下载工具类
    ResourceManager.init(this.context)
    await avPlayerManager.init(this.context); // 初始化播放器
    FormUtils.init(this.context) //初始化服务卡片工具
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
      LogUtil.info(`[${TAG}]`, `收到[on_song_state]事件订阅，状态为：[${data}]`);
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
    SourceAdapter.getAllRecommend()

    PreferencesCache.convertPlaylistData()
  }

  async onDestroy(): Promise<void> {
    Log.markCleanExit(); // 正常退出标记，供下次启动判定是否异常退出
    LogUtil.info(`[${TAG}]`, 'Ability onDestroy');
    PipManager.getInstance().setAutoStart(false)
    PreferencesCache.setUserPreference('Lyic_desktop','0')
    // 先把卡片状态置为暂停并等待推送派发完成，再销毁播放器；
    // 否则销毁/杀进程会与异步推送竞态，导致清后台后卡片仍显示播放态。
    await FormUtils.updateCardPlayStatus(false);
    avPlayerManager.destroy()
    sensor.off(sensor.SensorId.BAROMETER);
    LogUtil.info(`[${TAG}]`, `avPlayer&avSession has been destroyed: ${avPlayerManager.avPlayer?.getState()}`);
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    LogUtil.info(`[${TAG}]`, 'Ability onWindowStageCreate');
    // 崩溃复盘改为首页半模态弹窗（见 Index.ets），这里始终正常初始化主窗口，
    // 避免整页替换导致 WindowUtil 的窗口属性/监听/PiP 初始化被跳过
    WindowUtil.loadContent(windowStage, this.page);
  }

  onWindowStageWillDestroy(windowStage: window.WindowStage){
    windowStage.getMainWindow().then((windowClass) => {
      WindowUtil.setWindowFullScreen(windowClass, false)
    })
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    LogUtil.info(`[${TAG}]`, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    LogUtil.info(`[${TAG}]`, 'Ability onForeground');
    // 这里原先调的是 stopHoldingHand()：回到前台反而把智感握持监听注销了，
    // 而重新注册只发生在 Index 首次挂载时，导致切一次后台回来握持就永久失效。
    // 前台时应确保监听存在（startHoldingHand 内部幂等，重复调用不会叠加回调）。
    if (canIUse("SystemCapability.MultimodalAwareness.Motion")) {
      import('../util/HoldHand').then((nv) => {
        nv.startHoldingHand()
      })
    }
  }

  onBackground(): void {
    // Ability has back to background
    LogUtil.info(`[${TAG}]`, 'Ability onBackground');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.log('jizhishi0114'+JSON.stringify(want))
    if (want?.parameters?.formID) {
      if (want?.parameters?.params) {
        let params: Record<string, Object> = JSON.parse(want.parameters.params as string);
        let type = params.type as string;
        EventHelper.postFormJumpPage(type)
        LogUtil.info(`[${TAG}]`, 'targetPage: '+ type);
      }
    }else {
      if (want?.parameters?.["ohos.aafwk.param.callerBundleName"]==='com.ohos.sceneboard') {
        EventHelper.postFormJumpPage('ImmersivePlayer')

      }
    }
  }
}
