import { HdsNavDestination, HdsNavDestinationAttribute, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';

@Builder
export function  EQ_Choose(){
      EQ()
}
@Entry
@ComponentV2
struct EQ {
  @Local message: string = 'Audio Equalizer';
  @Local sliderValues: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  @Local AudioEqualizerShow:boolean = false
  // 频率标签数组
  private frequencyLabels: string[] = ['60', '125', '250', '500', '1K', '2K', '4K', '8K', '12K', '16K']

  // 刻度值数组
  private scaleValues: number[] = [12, 5, 4, 3, 2, 1, 0, -1, -2, -3, -4, -5, -12]

  // 滑块高度
  private sliderHeight: number = 200

  // 获取刻度显示文本
  private getScaleDisplayText(scaleValue: number): string {
    if (scaleValue === 6) return '+6dB'
    if (scaleValue === 0) return '0dB'
    if (scaleValue === -6) return '-6dB'
    return '-'
  }
  //TODO：：增加页面初始化获取均衡器各个值，如果自定义则使能均衡器，不是自定义就弄个透明遮罩啥的盖住均衡器（这个我也没实现）
  @Builder
  EQ_Choose_build(){
    Column(){
      // 滑块控制区域
      Row() {

        Column() {


          // 滑块行 - 整体高度与刻度区域对齐
          Row() {
            Column() {
              // 左侧刻度标签 - 精确对齐滑块位置
              ForEach(this.scaleValues, (scaleValue: number) => {
                Text(this.getScaleDisplayText(scaleValue))
                  .fontSize(11)
                  .fontColor('#666666')
                  .textAlign(TextAlign.Start)

              })
            }
            ForEach(this.frequencyLabels, (label: string, index: number) => {
              Column() {
                // 当前值显示
                Text(`${this.sliderValues[index] > 0 ? '+' : ''}${this.sliderValues[index]}`)
                  .fontSize(12)
                  .fontColor('#4169E1')
                  .fontWeight(FontWeight.Bold)
                  .margin({ bottom: 8 })

                // 垂直滑块
                Slider({
                  value: this.sliderValues[index],
                  style: SliderStyle.OutSet,
                  direction: Axis.Vertical,
                  step: 1,
                  min: -12,
                  max: 12,
                  reverse:true
                })
                  .height(this.sliderHeight)
                  .blockColor('#191970')
                  .trackColor('#E6E6E6')
                  .selectedColor('#4169E1')
                  // .showTips(true)
                  .onChange((value: number) => {
                    this.sliderValues[index] = value;
                    console.info(`Frequency ${label}: ${value > 0 ? '+' : ''}${value}dB`);
                  })
                Text(this.frequencyLabels[index])
                  .fontSize(12)
                  .fontColor('#4169E1')
                  .fontWeight(FontWeight.Bold)
                  .margin({ top: 8 })
              }
              .alignItems(HorizontalAlign.Center)
              .layoutWeight(1)
              .margin({ left: 4, right: 4 })
            })
          }
          .width('100%')
          .height(this.sliderHeight + 80) // 包含滑块上方空间
          .justifyContent(FlexAlign.SpaceAround)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Top)
      .backgroundColor($r('app.color.card_background_two'))

      // 控制按钮区域
      Row() {
        Button('重置')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .borderRadius(8)
          .padding({ left: 24, right: 24, top: 12, bottom: 12 })
          .onClick(() => {
            this.sliderValues = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            this.message = 'Audio Equalizer - Reset';
          })
          .margin({ right: 16 })

        Button('应用')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#4169E1')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .padding({ left: 32, right: 32, top: 12, bottom: 12 })
          .onClick(() => {
            this.message = 'Audio Equalizer - Applied!';
            //TODO:: 需要应用的保存逻辑
          })
      }
      .margin({ top: 32, bottom: 40 })
      .justifyContent(FlexAlign.Center)
    }
  }


  build() {
    HdsNavDestination(){
      Column(){
        Blank().height(56)
        //TODO::最好是加个列表选择默认音质，然后选择自定义音质时显示下面这个
        this.EQ_Choose_build()

      }
        }.titleMode(HdsNavDestinationTitleMode.MODAL)
    .hideBackButton(true)
    .titleBar({

      content: {
        title:{
          mainTitle:'音效'
        }
      }

    })
    .backgroundColor($r('app.color.page_background'))
  }

}