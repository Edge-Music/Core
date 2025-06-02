import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { PipManager } from './PipManager';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventHelper } from './EventHelper';
import { LogUtil } from '@pura/harmony-utils';

const TAG = 'WindowUtil'
class WindowUtil {

  setupPipManager(windowStage: window.WindowStage) {
    if (!windowStage) return;
    windowStage.getMainWindow().then((window) => {
      let ctx = window.getUIContext();
      // 通过主窗口UIContext创建typeNode节点
      PipManager.getInstance().makeTypeNode(ctx);
      LogUtil.info(`[${TAG}]`, 'Succeeded in create typeNode.');
    })
  }

  setupWindowListeners(windowStage: window.WindowStage) {
    if (!windowStage) return;
    windowStage.getMainWindow().then((windowClass) => {
      // 监听窗口尺寸变化
      windowClass.on('windowSizeChange', (windowSize) => {
        AppStorage.setOrCreate('winWidth', windowSize.width);
        AppStorage.setOrCreate('winHeight', windowSize.height);
        LogUtil.info(`[${TAG}]`, 'Succeeded in adding windowSizeChange listener.');
      });

      // 监听避让高度变化
      windowClass.on('avoidAreaChange', (avoidArea) => {
        if (avoidArea.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate('topRect', avoidArea.area.topRect.height);
        } else if (avoidArea.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate('bottomRect', avoidArea.area.bottomRect.height);
        }
        LogUtil.info(`[${TAG}]`, 'Succeeded in adding avoidAreaChange listener.');
      });
    })
  }

  setupWindowProperties(windowStage: window.WindowStage) {
    if (!windowStage) return;
    windowStage.getMainWindow().then((windowClass) => {
      // 获取窗口尺寸，存入AppStorage
      AppStorage.setOrCreate('winWidth', windowClass.getWindowProperties().windowRect.width);
      AppStorage.setOrCreate('winHeight', windowClass.getWindowProperties().windowRect.height);
      // 获取避让高度，存入AppStorage
      AppStorage.setOrCreate('topRect', windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height);
      AppStorage.setOrCreate('bottomRect', windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height);

      LogUtil.info(`[${TAG}]`, 'Succeeded in initting window properties.');
    })

  }

  setupPageJump(page: string) {
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
          if(canIUse('SystemCapability.Window.SessionManager')){
            windowClass?.setWindowDecorVisible(isVisible);
            let height = windowClass?.getWindowDecorHeight();
            AppStorage.setOrCreate('decorHeight', height);
          }
        } catch (exception) {
          LogUtil.error(`[${TAG}]`, `Failed to set the visibility of window decor. Cause code: ${exception.code}, message: ${exception.message}`);
        }
      });
    })

  }

}

export default new WindowUtil()