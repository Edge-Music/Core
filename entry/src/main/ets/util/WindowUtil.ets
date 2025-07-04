import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { PipManager } from './PipManager';
import { EventHelper } from './EventHelper';
import { LogUtil } from '@pura/harmony-utils';

const TAG = 'WindowUtil'
class WindowUtil {

  setPipManager(windowStage: window.WindowStage) {
    if (!windowStage) return;
    windowStage.getMainWindow().then((window) => {
      let ctx = window.getUIContext();
      // 通过主窗口UIContext创建typeNode节点
      PipManager.getInstance().makeTypeNode(ctx);
      LogUtil.info(`[${TAG}]`, 'Succeeded in create typeNode.');
    })
  }

  setWindowListeners(windowStage: window.WindowStage) {
    if (!windowStage) return;
    windowStage.getMainWindow().then((windowClass) => {
      const uiContext = windowClass.getUIContext()
      // 监听窗口尺寸变化
      windowClass.on('windowSizeChange', (windowSize) => {
        AppStorage.setOrCreate('winWidth', uiContext.px2vp(windowSize.width));
        AppStorage.setOrCreate('winHeight', uiContext.px2vp(windowSize.height));
        AppStorage.setOrCreate('winWidthWithPx', windowSize.width);
        AppStorage.setOrCreate('winHeightWithPx', windowSize.height);
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
    })
  }

  setWindowProperties(windowStage: window.WindowStage) {
    if (!windowStage) return;
    windowStage.getMainWindow().then((windowClass) => {
      const uiContext = windowClass.getUIContext()
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
      LogUtil.info(`[${TAG}]`, 'Succeeded in initting window properties.');
    })

  }

  setPageJump(page: string) {
    if (page){
      setTimeout((page:string) => {
        EventHelper.postFormJumpPage(page)
        LogUtil.info(`[${TAG}]`, 'targetPage: ' + page);
      }, 500, page);
    }
  }

  loadContent(windowStage: window.WindowStage) {
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
        let isVisible = false;
        // 调用setWindowDecorVisible接口
        try {
          const uiContext = windowClass.getUIContext()
          if(canIUse('SystemCapability.Window.SessionManager')){
            windowClass?.setWindowDecorVisible(isVisible);
            let height = windowClass?.getWindowDecorHeight();
            AppStorage.setOrCreate('decorHeight', uiContext.px2vp(height));
          }
        } catch (exception) {
          LogUtil.error(`[${TAG}]`, `Failed to set the visibility of window decor. Cause code: ${exception.code}, message: ${exception.message}`);
        }
      });
    })

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

  setWindowFullScreen(windowStage: window.WindowStage, isKeepScreenFull: boolean){
    windowStage.getMainWindow().then((windowClass) => {
      windowClass.setWindowLayoutFullScreen(isKeepScreenFull).then(() => {
        if(isKeepScreenFull){
          LogUtil.info(`[${TAG}]`, `Succeeded in setting the window to be full screen: ${isKeepScreenFull}.`);
        }else{
          LogUtil.info(`[${TAG}]`, `Succeeded in setting the window to be full screen: ${isKeepScreenFull}.`);
        }
      }).catch((err: BusinessError) => {
        LogUtil.error(`[${TAG}]`, `Failed to set the window to be full screen. Cause code: ${err.code}, message: ${err.message}`);
      });
    })
  }

  setWindowStatus(windowStage: window.WindowStage){
    if(canIUse('SystemCapability.Window.SessionManager')) {
      windowStage.getMainWindow().then((windowClass) => {
        let windowStatus: window.WindowStatusType = windowClass.getWindowStatus()
        AppStorage.setOrCreate<window.WindowStatusType>('windowStatus', windowStatus)

        windowClass.on('windowStatusChange', (windowStatus: window.WindowStatusType) => {
          AppStorage.setOrCreate('windowStatus', windowStatus)
        })
      })
    }
  }

}

export default new WindowUtil()