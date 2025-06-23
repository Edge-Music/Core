import { BusinessError } from "@kit.BasicServicesKit";
import { common } from "@kit.AbilityKit";

class ResourceManager {

  private static context: Context

  init(context: common.UIAbilityContext){
    ResourceManager.context = context
  }

  getStringArrayValueSync(res: Resource): string[] {
    let result: string[] = []
    try {
      result = ResourceManager.context.resourceManager.getStringArrayValueSync(res.id);
    } catch (error) {
      let code = (error as BusinessError).code;
      let message = (error as BusinessError).message;
      console.error(`getStringArrayValueSync failed, error code: ${code}, message: ${message}.`);
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
      console.error(`getStringArrayValueSync failed, error code: ${code}, message: ${message}.`);
    } finally {
      return result
    }
  }

}

export default new ResourceManager()