import { window } from '@kit.ArkUI';

export function screen_on(windowStage: window.WindowStage, judge: boolean){
  try {
      windowStage.getMainWindow((err, data) => { // 获取window实例
        let windowClass = data;
        windowClass.setWindowKeepScreenOn(judge).catch(() => {
          console.error( 'screen_on ctrl error');
        })
      });
  } catch (exception) {
    console.error( 'judge' + JSON.stringify(exception));
  }
}
