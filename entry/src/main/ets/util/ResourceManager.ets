import { BusinessError } from "@kit.BasicServicesKit";
import { common } from "@kit.AbilityKit";
import { resourceManager } from "@kit.LocalizationKit";
import { LogUtil } from "@pura/harmony-utils";
import { image } from "@kit.ImageKit";

const TAG = 'ResourceManager'
class ResourceManager {

  private static context: Context

  init(context: common.UIAbilityContext){
    ResourceManager.context = context
    this.setDeviceConfiguration()
  }

  getStringArrayValueSync(res: Resource): string[] {
    let result: string[] = []
    try {
      result = ResourceManager.context.resourceManager.getStringArrayValueSync(res.id);
    } catch (error) {
      let code = (error as BusinessError).code;
      let message = (error as BusinessError).message;
      LogUtil.error(`[${TAG}]`, `getStringArrayValueSync failed, error code: ${code}, message: ${message}.`);
    } finally {
      return result
    }
  }

  getStringValueSync(res: Resource): string {
    let result: string = ''
    try {
      result = ResourceManager.context.resourceManager.getStringSync(res.id)
    } catch (error) {
      let code = (error as BusinessError).code;
      let message = (error as BusinessError).message;
      LogUtil.error(`[${TAG}]`, `getStringArrayValueSync failed, error code: ${code}, message: ${message}.`);
    } finally {
      return result
    }
  }

  setDeviceConfiguration(){
    try {
      ResourceManager.context.resourceManager.getConfiguration().then((value: resourceManager.Configuration) => {
        AppStorage.setOrCreate<resourceManager.Configuration>('deviceConfiguration', value);
        AppStorage.setOrCreate<resourceManager.DeviceType>('deviceType', value.deviceType);
        LogUtil.info(`[${TAG}]`, `setDeviceConfiguration successfully: ${JSON.stringify(value)}}`)
      }).catch((error: BusinessError) => {
        LogUtil.info(`[${TAG}]`, `getConfiguration failed, error code: ${error.code}, message: ${error.message}.`)
      });
    } catch (error) {
      LogUtil.error(`[${TAG}]`, `getConfiguration failed, error code: ${(error as BusinessError).code}, message: ${(error as BusinessError).message}.`)
    }
  }

  getRawfilePixelMapSync(path: string): image.PixelMap {
    try {
      const BUFFER = ResourceManager.context.resourceManager.getRawFileContentSync(path);
      const IMAGE_SOURCE: image.ImageSource = image.createImageSource(BUFFER.buffer as ArrayBuffer);
      LogUtil.debug(TAG, `Get rawfile pixelMap path '${path}' successfully`);
      return IMAGE_SOURCE.createPixelMapSync();
    } catch (e) {
      LogUtil.error(TAG, `Get rawfile pixelMap path '${path}' failed, error: ${e}`);
      throw e as Error;
    }
  }

}

export default new ResourceManager()