import { StyleConstants } from "../constants/StyleConstants";
import { Song } from "../type/Adapter";

@Component
export struct SongInfo {
  song: Song | null = null;
  showBorder: boolean = true;
  onTap?: (song: Song) => void;
  @Prop active: boolean = false;
  @Prop disabled: boolean = false;
  @Prop index: number = 0;
  @Prop showIndex: boolean = true;
  @Watch('updateHighlightState') @Prop highlight: boolean = false; // 新增高亮参数
  @BuilderParam rightSlot?: () => void;
  @State On_Mouse:boolean =false
  // 用于高亮动画的状态变量
  @State private isHighlighting: boolean = false;

  // 监听highlight属性变化
  aboutToAppear() {
    this.updateHighlightState();
  }

  updateHighlightState() {
    if (this.highlight) {
      this.isHighlighting = true;
      // 高亮持续1.5秒后自动消失
      setTimeout(() => {
        this.isHighlighting = false;
      }, 1500);
    }
  }

  private getTextColor(defaultColor: Resource) {
    if (this.disabled) {
      return $r('app.color.text_hint');
    }
    if (this.active) {
      return $r('app.color.text_click');
    }
    return defaultColor;
  }

  // 获取背景颜色
  private getBackgroundColor() {
    if (this.isHighlighting) {
      return 'rgba(100, 149, 237, 0.15)'; // 高亮背景色
    }
    return $r('app.color.setting_item_background');
  }

  // 获取边框颜色
  private getBorderColor() {
    if (this.isHighlighting) {
      return 'rgba(100, 149, 237, 0.4)'; // 高亮边框色
    } else if (!this.showBorder) {
      return Color.Transparent;
    }
    return $r('app.color.border_line');
  }

  build() {
    Column() {
      Row() {
        if (this.showIndex) {
          // 序号区域 - 扁平简约设计
          Text((this.index + 1).toString())
            .fontSize(15)
            .fontColor(this.getTextColor($r('app.color.text_secondary')))
            .fontWeight(FontWeight.Medium)
            .width(28)
            .textAlign(TextAlign.Center)
            .margin({ right: 16 })
        }

        // 歌曲信息区域
        Column({ space: 6 }) {
          // 歌曲名称（包含别名）
          Text() {
            Span(this.song?.name || '未知歌曲')
              .fontSize(16)
              .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
              .fontColor(this.getTextColor($r('app.color.text_title')))

            if (this.song && this.song.tns && this.song.tns.length > 0) {
              Span(` (${this.song.tns.join('/')})`)
                .fontSize(16)
                .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
                .fontColor(this.getTextColor($r('app.color.text_secondary')))
            }
          }
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 艺术家信息
          if (this.song && this.song.artists?.length > 0) {
            Text(this.song.artists.map(artist => artist.name).join(' / '))
              .fontSize(14)
              .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
              .fontColor(this.getTextColor($r('app.color.text_secondary')))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            Text('未知艺术家')
              .fontSize(14)
              .fontWeight(StyleConstants.FONT_WEIGHT_FOUR)
              .fontColor(this.getTextColor($r('app.color.text_secondary')))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 右侧插槽 - 简约处理
        if (this.rightSlot) {
          this.rightSlot()
        }
      }
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .width(StyleConstants.FULL_WIDTH)
      .height(68)
      .padding({ left: 16, right: 16 })
      .borderRadius(10)
      .onHover((isHover: boolean, event: HoverEvent)=>{
          this.On_Mouse =isHover
      })
      .backgroundColor(this.On_Mouse? 'rgba(100, 149, 237, 0.15)':this.getBackgroundColor())
      // .border({
      //   width: 1,
      //   color: this.getBorderColor(),
      //   style: BorderStyle.Solid
      // })
      .opacity(this.disabled ? 0.6 : 1)
      .animation({
        duration: 300,
        curve: Curve.EaseInOut,
        iterations: 1
      })
      .onClick(() => {
        if (!this.disabled && this.onTap && this.song) {
          this.onTap(this.song);
        }
      })
    }

    .width(StyleConstants.FULL_WIDTH)
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
    .expandSafeArea()
  }
}