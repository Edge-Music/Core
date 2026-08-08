import { motion } from "@kit.MultimodalAwarenessKit";
import { BusinessError } from '@kit.BasicServicesKit'

// 注册幂等守卫：motion.on 会叠加回调，重复注册后同一次握持会触发多次窗口移动；
// 同时让 onForeground 可以无条件调用 startHoldingHand 来确保监听存在
let registered: boolean = false
// 独立持有 UIContext：onForeground 早于页面 aboutToAppear，先以无 context 完成注册，
// 页面挂载后再把 context 补进来，回调始终读取这个最新值
let uiContext: UIContext | undefined = undefined

/**
 * 注册智感握持监听：结果（1 = 左手，2 = 右手）写入 AppStorage 'hand'，
 * 由 MultiFuncSubWindow 监听并把悬浮球移到对应手侧。
 * @param context 可选，仅用于给悬浮球移动补一段动画；缺省时直接写状态
 */
export function startHoldingHand(context?: UIContext) {
  if (context) {
    uiContext = context
  }
  if (registered) {
    return
  }
  if (!canIUse("SystemCapability.MultimodalAwareness.Motion")) {
    return
  }

  const callback: Callback<motion.HoldingHandStatus> = (data: motion.HoldingHandStatus) => {
    if (uiContext) {
      uiContext.animateTo({
        duration: 200,
        curve: Curve.Friction,
        playMode: PlayMode.Alternate,
        expectedFrameRateRange: {
          min: 10,
          max: 120,
          expected: 60,
        }
      }, () => {
        AppStorage.setOrCreate('hand', data)
      })
    } else {
      AppStorage.setOrCreate('hand', data)
    }
  };

  try {
    motion.on('holdingHandChanged', callback);
    registered = true
    console.info("[HoldHand] holdingHandChanged registered");
  } catch (err) {
    let error = err as BusinessError;
    console.error("[HoldHand] register failed, code: " + error.code);
  }
}

export function stopHoldingHand() {
  try {
    motion.off('holdingHandChanged')
    console.info("[HoldHand] holdingHandChanged is off");
  } catch (e) {
    // 未注册过时 off 会抛错，忽略
  }
  registered = false
}
