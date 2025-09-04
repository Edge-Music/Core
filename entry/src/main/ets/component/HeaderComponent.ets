import { StyleConstants } from "../constants/StyleConstants"
import { curves } from "@kit.ArkUI"
import { PreferencesCache } from "../util/PreferenceCache"
import { LogUtil } from "@pura/harmony-utils"

const BOUNCE_OFFSET: number = 20
const TAG = 'HeaderComponent'
@Component
export struct HeaderComponent {

  @StorageProp('topRect') @Watch('onChangedRect') topRect: number = 0
  @StorageProp('decorHeight') @Watch('onChangedRect') decorHeight: number = 0
  @StorageProp('winHeight') @Watch('onChangedRect') winHeight: number = 0
  @StorageProp('slide_up_hide_title') @Watch('onChangedRect') hideTitle: string = PreferencesCache.getUserPreference('slide_up_hide_title', '0')
  @StorageProp('current_height_breakpoint') heightBreakpoint: HeightBreakpoint = HeightBreakpoint.HEIGHT_SM

  private readonly SHOW_THRESHOLD: number = 10; // 显示需要的下拉距离

  @Link @Watch('getShowTitle') scrollOffsetY: number
  @Link startScrollOffsetY: number
  @Prop hasHeaderBuilder: boolean = false
  @State showTitle: boolean = true
  @State translateY: number = -BOUNCE_OFFSET
  @State HIDE_THRESHOLD: number = (this.topRect > this.decorHeight ? this.topRect : this.decorHeight) + StyleConstants.TITLE_HEIGHT; // 开始隐藏的阈值
  @State backHeight: number = this.HIDE_THRESHOLD + BOUNCE_OFFSET
  @State headerBuilderHeight: number = 0

  @BuilderParam titleBuilder: () => void
  @BuilderParam headerBuilder: () => void

  aboutToAppear(): void {

  }

  onChangedRect() {
    LogUtil.info(`[${TAG}]`, `decorHeight: ${this.decorHeight} topRect: ${this.topRect}`)
    this.showTitle = true
    this.HIDE_THRESHOLD = (this.topRect > this.decorHeight ? this.topRect : this.decorHeight) + StyleConstants.TITLE_HEIGHT
    this.backHeight = this.HIDE_THRESHOLD + BOUNCE_OFFSET
    this.translateY = -BOUNCE_OFFSET
  }

  build() {
    Column() {
      Column()
        .width('100%')
        .height(this.backHeight)
        .linearGradientBlur(BlurStyle.BACKGROUND_ULTRA_THICK, {
          fractionStops: [
            [0.00, 0.00],
            [0.80, 0.20],
            [1.00, 0.80],
            [1.00, 1.00]
          ],
          direction: GradientDirection.Top
        })
        .linearGradient({
          angle: 0,
          colors: [
            [$r('app.color.title_head_start'), 0.0],
            [$r('app.color.page_background'), 1.0]
          ]
        })
        .zIndex(0)
        .translate({ y: this.translateY })

      // 标题内容层
      Column() {
        this.titleBuilder() // 使用传入的构建器
      }
      .zIndex(1)
      .translate({ y: this.translateY - this.HIDE_THRESHOLD })

      if(this.hasHeaderBuilder) {
        Column() {
          this.headerBuilder() // 使用传入的构建器
        }
        .zIndex(2)
        .visibility(this.hasHeaderBuilder ? Visibility.Visible : Visibility.None)
        .translate({ y: this.showTitle ? this.translateY - this.HIDE_THRESHOLD : this.translateY - this.HIDE_THRESHOLD + this.topRect })
      }
    }
    .alignItems(HorizontalAlign.End)
    .hitTestBehavior(HitTestMode.None)
    .position({ x: 0, y: 0 })

  }

  getShowTitle(): void {
    if(this.hideTitle === '1' || this.heightBreakpoint <= HeightBreakpoint.HEIGHT_MD) {
      if(this.scrollOffsetY > this.HIDE_THRESHOLD && this.scrollOffsetY - this.startScrollOffsetY >= this.SHOW_THRESHOLD) {
        this.startScrollOffsetY = this.scrollOffsetY
        if(this.showTitle) {
          this.getUIContext().animateTo({
            duration: 800,
            curve: curves.springCurve(1, 1, 100, 18),
            onFinish: () => {
            }
          }, () => {
            this.showTitle = false
            this.translateY = -this.HIDE_THRESHOLD - BOUNCE_OFFSET
          })
        }
      } else if(this.scrollOffsetY - this.startScrollOffsetY <= -this.SHOW_THRESHOLD) {
        this.startScrollOffsetY = this.scrollOffsetY
        if(!this.showTitle) {
          this.getUIContext().animateTo({
            duration: 800,
            // curve: curves.cubicBezierCurve(0.5, 1.5, 0.7, 1.0),
            curve: curves.springCurve(1, 1, 200, 18),
          }, () => {
            this.showTitle = true
            this.translateY = -BOUNCE_OFFSET
          })
        }
      }
    }
  }
}