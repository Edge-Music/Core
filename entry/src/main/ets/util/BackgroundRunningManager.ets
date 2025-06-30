import { Context, wantAgent } from "@kit.AbilityKit"
import { backgroundTaskManager } from "@kit.BackgroundTasksKit"
import { LogUtil } from "@pura/harmony-utils";

const TAG = 'BackgroundRunningManager';

class BackgroundRunningManager {
  // 申请长时任务
  async startBackgroundRunning(ctx?: Context) {
    try {

      // 获取 bundle 应用信息
      // const bundleInfo = bundleManager.getBundleInfoForSelfSync(
      //   bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      // )

      // // 通过wantAgent模块下getWantAgent方法获取WantAgent对象
      // const wantAgentObj = await wantAgent.getWantAgent({
      //   wants: [{ bundleName: bundleInfo.name, abilityName: "EntryAbility" }],
      //   requestCode: 0,
      // })

      // // 创建后台任务
      // await backgroundTaskManager.startBackgroundRunning(
      //   context,
      //   backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
      //   wantAgentObj
      // )

      let wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: "zone.yby.seamusic",
            abilityName: "EntryAbility",
          },
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
      }

      const wantObj = await wantAgent.getWantAgent(wantAgentInfo)
      await backgroundTaskManager.startBackgroundRunning(
        ctx,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        wantObj
      )
      LogUtil.info(`[${TAG}]`, `长时任务申请成功`)
    } catch (error) {
      LogUtil.error(`[${TAG}]`, `长时任务申请失败, err.code: ${error.code}, err.message: ${error.message}`)
    }
  }

  // 停止后台任务
  async stopBackgroundRunning(ctx?: Context) {
    try {
      // 停止后台任务
      await backgroundTaskManager.stopBackgroundRunning(ctx)
      LogUtil.info(`[${TAG}]`, `长时任务停止成功`)
    } catch (error) {
      LogUtil.error(`[${TAG}]`, `长时任务停止失败, err.code: ${error.code}, err.message: ${error.message}`)
    }
  }
}

export const backgroundRunningManager = new BackgroundRunningManager()
