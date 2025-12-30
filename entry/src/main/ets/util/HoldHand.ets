import { motion } from "@kit.MultimodalAwarenessKit";
import { BusinessError } from '@kit.BasicServicesKit'
export function startHoldingHand(context:UIContext){
  let callback:Callback<motion.HoldingHandStatus> = (data:motion.HoldingHandStatus) => {
    console.info('callback succeeded' + data);
    context.animateTo({
      duration: 200,
      curve: Curve.Friction,
      // delay: 500,
      // iterations: -1, // 设置-1表示动画无限循环
      playMode: PlayMode.Alternate,
      expectedFrameRateRange: {
        min: 10,
        max: 120,
        expected: 60,
      }
    }, () => {
      AppStorage.setOrCreate('hand',data)
      // hand = data // 1左 2 右
    })
    let hand_timer:number = AppStorage.get('hand_timer') ??0

    clearInterval(hand_timer)

    hand_timer = setInterval(()=>{
      context.animateTo({
        duration: 200,
        curve: Curve.Friction,
        // delay: 500,
        // iterations: -1, // 设置-1表示动画无限循环
        playMode: PlayMode.Alternate,
        expectedFrameRateRange: {
          min: 10,
          max: 120,
          expected: 60,
        }
      }, () => {
        AppStorage.setOrCreate('hand',0)
      })
    },5000)
    AppStorage.setOrCreate('hand_timer',hand_timer)



  };
  try {
    if (canIUse("SystemCapability.MultimodalAwareness.Motion")) {

      motion.on('holdingHandChanged', callback);
    } else {
      // Fallback for unsupported SystemCapability
    }
    console.info("jizhishi 11 on succeeded");
  } catch (err) {
    let error = err as BusinessError;
    console.error("Failed on and err code is " + error.code);
  }
}
export function stopHoldingHand(){

  try {
    motion.off('holdingHandChanged')
    console.info("jizhishi debug holdingHandChanged is off");

  }catch (e){
    //TODO:: HMOS!!!! 炸了就炸了。
  }
}