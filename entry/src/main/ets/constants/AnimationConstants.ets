export class AnimationConstants {
  static readonly DAMPING = 0.888; // 拖动阻尼系数
  static readonly ANIMATION_DURATION = 300; // 动画持续时间

  // 现代化动画时长规范
  static readonly DURATION_INSTANT = 100; // 即时反馈
  static readonly DURATION_FAST = 200; // 快速动画
  static readonly DURATION_NORMAL = 300; // 标准动画
  static readonly DURATION_SLOW = 400; // 慢速动画
  static readonly DURATION_SLOWER = 500; // 更慢动画

  // 缓动曲线
  static readonly CURVE_STANDARD = Curve.EaseInOut; // 标准曲线
  static readonly CURVE_DECELERATE = Curve.EaseOut; // 减速曲线
  static readonly CURVE_ACCELERATE = Curve.EaseIn; // 加速曲线
  static readonly CURVE_SHARP = Curve.Sharp; // 锐利曲线
  static readonly CURVE_SMOOTH = Curve.Smooth; // 平滑曲线
  static readonly CURVE_FRICTION = Curve.Friction; // 摩擦曲线
  static readonly CURVE_SPRING = Curve.FastOutSlowIn; // 弹性曲线

  // 页面过渡动画配置
  static readonly PAGE_TRANSITION_DURATION = 350;
  static readonly PAGE_TRANSITION_CURVE = Curve.EaseInOut;

  // 卡片动画配置
  static readonly CARD_HOVER_DURATION = 200;
  static readonly CARD_HOVER_SCALE = 1.02;
  static readonly CARD_PRESS_SCALE = 0.98;

  // 列表项动画配置
  static readonly LIST_ITEM_APPEAR_DURATION = 250;
  static readonly LIST_ITEM_DISAPPEAR_DURATION = 200;

  // 滚动动画配置
  static readonly SCROLL_ANIMATION_DURATION = 300;
  static readonly SCROLL_ANIMATION_CURVE = Curve.EaseOut;

  // 渐变动画配置
  static readonly FADE_DURATION = 250;
  static readonly FADE_CURVE = Curve.Linear;

  // 缩放动画配置
  static readonly SCALE_DURATION = 200;
  static readonly SCALE_CURVE = Curve.EaseOut;

  // 旋转动画配置
  static readonly ROTATE_DURATION = 300;
  static readonly ROTATE_CURVE = Curve.EaseInOut;

  // 位移动画配置
  static readonly TRANSLATE_DURATION = 300;
  static readonly TRANSLATE_CURVE = Curve.EaseOut;
}