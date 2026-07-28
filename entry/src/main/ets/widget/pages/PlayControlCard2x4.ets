import ActionUtils from '../model/ActionUtils';
import { CollectAction, PlayActionType } from '../model/FormCardConstant';

const CollectAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
  'right': { 'anchor': '__container__', 'align': HorizontalAlign.End }
};

const TitleAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'top' : { 'anchor': '__container__', 'align': VerticalAlign.Top },
  'left': { 'anchor': 'musicCover', 'align': HorizontalAlign.End }
};

const SingerAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'top': { 'anchor': 'musicTitle', 'align': VerticalAlign.Bottom },
  'left': { 'anchor': 'musicCover', 'align': HorizontalAlign.End }
};

const LyricsAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'bottom': { 'anchor': 'musicControl', 'align': VerticalAlign.Top },
  'left': { 'anchor': 'musicCover', 'align': HorizontalAlign.End }
};

const ControlAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'bottom': { 'anchor': '__container__', 'align': VerticalAlign.Bottom },
  'left': { 'anchor': 'musicCover', 'align': HorizontalAlign.End }
};

let storageUpdateCall = new LocalStorage();

@Entry(storageUpdateCall)
@Component
struct PlayControlCard2x4 {
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('isPlay') isPlay: boolean = false;
  @LocalStorageProp('title') title: string = '暂无播放';
  @LocalStorageProp('isCollected') isCollected: boolean = false;
  @LocalStorageProp('imgName') imgName: ResourceStr = $r('app.media.default_cover');
  @LocalStorageProp('singer') singer: string = '未知歌手';
  @LocalStorageProp('songId') songId: string = '';
  @LocalStorageProp('isNeedRequestUpdate') @Watch('requestData') isNeedRequestUpdate: boolean = false;
  @LocalStorageProp('imageColor') imageColor: string = 'rgba(30,30,30,1)';
  @LocalStorageProp('imageColorHex') imageColorHex: string = '1E1E1E';
  @LocalStorageProp('accentColor') accentColor: string = 'rgba(60,60,60,1)';
  @LocalStorageProp('accentColorHex') accentColorHex: string = '3C3C3C';
  @LocalStorageProp('loaded') loaded: boolean = false;
  @LocalStorageProp('currentLyric') currentLyric: string = '';
  @LocalStorageProp('blurImg') blurImg: string = '';

  // 切歌按钮缩放动效 trigger：值变化即触发一次 ScaleSymbolEffect
  @State prevTrigger: number = 0;
  @State nextTrigger: number = 0;

  requestData() {
    ActionUtils.updateControlCardAction(this, this.formId);
  }

  build() {
    RelativeContainer() {
      Image(this.loaded ? 'memory://' + this.imgName: $r('app.media.default_cover'))
        .height('100%')
        .borderRadius(10)
        .aspectRatio(1)
        .id('musicCover')
        .shadow({
          radius: 12,
          color: 'rgba(0,0,0,0.4)',
          offsetX: 0,
          offsetY: 4
        })
        .onClick(() => {
          ActionUtils.jumpPlayPage(this);
        })

      SymbolGlyph(this.isCollected ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
        .fontSize(24)
        .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), true)
        .fontColor(['#E5FFFFFF'])
        .alignRules(CollectAlignRules)
        .onClick(() => {
          if (this.isCollected) {
            ActionUtils.collectAction(this, CollectAction.UNCOLLECTED, this.formId, this.songId);
          } else {
            ActionUtils.collectAction(this, CollectAction.COLLECTED, this.formId, this.songId);
          }
        })

      Text(this.title)
        .fontSize(16)
        .fontWeight(700)
        .fontColor(Color.White)
        .maxLines(1)
        .margin({
          left: 24
        })
        .alignRules(TitleAlignRules)
        .id('musicTitle')
        .textOverflow({overflow: TextOverflow.Ellipsis})
        .width(140)
        .textShadow({
          radius: 6,
          color: 'rgba(255,255,255,0.25)',
          offsetX: 0,
          offsetY: 0
        })

      Text(this.singer)
        .fontSize(14)
        .fontColor(Color.White)
        .fontWeight(500)
        .opacity(0.6)
        .maxLines(1)
        .id('musicSinger')
        .alignSelf(ItemAlign.Start)
        .margin({
          top: 5,
          left: 24
        })
        .alignRules(SingerAlignRules)
        .textOverflow({overflow: TextOverflow.Ellipsis})
        .width(150)

      Text(this.currentLyric)
        .fontSize(14)
        .maxFontSize(14)
        .minFontSize(10)
        .fontWeight(700)
        .fontColor(Color.White)
        .opacity(0.85)
        .maxLines(2)
        .margin({
          left: 24,
          bottom: 16
        })
        .alignRules(LyricsAlignRules)
        .textAlign(TextAlign.Center)
        .id('musicLyric')
        .textOverflow({overflow: TextOverflow.Ellipsis })
        .width(150)
        .textShadow({
          radius: 8,
          color: `#${this.accentColorHex}40`,
          offsetX: 0,
          offsetY: 0
        })

      Row() {
        SymbolGlyph($r('sys.symbol.backward_end_fill'))
          .fontSize(30)
          .fontColor(['#E5FFFFFF'])
          .symbolEffect(new ScaleSymbolEffect(EffectScope.WHOLE), this.prevTrigger)
          .onClick(() => {
            this.prevTrigger++;
            ActionUtils.playByAction(this, PlayActionType.PREVIOUS, this.formId);
          })

        SymbolGlyph(this.isPlay ? $r('sys.symbol.pause_round_triangle_fill') : $r('sys.symbol.play_round_triangle_fill'))
          .fontSize(30)
          .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), true)
          .fontColor(['#E5FFFFFF'])
          .margin({
            left: 25,
            right: 25
          })
          .onClick(() => {
            if (this.isPlay) {
              ActionUtils.playByAction(this, PlayActionType.PAUSE, this.formId);
            } else {
              ActionUtils.playByAction(this, PlayActionType.PLAY, this.formId);
            }
          })

        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(30)
          .fontColor(['#E5FFFFFF'])
          .symbolEffect(new ScaleSymbolEffect(EffectScope.WHOLE), this.nextTrigger)
          .onClick(() => {
            this.nextTrigger++;
            ActionUtils.playByAction(this, PlayActionType.NEXT, this.formId);
          })
      }
      .height(30)
      .margin({ left: 24 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignRules(ControlAlignRules)
      .id('musicControl')
    }
    .height('100%')
    .width('100%')
    .padding(12)
    .onClick(() => {
      ActionUtils.jumpPlayPage(this);
    })
    // 未加载时显示干净的深色底
    .backgroundColor(this.loaded ? 'rgba(0,0,0,0)' : 'rgba(26,26,26,1)')
    // 预模糊封面铺底
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
  }
}