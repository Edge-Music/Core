import { sensor } from "@kit.SensorServiceKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { LogUtil, ToastUtil } from "@pura/harmony-utils";
import RealTimeTrendDetector from "./RealTimeTrendDetector";
import { PreferencesCache } from "./PreferenceCache";

const TAG = 'SensorUtil'
class SensorUtil {

  onAccelerometer(){
    try {
      let isOnDoubleTap: string = PreferencesCache.getUserPreference('double_tap_switch_songs','0')
      let isOnFlipMute: string = PreferencesCache.getUserPreference('flip_mute','0')
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        // LogUtil.info(`[${TAG}]`, `Succeeded in invoking on. X: ${data.x}, Y:  ${data.y}, Z:  ${data.z}. (x^2+y^2+z^2): ${Math.pow(data.x, 2)+Math.pow(data.y, 2)+Math.pow(data.z, 2)}`)
        if(isOnDoubleTap === '1') {
          RealTimeTrendDetector.update(data.z)
        }
        if(isOnFlipMute === '1') {
          RealTimeTrendDetector.monitorPhoneOrientation(data.z)
        }
        // if(data.z < 0){
        //   LogUtil.info(`[${TAG}]`, `这里有一个z的负值：${data.z}`);
        // }
        // LogUtil.info(`${Date.now()} ${data.z} `);
        // ToastUtil.showToast(`当前加速度方向: ${data.z}`)
      }, { interval: 100000000 });
      LogUtil.info(`[${TAG}]`, 'Succeeded in invoking on');
    } catch (error) {
      let e: BusinessError = error as BusinessError;
      LogUtil.error(`[${TAG}]`, `Failed to invoke on. Code: ${e.code}, message: ${e.message}`);
    }
  }

  offAccelerometer(){
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
      LogUtil.info(`[${TAG}]`, 'Succeeded in invoking off');
    } catch (error) {
      let e: BusinessError = error as BusinessError;
      console.error(`[${TAG}]`, `Failed to invoke off. Code: ${e.code}, message: ${e.message}`);
    }
  }
}

export default new SensorUtil()