import { abilityAccessCtrl, common, Permissions } from "@kit.AbilityKit";
import { LogUtil } from "@pura/harmony-utils";
const TAG = 'PermissionManager'

export async function reqPermissionsFromUser(permissions: Array<Permissions>, context: common.UIAbilityContext): Promise<boolean> {
  let result: boolean = true
  let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  // requestPermissionsFromUser会判断权限的授权状态来决定是否唤起弹窗。
  atManager.requestPermissionsFromUser(context, permissions).then((data) => {
    let grantStatus: Array<number> = data.authResults;
    let length: number = grantStatus.length;
    for (let i = 0; i < length; i++) {
      if (grantStatus[i] === 0) {
        // 用户授权，可以继续访问目标操作。
      } else {
        // 用户拒绝授权，提示用户必须授权才能访问当前页面的功能，并引导用户到系统设置中打开相应的权限。
        result = false
      }
    }
  }).catch((err: BusinessError<Error>) => {
    LogUtil.error(`[${TAG}]`, `Failed to request permissions from user. Code is ${err.code}, message is ${err.message}`);
  });
  return result
}