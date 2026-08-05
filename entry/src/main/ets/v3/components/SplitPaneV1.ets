/**
 * SplitPaneV1 —— 响应式左右分栏容器（状态管理 V1 版本）
 *
 * 特性：
 * 1. 默认左右分栏并排展示两个自定义内容区（@BuilderParam 传入）；
 * 2. 编辑模式下在两栏中间悬浮显示可拖拽分隔条，实时调整两栏宽度比例；
 * 3. 支持左/右栏最小宽度约束，防止过度压缩；
 * 4. 容器总宽度小于阈值时自动降级为 Swiper 滑动分页模式，左右滑动切换内容；
 * 5. 布局模式切换带淡入淡出过渡，平滑切换；
 * 6. 支持收起右栏（rightCollapsed）：右栏不渲染、左栏占满全宽，仅分栏模式生效。
 *
 * 所有尺寸单位均为 vp。
 */

/** V1 版本配置项（Props 接口定义） */
export class SplitPaneV1Config {
  /** 左栏最小宽度（vp），默认 120 */
  minLeftWidth: number = 190;
  /** 右栏最小宽度（vp），默认 120 */
  minRightWidth: number = 120;
  /** 降级阈值（vp）：容器宽度小于该值时切换为滑动分页模式，默认 320 */
  collapseThreshold: number = 325;
  /** 初始左栏宽度占比（0~1），默认 0.5 */
  initialRatio: number = 0.5;
  /** 分隔条热区宽度（vp），默认 28 */
  handleWidth: number = 28;
  /** 滑动分页模式下是否显示指示点，默认 true */
  showIndicator: boolean = true;
}

@Component
export struct SplitPaneV1 {
  /** 左栏内容（必传） */
  @BuilderParam leftContent: () => void = this.defaultContent;
  /** 右栏内容（必传） */
  @BuilderParam rightContent: () => void = this.defaultContent;
  /** 滑动分页控制器 */
  @Require swiperController: SwiperController = new SwiperController();
  /** 配置项 */
  @Prop config: SplitPaneV1Config = new SplitPaneV1Config();
  /** 是否处于编辑模式（显示可拖拽分隔条） */
  @Prop isEditMode: boolean = false;
  /**
   * 左栏宽度占比（0~1，可选受控入参）。
   * 传入 >= 0 的值时组件进入受控模式：占比由外部持有（便于父组件持久化），
   * 拖拽仅通过 onRatioChange 通知外部更新；不传（默认 -1）时使用组件内部状态。
   */
  @Prop ratio: number = -1;
  /** 右栏是否收起（仅左右分栏模式生效）：收起后右栏不渲染，左栏占满全宽 */
  @Prop rightCollapsed: boolean = false;
  /** 占比变化回调（拖拽时触发），父组件在此更新数据源并做持久化 */
  onRatioChange: (ratio: number) => void = (_ratio: number) => {
  };
  /** 分隔条拖拽结束回调：父组件在此做持久化等收尾工作（与每帧的 onRatioChange 区分） */
  onDividerDragEnd: () => void = () => {
  };
  /** 滑动分页页码变化回调：父组件借此冻结离屏页的重动画（如歌词链式动画） */
  onSwipeIndexChange: (index: number) => void = (_index: number) => {
  };
  /** 容器当前宽度（vp），由 onAreaChange 测量 */
  @State private containerWidth: number = 0;
  /** 内部左栏宽度占比（0~1），仅在非受控模式下使用 */
  @State private innerRatio: number = 0.5;
  /** 当前是否为滑动分页模式 */
  @Link  isSwipeMode: boolean ;

  /** 拖拽起始时刻的左栏宽度，非状态变量避免多余刷新 */
  private dragStartLeftWidth: number = 0;

  @Builder
  defaultContent() {
  }

  aboutToAppear(): void {
    this.innerRatio = this.clampRatio(this.config.initialRatio);
  }

  /** 将占比限制在合法区间 */
  private clampRatio(value: number): number {
    if (value < 0.1) {
      return 0.1;
    }
    if (value > 0.9) {
      return 0.9;
    }
    return value;
  }

  /** 当前生效的占比：受控模式取外部值，否则取内部状态 */
  private effectiveRatio(): number {
    return this.ratio >= 0 ? this.clampRatio(this.ratio) : this.innerRatio;
  }

  /** 左栏实际宽度（vp），带最小宽度边界保护。注意：V1 组件中不能使用 getter，需用普通方法 */
  private calcLeftWidth(): number {
    if (this.containerWidth <= 0) {
      return 0;
    }
    const minLeft: number = this.config.minLeftWidth;
    const maxLeft: number = Math.max(minLeft, this.containerWidth - this.config.minRightWidth);
    const want: number = this.containerWidth * this.effectiveRatio();
    return Math.min(Math.max(want, minLeft), maxLeft);
  }

  /** 右栏实际宽度（vp） */
  private calcRightWidth(): number {
    return Math.max(0, this.containerWidth - this.calcLeftWidth());
  }

  /** 是否已完成首次测量：未完成前不渲染任何内容，避免启动时先显示默认分栏再切滑动分页的闪烁 */
  @State private measured: boolean = false;

  /** 容器尺寸变化：更新宽度并按阈值切换布局模式 */
  private handleAreaChange(width: number): void {
    if (width <= 0) {
      return;
    }
    console.log("jizhishitest1122" + String(width))
    const swipe: boolean = width < this.config.collapseThreshold;
    if (!this.measured) {
      // 首次测量：直接落定模式（不做切换动画），宽窗口落定分栏、窄窗口落定滑动分页
      this.containerWidth = width;
      this.isSwipeMode = swipe;
      this.measured = true;
      return;
    }
    if (width !== this.containerWidth) {
      this.containerWidth = width;
    }
    if (swipe !== this.isSwipeMode) {
      // 模式切换使用显式动画，保证过渡平滑
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
        this.isSwipeMode = swipe;
      });
    }
  }

  /** 拖拽开始：记录起始左栏宽度 */
  private onDividerDragStart(): void {
    this.dragStartLeftWidth = this.calcLeftWidth();
  }

  /** 拖拽中：实时更新占比，并做最小宽度边界保护 */
  private onDividerDragUpdate(offsetX: number): void {
    if (this.containerWidth <= 0) {
      return;
    }
    const minLeft: number = this.config.minLeftWidth;
    const maxLeft: number = Math.max(minLeft, this.containerWidth - this.config.minRightWidth);
    let target: number = this.dragStartLeftWidth + offsetX;
    target = Math.min(Math.max(target, minLeft), maxLeft);
    const newRatio: number = target / this.containerWidth;
    if (this.ratio >= 0) {
      // 受控模式：通知外部更新数据源，由外部（可持久化）回同步给组件
      this.onRatioChange(newRatio);
    } else {
      this.innerRatio = newRatio;
      this.onRatioChange(newRatio);
    }
  }

  build() {
    Stack() {
      // 首次测量完成前不渲染：容器宽度未知时无法判定模式，渲染默认分栏会在窄屏启动时闪一帧
      if (this.measured && !this.isSwipeMode) {
        // ============ 左右分栏模式 ============
        Row() {
          Column() {
            this.leftContent();
          }
          // 收起右栏时左栏占满全宽（保持数值宽度，animateTo 切换时有过渡）
          .width(this.rightCollapsed ? this.containerWidth : this.calcLeftWidth())
          .height('100%')
          .clip(true)

          if (!this.rightCollapsed) {
            Column() {
              this.rightContent();
            }
            .width(this.calcRightWidth())
            .height('100%')
            .clip(true)
          }
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY)

        // 编辑模式下悬浮显示可拖拽分隔条（右栏收起时无栏可拖，隐藏）
        if (this.isEditMode && !this.rightCollapsed) {
          Column() {
            // 通高细分隔线（浅色半透明，暗色背景下可见）
            Column()
              .width(1)
              .height('100%')
              .backgroundColor('rgba(255,255,255,0.16)')
            // 中间握把
            Column()
              .width(4)
              .height(36)
              .borderRadius(2)
              .backgroundColor('rgba(255,255,255,0.45)')
              .position({ x: (this.config.handleWidth - 4) / 2, y: '50%' })
              .markAnchor({ x: 0, y: 18 })
          }
          .width(this.config.handleWidth)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .offset({ x: this.calcLeftWidth() - this.config.handleWidth / 2, y: 0 })
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal })
              .onActionStart(() => {
                this.onDividerDragStart();
              })
              .onActionUpdate((event: GestureEvent) => {
                this.onDividerDragUpdate(event.offsetX);
              })
              .onActionEnd(() => {
                // 拖拽结束回调：父组件在此做持久化（避免拖拽中每帧写磁盘）
                this.onDividerDragEnd();
              })
          )
          .transition(TransitionEffect.OPACITY)
        }
      } else if (this.measured) {
        // ============ 滑动分页模式（类 Swiper） ============
        Swiper() {
          Column() {
            this.leftContent();
          }
          .width('100%')
          .height('100%')

          Column() {
            this.rightContent();
          }
          .width('100%')
          .height('100%')
        }
        .loop(false)
        .onChange((index: number) => {
          this.onSwipeIndexChange(index);
        })
        .indicator(
          this.config.showIndicator
            ? Indicator.dot()
              .itemWidth(6)
              .itemHeight(6)
              .selectedItemWidth(6)
              .selectedItemHeight(6)
              .color('#33000000')
              .selectedColor('#99000000')
              .bottom(8)
            : false
        )
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY)
      }
    }
    .width('100%')
    .height('100%')
    // Stack 默认居中对齐会导致悬浮分隔条定位偏移，需改为顶部起始对齐
    .alignContent(Alignment.TopStart)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.handleAreaChange(newValue.width as number);
    })
  }
}
