import { hdsEffect } from '@kit.UIDesignKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { emitter } from '@kit.BasicServicesKit'

const TAG = 'MyButtonModifier'
const DOMAIN = 0x0000

// 默认颜色，使用可见的颜色而非透明色
const DEFAULT_COLORS: Array<ResourceColor> = ['#FF6B6B', '#4ECDC4', '#45B7D1']

// Emitter 事件 ID
const UV_COLOR_UPDATE_EVENT_ID: number = 10086

/**
 * 自定义按钮/列效果修饰器
 * 用于 API 20+ 设备的 UV 背景流光效果
 * 注意：此文件只能在 API 20+ 设备上动态导入使用
 */
export class MyButtonModifier implements AttributeModifier<ColumnAttribute> {
  // 可以实现一个Modifier，定义私有的成员变量，外部可动态修改
  isApi20: boolean = false
  is_need: boolean = false
  Ctrl_vision: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController()
  // 当前使用的颜色，可以通过构造函数传入或动态更新
  colors: Array<ResourceColor> = DEFAULT_COLORS

  // 通过构造函数，创建时传参
  constructor(isApi20?: boolean, Ctrl_vision?: hdsEffect.ShaderEffectController, is_need?: boolean, colors?: Array<ResourceColor>) {
    this.is_need = is_need ?? false
    this.isApi20 = isApi20 ?? false
    this.colors = colors ?? DEFAULT_COLORS

    hilog.info(DOMAIN, TAG, `Constructor called: isApi20=${this.isApi20}, is_need=${this.is_need}, colors=${JSON.stringify(this.colors)}`)

    if (Ctrl_vision) {
      this.Ctrl_vision = Ctrl_vision
      // 使用传入的颜色更新控制器参数
      this.Ctrl_vision.setEffectParams({ colorSource: this.colors })
    } else {
      // 创建新的控制器并设置颜色
      this.Ctrl_vision = new hdsEffect.ShaderEffectController()
      this.Ctrl_vision.setEffectParams({ colorSource: this.colors })
      hilog.info(DOMAIN, TAG, `Created new ShaderEffectController with colors: ${JSON.stringify(this.colors)}`)
    }

    // 注册 emitter 监听器，监听颜色更新事件
    this.registerColorUpdateListener()
  }

  /**
   * 注册颜色更新事件监听器
   */
  private registerColorUpdateListener(): void {
    hilog.info(DOMAIN, TAG, `Registering color update listener for eventId: ${UV_COLOR_UPDATE_EVENT_ID}`)

    const innerEvent: emitter.InnerEvent = {
      eventId: UV_COLOR_UPDATE_EVENT_ID
    }

    emitter.on(innerEvent, (eventData: emitter.EventData) => {
      hilog.info(DOMAIN, TAG, `Received color update event: ${JSON.stringify(eventData)}`)

      if (eventData.data) {
        const data = eventData.data as Record<string, Object>
        if (data.colors) {
          const newColors = data.colors as Array<ResourceColor>
          this.colors = newColors

          hilog.info(DOMAIN, TAG, `Updating UV background colors: ${JSON.stringify(newColors)}`)

          try {
            // 停止当前动画
            this.Ctrl_vision.stop()
            // 更新控制器参数
            this.Ctrl_vision.setEffectParams({ colorSource: newColors })
            // 重新播放动画
            this.Ctrl_vision.play()

            hilog.info(DOMAIN, TAG, `UV background colors updated successfully via emitter`)
          } catch (error) {
            hilog.error(DOMAIN, TAG, `Failed to update colors via emitter: ${JSON.stringify(error)}`)
          }
        }
      }
    })

    hilog.info(DOMAIN, TAG, `Color update listener registered`)
  }

  applyNormalAttribute(instance: ColumnAttribute): void {
    hilog.info(DOMAIN, TAG, `applyNormalAttribute called: isApi20=${this.isApi20}, is_need=${this.is_need}, colors=${JSON.stringify(this.colors)}`)

    // instance为Button的属性对象，可以通过instance对象对属性进行修改
    if (this.isApi20 && this.is_need) {
      hilog.info(DOMAIN, TAG, `Applying UV background effect with colors: ${JSON.stringify(this.colors)}`)

      try {
        instance.visualEffect(new hdsEffect.HdsEffectBuilder()
          .shaderEffect({
            effectType: hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT,
            animation: {
              duration: 5000,
              iterations: -1,
              autoPlay: true,
              onFinish: () => {
                hilog.info(DOMAIN, TAG, 'Animation finished, calling play()')
                this.Ctrl_vision.play()
              }
            },
            params: { colorSource: this.colors },
            controller: this.Ctrl_vision
          })
          .buildEffect())

        hilog.info(DOMAIN, TAG, `UV background effect applied successfully`)
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Failed to apply UV background effect: ${JSON.stringify(error)}`)
      }
    } else {
      hilog.info(DOMAIN, TAG, `Skipping UV background effect (isApi20=${this.isApi20}, is_need=${this.is_need})`)
    }
  }
}

/**
 * 获取颜色更新事件 ID
 */
export function getColorUpdateEventId(): number {
  return UV_COLOR_UPDATE_EVENT_ID
}

/**
 * 创建 ShaderEffectController 实例
 * 用于在 Playing.ets 中初始化控制器
 */
export function createShaderEffectController(): hdsEffect.ShaderEffectController {
  hilog.info(DOMAIN, TAG, 'Creating new ShaderEffectController')
  const controller = new hdsEffect.ShaderEffectController()
  // 设置默认可见颜色
  controller.setEffectParams({ colorSource: ['#FF6B6B', '#4ECDC4', '#45B7D1'] })
  return controller
}

/**
 * 设置控制器的效果参数
 */
export function setControllerParams(controller: hdsEffect.ShaderEffectController, colorSource: Array<ResourceColor>): void {
  hilog.info(DOMAIN, TAG, `Setting controller params with colors: ${JSON.stringify(colorSource)}`)
  controller.setEffectParams({ colorSource: colorSource })
}

