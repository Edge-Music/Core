import { display, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { PipManager } from './PipManager';
import { EventHelper } from './EventHelper';
import { LogUtil, ToastUtil } from '@pura/harmony-utils';
import { PreferencesCache, SBLyricsPre } from './PreferenceCache';

const TAG = 'WindowUtil'
class WindowUtil {

  private lyricsFloatWindow: window.Window | undefined = undefined

  loadContent(windowStage: window.WindowStage, page: string | undefined | null) {
    if(!windowStage) return

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        LogUtil.error(`[${TAG}]`, 'Failed to load the content. Cause: ', JSON.stringify(err) ?? '');
        return;
      }
      LogUtil.info(`[${TAG}]`, 'Succeeded in loading the content.');
    });

    let storage: LocalStorage = new LocalStorage();
    windowStage.getMainWindow().then((windowClass) => {
      windowClass.loadContent('pages/Index', storage, (err: BusinessError) => {
        let errCode: number = err.code;
        if (errCode) {
          LogUtil.error(`[${TAG}]`, `Failed to load the content. Cause code: ${err.code}, message: ${err.message}`);
          return;
        }
        LogUtil.info(`[${TAG}]`, 'Succeeded in loading the content.');
        // 调用setWindowDecorVisible接口
        try {
          this.setWindowProperties(windowClass)
          this.setWindowListeners(windowClass)
          this.setPipManager(windowClass)
          this.setWindowFullScreen(windowClass, true)
          this.setWindowStatus(windowClass)
          if (page){
            this.setPageJump(page)
          }
        } catch (exception) {
          LogUtil.error(`[${TAG}]`, `Failed to set the visibility of window decor. Cause code: ${exception.code}, message: ${exception.message}`);
        }
      });
    })

  }

  setPipManager(windowClass: window.Window) {
    const uiContext = windowClass.getUIContext();
    // 通过主窗口UIContext创建typeNode节点
    PipManager.getInstance().makeTypeNode(uiContext);
    LogUtil.info(`[${TAG}]`, 'Succeeded in create typeNode.');
  }

  setWindowListeners(windowClass: window.Window) {
    const uiContext = windowClass.getUIContext()
    // 监听窗口尺寸变化
    windowClass.on('windowSizeChange', (windowSize) => {
      AppStorage.setOrCreate('current_width_breakpoint', uiContext.getWindowWidthBreakpoint())
      AppStorage.setOrCreate('current_height_breakpoint', uiContext.getWindowHeightBreakpoint())
      AppStorage.setOrCreate('winWidth', uiContext.px2vp(windowSize.width));
      AppStorage.setOrCreate('winHeight', uiContext.px2vp(windowSize.height));
      AppStorage.setOrCreate('winWidthWithPx', windowSize.width);
      AppStorage.setOrCreate('winHeightWithPx', windowSize.height);
      if(canIUse('SystemCapability.Window.SessionManager')){
        let height = windowClass.getWindowDecorHeight();
        AppStorage.setOrCreate('decorHeight', uiContext.px2vp(height));
      }
      LogUtil.info(`[${TAG}]`, `width: ${windowSize.width}, height: ${windowSize.height}, width/height: ${windowSize.width/windowSize.height} height/width: ${windowSize.height/windowSize.width}`);
      LogUtil.info(`[${TAG}]`, `width: ${uiContext.px2vp(windowSize.width)}, height: ${uiContext.px2vp(windowSize.height)}, width/height: ${uiContext.px2vp(windowSize.width)/uiContext.px2vp(windowSize.height)}`);
    });
    LogUtil.info(`[${TAG}]`, 'Succeeded in adding windowSizeChange listener.');

    // 监听避让高度变化
    windowClass.on('avoidAreaChange', (avoidArea) => {
      if (avoidArea.type === window.AvoidAreaType.TYPE_SYSTEM) {
        AppStorage.setOrCreate('topRect', uiContext.px2vp(avoidArea.area.topRect.height));
      } else if (avoidArea.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
        AppStorage.setOrCreate('bottomRect', uiContext.px2vp(avoidArea.area.bottomRect.height));
      } else if (avoidArea.type === window.AvoidAreaType.TYPE_CUTOUT) {
        AppStorage.setOrCreate('leftCutoutRectHeight', uiContext.px2vp(avoidArea.area.leftRect.height))
        AppStorage.setOrCreate('leftCutoutRectWidth', uiContext.px2vp(avoidArea.area.leftRect.width))
        AppStorage.setOrCreate('rightCutoutRectHeight', uiContext.px2vp(avoidArea.area.rightRect.height))
        AppStorage.setOrCreate('rightCutoutRectWidth', uiContext.px2vp(avoidArea.area.rightRect.width))
      }
    });
    LogUtil.info(`[${TAG}]`, 'Succeeded in adding avoidAreaChange listener.');
  }

  setWindowProperties(windowClass: window.Window) {
    const uiContext = windowClass.getUIContext()
    // 获取宽高断点
    AppStorage.setOrCreate('current_width_breakpoint', uiContext.getWindowWidthBreakpoint())
    AppStorage.setOrCreate('current_height_breakpoint', uiContext.getWindowHeightBreakpoint())
    // 获取窗口尺寸，存入AppStorage
    AppStorage.setOrCreate('winWidth', uiContext.px2vp(windowClass.getWindowProperties().windowRect.width));
    AppStorage.setOrCreate('winHeight', uiContext.px2vp(windowClass.getWindowProperties().windowRect.height));
    AppStorage.setOrCreate('winWidthWithPx', windowClass.getWindowProperties().windowRect.width);
    AppStorage.setOrCreate('winHeightWithPx', windowClass.getWindowProperties().windowRect.height);
    // 获取避让高度，存入AppStorage
    AppStorage.setOrCreate('topRect', uiContext.px2vp(windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height));
    AppStorage.setOrCreate('bottomRect', uiContext.px2vp(windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height));
    // 刘海屏避让区
    AppStorage.setOrCreate('leftCutoutRectHeight', uiContext.px2vp(windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT).leftRect.height))
    AppStorage.setOrCreate('leftCutoutRectWidth', uiContext.px2vp(windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT).leftRect.width))
    AppStorage.setOrCreate('rightCutoutRectHeight', uiContext.px2vp(windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT).rightRect.height))
    AppStorage.setOrCreate('rightCutoutRectWidth', uiContext.px2vp(windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT).rightRect.width))
    if(canIUse('SystemCapability.Window.SessionManager')){
      windowClass.setWindowDecorVisible(false);
      let height = windowClass.getWindowDecorHeight();
      AppStorage.setOrCreate('decorHeight', uiContext.px2vp(height));
    }

    LogUtil.info(`[${TAG}]`, 'Succeeded in initting window properties.');
  }

  setPageJump(page: string) {
    if (page){
      setTimeout((page:string) => {
        EventHelper.postFormJumpPage(page)
        LogUtil.info(`[${TAG}]`, 'targetPage: ' + page);
      }, 500, page);
    }
  }

  addListenerOrientationChange(windowStage: window.WindowStage, enable: boolean = true){
    this.setSystemBarEnabled(windowStage, enable)
    display.on('change', () => {
      LogUtil.info(`[${TAG}]`, 'Succeeded to change orientation.');
      this.setSystemBarEnabled(windowStage, enable)
      try {
        let displayW = display.getDefaultDisplaySync().width;
        let displayH = display.getDefaultDisplaySync().height;
        AppStorage.setOrCreate('displayW', displayW);
        AppStorage.setOrCreate('displayH', displayH);
      } catch (error) {
        LogUtil.info(`[${TAG}]`, `Failed to get display info, message: ${error.message}`)
      }
    })
  }

  deleteListenerOrientationChange(windowStage: window.WindowStage, enable: boolean = false){
    this.setSystemBarEnabled(windowStage, enable)
    display.off('change')
    LogUtil.info(`[${TAG}]`, 'Succeeded to delete orientation listener.');
  }

  setSystemBarEnabled(windowStage: window.WindowStage, enable: boolean = true){
    windowStage.getMainWindow((err: BusinessError, windowClass) => {
      const errCode: number = err.code;
      if (errCode) {
        LogUtil.info(`[${TAG}]`, `窗口资源已经释放，无需再设置导航栏状态`);
        return;
      }
      try {
        if(canIUse('SystemCapability.Window.SessionManager')){
          let promise = windowClass.setSpecificSystemBarEnabled('navigationIndicator', enable, true);
          promise.then(() => {
            if(enable){
              LogUtil.info(`[${TAG}]`, 'Succeeded in setting the system bar to be visible.');
            }else{
              LogUtil.info(`[${TAG}]`, 'Succeeded in setting the system bar to be invisible.');
            }
          }).catch((err: BusinessError) => {
            LogUtil.error(`[${TAG}]`, `Failed to set the system bar to be invisible. Cause code: ${err.code}, message: ${err.message}`);
          });
        }
      } catch (exception) {
        LogUtil.error(`[${TAG}]`, `Failed to set the system bar to be invisible. Cause code: ${exception.code}, message: ${exception.message}`);
      }
    });
  }

  setWindowScreenOn(windowStage: window.WindowStage, isKeepScreenOn: boolean){
    windowStage.getMainWindow().then((windowClass) => {
      try {
        windowClass.setWindowKeepScreenOn(isKeepScreenOn, (err: BusinessError) => {
          const errCode: number = err.code;
          if (errCode) {
            LogUtil.error(`[${TAG}]`, `Failed to set the screen to be always on. Cause code: ${err.code}, message: ${err.message}`);
            return;
          }
          LogUtil.info(`[${TAG}]`, `Succeeded in setting the screen to be always on: ${isKeepScreenOn}.`);
        });
      } catch (exception) {
        LogUtil.error(`[${TAG}]`, `Failed to set the screen to be always on. Cause code: ${exception.code}, message: ${exception.message}`);
      }
    })
  }

  setWindowFullScreen(windowClass: window.Window, isKeepScreenFull: boolean){
    windowClass.setWindowLayoutFullScreen(isKeepScreenFull).then(() => {
      if(isKeepScreenFull){
        LogUtil.info(`[${TAG}]`, `Succeeded in setting the window to be full screen: ${isKeepScreenFull}.`);
      }else{
        LogUtil.info(`[${TAG}]`, `Succeeded in setting the window to be full screen: ${isKeepScreenFull}.`);
      }
    }).catch((err: BusinessError) => {
      LogUtil.error(`[${TAG}]`, `Failed to set the window to be full screen. Cause code: ${err.code}, message: ${err.message}`);
    });
  }

  setWindowStatus(windowClass: window.Window){
    if(canIUse('SystemCapability.Window.SessionManager')) {
      let windowStatus: window.WindowStatusType = windowClass.getWindowStatus()
      AppStorage.setOrCreate<window.WindowStatusType>('windowStatus', windowStatus)

      windowClass.on('windowStatusChange', (windowStatus: window.WindowStatusType) => {
        if(windowStatus === window.WindowStatusType.FLOATING){
          AppStorage.setOrCreate('windowStatus', 'FLOATING')
        }
        if(windowStatus === window.WindowStatusType.FULL_SCREEN){
          AppStorage.setOrCreate('windowStatus', 'FULL_SCREEN')
        }
        LogUtil.info(`[${TAG}]`, `WindowStatus Change: ${windowStatus}.`);
      })
    }
  }

  createLyricsFloatWindow(): void {
    if(this.lyricsFloatWindow) return
    let config: window.Configuration = {
      name: 'SBLyrics',
      windowType: window.WindowType.TYPE_FLOAT,
      ctx: getContext(this)
    };

    window.createWindow(config, async (err, data) => {
      if (err.code) {
        ToastUtil.showToast(`开启悬浮窗失败: code-${err.code}`)
        LogUtil.error(`[${TAG}]`, 'Failed to create the floatWindow. Cause: ' + JSON.stringify(err));
        return;
      }
      this.lyricsFloatWindow = data;
      await this.lyricsFloatWindow.setUIContent('pages/FloatLyrics')
      const uiContext = data.getUIContext()
      let settingData = PreferencesCache.statusBarLyricsSetting()
      let displayW = display.getDefaultDisplaySync().width;
      let displayH = display.getDefaultDisplaySync().height;
      const showWidth = settingData.width*displayW-uiContext.vp2px(8)
      const showHeight = uiContext.vp2px(settingData.fontSize+8)
      this.lyricsFloatWindow.resize(showWidth, showHeight);
      const offsetX_1 = settingData.x*displayW + uiContext.vp2px(4)
      const offsetX_2 = settingData.x*displayW - showWidth - uiContext.vp2px(4)
      const offsetX = Math.min(offsetX_1, Math.max(uiContext.vp2px(4), offsetX_2))
      const offsetY_1 = settingData.y*displayH
      const offsetY_2 = settingData.y*displayH - showHeight
      const offsetY = Math.min(offsetY_1, Math.max(0, offsetY_2))
      this.lyricsFloatWindow.moveWindowToGlobal(offsetX, offsetY);
      this.lyricsFloatWindow.setWindowBackgroundColor("#00000000")
      this.lyricsFloatWindow.setWindowTouchable(false)
      this.lyricsFloatWindow.setWindowFocusable(false)
      this.lyricsFloatWindow.showWindow()

      LogUtil.info(`[${TAG}]`, 'Successfully created the floating window. Data: ' + JSON.stringify(data));
    });
  }

  destroyLyricsFloatWindow(): void {
    if(!this.lyricsFloatWindow) return
    this.lyricsFloatWindow.destroyWindow(() => {
      this.lyricsFloatWindow = undefined
      LogUtil.info(`[${TAG}]`, 'Successfully destroyed the floating window.');
    })
  }

  getLyricsFloatWindow(): window.Window {
    let resultWindow: window.Window | undefined = undefined
    if(this.lyricsFloatWindow) {
      resultWindow = this.lyricsFloatWindow
    } else {
      this.createLyricsFloatWindow()
      try {
        resultWindow = window.findWindow('SBLyrics')
      } catch (error) {
        LogUtil.error(`[${TAG}]`, 'Failed to find the floating window. Cause: ' + JSON.stringify(error))
      }
    }
    return resultWindow as window.Window
  }

}

export default new WindowUtil()