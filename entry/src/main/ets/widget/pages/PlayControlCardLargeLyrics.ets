import ActionUtils from '../model/ActionUtils';
import { PlayActionType } from '../model/FormCardConstant';

const ControlAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'bottom': { 'anchor': '__container__', 'align': VerticalAlign.Bottom },
  'left': { 'anchor': 'musicCover', 'align': HorizontalAlign.End }
};

interface LyricsLineData {
  time: number;
  text: string;
}

let storageUpdateCall = new LocalStorage();

@Entry(storageUpdateCall)
@Component
struct PlayControlCardLargeLyrics {
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('isPlay') isPlay: boolean = false;
  @LocalStorageProp('title') title: string = '暂无播放';
  @LocalStorageProp('imgName') imgName: ResourceStr = $r('app.media.default_cover');
  @LocalStorageProp('singer') singer: string = '未知歌手';
  @LocalStorageProp('songId') songId: string = '';
  @LocalStorageProp('isNeedRequestUpdate') @Watch('requestData') isNeedRequestUpdate: boolean = false;
  @LocalStorageProp('imageColor') imageColor: string = 'rgba(30,30,30,1)';
  @LocalStorageProp('imageColorHex') imageColorHex: string = '1E1E1E';
  @LocalStorageProp('accentColor') accentColor: string = 'rgba(60,60,60,1)';
  @LocalStorageProp('accentColorHex') accentColorHex: string = '3C3C3C';
  @LocalStorageProp('loaded') loaded: boolean = false;
  @LocalStorageProp('blurImg') blurImg: string = '';
  @LocalStorageProp('parsedLyrics') parsedLyrics: LyricsLineData[] = [];
  @LocalStorageProp('currentLyricsIndex') @Watch('onLyricIndexChange') currentLyricsIndex: number = 0;

  // 卡片（form widget）是受限 ArkUI 子集，不支持 Scroller / scrollToIndex / ScrollAlign /
  // enableScrollInteraction。这里用 translate + animation 手动实现「逐行向上滑动」：
  // 渲染整列歌词，整体 translate 上移「当前行 × 行高」，当前行自然落到视觉中段并高亮；
  // .animation() 把 translate 变化插值成平滑动画。
  // 行高（与下方 Text.lineHeight 对齐）
  private readonly LINE_HEIGHT: number = 42;
  @State lyricTranslateY: number = 0;
  // 切歌按钮缩放动效 trigger：值变化即触发一次 ScaleSymbolEffect
  @State prevTrigger: number = 0;
  @State nextTrigger: number = 0;

  requestData() {
    ActionUtils.updateControlCardAction(this, this.formId);
  }

  onLyricIndexChange() {
    if (this.currentLyricsIndex >= 0) {
      // 每推进一行，整列上移一个行高，当前行落到高亮位
      console.log(`zt Lyric parsedLyrics: ${JSON.stringify(this.parsedLyrics)}
        ${JSON.stringify(this.currentLyricsIndex)}
      `);
      this.lyricTranslateY = -this.currentLyricsIndex * this.LINE_HEIGHT;
    }
  }

  // 分级字号：当前行最大，越远越小
  private lineFontSize(index: number): number {
    const d = Math.abs(index - this.currentLyricsIndex);
    if (d === 0) return 18;
    if (d === 1) return 15;
    if (d === 2) return 15;
    return 13;
  }

  // 分级透明度：当前行不透明，越远越淡
  private lineOpacity(index: number): number {
    const d = Math.abs(index - this.currentLyricsIndex);
    if (d === 0) return 1;
    if (d === 1) return 0.6;
    if (d === 2) return 0.35;
    return 0.18;
  }

  private lineColor(index: number): ResourceColor {
    return index === this.currentLyricsIndex ? Color.White : '#B3FFFFFF';
  }

  build() {
    Column() {
      // 歌词区域（上方主体，layoutWeight 撑满剩余空间）
      if (this.parsedLyrics.length === 0) {
        Column() {
          Text(this.title ? `${this.title} - ${this.singer}` : '')
            .fontSize(24)
            .fontWeight(700)
            .fontColor(Color.White)
            .lineHeight(28)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textShadow({
              radius: 8,
              color: `#${this.accentColorHex}40`,
              offsetX: 0,
              offsetY: 0
            })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, bottom: 10 })
      } else {
        // 单层 Stack 裁剪窗。translateY = -currentLyricsIndex × 行高 把当前行顶到
        // 裁剪窗上沿（y=0）：上一行被推到 y<0 裁掉，下一条在 y=行高 处露出。
        // 不加顶部 padding（会吃掉窗口高度、只剩一行）；横向 padding 不影响行数。
        Stack() {
          Column() {
            ForEach(this.parsedLyrics, (line: LyricsLineData, index: number) => {
              Text(line.text)
                .fontSize(this.lineFontSize(index))
                .fontWeight(index === this.currentLyricsIndex ? 700 : 500)
                .fontColor(this.lineColor(index))
                .opacity(this.lineOpacity(index))
                .lineHeight(this.LINE_HEIGHT)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .textAlign(TextAlign.Center)
                .width('100%')
                .textShadow(index === this.currentLyricsIndex ? {
                  radius: 8,
                  color: `#${this.accentColorHex}40`,
                  offsetX: 0,
                  offsetY: 0
                } : { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
            }, (line: LyricsLineData) => `${line.time}_${line.text}`)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .translate({ y: this.lyricTranslateY })
          .animation({ duration: 450, curve: Curve.EaseInOut })
        }
        .layoutWeight(1)
        .width('100%')
        .clip(true)
        .padding({ left: 16, right: 16, bottom: 10 })
      }

      // 底部控制栏
      Row() {
        Row() {
          Image(this.loaded ? 'memory://' + this.imgName : $r('app.media.default_cover'))
            .height(36)
            .width(36)
            .borderRadius(10)
            .shadow({
              radius: 12,
              color: 'rgba(0,0,0,0.4)',
              offsetX: 0,
              offsetY: 4
            })
          Column() {
            Text(this.title)
              .fontSize(13)
              .fontColor(Color.White)
              .fontWeight(700)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(this.singer)
              .fontSize(11)
              .fontColor('#99FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
              .width('100%')
          }
          .margin({ left: 10 })
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('60%')

        Row() {
          SymbolGlyph($r('sys.symbol.backward_end_fill'))
            .fontSize(24)
            .fontColor(['#E5FFFFFF'])
            .symbolEffect(new ScaleSymbolEffect(EffectScope.WHOLE), this.prevTrigger)
            .onClick(() => {
              this.prevTrigger++;
              ActionUtils.playByAction(this, PlayActionType.PREVIOUS, this.formId);
            })

          SymbolGlyph(this.isPlay ? $r('sys.symbol.pause_round_triangle_fill') : $r('sys.symbol.play_round_triangle_fill'))
            .fontSize(28)
            .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), true)
            .fontColor(['#E5FFFFFF'])
            .margin({ left: 20, right: 20 })
            .onClick(() => {
              if (this.isPlay) {
                ActionUtils.playByAction(this, PlayActionType.PAUSE, this.formId);
              } else {
                ActionUtils.playByAction(this, PlayActionType.PLAY, this.formId);
              }
            })

          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(24)
            .fontColor(['#E5FFFFFF'])
            .symbolEffect(new ScaleSymbolEffect(EffectScope.WHOLE), this.nextTrigger)
            .onClick(() => {
              this.nextTrigger++;
              ActionUtils.playByAction(this, PlayActionType.NEXT, this.formId);
            })
        }
      }
      .width('100%')
      .height(54)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignRules(ControlAlignRules)
      .backgroundColor('rgba(0,0,0,0.3)')
      .padding({ top: 9, left: 10, right: 10, bottom: 9 })
    }
    .height('100%')
    .width('100%')
    // 未加载时显示干净的深色底
    .backgroundColor(this.loaded ? 'rgba(0,0,0,0)' : 'rgba(26,26,26,1)')
    // 预模糊封面铺底（与 PlayControlCard2x4 一致）
    .backgroundImage(this.loaded && this.blurImg ? `memory://${this.blurImg}` : undefined)
    .backgroundImageSize(ImageSize.Cover)
    // 光感晕 - accent 色从封面区域扩散（仅加载后显示）
    .radialGradient({
      center: ['25%', '30%'],
      radius: '65%',
      colors: [
        [this.loaded ? `#${this.accentColorHex}30` : 'rgba(0,0,0,0)', 0.0],
        [this.loaded ? `#${this.accentColorHex}00` : 'rgba(0,0,0,0)', 1.0]
      ]
    })
    // scrim 渐变（4-stop，双色，压暗让白字可读）
    .linearGradient({
      direction: GradientDirection.Bottom,
      repeating: false,
      colors: [
        [this.loaded ? `#${this.imageColorHex}CC` : 'rgba(26,26,26,0.8)', 0.0],
        [this.loaded ? `#${this.accentColorHex}66` : 'rgba(20,20,20,0.85)', 0.3],
        [this.loaded ? `#${this.imageColorHex}99` : 'rgba(15,15,15,0.9)', 0.6],
        [this.loaded ? `#${this.imageColorHex}D9` : 'rgba(10,10,10,0.95)', 1.0]
      ]
    })
    // 玻璃折射边框
    .border({
      width: 1,
      color: this.loaded ? 'rgba(255,255,255,0.18)' : 'rgba(255,255,255,0.08)'
    })
    // 氛围投影（封面色发光悬浮，仅加载后显示）
    .shadow({
      radius: this.loaded ? 40 : 0,
      color: this.loaded ? `#${this.imageColorHex}50` : 'rgba(0,0,0,0)',
      offsetX: 0,
      offsetY: 8
    })
    .onClick(() => {
      ActionUtils.jumpPlayPage(this);
    })
  }
}
