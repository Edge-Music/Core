import { window } from '@kit.ArkUI';

export function  screen_on(judge:boolean,st_judge:boolean=false){
  try {
      window.getLastWindow(getContext(), (err, data) => { // 获取window实例
        let windowClass = data;
        windowClass.setWindowKeepScreenOn(judge)
      });
  } catch (exception) {
    console.error( 'judge' + JSON.stringify(exception));
  }
}
