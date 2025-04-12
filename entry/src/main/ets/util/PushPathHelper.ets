import { DialogHelper } from "@pura/harmony-dialog";
import { ClickUtil, LogUtil } from "@pura/harmony-utils";

const TAG = "PushPathHelper";

/**
 * 跳转页面辅助类
 */
export class PushPathHelper {

  /**
   * 跳转页面
   * @param name 页面名称
   * @param beforeFn 在跳转之前执行的函数
   * @param afterFn 在跳转之后执行的函数
   */
  static async pushPathWithoutLoading(pathStack: NavPathStack, name: string, beforeFn?: (() => void) | (() => Promise<void>),
    afterFn?: () => void) {
    ClickUtil.debounce(async () => {
      if (beforeFn) {
        try {
          await Promise.resolve(beforeFn());
        } catch (error) {
        }
      }
      pathStack.pushPath({ name })

      if (afterFn) {
        afterFn();
      }
    }, 500, name)
  }

  /**
   * 跳转优先
   * @param name 页面名称
   * @param beforeFn 在跳转之前执行的函数
   * @param afterFn 在跳转之后执行的函数
   */
  static async pushPathImmediately(pathStack: NavPathStack, name: string,
    beforeFn?: (() => void) | (() => Promise<void>),
    afterFn?: () => void) {
    pathStack.pushPath({ name })
    if (beforeFn) {
      try {
        await Promise.resolve(beforeFn());
      } catch (error) {
        LogUtil.error(TAG, "pushPathImmediately failed");
      }
    }
    if (afterFn) {
      afterFn();
    }
  }

  /**
   * 跳转页面
   * @param name 页面名称
   * @param beforeFn 在跳转之前执行的函数
   * @param afterFn 在跳转之后执行的函数
   */
  static async pushPath(pathStack: NavPathStack, name: string, beforeFn?: (() => void) | (() => Promise<void>),
    afterFn?: () => void) {
    ClickUtil.debounce(async () => {
      const dialogId = DialogHelper.showLoadingDialog({
        loadColor: Color.Black,
        backgroundColor: Color.White
      });

      if (beforeFn) {
        try {
          await Promise.resolve(beforeFn());
        } catch (error) {
        }
      }

      pathStack.pushPath({ name })

      if (afterFn) {
        afterFn();
      }

      DialogHelper.closeDialog(dialogId);

    }, 500, name)
  }

  static async loading(name: string, beforeFn?: (() => void) | (() => Promise<void>),
    afterFn?: () => void) {
    ClickUtil.debounce(async () => {
      const dialogId = DialogHelper.showLoadingDialog({
        loadColor: Color.Black,
        backgroundColor: Color.White
      });

      if (beforeFn) {
        try {
          await Promise.resolve(beforeFn());
        } catch (error) {
        }
      }

      if (afterFn) {
        afterFn();
      }

      DialogHelper.closeDialog(dialogId);

    }, 500, name)
  }
}